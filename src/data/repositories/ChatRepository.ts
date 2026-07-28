import type { ChatRoom, Message } from '@/types';

export interface ChatRepository {
  listRooms(): Promise<ChatRoom[]>;
  saveRooms(rooms: ChatRoom[]): Promise<void>;
  listMessages(): Promise<Message[]>;
  saveMessages(messages: Message[]): Promise<void>;
}
