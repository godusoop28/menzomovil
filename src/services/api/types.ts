// Contrato 1:1 con menzoapi (ver menzoapi/README.md). Nombres de campo exactos, case-sensitive.

export type PostType = 'text' | 'image' | 'poll' | 'question' | 'event';
export type MessageType = 'text' | 'system';
export type NotificationCategory = 'comentarios' | 'likes' | 'mensajes' | 'eventos' | 'seguimientos';
export type ActivityKind = 'post' | 'member';

export type PageResponse<T> = {
  items: T[];
  page: number;
  size: number;
  totalElements: number;
  totalPages: number;
  hasNext: boolean;
};

export type ErrorResponse = {
  timestamp: string;
  status: number;
  error: string;
  message: string;
  path: string;
  fieldErrors: Record<string, string> | null;
};

export type UserSummaryDto = {
  id: string;
  displayName: string;
  username: string;
  avatarUri: string | null;
  avatarGradient: string | null;
  isOnline: boolean;
};

export type UserProfileDto = {
  id: string;
  displayName: string;
  username: string;
  avatarUri: string | null;
  avatarGradient: string | null;
  coverUri: string | null;
  aura: string;
  bio: string | null;
  statusText: string | null;
  interests: string[];
  joinedAt: string;
  level: number;
  xp: number;
  reputation: number;
  followers: number;
  following: number;
  visitors: number;
  isOnline: boolean;
  badges: string[];
  followedByMe: boolean;
};

export type AuthResponseDto = {
  accessToken: string;
  refreshToken: string;
  accessTokenExpiresAt: string;
  email: string;
  onboardingCompleted: boolean;
  profile: UserProfileDto;
};

export type RegisterRequest = { email: string; password: string };
export type LoginRequest = { email: string; password: string };
export type RefreshRequest = { refreshToken: string };

export type OnboardingRequest = {
  displayName: string;
  aura: string;
  avatarUri: string | null;
  avatarGradient: string;
  interests: string[];
};

export type UpdateProfileRequest = {
  displayName?: string;
  username?: string;
  avatarUri?: string;
  avatarGradient?: string;
  coverUri?: string;
  aura?: string;
  bio?: string;
  statusText?: string;
  interests?: string[];
};

export type SettingsDto = {
  theme: string;
  effectIntensity: string;
  hapticsEnabled: boolean;
  animationsEnabled: boolean;
  showSimulatedActivity: boolean;
  confirmationsEnabled: boolean;
  showOnlineStatus: boolean;
  allowProfileVisits: boolean;
  showInterests: boolean;
};

export type UpdateSettingsRequest = Partial<SettingsDto>;

export type WallMessageDto = {
  id: string;
  profileId: string;
  author: UserSummaryDto;
  body: string;
  createdAt: string;
};

export type AuraDto = { id: string; name: string; description: string; gradient: string };
export type InterestDto = { id: string; label: string; icon: string; gradient: string };
export type BadgeDto = { id: string; name: string; description: string; icon: string; gradient: string };

export type AbstractVisualDto = { preset: string; caption: string | null };
export type PollOptionDto = { id: string; label: string; voteCount: number; votedByMe: boolean };

export type PostDto = {
  id: string;
  author: UserSummaryDto;
  type: PostType;
  title: string | null;
  body: string;
  imageUri: string | null;
  abstractVisual: AbstractVisualDto | null;
  gradient: string | null;
  tags: string[];
  pollOptions: PollOptionDto[];
  eventId: string | null;
  likeCount: number;
  likedByMe: boolean;
  bookmarkedByMe: boolean;
  commentCount: number;
  featured: boolean;
  createdAt: string;
};

export type CreatePostRequest = {
  type: PostType;
  title?: string;
  body: string;
  imageUri?: string;
  abstractVisual?: { preset: string; caption?: string };
  gradient?: string;
  tags?: string[];
  pollOptions?: string[];
  eventId?: string;
};

export type CommentDto = {
  id: string;
  postId: string;
  author: UserSummaryDto;
  body: string;
  createdAt: string;
};

export type CreateRoomRequest = {
  name: string;
  description?: string;
  topic?: string;
  gradient?: string;
  icon?: string;
};

export type ChatRoomDto = {
  id: string;
  slug: string | null;
  name: string | null;
  description: string | null;
  topic: string | null;
  gradient: string | null;
  icon: string | null;
  type: 'PUBLIC' | 'DIRECT';
  peer: UserSummaryDto | null;
  memberCount: number;
  onlineCount: number;
  favorite: boolean;
  joined: boolean;
};

export type MessageDto = {
  id: string;
  roomId: string;
  authorId: string;
  author: UserSummaryDto | null;
  type: MessageType;
  body: string;
  imageUri: string | null;
  createdAt: string;
};

export type SendMessageRequest = { body: string; imageUri?: string };

export type CommunityConfigDto = {
  name: string;
  subtitle: string;
  description: string;
  motto: string;
  memberCount: number;
  onlineCount: number;
  tags: string[];
};

export type EventDto = {
  id: string;
  title: string;
  description: string;
  date: string;
  time: string;
  kind: string;
  attendeeCount: number;
  attendingByMe: boolean;
};

export type CreateEventRequest = {
  title: string;
  description: string;
  date: string;
  time: string;
  kind: string;
};

export type NotificationDto = {
  id: string;
  category: NotificationCategory;
  title: string;
  body: string | null;
  createdAt: string;
  read: boolean;
  relatedPostId: string | null;
  relatedRoomId: string | null;
  relatedUserId: string | null;
  relatedEventId: string | null;
};

export type RecentlyViewedDto = { kind: ActivityKind; id: string; viewedAt: string };
export type UploadResponseDto = { url: string };
