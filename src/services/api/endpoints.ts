import { apiFetch } from './client';
import type {
  AuraDto,
  AuthResponseDto,
  BadgeDto,
  ChatRoomDto,
  CommentDto,
  CommunityConfigDto,
  CreateEventRequest,
  CreatePostRequest,
  CreateRoomRequest,
  EventDto,
  InterestDto,
  LoginRequest,
  MessageDto,
  NotificationDto,
  OnboardingRequest,
  PageResponse,
  PostDto,
  RecentlyViewedDto,
  RefreshRequest,
  RegisterRequest,
  SendMessageRequest,
  SettingsDto,
  UpdateProfileRequest,
  UpdateRoomRequest,
  UpdateSettingsRequest,
  UploadResponseDto,
  UserProfileDto,
  VoiceParticipantsDto,
  VoiceTokenDto,
  WallCommentDto,
  WallMessageDto,
} from './types';

function qs(params: Record<string, string | number | undefined>) {
  const entries = Object.entries(params).filter(([, v]) => v !== undefined && v !== '');
  if (entries.length === 0) return '';
  return '?' + entries.map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(String(v))}`).join('&');
}

export const authApi = {
  register: (body: RegisterRequest) =>
    apiFetch<AuthResponseDto>('/api/auth/register', { method: 'POST', body, skipAuth: true }),
  login: (body: LoginRequest) =>
    apiFetch<AuthResponseDto>('/api/auth/login', { method: 'POST', body, skipAuth: true }),
  refresh: (body: RefreshRequest) =>
    apiFetch<AuthResponseDto>('/api/auth/refresh', { method: 'POST', body, skipAuth: true }),
  logout: (body: RefreshRequest) =>
    apiFetch<void>('/api/auth/logout', { method: 'POST', body, skipAuth: true }),
};

export const usersApi = {
  me: () => apiFetch<UserProfileDto>('/api/users/me'),
  onboarding: (body: OnboardingRequest) =>
    apiFetch<UserProfileDto>('/api/users/me/onboarding', { method: 'POST', body }),
  updateMe: (body: UpdateProfileRequest) => apiFetch<UserProfileDto>('/api/users/me', { method: 'PATCH', body }),
  heartbeat: () => apiFetch<void>('/api/users/me/heartbeat', { method: 'POST' }),
  getSettings: () => apiFetch<SettingsDto>('/api/users/me/settings'),
  updateSettings: (body: UpdateSettingsRequest) =>
    apiFetch<SettingsDto>('/api/users/me/settings', { method: 'PATCH', body }),
  search: (query: string, page = 0, size = 20) =>
    apiFetch<PageResponse<UserProfileDto>>(`/api/users/search${qs({ query, page, size })}`),
  getById: (id: string) => apiFetch<UserProfileDto>(`/api/users/${id}`),
  follow: (id: string) => apiFetch<void>(`/api/users/${id}/follow`, { method: 'PUT' }),
  unfollow: (id: string) => apiFetch<void>(`/api/users/${id}/follow`, { method: 'DELETE' }),
  followers: (id: string) => apiFetch<UserProfileDto[]>(`/api/users/${id}/followers`),
  following: (id: string) => apiFetch<UserProfileDto[]>(`/api/users/${id}/following`),
  wall: (id: string, page = 0, size = 20) =>
    apiFetch<PageResponse<WallMessageDto>>(`/api/users/${id}/wall${qs({ page, size })}`),
  postWall: (id: string, body: string) =>
    apiFetch<WallMessageDto>(`/api/users/${id}/wall`, { method: 'POST', body: { body } }),
  posts: (id: string, page = 0, size = 20) =>
    apiFetch<PageResponse<PostDto>>(`/api/users/${id}/posts${qs({ page, size })}`),
  wallComments: (messageId: string) => apiFetch<WallCommentDto[]>(`/api/wall/${messageId}/comments`),
  addWallComment: (messageId: string, body: string) =>
    apiFetch<WallCommentDto>(`/api/wall/${messageId}/comments`, { method: 'POST', body: { body } }),
  likeWallComment: (commentId: string) => apiFetch<void>(`/api/wall/comments/${commentId}/like`, { method: 'PUT' }),
  unlikeWallComment: (commentId: string) =>
    apiFetch<void>(`/api/wall/comments/${commentId}/like`, { method: 'DELETE' }),
};

export const lookupsApi = {
  auras: () => apiFetch<AuraDto[]>('/api/lookups/auras'),
  interests: () => apiFetch<InterestDto[]>('/api/lookups/interests'),
  badges: () => apiFetch<BadgeDto[]>('/api/lookups/badges'),
};

export const postsApi = {
  list: (page = 0, size = 20) => apiFetch<PageResponse<PostDto>>(`/api/posts${qs({ page, size })}`),
  featured: (page = 0, size = 20) => apiFetch<PageResponse<PostDto>>(`/api/posts/featured${qs({ page, size })}`),
  bookmarked: (page = 0, size = 20) => apiFetch<PageResponse<PostDto>>(`/api/posts/bookmarked${qs({ page, size })}`),
  search: (query: string, page = 0, size = 20) =>
    apiFetch<PageResponse<PostDto>>(`/api/posts/search${qs({ query, page, size })}`),
  getById: (id: string) => apiFetch<PostDto>(`/api/posts/${id}`),
  create: (body: CreatePostRequest) => apiFetch<PostDto>('/api/posts', { method: 'POST', body }),
  remove: (id: string) => apiFetch<void>(`/api/posts/${id}`, { method: 'DELETE' }),
  like: (id: string) => apiFetch<void>(`/api/posts/${id}/like`, { method: 'PUT' }),
  unlike: (id: string) => apiFetch<void>(`/api/posts/${id}/like`, { method: 'DELETE' }),
  bookmark: (id: string) => apiFetch<void>(`/api/posts/${id}/bookmark`, { method: 'PUT' }),
  unbookmark: (id: string) => apiFetch<void>(`/api/posts/${id}/bookmark`, { method: 'DELETE' }),
  vote: (id: string, optionId: string) =>
    apiFetch<PostDto>(`/api/posts/${id}/vote`, { method: 'POST', body: { optionId } }),
  comments: (id: string, page = 0, size = 30) =>
    apiFetch<PageResponse<CommentDto>>(`/api/posts/${id}/comments${qs({ page, size })}`),
  addComment: (id: string, body: string) =>
    apiFetch<CommentDto>(`/api/posts/${id}/comments`, { method: 'POST', body: { body } }),
};

export const chatApi = {
  rooms: () => apiFetch<ChatRoomDto[]>('/api/chat/rooms'),
  discover: (sort: 'recent' | 'popular' = 'recent') =>
    apiFetch<ChatRoomDto[]>(`/api/chat/rooms/discover${qs({ sort })}`),
  getRoom: (id: string) => apiFetch<ChatRoomDto>(`/api/chat/rooms/${id}`),
  openDirect: (userId: string) => apiFetch<ChatRoomDto>(`/api/chat/rooms/dm/${userId}`, { method: 'POST' }),
  createRoom: (body: CreateRoomRequest) => apiFetch<ChatRoomDto>('/api/chat/rooms', { method: 'POST', body }),
  updateRoom: (id: string, body: UpdateRoomRequest) =>
    apiFetch<ChatRoomDto>(`/api/chat/rooms/${id}`, { method: 'PATCH', body }),
  join: (id: string) => apiFetch<void>(`/api/chat/rooms/${id}/join`, { method: 'POST' }),
  leave: (id: string) => apiFetch<void>(`/api/chat/rooms/${id}/leave`, { method: 'POST' }),
  favorite: (id: string) => apiFetch<void>(`/api/chat/rooms/${id}/favorite`, { method: 'PUT' }),
  unfavorite: (id: string) => apiFetch<void>(`/api/chat/rooms/${id}/favorite`, { method: 'DELETE' }),
  messages: (id: string, page = 0, size = 40) =>
    apiFetch<PageResponse<MessageDto>>(`/api/chat/rooms/${id}/messages${qs({ page, size })}`),
  sendMessage: (id: string, body: SendMessageRequest) =>
    apiFetch<MessageDto>(`/api/chat/rooms/${id}/messages`, { method: 'POST', body }),
};

export const voiceApi = {
  getToken: (roomId: string) => apiFetch<VoiceTokenDto>(`/api/chat/rooms/${roomId}/voice/token`, { method: 'POST' }),
  join: (roomId: string) => apiFetch<VoiceParticipantsDto>(`/api/chat/rooms/${roomId}/voice/join`, { method: 'POST' }),
  leave: (roomId: string) => apiFetch<VoiceParticipantsDto>(`/api/chat/rooms/${roomId}/voice/leave`, { method: 'POST' }),
  participants: (roomId: string) => apiFetch<VoiceParticipantsDto>(`/api/chat/rooms/${roomId}/voice/participants`),
};

export const communityApi = {
  config: () => apiFetch<CommunityConfigDto>('/api/community/config'),
  events: () => apiFetch<EventDto[]>('/api/community/events'),
  getEvent: (id: string) => apiFetch<EventDto>(`/api/community/events/${id}`),
  createEvent: (body: CreateEventRequest) => apiFetch<EventDto>('/api/community/events', { method: 'POST', body }),
  attend: (id: string) => apiFetch<void>(`/api/community/events/${id}/attend`, { method: 'PUT' }),
  unattend: (id: string) => apiFetch<void>(`/api/community/events/${id}/attend`, { method: 'DELETE' }),
};

export const notificationsApi = {
  list: (page = 0, size = 30) => apiFetch<PageResponse<NotificationDto>>(`/api/notifications${qs({ page, size })}`),
  markRead: (id: string) => apiFetch<void>(`/api/notifications/${id}/read`, { method: 'POST' }),
  markAllRead: () => apiFetch<void>('/api/notifications/read-all', { method: 'POST' }),
};

export const activityApi = {
  recentlyViewed: () => apiFetch<RecentlyViewedDto[]>('/api/activity/recently-viewed'),
  addRecentlyViewed: (kind: 'post' | 'member', id: string) =>
    apiFetch<void>('/api/activity/recently-viewed', { method: 'POST', body: { kind, id } }),
  recentSearches: () => apiFetch<string[]>('/api/activity/recent-searches'),
  addRecentSearch: (query: string) =>
    apiFetch<void>('/api/activity/recent-searches', { method: 'POST', body: { query } }),
  clearRecentSearches: () => apiFetch<void>('/api/activity/recent-searches', { method: 'DELETE' }),
};

export const uploadsApi = {
  upload: async (localUri: string): Promise<string> => {
    const filename = localUri.split('/').pop() ?? `upload-${Date.now()}.jpg`;
    const extMatch = /\.(\w+)$/.exec(filename);
    const ext = extMatch ? extMatch[1].toLowerCase() : 'jpg';
    const mime = ext === 'png' ? 'image/png' : ext === 'webp' ? 'image/webp' : ext === 'gif' ? 'image/gif' : 'image/jpeg';

    const form = new FormData();
    // React Native's fetch/FormData accepts this shape for file uploads.
    form.append('file', { uri: localUri, name: filename, type: mime } as unknown as Blob);

    const response = await apiFetch<UploadResponseDto>('/api/uploads', { method: 'POST', formData: form });
    return response.url;
  },
};

/** Sube el archivo solo si `uri` es un archivo local; si ya es una URL http(s) la deja igual. */
export async function ensureUploaded(uri: string | undefined): Promise<string | undefined> {
  if (!uri) return undefined;
  if (/^https?:\/\//.test(uri)) return uri;
  return uploadsApi.upload(uri);
}
