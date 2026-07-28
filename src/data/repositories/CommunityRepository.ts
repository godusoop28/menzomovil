import type { CommunityConfig, CommunityEvent, Notification } from '@/types';

export interface CommunityRepository {
  getConfig(): Promise<CommunityConfig>;
  listEvents(): Promise<CommunityEvent[]>;
  saveEvents(events: CommunityEvent[]): Promise<void>;
  listNotifications(): Promise<Notification[]>;
  saveNotifications(notifications: Notification[]): Promise<void>;
}
