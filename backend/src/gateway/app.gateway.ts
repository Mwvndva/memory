import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  OnGatewayConnection,
  OnGatewayDisconnect,
  MessageBody,
  ConnectedSocket,
  WsException,
} from '@nestjs/websockets';
import { IncomingMessage } from 'http';
import { WebSocket, WebSocketServer as WsServer } from 'ws';
import { JwtService } from '@nestjs/jwt';
import { Logger } from '@nestjs/common';
import { RedisService } from '../redis/redis.service';
import { MessagesService } from '../messages/messages.service';
import { PrismaService } from '../prisma/prisma.service';

// ─── Socket data attached per connection ───────────────────────────────────
interface AuthenticatedSocket extends WebSocket {
  userId: string;
  username: string;
}

// ─── Payload types ─────────────────────────────────────────────────────────
interface SendMessagePayload {
  receiver: string;  // username (Flutter sends contact name/username)
  text: string;
}

interface ReactionPayload {
  memory_id: string;
  emoji: string;
  action: 'add' | 'remove';
}

// ─── Gateway ───────────────────────────────────────────────────────────────

@WebSocketGateway({ path: '/ws' })
export class AppGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: WsServer;

  private readonly logger = new Logger(AppGateway.name);

  // Map userId → AuthenticatedSocket for targeted delivery
  private readonly clients = new Map<string, AuthenticatedSocket>();

  constructor(
    private readonly jwtService: JwtService,
    private readonly redisService: RedisService,
    private readonly messagesService: MessagesService,
    private readonly prisma: PrismaService,
  ) {}

  // ─── Connection: validate JWT from query param ─────────────────────────────

  async handleConnection(client: AuthenticatedSocket, req: IncomingMessage) {
    try {
      // Prefer Authorization header (Bearer <token>). If not present,
      // fall back to Sec-WebSocket-Protocol (useful for browser clients
      // which cannot set arbitrary headers during the WebSocket upgrade).
      const headers = (req.headers || {}) as Record<string, unknown>;
      let token: string | undefined;

      const authHeader = (headers['authorization'] || headers['Authorization']) as string | undefined;
      if (authHeader && authHeader.startsWith('Bearer ')) {
        token = authHeader.slice(7).trim();
      }

      // Fallback: some clients pass the token inside Sec-WebSocket-Protocol
      if (!token && headers['sec-websocket-protocol']) {
        const proto = String(headers['sec-websocket-protocol']);
        // May be comma-separated list; pick the first entry that looks like a JWT
        const candidates = proto.split(',').map((s) => s.trim()).filter(Boolean);
        for (const p of candidates) {
          if (p.startsWith('Bearer ')) {
            token = p.slice(7).trim();
            break;
          }
          // crude JWT shape check: contains two dots
          if (p.split('.').length === 3) {
            token = p;
            break;
          }
        }
      }

      if (!token) throw new Error('No token provided');

      // Use the application's JwtService (configured via JwtModule). Avoid
      // supplying a silent fallback secret here so missing secrets fail fast.
      const payload = this.jwtService.verify<{ sub: string; username: string }>(token);

      client.userId = payload.sub;
      client.username = payload.username;

      // Track in memory-map and Redis
      this.clients.set(payload.sub, client);
      await this.redisService.setSocketSession(payload.sub, payload.sub);

      client.on('close', (code: number, reason: Buffer) => {
        this.logger.warn(
          `🔌 Socket closed for ${client.username || payload.username} code=${code} reason=${reason?.toString?.() ?? ''}`,
        );
      });

      this.logger.log(`✅ Connected: ${payload.username} (${payload.sub})`);

      this._send(client, { event: 'connected', data: { userId: payload.sub, username: payload.username } });
    } catch (err) {
      this.logger.warn(`❌ Rejected unauthenticated connection: ${err?.message ?? err}`);
      try {
        this._send(client, { event: 'auth_error', data: { message: 'Invalid or missing token' } });
      } catch (_) {}
      client.terminate();
    }
  }

  // ─── Disconnection ─────────────────────────────────────────────────────────

  async handleDisconnect(client: AuthenticatedSocket) {
    if (client.userId) {
      this.clients.delete(client.userId);
      await this.redisService.removeSocketSession(client.userId);
      this.logger.log(`🔌 Disconnected: ${client.username}`);
    }
  }

  // ─── Event: send_message ───────────────────────────────────────────────────
  //
  // Flutter emits: { "receiver": "<username>", "text": "Hello!" }
  // Server emits to receiver: { event: "new_message", data: { id, sender, text, timestamp, is_mine: false } }
  // Server emits ACK to sender: { event: "message_sent", data: { ... } }

  @SubscribeMessage('send_message')
  async handleMessage(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() payload: SendMessagePayload,
  ) {
    this.logger.log(`[WS send_message] Message from client="${client.username}" to receiver="${payload?.receiver}"`);
    if (!client.userId) throw new WsException('Unauthorized');
    if (!payload?.receiver || !payload?.text?.trim()) {
      throw new WsException('Invalid payload: receiver and text are required');
    }

    // Resolve receiver by username → userId from Redis/DB
    this.logger.log(`[WS send_message] Step 1: Resolving receiver user UUID for username="${payload.receiver}"`);
    const receiverSocket = this._findByUsername(payload.receiver);
    let receiverId = receiverSocket?.userId;

    if (!receiverId) {
      // Receiver not connected; query DB for their UUID
      const dbUser = await this.prisma.user.findUnique({
        where: { username: payload.receiver },
        select: { id: true },
      });
      if (dbUser) {
        receiverId = dbUser.id;
      }
    }

    if (!receiverId) {
      this.logger.warn(`[WS send_message] Receiver user "${payload.receiver}" not found`);
      throw new WsException(`Receiver user "${payload.receiver}" not found`);
    }

    // Verify sender has added (and has accepted) the receiver in their circle.
    this.logger.log(`[WS send_message] Step 2: Verifying active circle membership between client="${client.username}" and receiver="${payload.receiver}"`);
    const outgoing = await this.prisma.circleMembership.findUnique({
      where: { unique_user_member: { userId: client.userId, memberId: receiverId } },
    });
    const incoming = await this.prisma.circleMembership.findUnique({
      where: { unique_user_member: { userId: receiverId, memberId: client.userId } },
    });

    if (!((outgoing && outgoing.accepted) || (incoming && incoming.accepted))) {
      this.logger.warn(`[WS send_message] Blocked: client="${client.username}" is not allowed to message receiver="${payload.receiver}"`);
      throw new WsException(`You are not allowed to message @${payload.receiver}`);
    }

    // Persist to PostgreSQL
    this.logger.log(`[WS send_message] Step 3: Persisting message in database`);
    const message = await this.messagesService.create({
      senderId: client.userId,
      receiverId: receiverId,
      text: payload.text.trim(),
    });

    const outgoingPayload = {
      id: message.id,
      sender: client.username,
      text: message.text,
      timestamp: message.timestamp,
      is_mine: false,
    };

    // Deliver to receiver if online
    this.logger.log(`[WS send_message] Step 4: Delivering event to receiver if online`);
    if (receiverSocket) {
      this._send(receiverSocket, { event: 'new_message', data: outgoingPayload });
      this.logger.log(`[WS send_message] Delivered 'new_message' to receiver="${payload.receiver}" online`);
    } else {
      this.logger.log(`[WS send_message] Receiver="${payload.receiver}" is offline; message saved for retrieval`);
    }

    // ACK to sender (with is_mine: true for their own display)
    this.logger.log(`[WS send_message] Step 5: Sending ACK back to sender client`);
    this._send(client, {
      event: 'message_sent',
      data: { ...outgoingPayload, is_mine: true },
    });

    this.logger.log(`[WS send_message] Message processed successfully: msgId="${message.id}"`);
    return message;
  }

  // ─── Event: send_reaction ──────────────────────────────────────────────────
  //
  // Flutter emits: { "memory_id": "uuid", "emoji": "😂", "action": "add" }
  // Server broadcasts to all: { event: "reaction_update", data: { memory_id, emoji, count } }

  @SubscribeMessage('send_reaction')
  async handleReaction(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() payload: ReactionPayload,
  ) {
    this.logger.log(`[WS send_reaction] Reaction update by client="${client.username}" for memoryId="${payload?.memory_id}" emoji="${payload?.emoji}" action="${payload?.action}"`);
    if (!client.userId) throw new WsException('Unauthorized');
    if (!payload?.memory_id || !payload?.emoji) {
      throw new WsException('Invalid payload: memory_id and emoji are required');
    }

    this.logger.log(`[WS send_reaction] Step 1: Updating reaction count in Redis`);
    let count: number;
    if (payload.action === 'remove') {
      count = await this.redisService.decrementReaction(payload.memory_id, payload.emoji);
    } else {
      count = await this.redisService.incrementReaction(payload.memory_id, payload.emoji);
    }

    const update = { memory_id: payload.memory_id, emoji: payload.emoji, count };

    // Broadcast to all connected clients
    this.logger.log(`[WS send_reaction] Step 2: Broadcasting reaction update to all online clients`);
    this.clients.forEach((socket) => {
      this._send(socket, { event: 'reaction_update', data: update });
    });

    // Notify the memory creator of the new reaction (if they are not the reactor)
    if (payload.action !== 'remove') {
      this.logger.log(`[WS send_reaction] Step 3: Notifying memory creator of new reaction`);
      try {
        const memory = await this.prisma.memory.findUnique({
          where: { id: payload.memory_id },
          select: { creatorId: true, caption: true },
        });
        if (memory && memory.creatorId !== client.userId) {
          this.sendToUser(memory.creatorId, 'new_reaction', {
            reactorName: client.username,
            emoji: payload.emoji,
            memoryCaption: memory.caption,
          });
          this.logger.log(`[WS send_reaction] Sent 'new_reaction' notification to memory creatorId="${memory.creatorId}"`);
        }
      } catch (err) {
        this.logger.error(`[WS send_reaction] Failed to send reaction notification: ${err.message}`);
      }
    }

    this.logger.log(`[WS send_reaction] Reaction update processed successfully: memoryId="${payload.memory_id}" count=${count}`);
    return update;
  }

  @SubscribeMessage('ping')
  handlePing(@ConnectedSocket() client: AuthenticatedSocket) {
    if (!client.userId) throw new WsException('Unauthorized');
    this._send(client, { event: 'pong', data: { ts: Date.now() } });
    return { ok: true };
  }

  /** Send an event to a specific user if they are online. */
  sendToUser(userId: string, event: string, data: unknown) {
    const socket = this.clients.get(userId);
    if (socket) {
      this._send(socket, { event, data });
    }
  }

  // ─── Event: get_online_users ───────────────────────────────────────────────

  @SubscribeMessage('get_online_users')
  async handleGetOnlineUsers(@ConnectedSocket() client: AuthenticatedSocket) {
    if (!client.userId) throw new WsException('Unauthorized');
    const onlineUsers = await this.redisService.getOnlineUserIds();
    this._send(client, { event: 'online_users', data: { onlineUsers } });
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  /** Send a typed JSON frame to a single raw WebSocket client. */
  private _send(client: WebSocket, payload: { event: string; data: unknown }) {
    if (client.readyState === WebSocket.OPEN) {
      client.send(JSON.stringify(payload));
    }
  }

  /** Find an online client by their username (O(n) but n is small for a small app). */
  private _findByUsername(username: string): AuthenticatedSocket | undefined {
    for (const [, socket] of this.clients) {
      if (socket.username === username) return socket;
    }
    return undefined;
  }
}
