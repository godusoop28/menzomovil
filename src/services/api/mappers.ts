import { LOCAL_USER_ID } from '@/store/localUser';
import { Gradients, type GradientId } from '@/theme';
import type {
  AbstractVisualPreset,
  ChatRoom,
  ChatRoomRole,
  Comment,
  CommunityEvent,
  DemoUser,
  Message,
  Notification,
  Post,
  RoomBan,
  RoomMember,
  UserProfile,
  WallComment,
  WallMessage,
} from '@/types';

import type {
  BanDto,
  ChatRoomDto,
  CommentDto,
  EventDto,
  MessageDto,
  NotificationDto,
  PostDto,
  RoomMemberDto,
  UserProfileDto,
  UserSummaryDto,
  WallCommentDto,
  WallMessageDto,
} from './types';

/**
 * La app fue construida asumiendo un único usuario local identificado con LOCAL_USER_ID.
 * Como la API sí es multiusuario (IDs UUID reales), toda respuesta que mencione al usuario
 * autenticado se "traduce" a LOCAL_USER_ID acá, en el borde API→estado local. Así el resto
 * de las 36 pantallas que ya comparan contra LOCAL_USER_ID no necesitan tocarse.
 */
function alias(id: string, myRealId: string | null): string {
  return myRealId && id === myRealId ? LOCAL_USER_ID : id;
}

/**
 * Varias pantallas usan `likes.length`/`likes.includes(id)` (o attendees/votes) para mostrar
 * conteo + "¿lo hice yo?" a la vez, porque el mock original era una lista real de IDs.
 * La API solo da count + booleano-por-viewer, así que se sintetiza un array del tamaño correcto
 * (ningún componente itera estos arrays salvo por .length/.includes, así que es seguro).
 */
function synthArray(count: number, includeMe: boolean): string[] {
  return Array.from({ length: Math.max(count, 0) }, (_, i) => (includeMe && i === 0 ? LOCAL_USER_ID : `other-${i}`));
}

function toGradient(value: string | null | undefined, fallback: GradientId = 'fire'): GradientId {
  return value && value in Gradients ? (value as GradientId) : fallback;
}

export function mapUserProfile(dto: UserProfileDto, myRealId: string | null): UserProfile {
  return {
    id: alias(dto.id, myRealId),
    displayName: dto.displayName,
    username: dto.username,
    avatarUri: dto.avatarUri ?? undefined,
    avatarGradient: toGradient(dto.avatarGradient),
    coverUri: dto.coverUri ?? undefined,
    backgroundUri: dto.backgroundUri ?? undefined,
    backgroundColor: dto.backgroundColor ?? undefined,
    aura: dto.aura as UserProfile['aura'],
    bio: dto.bio ?? '',
    statusText: dto.statusText ?? '',
    interests: dto.interests as UserProfile['interests'],
    joinedAt: dto.joinedAt,
    level: dto.level,
    xp: dto.xp,
    reputation: dto.reputation,
    followers: dto.followers,
    following: dto.following,
    visitors: dto.visitors,
    isOnline: dto.isOnline,
    badges: dto.badges,
    isLocalUser: !!myRealId && dto.id === myRealId,
    followedByMe: dto.followedByMe,
    followsMe: dto.followsMe,
  };
}

export function mapDemoUser(dto: UserProfileDto, myRealId: string | null): DemoUser {
  return { ...mapUserProfile(dto, myRealId), activityStatus: dto.statusText ?? '' };
}

/**
 * Posts/mensajes/comentarios traen solo un `UserSummaryDto` embebido (no el perfil completo).
 * Se usa para tener SIEMPRE una entrada en `state.social.users` para ese autor —si no,
 * PostCard/ChatBubble/etc. no encuentran al autor y no renderizan nada—, con placeholders
 * razonables en los campos que ese resumen no trae (nivel, reputación, bio...).
 */
export function mapUserSummary(dto: UserSummaryDto, myRealId: string | null): DemoUser {
  return {
    id: alias(dto.id, myRealId),
    displayName: dto.displayName,
    username: dto.username,
    avatarUri: dto.avatarUri ?? undefined,
    avatarGradient: toGradient(dto.avatarGradient),
    aura: 'fuego',
    bio: '',
    statusText: '',
    interests: [],
    joinedAt: new Date().toISOString(),
    level: 1,
    xp: 0,
    reputation: 0,
    followers: 0,
    following: 0,
    visitors: 0,
    isOnline: dto.isOnline,
    badges: [],
    isLocalUser: !!myRealId && dto.id === myRealId,
    activityStatus: '',
  };
}

export function mapRoomMember(dto: RoomMemberDto, myRealId: string | null): RoomMember {
  return { user: mapUserSummary(dto.user, myRealId), role: dto.role.toLowerCase() as ChatRoomRole, joinedAt: dto.joinedAt };
}

export function mapBan(dto: BanDto, myRealId: string | null): RoomBan {
  return {
    user: mapUserSummary(dto.user, myRealId),
    reason: dto.reason,
    createdAt: dto.createdAt,
    bannedBy: dto.bannedBy ? mapUserSummary(dto.bannedBy, myRealId) : null,
  };
}

