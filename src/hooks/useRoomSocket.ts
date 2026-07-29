import { Client } from '@stomp/stompjs';
import { useCallback, useEffect, useRef, useState } from 'react';

import { useAppState } from '@/hooks/useAppState';
import { API_BASE_URL, getCachedSession } from '@/services/api';
import type { RoomModerationEvent } from '@/services/api/types';

const TYPING_EXPIRY_MS = 3000;
const TYPING_PUBLISH_THROTTLE_MS = 2000;

export type TypingUser = { userId: string; displayName: string };
export type RemovalReason = 'kicked' | 'banned';

function wsUrl(): string {
  return API_BASE_URL.replace(/^http/, 'ws') + '/ws';
}

/** Reemplaza el polling de 5s por push en vivo: se suscribe a los mensajes y a las señales de
 * "está escribiendo" de una sala por WebSocket/STOMP — misma implementación que la web (ver
 * lib/realtime/useRoomSocket.ts en menzoweb), usando el WebSocket global que React Native también
 * expone. Los "escribiendo" son puramente locales a este hook y expiran solos 3s después del
 * último evento, sin tocar la base de datos. */
export function useRoomSocket(roomId: string | undefined) {
  const { actions } = useAppState();
  const [typingUsers, setTypingUsers] = useState<TypingUser[]>([]);
  const [removalReason, setRemovalReason] = useState<RemovalReason | null>(null);
  const clientRef = useRef<Client | null>(null);
  const typingTimeoutsRef = useRef<Map<string, ReturnType<typeof setTimeout>>>(new Map());
  const lastTypingPublishRef = useRef(0);

  useEffect(() => {
    if (!roomId) return;
    const session = getCachedSession();
    if (!session) return;

    const typingTimeouts = typingTimeoutsRef.current;

    const client = new Client({
      brokerURL: wsUrl(),
      connectHeaders: { Authorization: `Bearer ${session.accessToken}` },
      reconnectDelay: 3000,
      onConnect: () => {
        client.subscribe(`/topic/rooms/${roomId}/messages`, (frame) => {
          actions.receiveRoomMessage(JSON.parse(frame.body));
        });
        client.subscribe(`/topic/rooms/${roomId}/typing`, (frame) => {
          const event = JSON.parse(frame.body) as { userId: string; displayName: string; typing: boolean };
          if (event.userId === session.userId) return;

          const existing = typingTimeouts.get(event.userId);
          if (existing) clearTimeout(existing);

          if (!event.typing) {
            typingTimeouts.delete(event.userId);
            setTypingUsers((prev) => prev.filter((u) => u.userId !== event.userId));
            return;
          }

          setTypingUsers((prev) =>
            prev.some((u) => u.userId === event.userId) ? prev : [...prev, { userId: event.userId, displayName: event.displayName }]
          );
          typingTimeouts.set(
            event.userId,
            setTimeout(() => {
              typingTimeouts.delete(event.userId);
              setTypingUsers((prev) => prev.filter((u) => u.userId !== event.userId));
            }, TYPING_EXPIRY_MS)
          );
        });
        client.subscribe(`/topic/rooms/${roomId}/moderation`, (frame) => {
          const event = JSON.parse(frame.body) as RoomModerationEvent;
          if (event.targetUserId !== session.userId) return;
          if (event.type === 'KICKED') setRemovalReason('kicked');
          if (event.type === 'BANNED') setRemovalReason('banned');
        });
      },
    });
    client.activate();
    clientRef.current = client;

    return () => {
      client.deactivate();
      clientRef.current = null;
      for (const timeout of typingTimeouts.values()) clearTimeout(timeout);
      typingTimeouts.clear();
      setTypingUsers([]);
      setRemovalReason(null);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps -- actions is stable app-wide; re-running this on identity churn would tear down/reconnect the socket for no reason
  }, [roomId]);

  const publishTyping = useCallback(() => {
    if (!roomId) return;
    const client = clientRef.current;
    if (!client?.connected) return;
    const now = Date.now();
    if (now - lastTypingPublishRef.current < TYPING_PUBLISH_THROTTLE_MS) return;
    lastTypingPublishRef.current = now;
    client.publish({ destination: `/app/rooms/${roomId}/typing`, body: JSON.stringify({ typing: true }) });
  }, [roomId]);

  return { typingUsers, publishTyping, removalReason };
}
