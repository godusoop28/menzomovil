import {
  defaultSettings,
  type AppSettings,
  type Comment,
  type CommunityEvent,
  type Message,
  type Post,
  type UserProfile,
  type WallMessage,
} from '@/types';

import { LOCAL_USER_ID } from './localUser';
import type { AppState, RecentlyViewedEntry, SocialState } from './types';

export function createDefaultSocialState(): SocialState {
  return {
    users: [],
    posts: [],
    comments: [],
    rooms: [],
    messages: [],
    notifications: [],
    events: [],
    wallMessages: [],
    wallComments: [],
    following: [],
    recentlyViewed: [],
    recentSearches: [],
  };
}

export function createDefaultState(): AppState {
  return {
    isHydrated: false,
    profile: null,
    onboardingCompleted: false,
    settings: { ...defaultSettings },
    social: createDefaultSocialState(),
  };
}

type MergeableSocialState = Pick<
  SocialState,
  'users' | 'posts' | 'comments' | 'messages' | 'wallMessages' | 'wallComments' | 'events' | 'rooms' | 'notifications'
>;

export type Action =
  | { type: 'HYDRATE'; payload: AppState }
  | { type: 'SET_SESSION'; payload: { profile: UserProfile; onboardingCompleted: boolean } }
  | { type: 'LOGOUT' }
  | { type: 'SET_SOCIAL_BULK'; payload: Partial<SocialState> }
  | { type: 'MERGE_SOCIAL'; payload: Partial<MergeableSocialState> }
  | { type: 'UPDATE_PROFILE'; payload: Partial<UserProfile> }
  | { type: 'TOGGLE_LIKE'; payload: { postId: string } }
  | { type: 'TOGGLE_BOOKMARK'; payload: { postId: string } }
  | { type: 'CREATE_POST'; payload: Post }
  | { type: 'CREATE_EVENT'; payload: CommunityEvent }
  | { type: 'ADD_COMMENT'; payload: Comment }
  | { type: 'ADD_WALL_MESSAGE'; payload: WallMessage }
  | { type: 'TOGGLE_FOLLOW'; payload: { userId: string } }
  | { type: 'SEND_MESSAGE'; payload: Message }
  | { type: 'TOGGLE_FAVORITE_ROOM'; payload: { roomId: string } }
  | { type: 'VOTE_POLL'; payload: { postId: string; optionId: string } }
  | { type: 'ATTEND_EVENT'; payload: { eventId: string } }
  | { type: 'MARK_NOTIFICATION_READ'; payload: { id: string } }
  | { type: 'MARK_ALL_NOTIFICATIONS_READ' }
  | { type: 'UPDATE_SETTINGS'; payload: Partial<AppSettings> }
  | { type: 'ADD_RECENTLY_VIEWED'; payload: RecentlyViewedEntry }
  | { type: 'ADD_RECENT_SEARCH'; payload: string }
  | { type: 'CLEAR_RECENT_SEARCHES' }
  | { type: 'RESET_DEMO' };

function nextLevel(xp: number) {
  return Math.floor(xp / 500) + 1;
}

function mergeById<T extends { id: string }>(existing: T[], incoming: T[]): T[] {
  const map = new Map(existing.map((item) => [item.id, item]));
  for (const item of incoming) map.set(item.id, item);
  return Array.from(map.values());
}

