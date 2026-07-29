import { Client } from '@stomp/stompjs';
import { useEffect, useRef } from 'react';

import { useAppState } from '@/hooks/useAppState';
import { API_BASE_URL, getCachedSession } from '@/services/api';
import type { WallCommentEventDto } from '@/services/api/types';

function wsUrl(): string {
  return API_BASE_URL.replace(/^http/, 'ws') + '/ws';
}

/** Espejo de useRoomSocket pero para los comentarios de UNA publicación de muro — solo se activa
 * mientras esa publicación está expandida (wallMessageId no es undefined), así que no hay una
 * conexión STOMP por cada tarjeta de muro renderizada, solo por la que el usuario abrió. */
export function useWallCommentsSocket(wallMessageId: string | undefined) {
  const { actions } = useAppState();
  const clientRef = useRef<Client | null>(null);

  useEffect(() => {
    if (!wallMessageId) return;
    const session = getCachedSession();
    if (!session) return;

    let hasConnectedBefore = false;

    const client = new Client({
      brokerURL: wsUrl(),
      connectHeaders: { Authorization: `Bearer ${session.accessToken}` },
      reconnectDelay: 3000,
      onConnect: () => {
        if (hasConnectedBefore) {
          actions.loadWallComments(wallMessageId);
        }
        hasConnectedBefore = true;

        client.subscribe(`/topic/wall/${wallMessageId}/comments`, (frame) => {
          const event = JSON.parse(frame.body) as WallCommentEventDto;
          if (event.type === 'created' && event.comment) {
            actions.receiveWallComment(event.comment);
          } else if (event.type === 'deleted' && event.deletedCommentId) {
            actions.removeWallComment(event.deletedCommentId, wallMessageId);
          }
        });
      },
    });
    client.activate();
    clientRef.current = client;

    return () => {
      client.deactivate();
      clientRef.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps -- actions is stable app-wide; re-running this on identity churn would tear down/reconnect the socket for no reason
  }, [wallMessageId]);
}
