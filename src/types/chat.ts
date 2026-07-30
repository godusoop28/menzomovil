import type { GradientId } from '@/theme';

import type { DemoUser } from './profile';

export type MessageType = 'text' | 'system';

export type Message = {
  id: string;
  roomId: string;
  authorId: string;
  body: string;
  createdAt: string;
  /** Timestamp local, tomado una sola vez cuando este mensaje se construyó a partir del DTO del
   * servidor (ver mapMessage). Respaldo estable para ordenar si createdAt no se puede parsear —
   * nunca se recalcula en cada sort/render, así que no salta de posición entre renders. */
  receivedAt: number;
  type: MessageType;
  imageUri?: string;
};

export type ChatRoomType = 'public' | 'direct';
export type ChatRoomRole = 'owner' | 'co_host' | 'member';

export type ChatPeer = {
  id: string;
  displayName: string;
  username: string;
  avatarUri?: string;
  avatarGradient: GradientId;
  isOnline: boolean;
};

export type ChatRoom = {
  id: string;
  type: ChatRoomType;
  name: string;
  description: string;
  topic: string;
  gradient: GradientId;
  icon: string;
  coverUri?: string;
  backgroundUri?: string;
  memberIds: string[];
  onlineCount: number;
  favorite: boolean;
  joined: boolean;
  role: ChatRoomRole | null;
  live: boolean;
  createdAt: string;
  peer?: ChatPeer;
  lastMessage?: ChatRoomLastMessage;
};

export type ChatRoomLastMessage = {
  body: string;
  hasImage: boolean;
  senderId: string;
  createdAt: string;
};

export type RoomMember = { user: DemoUser; role: ChatRoomRole; joinedAt: string };

export type RoomBan = { user: DemoUser; reason: string | null; createdAt: string; bannedBy: DemoUser | null };

export type WallMessage = {
  id: string;
  profileId: string;
  authorId: string;
  body: string;
  imageUri?: string;
  createdAt: string;
  commentCount: number;
};

export type WallComment = {
  id: string;
  wallMessageId: string;
  parentCommentId?: string;
  authorId: string;
  body: string;
  imageUri?: string;
  createdAt: string;
  likeCount: number;
  likedByMe: boolean;
};

// ---- LIVE moderado ------------------------------------------------------------------------

export type LiveParticipantRole = 'host' | 'co_host' | 'speaker' | 'audience' | 'requested';

export type LiveParticipant = {
  user: DemoUser;
  role: LiveParticipantRole;
  microphoneEnabled: boolean;
  requestedToSpeakAt: string | null;
  joinedAt: string;
  /** 0-1, viene de Agora (onAudioVolumeIndication) — nunca del backend. */
  speakingLevel: number;
};

export type LiveSessionSummary = {
  id: string;
  roomId: string;
  status: 'active' | 'ended';
  title: string | null;
  description: string | null;
  announcement: string | null;
  startedByUserId: string | null;
  startedAt: string;
  participantCount: number;
  speakerCount: number;
  myRole: LiveParticipantRole | null;
  myMicrophoneEnabled: boolean;
  hasPendingSpeakRequest: boolean;
};

// ---- Menzi DJ ------------------------------------------------------------------------------

export type QueueItemStatus = 'pending' | 'queued' | 'playing' | 'played' | 'skipped' | 'rejected' | 'removed';

export type QueueItem = {
  id: string;
  videoId: string;
  title: string;
  channelTitle: string;
  thumbnailUrl: string | null;
  durationSeconds: number | null;
  requestedBy: DemoUser | null;
  approvedBy: DemoUser | null;
  position: number | null;
  status: QueueItemStatus;
  createdAt: string;
};

export type MusicSessionSummary = {
  musicSessionId: string;
  roomId: string;
  liveSessionId: string;
  status: 'idle' | 'playing' | 'paused' | 'stopped' | 'error';
  currentQueueItemId: string | null;
  currentVideoId: string | null;
  currentTitle: string | null;
  currentChannelTitle: string | null;
  currentThumbnailUrl: string | null;
  durationSeconds: number | null;
  positionSeconds: number;
  allowRequests: boolean;
  version: number;
  queue: QueueItem[];
  pendingRequests: QueueItem[];
  history: QueueItem[];
};

export type YoutubeSearchResult = {
  videoId: string;
  title: string;
  channelTitle: string;
  thumbnailUrl: string | null;
  durationSeconds: number | null;
  embeddable: boolean;
  live: boolean;
};
