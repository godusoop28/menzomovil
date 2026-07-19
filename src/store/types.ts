import type {
  AppSettings,
  ChatRoom,
  Comment,
  CommunityEvent,
  DemoUser,
  Message,
  Notification,
  Post,
  UserProfile,
  WallMessage,
} from '@/types';

export type RecentlyViewedEntry = {
  kind: 'post' | 'member';
  id: string;
  at: string;
};

export type SocialState = {
  users: DemoUser[];
  posts: Post[];
  comments: Comment[];
  rooms: ChatRoom[];
  messages: Message[];
  notifications: Notification[];
  events: CommunityEvent[];
  wallMessages: WallMessage[];
  following: string[];
  recentlyViewed: RecentlyViewedEntry[];
  recentSearches: string[];
};

export type AppState = {
  isHydrated: boolean;
  profile: UserProfile | null;
  onboardingCompleted: boolean;
  settings: AppSettings;
  social: SocialState;
};

export type OnboardingPayload = {
  displayName: string;
  aura: UserProfile['aura'];
  avatarUri?: string;
  avatarGradient: UserProfile['avatarGradient'];
  interests: UserProfile['interests'];
};
