import { communityConfig } from '@/config/community';
import { getItem, setItem, StorageKeys } from '@/store/storage';
import type { AppState } from '@/store/types';

import type { ChatRepository } from '../ChatRepository';
import type { CommunityRepository } from '../CommunityRepository';
import type { PostRepository } from '../PostRepository';
import type { ProfileRepository } from '../ProfileRepository';

/**
 * Local (AsyncStorage-backed) implementations of the repository interfaces.
 * The app screens read/write through `AppStateContext`, which already owns this
 * same storage — these classes are the seam a future HTTP implementation would
 * slot into without touching screen code, per the "no backend yet" requirement.
 */

async function readSocial() {
  return (await getItem<AppState['social']>(StorageKeys.socialState)) ?? null;
}

async function writeSocial(patch: Partial<AppState['social']>) {
  const current = await readSocial();
  if (!current) return;
  await setItem(StorageKeys.socialState, { ...current, ...patch });
}

export const localProfileRepository: ProfileRepository = {
  async getProfile() {
    return getItem(StorageKeys.profile);
  },
  async saveProfile(profile) {
    await setItem(StorageKeys.profile, profile);
  },
};

export const localPostRepository: PostRepository = {
  async listPosts() {
    return (await readSocial())?.posts ?? [];
  },
  async savePosts(posts) {
    await writeSocial({ posts });
  },
  async listComments() {
    return (await readSocial())?.comments ?? [];
  },
  async saveComments(comments) {
    await writeSocial({ comments });
  },
};

export const localChatRepository: ChatRepository = {
  async listRooms() {
    return (await readSocial())?.rooms ?? [];
  },
  async saveRooms(rooms) {
    await writeSocial({ rooms });
  },
  async listMessages() {
    return (await readSocial())?.messages ?? [];
  },
  async saveMessages(messages) {
    await writeSocial({ messages });
  },
};

export const localCommunityRepository: CommunityRepository = {
  async getConfig() {
    return communityConfig;
  },
  async listEvents() {
    return (await readSocial())?.events ?? [];
  },
  async saveEvents(events) {
    await writeSocial({ events });
  },
  async listNotifications() {
    return (await readSocial())?.notifications ?? [];
  },
  async saveNotifications(notifications) {
    await writeSocial({ notifications });
  },
};
