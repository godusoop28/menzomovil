import { apiFetch } from './client';
import type {
  AddQueueItemRequest,
  AuraDto,
  AuthResponseDto,
  BadgeDto,
  BanDto,
  ChatRoomDto,
  CommentDto,
  CommunityConfigDto,
  CreateEventRequest,
  CreatePostRequest,
  CreateRoomRequest,
  EventDto,
  InterestDto,
  LiveParticipantDto,
  LiveSessionDto,
  LiveTokenDto,
  LoginRequest,
  MessageDto,
  ModerationActionRequest,
  MusicSessionDto,
  MusicSettingsRequest,
  NotificationDto,
  OnboardingRequest,
  PageResponse,
  PostDto,
  QueueItemDto,
  RecentlyViewedDto,
  RefreshRequest,
  RegisterRequest,
  ReorderQueueRequest,
  RequestSongRequest,
  RoomMemberDto,
  SeekRequest,
  SendMessageRequest,
  SettingsDto,
  StartLiveRequest,
  UpdateLiveRequest,
  UpdateProfileRequest,
  UpdateRoomRequest,
  UpdateSettingsRequest,
  UploadResponseDto,
  UserProfileDto,
  VersionedRequest,
  VoiceParticipantsDto,
  VoiceTokenDto,
  WallCommentDto,
  WallMessageDto,
  YoutubeSearchResultDto,
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
  postWall: (id: string, body: string, imageUri?: string) =>
    apiFetch<WallMessageDto>(`/api/users/${id}/wall`, { method: 'POST', body: { body, imageUri } }),
  posts: (id: string, page = 0, size = 20) =>
    apiFetch<PageResponse<PostDto>>(`/api/users/${id}/posts${qs({ page, size })}`),
  wallComments: (messageId: string, page = 0, size = 30) =>
    apiFetch<PageResponse<WallCommentDto>>(`/api/wall/${messageId}/comments${qs({ page, size })}`),
  addWallComment: (messageId: string, body: string, imageUri?: string, parentCommentId?: string) =>
    apiFetch<WallCommentDto>(`/api/wall/${messageId}/comments`, {
      method: 'POST',
      body: { body, imageUri, parentCommentId },
    }),
  deleteWallComment: (commentId: string) => apiFetch<void>(`/api/wall/comments/${commentId}`, { method: 'DELETE' }),
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
  liveRooms: () => apiFetch<ChatRoomDto[]>('/api/chat/rooms/live'),
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
  members: (id: string) => apiFetch<RoomMemberDto[]>(`/api/chat/rooms/${id}/members`),
  promote: (id: string, userId: string) =>
    apiFetch<void>(`/api/chat/rooms/${id}/members/${userId}/promote`, { method: 'POST' }),
  demote: (id: string, userId: string) =>
    apiFetch<void>(`/api/chat/rooms/${id}/members/${userId}/demote`, { method: 'POST' }),
  kick: (id: string, userId: string) =>
    apiFetch<void>(`/api/chat/rooms/${id}/members/${userId}`, { method: 'DELETE' }),
  ban: (id: string, userId: string, body?: ModerationActionRequest) =>
    apiFetch<void>(`/api/chat/rooms/${id}/members/${userId}/ban`, { method: 'POST', body }),
  unban: (id: string, userId: string) =>
    apiFetch<void>(`/api/chat/rooms/${id}/bans/${userId}`, { method: 'DELETE' }),
  bans: (id: string) => apiFetch<BanDto[]>(`/api/chat/rooms/${id}/bans`),
  invite: (id: string, userId: string) =>
    apiFetch<void>(`/api/chat/rooms/${id}/members/${userId}/invite`, { method: 'POST' }),
};

/** Endpoints viejos, sin roles — se mantienen intactos porque son los que ya usaba esta app.
 * `liveApi`/`musicApi` de abajo son el sistema nuevo (con roles HOST/CO_HOST/SPEAKER/AUDIENCE) que
 * reemplaza este flujo en VoiceRoomContext; se dejan estos por si algo más los referenciara. */
export const voiceApi = {
  getToken: (roomId: string) => apiFetch<VoiceTokenDto>(`/api/chat/rooms/${roomId}/voice/token`, { method: 'POST' }),
  join: (roomId: string) => apiFetch<VoiceParticipantsDto>(`/api/chat/rooms/${roomId}/voice/join`, { method: 'POST' }),
  leave: (roomId: string) => apiFetch<VoiceParticipantsDto>(`/api/chat/rooms/${roomId}/voice/leave`, { method: 'POST' }),
  participants: (roomId: string) => apiFetch<VoiceParticipantsDto>(`/api/chat/rooms/${roomId}/voice/participants`),
};