export function appReducer(state: AppState, action: Action): AppState {
  switch (action.type) {
    case 'HYDRATE':
      return { ...action.payload, isHydrated: true };

    case 'SET_SESSION': {
      const { profile, onboardingCompleted } = action.payload;
      return {
        ...state,
        profile,
        onboardingCompleted,
        social: {
          ...state.social,
          users: [
            { ...profile, activityStatus: profile.statusText },
            ...state.social.users.filter((u) => u.id !== profile.id),
          ],
        },
      };
    }

    case 'LOGOUT':
      return {
        ...state,
        profile: null,
        onboardingCompleted: false,
        social: createDefaultSocialState(),
      };

    case 'SET_SOCIAL_BULK':
      return { ...state, social: { ...state.social, ...action.payload } };

    case 'MERGE_SOCIAL': {
      const p = action.payload;
      return {
        ...state,
        social: {
          ...state.social,
          users: p.users ? mergeById(state.social.users, p.users) : state.social.users,
          posts: p.posts ? mergeById(state.social.posts, p.posts) : state.social.posts,
          comments: p.comments ? mergeById(state.social.comments, p.comments) : state.social.comments,
          messages: p.messages ? mergeById(state.social.messages, p.messages) : state.social.messages,
          wallMessages: p.wallMessages
            ? mergeById(state.social.wallMessages, p.wallMessages)
            : state.social.wallMessages,
          wallComments: p.wallComments
            ? mergeById(state.social.wallComments, p.wallComments)
            : state.social.wallComments,
          events: p.events ? mergeById(state.social.events, p.events) : state.social.events,
          rooms: p.rooms ? mergeById(state.social.rooms, p.rooms) : state.social.rooms,
          notifications: p.notifications
            ? mergeById(state.social.notifications, p.notifications)
            : state.social.notifications,
        },
      };
    }

    case 'UPDATE_PROFILE': {
      if (!state.profile) return state;
      const updatedProfile = { ...state.profile, ...action.payload };
      return {
        ...state,
        profile: updatedProfile,
        social: {
          ...state.social,
          users: state.social.users.map((u) =>
            u.id === LOCAL_USER_ID ? { ...u, ...updatedProfile, activityStatus: updatedProfile.statusText } : u
          ),
        },
      };
    }

    case 'TOGGLE_LIKE': {
      const { postId } = action.payload;
      return {
        ...state,
        social: {
          ...state.social,
          posts: state.social.posts.map((post) => {
            if (post.id !== postId) return post;
            const liked = post.likes.includes(LOCAL_USER_ID);
            return {
              ...post,
              likes: liked
                ? post.likes.filter((id) => id !== LOCAL_USER_ID)
                : [...post.likes, LOCAL_USER_ID],
            };
          }),
        },
      };
    }

    case 'TOGGLE_BOOKMARK': {
      const { postId } = action.payload;
      return {
        ...state,
        social: {
          ...state.social,
          posts: state.social.posts.map((post) => {
            if (post.id !== postId) return post;
            const saved = post.bookmarkedBy.includes(LOCAL_USER_ID);
            return {
              ...post,
              bookmarkedBy: saved
                ? post.bookmarkedBy.filter((id) => id !== LOCAL_USER_ID)
                : [...post.bookmarkedBy, LOCAL_USER_ID],
            };
          }),
        },
      };
    }

    case 'CREATE_POST': {
      const gainedXp = 15;
      const xp = (state.profile?.xp ?? 0) + gainedXp;
      const updatedProfile = state.profile ? { ...state.profile, xp, level: nextLevel(xp) } : state.profile;
      return {
        ...state,
        profile: updatedProfile,
        social: {
          ...state.social,
          posts: [action.payload, ...state.social.posts],
          users: state.social.users.map((u) =>
            u.id === LOCAL_USER_ID && updatedProfile ? { ...u, xp, level: nextLevel(xp) } : u
          ),
        },
      };
    }

    case 'CREATE_EVENT': {
      return {
        ...state,
        social: { ...state.social, events: [action.payload, ...state.social.events] },
      };
    }

    case 'ADD_COMMENT': {
      const comment = action.payload;
      return {
        ...state,
        social: {
          ...state.social,
          comments: [...state.social.comments, comment],
          posts: state.social.posts.map((p) =>
            p.id === comment.postId ? { ...p, commentCount: p.commentCount + 1 } : p
          ),
        },
      };
    }

    case 'ADD_WALL_MESSAGE': {
      return {
        ...state,
        social: { ...state.social, wallMessages: [action.payload, ...state.social.wallMessages] },
      };
    }

    case 'TOGGLE_FOLLOW': {
      const { userId } = action.payload;
      const isFollowing = state.social.following.includes(userId);
      const following = isFollowing
        ? state.social.following.filter((id) => id !== userId)
        : [...state.social.following, userId];

      return {
        ...state,
        profile: state.profile ? { ...state.profile, following: following.length } : state.profile,
        social: {
          ...state.social,
          following,
          users: state.social.users.map((u) =>
            u.id === userId ? { ...u, followers: u.followers + (isFollowing ? -1 : 1) } : u
          ),
        },
      };
    }

    case 'SEND_MESSAGE': {
      return {
        ...state,
        social: { ...state.social, messages: [...state.social.messages, action.payload] },
      };
    }

    case 'TOGGLE_FAVORITE_ROOM': {
      const { roomId } = action.payload;
      return {
        ...state,
        social: {
          ...state.social,
          rooms: state.social.rooms.map((r) =>
            r.id === roomId ? { ...r, favorite: !r.favorite } : r
          ),
        },
      };
    }

    case 'VOTE_POLL': {
      const { postId, optionId } = action.payload;
      return {
        ...state,
        social: {
          ...state.social,
          posts: state.social.posts.map((post) => {
            if (post.id !== postId || !post.pollOptions) return post;
            const alreadyVoted = post.pollOptions.find((o) => o.id === optionId)?.votes.includes(LOCAL_USER_ID);
            return {
              ...post,
              pollOptions: post.pollOptions.map((option) => {
                const withoutMe = option.votes.filter((id) => id !== LOCAL_USER_ID);
                if (option.id === optionId && !alreadyVoted) {
                  return { ...option, votes: [...withoutMe, LOCAL_USER_ID] };
                }
                return { ...option, votes: withoutMe };
              }),
            };
          }),
        },
      };
    }

    case 'ATTEND_EVENT': {
      const { eventId } = action.payload;
      return {
        ...state,
        social: {
          ...state.social,
          events: state.social.events.map((event) => {
            if (event.id !== eventId) return event;
            const attending = event.attendees.includes(LOCAL_USER_ID);
            return {
              ...event,
              attendees: attending
                ? event.attendees.filter((id) => id !== LOCAL_USER_ID)
                : [...event.attendees, LOCAL_USER_ID],
            };
          }),
        },
      };
    }

    case 'MARK_NOTIFICATION_READ': {
      const { id } = action.payload;
      return {
        ...state,
        social: {
          ...state.social,
          notifications: state.social.notifications.map((n) =>
            n.id === id ? { ...n, read: true } : n
          ),
        },
      };
    }

    case 'MARK_ALL_NOTIFICATIONS_READ':
      return {
        ...state,
        social: {
          ...state.social,
          notifications: state.social.notifications.map((n) => ({ ...n, read: true })),
        },
      };

    case 'UPDATE_SETTINGS':
      return { ...state, settings: { ...state.settings, ...action.payload } };

    case 'ADD_RECENTLY_VIEWED': {
      const filtered = state.social.recentlyViewed.filter(
        (entry) => !(entry.kind === action.payload.kind && entry.id === action.payload.id)
      );
      return {
        ...state,
        social: {
          ...state.social,
          recentlyViewed: [action.payload, ...filtered].slice(0, 20),
        },
      };
    }

    case 'ADD_RECENT_SEARCH': {
      const query = action.payload.trim();
      if (!query) return state;
      const filtered = state.social.recentSearches.filter(
        (q) => q.toLowerCase() !== query.toLowerCase()
      );
      return {
        ...state,
        social: { ...state.social, recentSearches: [query, ...filtered].slice(0, 8) },
      };
    }

    case 'CLEAR_RECENT_SEARCHES':
      return { ...state, social: { ...state.social, recentSearches: [] } };

    case 'RESET_DEMO':
      return { ...createDefaultState(), isHydrated: true };

    default:
      return state;
  }
}
