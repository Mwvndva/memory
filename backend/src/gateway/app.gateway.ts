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
      const url = new URL(req.url ?? '/', `http://localhost`);
      const token = url.searchParams.get('token');

      if (!token) throw new Error('No token provided');

      const payload = this.jwtService.verify<{ sub: string; username: string }>(
        token,
        { secret: process.env.JWT_SECRET ?? 'change_me_in_production' },
      );

      client.userId   = payload.sub;
      client.username = payload.username;

      // Track in memory-map and Redis
      this.clients.set(payload.sub, client);
      await this.redisService.setSocketSession(payload.sub, payload.sub);

      this.logger.log(`✅ Connected: ${payload.username} (${payload.sub})`);

      this._send(client, { event: 'connected', data: { userId: payload.sub, username: payload.username } });
    } catch (err) {
      this.logger.warn(`❌ Rejected unauthenticated connection`);
      this._send(client, { event: 'auth_error', data: { message: 'Invalid or missing token' } });
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
    if (!client.userId) throw new WsException('Unauthorized');
    if (!payload?.receiver || !payload?.text?.trim()) {
      throw new WsException('Invalid payload: receiver and text are required');
    }

    // Resolve receiver by username → userId from Redis/DB
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
      throw new WsException(`Receiver user "${payload.receiver}" not found`);
    }

    // Persist to PostgreSQL
    const message = await this.messagesService.create({
      senderId: client.userId,
      receiverId: receiverId,
      text: payload.text.trim(),
    });

    const outgoing = {
      id: message.id,
      sender: client.username,
      text: message.text,
      timestamp: message.timestamp,
      is_mine: false,
    };

    // Deliver to receiver if online
    if (receiverSocket) {
      this._send(receiverSocket, { event: 'new_message', data: outgoing });
    }

    // ACK to sender (with is_mine: true for their own display)
    this._send(client, {
      event: 'message_sent',
      data: { ...outgoing, is_mine: true },
    });

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
    if (!client.userId) throw new WsException('Unauthorized');
    if (!payload?.memory_id || !payload?.emoji) {
      throw new WsException('Invalid payload: memory_id and emoji are required');
    }

    let count: number;
    if (payload.action === 'remove') {
      count = await this.redisService.decrementReaction(payload.memory_id, payload.emoji);
    } else {
      count = await this.redisService.incrementReaction(payload.memory_id, payload.emoji);
    }

    const update = { memory_id: payload.memory_id, emoji: payload.emoji, count };

    // Broadcast to all connected clients
    this.clients.forEach((socket) => {
      this._send(socket, { event: 'reaction_update', data: update });
    });

    return update;
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
