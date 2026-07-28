import type { GradientId } from '@/theme';

export type AuraId = 'fuego' | 'tormenta' | 'eclipse' | 'renacer' | 'prisma';

export type InterestId =
  | 'anime'
  | 'manga'
  | 'videojuegos'
  | 'arte'
  | 'escritura'
  | 'futbol'
  | 'musica'
  | 'nostalgia';

export type Interest = {
  id: InterestId;
  label: string;
  icon: string;
  gradient: GradientId;
};

export type Aura = {
  id: AuraId;
  name: string;
  description: string;
  gradient: GradientId;
};

export type Badge = {
  id: string;
  name: string;
  description: string;
  icon: string;
  gradient: GradientId;
};

export type UserProfile = {
  id: string;
  displayName: string;
  username: string;
  avatarUri?: string;
  avatarGradient: GradientId;
  coverUri?: string;
  backgroundUri?: string;
  backgroundColor?: string;
  aura: AuraId;
  bio: string;
  statusText: string;
  interests: InterestId[];
  joinedAt: string;
  level: number;
  xp: number;
  reputation: number;
  followers: number;
  following: number;
  visitors: number;
  isOnline: boolean;
  badges: string[];
  isLocalUser?: boolean;
  followedByMe?: boolean;
  followsMe?: boolean;
};

export type DemoUser = UserProfile & {
  activityStatus: string;
};
