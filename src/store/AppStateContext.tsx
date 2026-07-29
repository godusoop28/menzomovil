import { createContext, useContext, useEffect, useMemo, useReducer, useRef } from 'react';

import {
  activityApi,
  authApi,
  chatApi,
  clearSession,
  communityApi,
  ensureUploaded,
  getCachedSession,
  getMyRealId,
  loadSession,
  mapChatRoom,
  mapComment,
  mapDemoUser,
  mapEvent,
  mapMessage,
  mapNotification,
  mapPost,
  mapUserProfile,
  mapUserSummary,
  mapWallComment,
  mapWallMessage,
  notificationsApi,
  onSessionExpired,
  postsApi,
  saveSession,
  usersApi,
} from '@/services/api';
import type { AppSettings, CommunityEvent, DemoUser, Post, UserProfile } from '@/types';

import { useToast } from '@/hooks/useToast';

import { LOCAL_USER_ID } from './localUser';
import { appReducer, createDefaultState } from './reducer';
import {
  CURRENT_STORAGE_VERSION,
  StorageKeys,
  ensureStorageVersion,
  getItem,
  removeItem,
  resetAllStorage,
  setItem,
} from './storage';
import type { AppState, OnboardingPayload, RecentlyViewedEntry, SocialState } from './types';

type AppStateContextValue = {
  state: AppState;
  actions: {
    register: (email: string, password: string) => Promise<void>;
    login: (email: string, password: string) => Promise<boolean>;
    completeOnboarding: (payload: OnboardingPayload) => Promise<void>;
    updateProfile: (payload: Partial<UserProfile>) => Promise<void>;
    refreshProfile: () => Promise<void>;
    toggleLike: (postId: string) => void;
    toggleBookmark: (postId: string) => void;
    createPost: (post: Post) => Promise<void>;
    createEvent: (event: CommunityEvent) => Promise<CommunityEvent | null>;
    addComment: (postId: string, body: string) => void;
    addWallMessage: (profileId: string, body: string) => void;
    toggleFollow: (userId: string) => void;
    sendMessage: (roomId: string, body: string, imageUri?: string) => Promise<boolean>;
    openDirectMessage: (userId: string) => Promise<string | null>;
    createRoom: (payload: { name: string; description?: string; topic?: string }) => Promise<string | null>;
    joinRoom: (roomId: string) => Promise<void>;
    loadDiscoverRooms: (sort: 'recent' | 'popular') => Promise<void>;
    updateRoomCover: (roomId: string, coverUri: string) => Promise<void>;
    updateRoomBackground: (roomId: string, backgroundUri: string) => Promise<void>;
    toggleFavoriteRoom: (roomId: string) => void;
    votePoll: (postId: string, optionId: string) => void;
    attendEvent: (eventId: string) => void;
    markNotificationRead: (id: string) => void;
    markAllNotificationsRead: () => void;
    updateSettings: (payload: Partial<AppSettings>) => void;
    addRecentlyViewed: (entry: RecentlyViewedEntry) => void;
    addRecentSearch: (query: string) => void;
    clearRecentSearches: () => void;
    resetDemo: () => Promise<void>;
    logout: () => Promise<void>;
    loadPostComments: (postId: string) => Promise<void>;
    ensurePostLoaded: (postId: string) => Promise<void>;
    ensureUserLoaded: (userId: string) => Promise<void>;
    loadRoomMessages: (roomId: string) => Promise<void>;
    receiveRoomMessage: (dto: import('@/services/api').MessageDto) => void;
    loadProfileWall: (profileId: string) => Promise<void>;
    loadWallComments: (wallMessageId: string) => Promise<void>;
    addWallComment: (wallMessageId: string, body: string) => Promise<void>;
    toggleWallCommentLike: (commentId: string, wallMessageId: string) => Promise<void>;
    refreshSocial: () => Promise<void>;
  };
};

const AppStateContext = createContext<AppStateContextValue | null>(null);

function hasSession() {
  return !!getCachedSession();
}

