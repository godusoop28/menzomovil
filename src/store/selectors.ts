import type { SocialState } from './types';

export function findUser(social: SocialState, userId: string) {
  return social.users.find((u) => u.id === userId);
}

export function findPost(social: SocialState, postId: string) {
  return social.posts.find((p) => p.id === postId);
}

export function findRoom(social: SocialState, roomId: string) {
  return social.rooms.find((r) => r.id === roomId);
}

export function findEvent(social: SocialState, eventId: string) {
  return social.events.find((e) => e.id === eventId);
}

export function commentsForPost(social: SocialState, postId: string) {
  return social.comments
    .filter((c) => c.postId === postId)
    .sort((a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime());
}

export function messagesForRoom(social: SocialState, roomId: string) {
  return social.messages
    .filter((m) => m.roomId === roomId)
    .sort((a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime());
}

export function wallMessagesForProfile(social: SocialState, profileId: string) {
  return social.wallMessages
    .filter((w) => w.profileId === profileId)
    .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
}

export function wallCommentsForMessage(social: SocialState, wallMessageId: string) {
  return social.wallComments
    .filter((c) => c.wallMessageId === wallMessageId)
    .sort((a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime());
}

export function postsByAuthor(social: SocialState, authorId: string) {
  return social.posts
    .filter((p) => p.authorId === authorId)
    .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
}

export function savedPosts(social: SocialState, userId: string) {
  return social.posts
    .filter((p) => p.bookmarkedBy.includes(userId))
    .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
}

export function featuredPosts(social: SocialState) {
  return social.posts.filter((p) => p.featured);
}

export function recentPosts(social: SocialState) {
  return [...social.posts].sort(
    (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
  );
}

export function onlineUsers(social: SocialState) {
  return social.users.filter((u) => u.isOnline);
}

export function unreadNotificationCount(social: SocialState) {
  return social.notifications.filter((n) => !n.read).length;
}
