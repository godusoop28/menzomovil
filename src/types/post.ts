import type { GradientId } from '@/theme';

export type PostType = 'text' | 'image' | 'poll' | 'question' | 'event';

export type AbstractVisualPreset =
  | 'fire'
  | 'storm'
  | 'eclipse'
  | 'rebirth'
  | 'prism'
  | 'midnight'
  | 'memory'
  | 'community';

export type AbstractVisual = {
  preset: AbstractVisualPreset;
  caption?: string;
};

export type PollOption = {
  id: string;
  label: string;
  votes: string[];
};

export type CommunityEvent = {
  id: string;
  title: string;
  description: string;
  date: string;
  time: string;
  kind: string;
  attendees: string[];
};

export type Post = {
  id: string;
  authorId: string;
  type: PostType;
  title?: string;
  body: string;
  abstractVisual?: AbstractVisual;
  imageUri?: string;
  createdAt: string;
  likes: string[];
  bookmarkedBy: string[];
  commentCount: number;
  featured: boolean;
  tags: string[];
  pollOptions?: PollOption[];
  eventId?: string;
  gradient?: GradientId;
};

export type Comment = {
  id: string;
  postId: string;
  authorId: string;
  body: string;
  createdAt: string;
};