export const liveApi = {
  state: (roomId: string) => apiFetch<LiveSessionDto | undefined>(`/api/chat/rooms/${roomId}/live`),
  start: (roomId: string, body?: StartLiveRequest) =>
    apiFetch<LiveSessionDto>(`/api/chat/rooms/${roomId}/live/start`, { method: 'POST', body }),
  end: (roomId: string) => apiFetch<void>(`/api/chat/rooms/${roomId}/live/end`, { method: 'POST' }),
  update: (roomId: string, body: UpdateLiveRequest) =>
    apiFetch<LiveSessionDto>(`/api/chat/rooms/${roomId}/live`, { method: 'PATCH', body }),
  join: (roomId: string) => apiFetch<LiveSessionDto>(`/api/chat/rooms/${roomId}/live/join`, { method: 'POST' }),
  leave: (roomId: string) => apiFetch<void>(`/api/chat/rooms/${roomId}/live/leave`, { method: 'POST' }),
  token: (roomId: string) => apiFetch<LiveTokenDto>(`/api/chat/rooms/${roomId}/live/token`),
  participants: (roomId: string) => apiFetch<LiveParticipantDto[]>(`/api/chat/rooms/${roomId}/live/participants`),
  setMicrophone: (roomId: string, enabled: boolean) =>
    apiFetch<void>(`/api/chat/rooms/${roomId}/live/microphone`, { method: 'POST', body: { enabled } }),
  requestToSpeak: (roomId: string) =>
    apiFetch<void>(`/api/chat/rooms/${roomId}/live/speaking-requests`, { method: 'POST' }),
  cancelSpeakRequest: (roomId: string) =>
    apiFetch<void>(`/api/chat/rooms/${roomId}/live/speaking-requests/cancel`, { method: 'POST' }),
  speakingRequests: (roomId: string) =>
    apiFetch<LiveParticipantDto[]>(`/api/chat/rooms/${roomId}/live/speaking-requests`),
  approveSpeaking: (roomId: string, userId: string) =>
    apiFetch<void>(`/api/chat/rooms/${roomId}/live/speaking-requests/${userId}/approve`, { method: 'POST' }),
  rejectSpeaking: (roomId: string, userId: string) =>
    apiFetch<void>(`/api/chat/rooms/${roomId}/live/speaking-requests/${userId}/reject`, { method: 'POST' }),
  demoteParticipant: (roomId: string, userId: string) =>
    apiFetch<void>(`/api/chat/rooms/${roomId}/live/participants/${userId}/demote`, { method: 'POST' }),
  muteParticipant: (roomId: string, userId: string) =>
    apiFetch<void>(`/api/chat/rooms/${roomId}/live/participants/${userId}/mute`, { method: 'POST' }),
  removeParticipant: (roomId: string, userId: string) =>
    apiFetch<void>(`/api/chat/rooms/${roomId}/live/participants/${userId}`, { method: 'DELETE' }),
};

export const musicApi = {
  snapshot: (roomId: string) => apiFetch<MusicSessionDto>(`/api/chat/rooms/${roomId}/live/music`),
  search: (roomId: string, q: string) =>
    apiFetch<YoutubeSearchResultDto[]>(`/api/chat/rooms/${roomId}/live/music/search${qs({ q })}`),
  queue: (roomId: string) => apiFetch<QueueItemDto[]>(`/api/chat/rooms/${roomId}/live/music/queue`),
  addToQueue: (roomId: string, body: AddQueueItemRequest) =>
    apiFetch<MusicSessionDto>(`/api/chat/rooms/${roomId}/live/music/queue`, { method: 'POST', body }),
  requestSong: (roomId: string, body: RequestSongRequest) =>
    apiFetch<void>(`/api/chat/rooms/${roomId}/live/music/requests`, { method: 'POST', body }),
  approveRequest: (roomId: string, requestId: string) =>
    apiFetch<void>(`/api/chat/rooms/${roomId}/live/music/requests/${requestId}/approve`, { method: 'POST' }),
  rejectRequest: (roomId: string, requestId: string) =>
    apiFetch<void>(`/api/chat/rooms/${roomId}/live/music/requests/${requestId}/reject`, { method: 'POST' }),
  play: (roomId: string, body?: VersionedRequest) =>
    apiFetch<MusicSessionDto>(`/api/chat/rooms/${roomId}/live/music/play`, { method: 'POST', body }),
  pause: (roomId: string, body?: VersionedRequest) =>
    apiFetch<MusicSessionDto>(`/api/chat/rooms/${roomId}/live/music/pause`, { method: 'POST', body }),
  resume: (roomId: string, body?: VersionedRequest) =>
    apiFetch<MusicSessionDto>(`/api/chat/rooms/${roomId}/live/music/resume`, { method: 'POST', body }),
  seek: (roomId: string, body: SeekRequest) =>
    apiFetch<MusicSessionDto>(`/api/chat/rooms/${roomId}/live/music/seek`, { method: 'POST', body }),
  skip: (roomId: string, body?: VersionedRequest) =>
    apiFetch<MusicSessionDto>(`/api/chat/rooms/${roomId}/live/music/skip`, { method: 'POST', body }),
  stop: (roomId: string, body?: VersionedRequest) =>
    apiFetch<MusicSessionDto>(`/api/chat/rooms/${roomId}/live/music/stop`, { method: 'POST', body }),
  updateSettings: (roomId: string, body: MusicSettingsRequest) =>
    apiFetch<MusicSessionDto>(`/api/chat/rooms/${roomId}/live/music/settings`, { method: 'PATCH', body }),
  reorderQueue: (roomId: string, body: ReorderQueueRequest) =>
    apiFetch<MusicSessionDto>(`/api/chat/rooms/${roomId}/live/music/queue/reorder`, { method: 'PATCH', body }),
  removeQueueItem: (roomId: string, queueItemId: string) =>
    apiFetch<void>(`/api/chat/rooms/${roomId}/live/music/queue/${queueItemId}`, { method: 'DELETE' }),
  clearQueue: (roomId: string) => apiFetch<void>(`/api/chat/rooms/${roomId}/live/music/queue`, { method: 'DELETE' }),
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
