import type { UserProfile } from '@/types';

export interface ProfileRepository {
  getProfile(): Promise<UserProfile | null>;
  saveProfile(profile: UserProfile): Promise<void>;
}
