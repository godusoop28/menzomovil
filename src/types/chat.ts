import type { GradientId } from '@/theme';

import type { DemoUser } from './profile';

export type MessageType = 'text' | 'system';

export type Message = {
  id: string;
  roomId: string;
  authorId: string;
  body: string;
  createdAt: string;
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
  createdAt: string;
  commentCount: number;
};

export type WallComment = {
  id: string;
  wallMessageId: string;
  authorId: string;
  body: string;
  createdAt: string;
  likeCount: number;
  likedByMe: boolean;
};