async function fetchInitialSocialSnapshot(myRealId: string, profile: UserProfile): Promise<Partial<SocialState>> {
  const [postsPage, rooms, events, notificationsPage, following, membersPage] = await Promise.all([
    postsApi.list(0, 20).catch(() => null),
    chatApi.rooms().catch(() => []),
    communityApi.events().catch(() => []),
    notificationsApi.list(0, 30).catch(() => null),
    usersApi.following(myRealId).catch(() => []),
    usersApi.search('', 0, 60).catch(() => null),
  ]);

  const userMap = new Map<string, DemoUser>();
  userMap.set(profile.id, { ...profile, activityStatus: profile.statusText });
  if (postsPage) {
    for (const dto of postsPage.items) {
      const u = mapUserSummary(dto.author, myRealId);
      if (!userMap.has(u.id)) userMap.set(u.id, u);
    }
  }
  for (const dto of following) {
    if (!userMap.has(dto.id)) userMap.set(dto.id, mapDemoUser(dto, myRealId));
  }
  if (membersPage) {
    for (const dto of membersPage.items) {
      if (!userMap.has(dto.id)) userMap.set(dto.id, mapDemoUser(dto, myRealId));
    }
  }

  return {
    users: Array.from(userMap.values()),
    posts: postsPage ? postsPage.items.map((dto) => mapPost(dto, myRealId)) : [],
    rooms: rooms.map((dto) => mapChatRoom(dto, myRealId)),
    events: events.map(mapEvent),
    notifications: notificationsPage ? notificationsPage.items.map((dto) => mapNotification(dto, myRealId)) : [],
    following: following.map((dto) => dto.id),
  };
}

