import { buildNotificationContent } from '../src/notifications/notification-content';

/**
 * These payloads are copied verbatim from the producers. The bodies previously
 * read keys that no producer ever sent (`requester`, `count`, `creator`), so
 * three of the five push notifications rendered as "@Someone …" / "0 members".
 * Asserting against the real payload shapes is what stops that recurring.
 */
describe('buildNotificationContent', () => {
  it('renders a message notification from gateway.handleMessage payload', () => {
    const content = buildNotificationContent('new_message', {
      id: 'msg-1',
      sender: 'amara',
      text: 'See you tonight',
      timestamp: new Date().toISOString(),
      is_mine: false,
    });

    expect(content.type).toBe('message');
    expect(content.title).toBe('Message from @amara');
    expect(content.body).toBe('See you tonight');
    expect(content.data.messageId).toBe('msg-1');
  });

  it('renders a circle request from CirclesService payload (senderUsername)', () => {
    const content = buildNotificationContent('new_circle_request', {
      senderId: 'u-1',
      senderUsername: 'amara',
      senderFirstName: 'Amara',
      senderAvatarUrl: null,
    });

    expect(content.type).toBe('circleRequest');
    expect(content.body).toBe('@amara wants to add you to their circle.');
    expect(content.body).not.toContain('Someone');
    expect(content.data.senderId).toBe('u-1');
  });

  it('renders a milestone from CirclesService payload (milestone, not count)', () => {
    const content = buildNotificationContent('new_circle_milestone', {
      circleOwnerId: 'u-1',
      circleOwnerUsername: 'amara',
      milestone: 10,
      members: [],
    });

    expect(content.type).toBe('circleMilestone');
    expect(content.body).toBe("@amara's circle reached 10 members!");
    expect(content.data.milestone).toBe('10');
  });

  it('renders a new memory from MemoriesService payload (creatorUsername)', () => {
    const content = buildNotificationContent('new_memory', {
      creatorName: 'Amara',
      creatorUsername: 'amara',
      memoryId: 'm-1',
    });

    expect(content.type).toBe('memory');
    expect(content.body).toBe('@amara posted a new memory!');
    expect(content.data.memoryId).toBe('m-1');
  });

  it('falls back to the display name when a memory has no creator handle', () => {
    const content = buildNotificationContent('new_memory', {
      creatorName: 'Amara',
    });

    expect(content.body).toBe('Amara posted a new memory!');
  });

  it('renders a reaction from gateway.handleReaction payload', () => {
    const content = buildNotificationContent('new_reaction', {
      reactorName: 'amara',
      emoji: '🔥',
      memoryCaption: 'The cake moment',
      memoryId: 'm-1',
    });

    expect(content.type).toBe('reaction');
    expect(content.body).toBe(
      '@amara reacted 🔥 to your memory: "The cake moment"',
    );
    expect(content.data.memoryId).toBe('m-1');
  });

  it('produces a safe default for an unknown event', () => {
    const content = buildNotificationContent('something_new', {});
    expect(content.type).toBe('message');
    expect(content.data.event).toBe('something_new');
  });
});