export function mapPost(dto: PostDto, myRealId: string | null): Post {
  return {
    id: dto.id,
    authorId: alias(dto.author.id, myRealId),
    type: dto.type,
    title: dto.title ?? undefined,
    body: dto.body,
    abstractVisual: dto.abstractVisual
      ? { preset: dto.abstractVisual.preset as AbstractVisualPreset, caption: dto.abstractVisual.caption ?? undefined }
      : undefined,
    imageUri: dto.imageUri ?? undefined,
    createdAt: dto.createdAt,
    likes: synthArray(dto.likeCount, dto.likedByMe),
    bookmarkedBy: dto.bookmarkedByMe ? [LOCAL_USER_ID] : [],
    commentCount: dto.commentCount,
    featured: dto.featured,
    tags: dto.tags,
    pollOptions:
      dto.pollOptions.length > 0
        ? dto.pollOptions.map((o) => ({ id: o.id, label: o.label, votes: synthArray(o.voteCount, o.votedByMe) }))
        : undefined,
    eventId: dto.eventId ?? undefined,
    gradient: toGradient(dto.gradient),
  };
}

export function mapComment(dto: CommentDto, myRealId: string | null): Comment {
  return {
    id: dto.id,
    postId: dto.postId,
    authorId: alias(dto.author.id, myRealId),
    body: dto.body,
    createdAt: dto.createdAt,
  };
}

export function mapWallMessage(dto: WallMessageDto, myRealId: string | null): WallMessage {
  return {
    id: dto.id,
    profileId: dto.profileId,
    authorId: alias(dto.author.id, myRealId),
    body: dto.body,
    createdAt: dto.createdAt,
    commentCount: dto.commentCount,
  };
}

export function mapWallComment(dto: WallCommentDto, myRealId: string | null): WallComment {
  return {
    id: dto.id,
    wallMessageId: dto.wallMessageId,
    authorId: alias(dto.author.id, myRealId),
    body: dto.body,
    createdAt: dto.createdAt,
    likeCount: dto.likeCount,
    likedByMe: dto.likedByMe,
  };
}

export function mapChatRoom(dto: ChatRoomDto, myRealId: string | null = null): ChatRoom {
  const isDirect = dto.type === 'DIRECT';
  return {
    id: dto.id,
    type: isDirect ? 'direct' : 'public',
    name: dto.name ?? dto.peer?.displayName ?? 'Conversación',
    description: dto.description ?? '',
    topic: dto.topic ?? '',
    gradient: toGradient(dto.gradient, 'connection'),
    icon: dto.icon ?? 'chatbubbles',
    coverUri: dto.coverUri ?? undefined,
    backgroundUri: dto.backgroundUri ?? undefined,
    memberIds: synthArray(dto.memberCount, dto.joined),
    onlineCount: dto.onlineCount,
    favorite: dto.favorite,
    joined: dto.joined,
    role: dto.role ? (dto.role.toLowerCase() as ChatRoomRole) : null,
    live: dto.live,
    createdAt: dto.createdAt,
    peer: dto.peer
      ? {
          id: alias(dto.peer.id, myRealId),
          displayName: dto.peer.displayName,
          username: dto.peer.username,
          avatarUri: dto.peer.avatarUri ?? undefined,
          avatarGradient: toGradient(dto.peer.avatarGradient),
          isOnline: dto.peer.isOnline,
        }
      : undefined,
    lastMessage: dto.lastMessage
      ? {
          body: dto.lastMessage.body ?? '',
          hasImage: dto.lastMessage.hasImage,
          senderId: dto.lastMessage.senderId === 'system' ? 'system' : alias(dto.lastMessage.senderId, myRealId),
          createdAt: dto.lastMessage.createdAt,
        }
      : undefined,
  };
}

export function mapMessage(dto: MessageDto, myRealId: string | null): Message {
  return {
    id: dto.id,
    roomId: dto.roomId,
    authorId: dto.authorId === 'system' ? 'system' : alias(dto.authorId, myRealId),
    body: dto.body,
    createdAt: dto.createdAt,
    // Se captura una sola vez acá, al construir el mensaje — nunca en el comparador de sort.
    receivedAt: Date.now(),
    type: dto.type,
    imageUri: dto.imageUri ?? undefined,
  };
}

export function mapEvent(dto: EventDto): CommunityEvent {
  return {
    id: dto.id,
    title: dto.title,
    description: dto.description,
    date: dto.date,
    time: dto.time,
    kind: dto.kind,
    attendees: synthArray(dto.attendeeCount, dto.attendingByMe),
  };
}

export function mapNotification(dto: NotificationDto, myRealId: string | null): Notification {
  return {
    id: dto.id,
    category: dto.category,
    title: dto.title,
    body: dto.body ?? '',
    createdAt: dto.createdAt,
    read: dto.read,
    relatedPostId: dto.relatedPostId ?? undefined,
    relatedRoomId: dto.relatedRoomId ?? undefined,
    relatedUserId: dto.relatedUserId ? alias(dto.relatedUserId, myRealId) : undefined,
    relatedEventId: dto.relatedEventId ?? undefined,
  };
}
