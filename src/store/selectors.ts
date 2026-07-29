import type { SocialState } from './types';

/** Date.parse en Hermes puede devolver NaN para timestamps mal formados; tratarlo como 0
 * evita que Array.sort trate esas entradas como "iguales" y las deje en cualquier posición. */
function safeTime(iso: string): number {
  const t = new Date(iso).getTime();
  return Number.isNaN(t) ? 0 : t;
}

/** Ascendente por fecha, con el id como desempate estable para no reordenar en cada render
 * cuando dos elementos comparten el mismo timestamp. */
function byCreatedAtAsc<T extends { createdAt: string; id: string }>(a: T, b: T): number {
  return safeTime(a.createdAt) - safeTime(b.createdAt) || a.id.localeCompare(b.id);
}

function byCreatedAtDesc<T extends { createdAt: string; id: string }>(a: T, b: T): number {
  return safeTime(b.createdAt) - safeTime(a.createdAt) || b.id.localeCompare(a.id);
}

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
  return social.comments.filter((c) => c.postId === postId).sort(byCreatedAtAsc);
}

export function messagesForRoom(social: SocialState, roomId: string) {
  return social.messages.filter((m) => m.roomId === roomId).sort(byCreatedAtAsc);
}

export function wallMessagesForProfile(social: SocialState, profileId: string) {
  return social.wallMessages.filter((w) => w.profileId === profileId).sort(byCreatedAtDesc);
}

export function wallCommentsForMessage(social: SocialState, wallMessageId: string) {
  return social.wallComments.filter((c) => c.wallMessageId === wallMessageId).sort(byCreatedAtAsc);
}

export function postsByAuthor(social: SocialState, authorId: string) {
  return social.posts.filter((p) => p.authorId === authorId).sort(byCreatedAtDesc);
}

export function savedPosts(social: SocialState, userId: string) {
  return social.posts.filter((p) => p.bookmarkedBy.includes(userId)).sort(byCreatedAtDesc);
}

export function featuredPosts(social: SocialState) {
  return social.posts.filter((p) => p.featured);
}

export function recentPosts(social: SocialState) {
  return [...social.posts].sort(byCreatedAtDesc);
}

export function onlineUsers(social: SocialState) {
  return social.users.filter((u) => u.isOnline);
}

export function unreadNotificationCount(social: SocialState) {
  return social.notifications.filter((n) => !n.read).length;
}
