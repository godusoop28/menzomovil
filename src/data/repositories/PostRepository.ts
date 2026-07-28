import type { Comment, Post } from '@/types';

export interface PostRepository {
  listPosts(): Promise<Post[]>;
  savePosts(posts: Post[]): Promise<void>;
  listComments(): Promise<Comment[]>;
  saveComments(comments: Comment[]): Promise<void>;
}