export function AppStateProvider({ children }: { children: React.ReactNode }) {
  const [state, dispatch] = useReducer(appReducer, createDefaultState());
  const hasHydrated = useRef(false);
  const stateRef = useRef(state);
  const showToast = useToast();

  useEffect(() => {
    stateRef.current = state;
  }, [state]);

  useEffect(() => {
    let cancelled = false;

    async function hydrate() {
      await ensureStorageVersion();
      const [localProfile, localSocial, localSettings, localOnboarding] = await Promise.all([
        getItem<AppState['profile']>(StorageKeys.profile),
        getItem<AppState['social']>(StorageKeys.socialState),
        getItem<AppState['settings']>(StorageKeys.settings),
        getItem<boolean>(StorageKeys.onboarding),
      ]);
      const session = await loadSession();

      const base = createDefaultState();
      let next: AppState = {
        isHydrated: true,
        profile: localProfile ?? base.profile,
        social: localSocial ?? base.social,
        settings: localSettings ?? base.settings,
        onboardingCompleted: localOnboarding ?? false,
      };

      if (session) {
        try {
          const meDto = await usersApi.me();
          const profile = mapUserProfile(meDto, session.userId);
          const snapshot = await fetchInitialSocialSnapshot(session.userId, profile);
          next = {
            ...next,
            profile,
            onboardingCompleted: localOnboarding ?? true,
            social: { ...next.social, ...snapshot },
          };
        } catch (error) {
          console.warn('[menzo/api] no se pudo restaurar la sesión', error);
          await clearSession();
          next = { ...next, profile: null, onboardingCompleted: false };
        }
      }

      if (!cancelled) {
        dispatch({ type: 'HYDRATE', payload: next });
        hasHydrated.current = true;
      }
    }

    hydrate().catch((error) => {
      console.warn('[menzo/store] hydration failed, using defaults', error);
      if (!cancelled) {
        dispatch({ type: 'HYDRATE', payload: { ...createDefaultState(), isHydrated: true } });
        hasHydrated.current = true;
      }
    });

    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    if (!hasHydrated.current) return;
    setItem(StorageKeys.profile, state.profile);
  }, [state.profile]);

  useEffect(() => {
    if (!hasHydrated.current) return;
    setItem(StorageKeys.socialState, state.social);
  }, [state.social]);

  useEffect(() => {
    if (!hasHydrated.current) return;
    setItem(StorageKeys.settings, state.settings);
  }, [state.settings]);

  useEffect(() => {
    if (!hasHydrated.current) return;
    setItem(StorageKeys.onboarding, state.onboardingCompleted);
  }, [state.onboardingCompleted]);

  useEffect(() => {
    if (!state.isHydrated || !state.profile) return;

    function beat() {
      if (!hasSession()) return;
      usersApi.heartbeat().catch((error) => console.warn('[menzo/api] heartbeat failed', error));
    }

    beat();
    const interval = setInterval(beat, 60_000);
    return () => clearInterval(interval);
  }, [state.isHydrated, state.profile]);

  useEffect(() => {
    return onSessionExpired(() => {
      removeItem(StorageKeys.profile);
      removeItem(StorageKeys.socialState);
      removeItem(StorageKeys.onboarding);
      dispatch({ type: 'LOGOUT' });
    });
  }, []);

  const actions = useMemo<AppStateContextValue['actions']>(() => {
    async function register(email: string, password: string) {
      const res = await authApi.register({ email, password });
      await saveSession({ accessToken: res.accessToken, refreshToken: res.refreshToken, userId: res.profile.id });
      const profile = mapUserProfile(res.profile, res.profile.id);
      dispatch({ type: 'SET_SESSION', payload: { profile, onboardingCompleted: res.onboardingCompleted } });
    }

    async function login(email: string, password: string) {
      const res = await authApi.login({ email, password });
      await saveSession({ accessToken: res.accessToken, refreshToken: res.refreshToken, userId: res.profile.id });
      const profile = mapUserProfile(res.profile, res.profile.id);
      dispatch({ type: 'SET_SESSION', payload: { profile, onboardingCompleted: res.onboardingCompleted } });
      if (res.onboardingCompleted) {
        try {
          const snapshot = await fetchInitialSocialSnapshot(res.profile.id, profile);
          dispatch({ type: 'SET_SOCIAL_BULK', payload: snapshot });
        } catch (error) {
          console.warn('[menzo/api] no se pudo cargar el contenido inicial', error);
        }
      }
      return res.onboardingCompleted;
    }

    async function completeOnboarding(payload: OnboardingPayload) {
      const avatarUri = await ensureUploaded(payload.avatarUri);
      const dto = await usersApi.onboarding({
        displayName: payload.displayName,
        aura: payload.aura,
        avatarUri: avatarUri ?? null,
        avatarGradient: payload.avatarGradient,
        interests: payload.interests,
      });
      const myRealId = getCachedSession()?.userId ?? dto.id;
      const profile = mapUserProfile(dto, myRealId);
      dispatch({ type: 'SET_SESSION', payload: { profile, onboardingCompleted: true } });
    }

    async function updateProfile(payload: Partial<UserProfile>) {
      dispatch({ type: 'UPDATE_PROFILE', payload });
      if (!hasSession()) return;
      const avatarUri = payload.avatarUri !== undefined ? await ensureUploaded(payload.avatarUri) : undefined;
      const coverUri = payload.coverUri !== undefined ? await ensureUploaded(payload.coverUri) : undefined;
      const backgroundUri =
        payload.backgroundUri !== undefined
          ? payload.backgroundUri === ''
            ? ''
            : await ensureUploaded(payload.backgroundUri)
          : undefined;
      const dto = await usersApi.updateMe({
        displayName: payload.displayName,
        avatarUri,
        avatarGradient: payload.avatarGradient,
        coverUri,
        backgroundUri,
        backgroundColor: payload.backgroundColor,
        aura: payload.aura,
        bio: payload.bio,
        statusText: payload.statusText,
        interests: payload.interests,
      });
      const profile = mapUserProfile(dto, getMyRealId());
      dispatch({ type: 'SET_SESSION', payload: { profile, onboardingCompleted: true } });
    }

    async function refreshProfile() {
      if (!hasSession()) return;
      const myRealId = getMyRealId();
      const dto = await usersApi.me();
      const profile = mapUserProfile(dto, myRealId);
      dispatch({ type: 'SET_SESSION', payload: { profile, onboardingCompleted: true } });
    }

    function toggleLike(postId: string) {
      const wasLiked = stateRef.current.social.posts.find((p) => p.id === postId)?.likes.includes(LOCAL_USER_ID) ?? false;
      dispatch({ type: 'TOGGLE_LIKE', payload: { postId } });
      if (!hasSession()) return;
      const call = wasLiked ? postsApi.unlike(postId) : postsApi.like(postId);
      call.catch((error) => console.warn('[menzo/api] toggleLike failed', error));
    }

    function toggleBookmark(postId: string) {
      const wasSaved =
        stateRef.current.social.posts.find((p) => p.id === postId)?.bookmarkedBy.includes(LOCAL_USER_ID) ?? false;
      dispatch({ type: 'TOGGLE_BOOKMARK', payload: { postId } });
      if (!hasSession()) return;
      const call = wasSaved ? postsApi.unbookmark(postId) : postsApi.bookmark(postId);
      call.catch((error) => console.warn('[menzo/api] toggleBookmark failed', error));
    }

    async function createPost(post: Post) {
      if (!hasSession()) throw new Error('No hay sesión activa');
      const imageUri = await ensureUploaded(post.imageUri);
      const dto = await postsApi.create({
        type: post.type,
        title: post.title,
        body: post.body,
        imageUri,
        abstractVisual: post.abstractVisual
          ? { preset: post.abstractVisual.preset, caption: post.abstractVisual.caption }
          : undefined,
        gradient: post.gradient,
        tags: post.tags,
        pollOptions: post.pollOptions?.map((o) => o.label),
        eventId: post.eventId,
      });
      dispatch({ type: 'CREATE_POST', payload: mapPost(dto, getMyRealId()) });
    }

    async function createEvent(event: CommunityEvent): Promise<CommunityEvent | null> {
      if (!hasSession()) return null;
      try {
        const dto = await communityApi.createEvent({
          title: event.title,
          description: event.description,
          date: event.date,
          time: event.time,
          kind: event.kind,
        });
        const mapped = mapEvent(dto);
        dispatch({ type: 'CREATE_EVENT', payload: mapped });
        return mapped;
      } catch (error) {
        console.warn('[menzo/api] createEvent failed', error);
        return null;
      }
    }

    function addComment(postId: string, body: string) {
      if (!hasSession()) return;
      postsApi
        .addComment(postId, body)
        .then((dto) => dispatch({ type: 'ADD_COMMENT', payload: mapComment(dto, getMyRealId()) }))
        .catch((error) => console.warn('[menzo/api] addComment failed', error));
    }

    function addWallMessage(profileId: string, body: string) {
      if (!hasSession()) return;
      const targetId = profileId === LOCAL_USER_ID ? getMyRealId() : profileId;
      if (!targetId) return;
      usersApi
        .postWall(targetId, body)
        .then((dto) => dispatch({ type: 'ADD_WALL_MESSAGE', payload: mapWallMessage(dto, getMyRealId()) }))
        .catch((error) => console.warn('[menzo/api] addWallMessage failed', error));
    }

    function toggleFollow(userId: string) {
      const wasFollowing = stateRef.current.social.following.includes(userId);
      dispatch({ type: 'TOGGLE_FOLLOW', payload: { userId } });
      if (!hasSession()) return;
      const call = wasFollowing ? usersApi.unfollow(userId) : usersApi.follow(userId);
      call.catch((error) => {
        console.warn('[menzo/api] toggleFollow failed', error);
        dispatch({ type: 'TOGGLE_FOLLOW', payload: { userId } });
        showToast(wasFollowing ? 'No pudimos dejar de seguir. Inténtalo de nuevo.' : 'No pudimos seguir a esta persona. Inténtalo de nuevo.');
      });
    }

    async function sendMessage(roomId: string, body: string, imageUri?: string): Promise<boolean> {
      if (!hasSession()) return false;
      try {
        const uploaded = await ensureUploaded(imageUri);
        const dto = await chatApi.sendMessage(roomId, { body, imageUri: uploaded });
        dispatch({ type: 'SEND_MESSAGE', payload: mapMessage(dto, getMyRealId()) });
        return true;
      } catch (error) {
        console.warn('[menzo/api] sendMessage failed', error);
        showToast('No pudimos enviar el mensaje. Inténtalo de nuevo.');
        return false;
      }
    }

    async function createRoom(payload: { name: string; description?: string; topic?: string }): Promise<string | null> {
      if (!hasSession()) return null;
      try {
        const dto = await chatApi.createRoom({
          name: payload.name,
          description: payload.description,
          topic: payload.topic,
        });
        const room = mapChatRoom(dto, getMyRealId());
        dispatch({ type: 'MERGE_SOCIAL', payload: { rooms: [room] } });
        return room.id;
      } catch (error) {
        console.warn('[menzo/api] createRoom failed', error);
        return null;
      }
    }

    async function openDirectMessage(userId: string): Promise<string | null> {
      if (!hasSession()) return null;
      try {
        const dto = await chatApi.openDirect(userId);
        const room = mapChatRoom(dto, getMyRealId());
        dispatch({ type: 'MERGE_SOCIAL', payload: { rooms: [room] } });
        return room.id;
      } catch (error) {
        console.warn('[menzo/api] openDirectMessage failed', error);
        return null;
      }
    }

    async function joinRoom(roomId: string) {
      if (!hasSession()) return;
      try {
        await chatApi.join(roomId);
        const dto = await chatApi.getRoom(roomId);
        dispatch({ type: 'MERGE_SOCIAL', payload: { rooms: [mapChatRoom(dto, getMyRealId())] } });
      } catch (error) {
        console.warn('[menzo/api] joinRoom failed', error);
      }
    }

    async function loadDiscoverRooms(sort: 'recent' | 'popular') {
      try {
        const dtos = await chatApi.discover(sort);
        const myRealId = getMyRealId();
        dispatch({ type: 'MERGE_SOCIAL', payload: { rooms: dtos.map((dto) => mapChatRoom(dto, myRealId)) } });
      } catch (error) {
        console.warn('[menzo/api] loadDiscoverRooms failed', error);
      }
    }

    async function updateRoomCover(roomId: string, coverUri: string) {
      if (!hasSession()) return;
      try {
        const uploaded = coverUri === '' ? '' : await ensureUploaded(coverUri);
        const dto = await chatApi.updateRoom(roomId, { coverUri: uploaded });
        dispatch({ type: 'MERGE_SOCIAL', payload: { rooms: [mapChatRoom(dto, getMyRealId())] } });
      } catch (error) {
        console.warn('[menzo/api] updateRoomCover failed', error);
        showToast('No pudimos actualizar la portada. Inténtalo de nuevo.');
      }
    }

    async function updateRoomBackground(roomId: string, backgroundUri: string) {
      if (!hasSession()) return;
      try {
        const uploaded = backgroundUri === '' ? '' : await ensureUploaded(backgroundUri);
        const dto = await chatApi.updateRoom(roomId, { backgroundUri: uploaded });
        dispatch({ type: 'MERGE_SOCIAL', payload: { rooms: [mapChatRoom(dto, getMyRealId())] } });
      } catch (error) {
        console.warn('[menzo/api] updateRoomBackground failed', error);
        showToast('No pudimos actualizar el fondo. Inténtalo de nuevo.');
      }
    }

    function toggleFavoriteRoom(roomId: string) {
      const wasFavorite = stateRef.current.social.rooms.find((r) => r.id === roomId)?.favorite ?? false;
      dispatch({ type: 'TOGGLE_FAVORITE_ROOM', payload: { roomId } });
      if (!hasSession()) return;
      const call = wasFavorite ? chatApi.unfavorite(roomId) : chatApi.favorite(roomId);
      call.catch((error) => console.warn('[menzo/api] toggleFavoriteRoom failed', error));
    }

    function votePoll(postId: string, optionId: string) {
      dispatch({ type: 'VOTE_POLL', payload: { postId, optionId } });
      if (!hasSession()) return;
      postsApi.vote(postId, optionId).catch((error) => console.warn('[menzo/api] votePoll failed', error));
    }

    function attendEvent(eventId: string) {
      const wasAttending =
        stateRef.current.social.events.find((e) => e.id === eventId)?.attendees.includes(LOCAL_USER_ID) ?? false;
      dispatch({ type: 'ATTEND_EVENT', payload: { eventId } });
      if (!hasSession()) return;
      const call = wasAttending ? communityApi.unattend(eventId) : communityApi.attend(eventId);
      call.catch((error) => console.warn('[menzo/api] attendEvent failed', error));
    }

    function markNotificationRead(id: string) {
      dispatch({ type: 'MARK_NOTIFICATION_READ', payload: { id } });
      if (hasSession()) notificationsApi.markRead(id).catch((error) => console.warn('[menzo/api] markRead failed', error));
    }

    function markAllNotificationsRead() {
      dispatch({ type: 'MARK_ALL_NOTIFICATIONS_READ' });
      if (hasSession()) notificationsApi.markAllRead().catch((error) => console.warn('[menzo/api] markAllRead failed', error));
    }

    function updateSettings(payload: Partial<AppSettings>) {
      dispatch({ type: 'UPDATE_SETTINGS', payload });
      if (hasSession()) usersApi.updateSettings(payload).catch((error) => console.warn('[menzo/api] updateSettings failed', error));
    }

    function addRecentlyViewed(entry: RecentlyViewedEntry) {
      dispatch({ type: 'ADD_RECENTLY_VIEWED', payload: entry });
      if (hasSession()) {
        activityApi.addRecentlyViewed(entry.kind, entry.id).catch((error) => console.warn('[menzo/api] addRecentlyViewed failed', error));
      }
    }

    function addRecentSearch(query: string) {
      dispatch({ type: 'ADD_RECENT_SEARCH', payload: query });
      if (hasSession()) activityApi.addRecentSearch(query).catch((error) => console.warn('[menzo/api] addRecentSearch failed', error));
    }

    function clearRecentSearches() {
      dispatch({ type: 'CLEAR_RECENT_SEARCHES' });
      if (hasSession()) activityApi.clearRecentSearches().catch((error) => console.warn('[menzo/api] clearRecentSearches failed', error));
    }

    async function resetDemo() {
      const session = getCachedSession();
      if (session) authApi.logout({ refreshToken: session.refreshToken }).catch(() => {});
      await clearSession();
      await resetAllStorage();
      await setItem(StorageKeys.storageVersion, CURRENT_STORAGE_VERSION);
      dispatch({ type: 'RESET_DEMO' });
    }

    async function logout() {
      const session = getCachedSession();
      if (session) authApi.logout({ refreshToken: session.refreshToken }).catch(() => {});
      await clearSession();
      await Promise.all([
        removeItem(StorageKeys.profile),
        removeItem(StorageKeys.socialState),
        removeItem(StorageKeys.onboarding),
      ]);
      dispatch({ type: 'LOGOUT' });
    }

    async function loadPostComments(postId: string) {
      try {
        const page = await postsApi.comments(postId, 0, 30);
        const myRealId = getMyRealId();
        dispatch({
          type: 'MERGE_SOCIAL',
          payload: {
            comments: page.items.map((dto) => mapComment(dto, myRealId)),
            users: page.items.map((dto) => mapUserSummary(dto.author, myRealId)),
          },
        });
      } catch (error) {
        console.warn('[menzo/api] loadPostComments failed', error);
      }
    }

    async function ensurePostLoaded(postId: string) {
      if (stateRef.current.social.posts.some((p) => p.id === postId)) return;
      try {
        const dto = await postsApi.getById(postId);
        const myRealId = getMyRealId();
        dispatch({
          type: 'MERGE_SOCIAL',
          payload: { posts: [mapPost(dto, myRealId)], users: [mapUserSummary(dto.author, myRealId)] },
        });
      } catch (error) {
        console.warn('[menzo/api] ensurePostLoaded failed', error);
      }
    }

    async function ensureUserLoaded(userId: string) {
      if (userId === LOCAL_USER_ID) return;
      if (stateRef.current.social.users.some((u) => u.id === userId)) return;
      try {
        const dto = await usersApi.getById(userId);
        dispatch({ type: 'MERGE_SOCIAL', payload: { users: [mapDemoUser(dto, getMyRealId())] } });
      } catch (error) {
        console.warn('[menzo/api] ensureUserLoaded failed', error);
      }
    }

    async function loadRoomMessages(roomId: string) {
      try {
        const page = await chatApi.messages(roomId, 0, 40);
        const myRealId = getMyRealId();
        const users = page.items.filter((m) => m.author).map((m) => mapUserSummary(m.author!, myRealId));
        dispatch({
          type: 'MERGE_SOCIAL',
          payload: { messages: page.items.map((dto) => mapMessage(dto, myRealId)), users },
        });
      } catch (error) {
        console.warn('[menzo/api] loadRoomMessages failed', error);
      }
    }

    /** Un mensaje empujado por WebSocket (propio o ajeno) — MERGE_SOCIAL ya deduplica por id, así
     * que si este mismo mensaje ya se agregó de forma optimista via sendMessage() no se duplica. */
    function receiveRoomMessage(dto: import('@/services/api').MessageDto) {
      const myRealId = getMyRealId();
      const users = dto.author ? [mapUserSummary(dto.author, myRealId)] : [];
      dispatch({ type: 'MERGE_SOCIAL', payload: { messages: [mapMessage(dto, myRealId)], users } });
    }

    async function loadProfileWall(profileId: string) {
      const targetId = profileId === LOCAL_USER_ID ? getMyRealId() : profileId;
      if (!targetId) return;
      try {
        const page = await usersApi.wall(targetId, 0, 20);
        const myRealId = getMyRealId();
        dispatch({
          type: 'MERGE_SOCIAL',
          payload: {
            wallMessages: page.items.map((dto) => mapWallMessage(dto, myRealId)),
            users: page.items.map((dto) => mapUserSummary(dto.author, myRealId)),
          },
        });
      } catch (error) {
        console.warn('[menzo/api] loadProfileWall failed', error);
      }
    }

    async function loadWallComments(wallMessageId: string) {
      try {
        const dtos = await usersApi.wallComments(wallMessageId);
        const myRealId = getMyRealId();
        dispatch({ type: 'MERGE_SOCIAL', payload: { wallComments: dtos.map((dto) => mapWallComment(dto, myRealId)) } });
      } catch (error) {
        console.warn('[menzo/api] loadWallComments failed', error);
      }
    }

    async function addWallComment(wallMessageId: string, body: string) {
      if (!hasSession()) return;
      try {
        const dto = await usersApi.addWallComment(wallMessageId, body);
        dispatch({ type: 'MERGE_SOCIAL', payload: { wallComments: [mapWallComment(dto, getMyRealId())] } });
      } catch (error) {
        console.warn('[menzo/api] addWallComment failed', error);
      }
    }

    async function toggleWallCommentLike(commentId: string, wallMessageId: string) {
      const wasLiked = stateRef.current.social.wallComments.find((c) => c.id === commentId)?.likedByMe ?? false;
      try {
        if (wasLiked) {
          await usersApi.unlikeWallComment(commentId);
        } else {
          await usersApi.likeWallComment(commentId);
        }
        const myRealId = getMyRealId();
        const dtos = await usersApi.wallComments(wallMessageId);
        dispatch({ type: 'MERGE_SOCIAL', payload: { wallComments: dtos.map((dto) => mapWallComment(dto, myRealId)) } });
      } catch (error) {
        console.warn('[menzo/api] toggleWallCommentLike failed', error);
      }
    }

    async function refreshSocial() {
      const session = getCachedSession();
      const profile = stateRef.current.profile;
      if (!session || !profile) return;
      try {
        const snapshot = await fetchInitialSocialSnapshot(session.userId, profile);
        dispatch({ type: 'SET_SOCIAL_BULK', payload: snapshot });
      } catch (error) {
        console.warn('[menzo/api] refreshSocial failed', error);
      }
    }

    return {
      register,
      login,
      completeOnboarding,
      updateProfile,
      refreshProfile,
      toggleLike,
      toggleBookmark,
      createPost,
      createEvent,
      addComment,
      addWallMessage,
      toggleFollow,
      sendMessage,
      openDirectMessage,
      createRoom,
      joinRoom,
      loadDiscoverRooms,
      updateRoomCover,
      updateRoomBackground,
      toggleFavoriteRoom,
      votePoll,
      attendEvent,
      markNotificationRead,
      markAllNotificationsRead,
      updateSettings,
      addRecentlyViewed,
      addRecentSearch,
      clearRecentSearches,
      resetDemo,
      logout,
      loadPostComments,
      ensurePostLoaded,
      ensureUserLoaded,
      loadRoomMessages,
      receiveRoomMessage,
      loadProfileWall,
      loadWallComments,
      addWallComment,
      toggleWallCommentLike,
      refreshSocial,
    };
  }, [showToast]);

  const value = useMemo(() => ({ state, actions }), [state, actions]);

  return <AppStateContext.Provider value={value}>{children}</AppStateContext.Provider>;
}

export function useAppState() {
  const ctx = useContext(AppStateContext);
  if (!ctx) throw new Error('useAppState must be used within an AppStateProvider');
  return ctx;
}

export { LOCAL_USER_ID };
