/**
 * Single source of truth translating a realtime event + payload into the
 * human-readable content shown in a push notification and stored in the
 * notification history.
 *
 * Both surfaces must agree: a user who receives a push and then opens the
 * notification screen should see the same words.
 */

/** Mirrors the client's `NotificationType` enum names exactly. */
export type NotificationKind =
  | 'message'
  | 'reaction'
  | 'memory'
  | 'circleRequest'
  | 'circleMilestone';

export interface NotificationContent {
  type: NotificationKind;
  title: string;
  body: string;
  /** Flat string map — FCM data payloads and the client model both require it. */
  data: Record<string, string>;
}

/** Coerce to a non-empty string, or undefined. */
function str(value: unknown): string | undefined {
  if (typeof value === 'string' && value.length > 0) return value;
  if (typeof value === 'number') return String(value);
  return undefined;
}

/**
 * The `payload` keys below are the ones actually emitted by the producers:
 *   - new_message         → gateway.handleMessage
 *   - new_reaction        → gateway.handleReaction
 *   - new_memory          → MemoriesService.create
 *   - new_circle_request  → CirclesService.sendRequest
 *   - new_circle_milestone→ CirclesService.checkAndBroadcastCircleMilestone
 */
export function buildNotificationContent(
  event: string,
  payload: Record<string, unknown>,
): NotificationContent {
  switch (event) {
    case 'new_message': {
      const sender = str(payload.sender) ?? 'Someone';
      const data: Record<string, string> = { event, sender };
      const messageId = str(payload.id);
      if (messageId) data.messageId = messageId;
      return {
        type: 'message',
        title: `Message from @${sender}`,
        body: str(payload.text) ?? 'Sent a message.',
        data,
      };
    }

    case 'new_reaction': {
      const reactor = str(payload.reactorName) ?? 'Someone';
      const emoji = str(payload.emoji) ?? '❤️';
      const caption = str(payload.memoryCaption);
      const data: Record<string, string> = { event, emoji };
      const memoryId = str(payload.memoryId);
      if (memoryId) data.memoryId = memoryId;
      return {
        type: 'reaction',
        title: 'New Reaction',
        body: `@${reactor} reacted ${emoji} to your memory${
          caption ? `: "${caption}"` : '.'
        }`,
        data,
      };
    }

    case 'new_memory': {
      // Producers send creatorUsername (handle) and creatorName (display name).
      const handle = str(payload.creatorUsername);
      const name = str(payload.creatorName) ?? 'Someone';
      const data: Record<string, string> = { event };
      if (handle) data.creatorUsername = handle;
      const memoryId = str(payload.memoryId);
      if (memoryId) data.memoryId = memoryId;
      return {
        type: 'memory',
        title: 'New Memory Shared',
        body: handle
          ? `@${handle} posted a new memory!`
          : `${name} posted a new memory!`,
        data,
      };
    }

    case 'new_circle_request': {
      const requester = str(payload.senderUsername) ?? 'Someone';
      const data: Record<string, string> = { event, senderUsername: requester };
      const senderId = str(payload.senderId);
      if (senderId) data.senderId = senderId;
      return {
        type: 'circleRequest',
        title: 'New Circle Request',
        body: `@${requester} wants to add you to their circle.`,
        data,
      };
    }

    case 'new_circle_milestone': {
      const milestone = str(payload.milestone) ?? '0';
      const owner = str(payload.circleOwnerUsername);
      return {
        type: 'circleMilestone',
        title: 'Circle Milestone Reached!',
        body: `${owner ? `@${owner}'s circle` : 'Your circle'} reached ${milestone} members!`,
        data: { event, milestone },
      };
    }

    default:
      return {
        type: 'message',
        title: 'New Notification',
        body: 'You have a new update in Memory.',
        data: { event },
      };
  }
}
