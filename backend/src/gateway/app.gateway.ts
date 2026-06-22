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
import { URL } from 'url';
import { WebSocket, WebSocketServer as WsServer } from 'ws';
import { Logger, OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import { RedisService } from '../redis/redis.service';
import { MessagesService } from '../messages/messages.service';
import { PrismaService } from '../prisma/prisma.service';
import Redis from 'ioredis';

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
export class AppGateway implements OnGatewayConnection, OnGatewayDisconnect, OnModuleInit, OnModuleDestroy {
  @WebSocketServer()
  server: WsServer;

  private readonly logger = new Logger(AppGateway.name);

  // Map userId → AuthenticatedSocket for targeted delivery
  private readonly clients = new Map<string, AuthenticatedSocket>();

  private subClient: Redis;

  constructor(
    private readonly redisService: RedisService,
    private readonly messagesService: MessagesService,
    private readonly prisma: PrismaService,
  ) {}

  // ─── Redis Pub/Sub horizontal scale message bus ────────────────────────────

  async onModuleInit() {
    this.logger.log('[Redis Pub/Sub] Initializing WebSocket message bus subscriber...');
    const redisClient = this.redisService.getClient();
    this.subClient = redisClient.duplicate();

    await this.subClient.subscribe('ws:message_bus');

    this.subClient.on('message', (channel, message) => {
      if (channel === 'ws:message_bus') {
        try {
          const payload = JSON.parse(message) as { userId: string; event: string; data: any };
          
          if (payload.userId === '*') {
            // Broadcast to all clients connected to this server instance
            this.clients.forEach((socket) => {
              this._send(socket, { event: payload.event, data: payload.data });
            });
          } else {
            // Unicast to a specific client connected to this server instance
            const socket = this.clients.get(payload.userId);
            if (socket) {
              this._send(socket, { event: payload.event, data: payload.data });
            }
          }
        } catch (err) {
          this.logger.error(`[Redis Pub/Sub] Failed to process message bus event: ${err.message}`);
        }
      }
    });
    this.logger.log('[Redis Pub/Sub] WebSocket message bus successfully subscribed.');
  }

  async onModuleDestroy() {
    this.logger.log('[Redis Pub/Sub] Disconnecting WebSocket message bus subscriber...');
    if (this.subClient) {
      await this.subClient.quit();
    }
  }

  // ─── Connection: validate one-time WS ticket from URL query param ────────────
  //
  // Clients MUST call POST /auth/ws-ticket first (JwtAuthGuard protected),
  // receive a 30-second opaque ticket, then connect as:
  //   ws://<host>/ws?ticket=<hex-ticket>
  //
  // The ticket is atomically consumed on first use (Redis GETDEL) so replay
  // attacks after a successful upgrade handshake are impossible.
  // No JWT ever appears in Sec-WebSocket-Protocol or any loggable header.

  async handleConnection(client: AuthenticatedSocket, req: IncomingMessage) {
    try {
      // Parse the ticket from the upgrade request URL (?ticket=<hex>).
      // req.url is the raw path+query of the WebSocket upgrade request.
      const reqUrl = req.url ?? '';
      const base = 'ws://placeholder'; // URL requires an absolute base to parse relative paths
      const parsedUrl = new URL(reqUrl, base);
      const ticket = parsedUrl.searchParams.get('ticket')?.trim();

      if (!ticket || ticket.length !== 64) {
        // 64 hex chars = 32 bytes = 256 bits.  Wrong length means forged/missing.
        throw new Error('Missing or malformed ticket');
      }

      // Atomically redeem the ticket (GET + DEL in a single Lua script).
      // Returns null if expired, already consumed, or not found.
      const identity = await this.redisService.redeemWsTicket(ticket);
      if (!identity) {
        throw new Error('Ticket expired or already used');
      }

      const { userId, username } = identity;
      client.userId   = userId;
      client.username = username;

      // Track in the in-process map and Redis (for cross-instance awareness)
      this.clients.set(userId, client);
      await this.redisService.setSocketSession(userId, userId);

      client.on('close', (code: number, reason: Buffer) => {
        this.logger.warn(
          `🔌 Socket closed for ${username} code=${code} reason=${reason?.toString?.() ?? ''}`,
        );
      });

      this.logger.log(`✅ Connected: ${username} (${userId})`);
      this._send(client, { event: 'connected', data: { userId, username } });
    } catch (err) {
      this.logger.warn(`❌ Rejected WS connection: ${err?.message ?? err}`);
      try {
        this._send(client, { event: 'auth_error', data: { message: 'Invalid or expired ticket' } });
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

    // Rate limit check: max 30 WebSocket events per user per minute
    const rlKey = `ws:actions:${client.userId}`;
    const rl = await this.redisService.rateLimit(rlKey, 60);
    if (rl.count > 30) {
      this.logger.warn(`[WS send_message] Rate limit exceeded for user "${client.username}"`);
      throw new WsException('Rate limit exceeded. Please wait a minute.');
    }

    if (!payload?.receiver || typeof payload.receiver !== 'string' || !payload.receiver.trim()) {
      throw new WsException('Invalid payload: receiver is required and must be a non-empty string');
    }
    if (!payload?.text || typeof payload.text !== 'string' || !payload.text.trim()) {
      throw new WsException('Invalid payload: text is required and must be a non-empty string');
    }
    if (payload.text.length > 2000) {
      throw new WsException('Message is too long (max 2000 characters)');
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

    // Deliver to receiver if online (via the Redis message bus to support multi-instance)
    this.logger.log(`[WS send_message] Step 4: Dispatching event to receiver via Redis message bus`);
    await this.sendToUser(receiverId, 'new_message', outgoingPayload);

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

    // Rate limit check: max 30 WebSocket events per user per minute
    const rlKey = `ws:actions:${client.userId}`;
    const rl = await this.redisService.rateLimit(rlKey, 60);
    if (rl.count > 30) {
      this.logger.warn(`[WS send_reaction] Rate limit exceeded for user "${client.username}"`);
      throw new WsException('Rate limit exceeded. Please wait a minute.');
    }

    if (!payload?.memory_id || typeof payload.memory_id !== 'string') {
      throw new WsException('Invalid payload: memory_id is required and must be a string');
    }
    if (!payload?.emoji || typeof payload.emoji !== 'string') {
      throw new WsException('Invalid payload: emoji is required and must be a string');
    }
    if (payload.emoji.length > 8) {
      throw new WsException('Emoji is too long (max 8 characters)');
    }
    if (payload.action !== 'add' && payload.action !== 'remove') {
      throw new WsException("Invalid action: action must be 'add' or 'remove'");
    }

    this.logger.log(`[WS send_reaction] Step 1: Updating reaction count in Redis`);
    let count: number;
    if (payload.action === 'remove') {
      count = await this.redisService.decrementReaction(payload.memory_id, payload.emoji);
    } else {
      count = await this.redisService.incrementReaction(payload.memory_id, payload.emoji);
    }

    const update = { memory_id: payload.memory_id, emoji: payload.emoji, count };

    // Broadcast to all connected clients across all server instances
    this.logger.log(`[WS send_reaction] Step 2: Broadcasting reaction update to all online clients via Redis bus`);
    await this.broadcast('reaction_update', update);

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

  /** Send an event to a specific user across any server instance via Redis Pub/Sub. */
  async sendToUser(userId: string, event: string, data: unknown) {
    try {
      const payload = JSON.stringify({ userId, event, data });
      await this.redisService.getClient().publish('ws:message_bus', payload);
    } catch (err) {
      this.logger.error(`[Redis Pub/Sub] Failed to publish event to user "${userId}": ${err.message}`);
    }
  }

  /** Broadcast an event to all users across all server instances via Redis Pub/Sub. */
  async broadcast(event: string, data: unknown) {
    try {
      const payload = JSON.stringify({ userId: '*', event, data });
      await this.redisService.getClient().publish('ws:message_bus', payload);
    } catch (err) {
      this.logger.error(`[Redis Pub/Sub] Failed to publish broadcast event: ${err.message}`);
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
