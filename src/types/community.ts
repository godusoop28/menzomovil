export type CommunityConfig = {
  name: string;
  subtitle: string;
  description: string;
  motto: string;
  memberCount: number;
  onlineCount: number;
  tags: string[];
};

export type Notification = {
  id: string;
  category: 'comentarios' | 'likes' | 'mensajes' | 'eventos' | 'seguimientos';
  title: string;
  body: string;
  createdAt: string;
  read: boolean;
  relatedPostId?: string;
  relatedRoomId?: string;
  relatedUserId?: string;
  relatedEventId?: string;
};
