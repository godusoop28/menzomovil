import { Client } from '@stomp/stompjs';
import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from 'react';
import { PermissionsAndroid, Platform } from 'react-native';
import {
  ChannelProfileType,
  ClientRoleType,
  createAgoraRtcEngine,
  type IRtcEngine,
  type IRtcEngineEventHandler,
} from 'react-native-agora';

import { startVoiceForegroundService, stopVoiceForegroundService } from '../../modules/voice-foreground-service';
import { API_BASE_URL, getCachedSession, getMyRealId, liveApi, mapLiveParticipant, mapLiveSession } from '@/services/api';
import type { LiveEventDto, LiveParticipantDto } from '@/services/api/types';
import { findRoom } from '@/store/selectors';
import { useAppState } from '@/store/AppStateContext';
import type { LiveParticipant, LiveParticipantRole, LiveSessionSummary } from '@/types';

/** AudioVolumeInfo.volume va de 0 a 255 — se normaliza a 0-1 para que la UI no dependa de la escala del SDK nativo. */
function normalizeVolume(volume: number): number {
  return Math.max(0, Math.min(1, volume / 255));
}

async function ensureMicPermission(): Promise<boolean> {
  if (Platform.OS !== 'android') return true;
  const granted = await PermissionsAndroid.request(PermissionsAndroid.PERMISSIONS.RECORD_AUDIO);
  return granted === PermissionsAndroid.RESULTS.GRANTED;
}

/** Sin esto, el foreground service arranca igual (Android lo exige) pero su notificación
 * persistente no se muestra en Android 13+ — no bloqueante, solo mejor UX si el usuario acepta. */
async function requestNotificationPermission(): Promise<void> {
  if (Platform.OS !== 'android' || Platform.Version < 33) return;
  await PermissionsAndroid.request(PermissionsAndroid.PERMISSIONS.POST_NOTIFICATIONS).catch(() => {});
}

function wsUrl(): string {
  return API_BASE_URL.replace(/^http/, 'ws') + '/ws';
}

const SPEAKING_ROLES: LiveParticipantRole[] = ['host', 'co_host', 'speaker'];

function roleOrder(role: LiveParticipantRole): number {
  switch (role) {
    case 'host':
      return 0;
    case 'co_host':
      return 1;
    case 'speaker':
      return 2;
    case 'requested':
      return 3;
    default:
      return 4;
  }
}

type VoiceRoomContextValue = {
  // Estado del LIVE de la sala que se está mirando (cabecera) — no implica estar conectado.
  watchedRoomId: string | null;
  viewingState: LiveSessionSummary | null;
  watchRoom: (roomId: string) => void;
  unwatchRoom: (roomId: string) => void;

  activeRoomId: string | null;
  connected: boolean;
  connecting: boolean;
  myRole: LiveParticipantRole | null;
  canSpeak: boolean;
  muted: boolean;
  // Fuente única del estado del micrófono (ver sección 17 del pedido) — cualquier botón de mic en
  // cualquier pantalla debe leer estos campos, nunca mantener su propia copia del estado.
  microphoneChanging: boolean;
  microphonePermission: 'unknown' | 'granted' | 'denied';
  localAudioPublished: boolean;
  lastMicrophoneError: string | null;
  /** @deprecated usar lastMicrophoneError — se mantiene para no romper pantallas existentes. */
  permissionDenied: boolean;
  participants: LiveParticipant[];
  speakingLevels: Map<string, number>;
  speakingRequests: LiveParticipant[];

  join: (roomId: string) => Promise<void>;
  leave: () => Promise<void>;
  toggleMute: () => Promise<void>;
  startLive: (roomId: string, info?: { title?: string; description?: string; announcement?: string }) => Promise<void>;
  endLive: (roomId: string) => Promise<void>;
  updateLiveInfo: (roomId: string, info: { title?: string; description?: string; announcement?: string }) => Promise<void>;
  requestToSpeak: () => Promise<void>;
  cancelSpeakRequest: () => Promise<void>;
  approveSpeaking: (userId: string) => Promise<void>;
  rejectSpeaking: (userId: string) => Promise<void>;
  demoteParticipant: (userId: string) => Promise<void>;
  muteParticipant: (userId: string) => Promise<void>;
  removeParticipant: (userId: string) => Promise<void>;
  refreshParticipants: () => Promise<void>;
};

const VoiceRoomContext = createContext<VoiceRoomContextValue | null>(null);

/** Provider global (montado una sola vez en src/app/_layout.tsx, por encima del Stack) — el
 * engine de Agora sobrevive a cualquier navegación entre pantallas.
 *
 * Migrado de /api/chat/rooms/{id}/voice/* (todos publisher, sin roles) a
 * /api/chat/rooms/{id}/live/* (HOST/CO_HOST/SPEAKER/AUDIENCE/REQUESTED) — mismo sistema que ya
 * usa menzoweb. Los endpoints /voice/* originales quedan intactos en el backend por si algo más
 * los usa, pero esta app ya no los llama. */
export function VoiceRoomProvider({ children }: { children: React.ReactNode }) {
  const { state } = useAppState();
  const [watchedRoomId, setWatchedRoomId] = useState<string | null>(null);
  const [viewingState, setViewingState] = useState<LiveSessionSummary | null>(null);

  const [activeRoomId, setActiveRoomId] = useState<string | null>(null);
  const [connected, setConnected] = useState(false);
  const [connecting, setConnecting] = useState(false);
  const [myRole, setMyRole] = useState<LiveParticipantRole | null>(null);
  const [muted, setMuted] = useState(true);
  const [microphoneChanging, setMicrophoneChanging] = useState(false);
  const [microphonePermission, setMicrophonePermission] = useState<'unknown' | 'granted' | 'denied'>('unknown');
  const [localAudioPublished, setLocalAudioPublished] = useState(false);
  const [lastMicrophoneError, setLastMicrophoneError] = useState<string | null>(null);
  const [participants, setParticipants] = useState<LiveParticipant[]>([]);
  const [speakingLevels, setSpeakingLevels] = useState<Map<string, number>>(new Map());
  const [speakingRequests, setSpeakingRequests] = useState<LiveParticipant[]>([]);

  const engineRef = useRef<IRtcEngine | null>(null);
  const handlerRef = useRef<IRtcEngineEventHandler | null>(null);
  const accountsByUid = useRef<Map<number, string>>(new Map());
  const activeRoomIdRef = useRef<string | null>(null);
  const myRoleRef = useRef<LiveParticipantRole | null>(null);
  // Refs espejo — leer siempre el valor más reciente dentro de callbacks async evita el bug de
  // doble-toque (un segundo toque antes de que React re-renderice leía un `muted` viejo).
  const mutedRef = useRef(true);
  const stompRef = useRef<Client | null>(null);
  const watchUnsubRef = useRef<(() => void) | null>(null);

  useEffect(() => {
    myRoleRef.current = myRole;
  }, [myRole]);
  useEffect(() => {
    mutedRef.current = muted;
  }, [muted]);

  function ensureStompClient(): Client {
    if (stompRef.current) return stompRef.current;
    const session = getCachedSession();
    const client = new Client({
      brokerURL: wsUrl(),
      connectHeaders: session ? { Authorization: `Bearer ${session.accessToken}` } : {},
      reconnectDelay: 3000,
    });
    client.activate();
    stompRef.current = client;
    return client;
  }

  const subscribeLiveTopic = useCallback((roomId: string, onEvent: (event: LiveEventDto) => void) => {
    const client = ensureStompClient();
    const destination = `/topic/rooms/${roomId}/live`;
    let stompSub: { unsubscribe: () => void } | null = null;
    let cancelled = false;

    function doSubscribe() {
      if (cancelled) return;
      stompSub = client.subscribe(destination, (frame) => {
        try {
          onEvent(JSON.parse(frame.body) as LiveEventDto);
        } catch (error) {
          console.warn('[menzo/live] failed to parse live event', error);
        }
      });
    }

    if (client.connected) {
      doSubscribe();
    } else {
      const prevOnConnect = client.onConnect;
      client.onConnect = (frame) => {
        prevOnConnect?.(frame);
        doSubscribe();
      };
    }

    return () => {
      cancelled = true;
      stompSub?.unsubscribe();
    };
  }, []);

  const refreshParticipants = useCallback(async () => {
    const roomId = activeRoomIdRef.current;
    if (!roomId) return;
    try {
      const dtos = await liveApi.participants(roomId);
      const myRealId = getMyRealId();
      const mapped = dtos.map((dto) => mapLiveParticipant(dto, myRealId)).filter((p): p is LiveParticipant => !!p);
      setParticipants(mapped.sort((a, b) => roleOrder(a.role) - roleOrder(b.role)));
    } catch (error) {
      console.warn('[menzo/live] participants failed', error);
    }
  }, []);

  const cleanupEngine = useCallback(() => {
    const engine = engineRef.current;
    if (engine) {
      engineRef.current = null;
      try {
        if (handlerRef.current) engine.unregisterEventHandler(handlerRef.current);
        engine.leaveChannel();
        engine.release();
      } catch (error) {
        console.warn('[menzo/voice] cleanup failed', error);
      }
    }
    handlerRef.current = null;
    accountsByUid.current.clear();
    stopVoiceForegroundService();
    setConnected(false);
    setSpeakingLevels(new Map());
    setLocalAudioPublished(false);
  }, []);

  /** Habilita captura + publicación de mic — siempre arranca silenciado ("iniciar silenciado por
   * seguridad", ver sección 17/19 del pedido): nadie queda con el micrófono caliente sin haberlo
   * activado a propósito. Si falla (permiso denegado, etc.) no miente sobre el estado: deja
   * localAudioPublished=false y un error legible en vez de un botón que no responde. */
  const enableLocalMic = useCallback(async (): Promise<boolean> => {
    const engine = engineRef.current;
    if (!engine) return false;
    try {
      const hasPermission = await ensureMicPermission();
      if (!hasPermission) {
        setMicrophonePermission('denied');
        setLastMicrophoneError('Necesitamos acceso al micrófono para que puedas hablar.');
        return false;
      }
      setMicrophonePermission('granted');
      engine.enableLocalAudio(true);
      engine.updateChannelMediaOptions({ publishMicrophoneTrack: true });
      engine.muteLocalAudioStream(true);
      setLocalAudioPublished(true);
      setMuted(true);
      setLastMicrophoneError(null);
      return true;
    } catch (error) {
      console.warn('[menzo/live] enableLocalMic failed', error);
      setLocalAudioPublished(false);
      setLastMicrophoneError('No pudimos activar tu micrófono. Intentá de nuevo.');
      return false;
    }
  }, []);

  const disableLocalMic = useCallback(() => {
    const engine = engineRef.current;
    if (!engine) return;
    try {
      engine.muteLocalAudioStream(true);
      engine.updateChannelMediaOptions({ publishMicrophoneTrack: false });
      engine.enableLocalAudio(false);
    } catch (error) {
      console.warn('[menzo/live] disableLocalMic failed', error);
    }
    setLocalAudioPublished(false);
    setMuted(true);
  }, []);

  const becomeSpeaker = useCallback(
    async (roomId: string) => {
      const engine = engineRef.current;
      if (!engine) return;
      try {
        const tokenDto = await liveApi.token(roomId);
        engine.renewToken(tokenDto.token);
        setMyRole('speaker');
        await enableLocalMic();
      } catch (error) {
        console.warn('[menzo/live] becomeSpeaker failed', error);
        setLastMicrophoneError('No pudimos activar tu lugar como hablante. Intentá de nuevo.');
      }
    },
    [enableLocalMic]
  );

  const becomeAudience = useCallback(async () => {
    const roomId = activeRoomIdRef.current;
    disableLocalMic();
    if (roomId) {
      try {
        const tokenDto = await liveApi.token(roomId);
        engineRef.current?.renewToken(tokenDto.token);
      } catch (error) {
        console.warn('[menzo/live] renew subscriber token failed', error);
      }
    }
  }, [disableLocalMic]);

  const applyParticipantEvent = useCallback(
    (event: LiveEventDto) => {
      const myRealId = getMyRealId();
      const payload = event.payload as LiveParticipantDto | null;
      const participant = payload ? mapLiveParticipant(payload, myRealId) : null;

      if (event.type === 'CHAT_LIVE_ENDED') {
        setParticipants([]);
        setSpeakingRequests([]);
        setViewingState((prev) => (prev ? { ...prev, status: 'ended' } : prev));
        return;
      }

      if (!participant) return;
      const isMe = participant.user.id === myRealId;

      setParticipants((prev) => {
        const withoutTarget = prev.filter((p) => p.user.id !== participant.user.id);
        if (event.type === 'CHAT_LIVE_PARTICIPANT_LEFT') return withoutTarget;
        return [...withoutTarget, participant].sort((a, b) => roleOrder(a.role) - roleOrder(b.role));
      });

      if (event.type === 'CHAT_LIVE_SPEAKING_REQUESTED') {
        setSpeakingRequests((prev) => [...prev.filter((p) => p.user.id !== participant.user.id), participant]);
      } else if (event.type === 'CHAT_LIVE_SPEAKING_APPROVED' || event.type === 'CHAT_LIVE_SPEAKING_REJECTED') {
        setSpeakingRequests((prev) => prev.filter((p) => p.user.id !== participant.user.id));
      }

      if (isMe && activeRoomIdRef.current === event.roomId) {
        if (event.type === 'CHAT_LIVE_SPEAKING_APPROVED') {
          becomeSpeaker(event.roomId);
        } else if (event.type === 'CHAT_LIVE_PARTICIPANT_DEMOTED' || event.type === 'CHAT_LIVE_SPEAKING_REJECTED') {
          becomeAudience();
          setMyRole(participant.role);
        } else if (event.type === 'CHAT_LIVE_MICROPHONE_CHANGED' && !participant.microphoneEnabled) {
          engineRef.current?.muteLocalAudioStream(true);
          setMuted(true);
        }
      }
    },
    [becomeSpeaker, becomeAudience]
  );

  const watchRoom = useCallback(
    (roomId: string) => {
      watchUnsubRef.current?.();
      setWatchedRoomId(roomId);
      liveApi
        .state(roomId)
        .then((dto) => setViewingState(dto ? mapLiveSession(dto) : null))
        .catch(() => setViewingState(null));

      watchUnsubRef.current = subscribeLiveTopic(roomId, (event) => {
        if (event.type === 'CHAT_LIVE_STARTED' || event.type === 'CHAT_LIVE_UPDATED') {
          liveApi
            .state(roomId)
            .then((dto) => setViewingState(dto ? mapLiveSession(dto) : null))
            .catch(() => {});
        } else if (event.type === 'CHAT_LIVE_ENDED') {
          setViewingState((prev) => (prev ? { ...prev, status: 'ended' } : prev));
        }
      });
    },
    [subscribeLiveTopic]
  );

  const unwatchRoom = useCallback((roomId: string) => {
    setWatchedRoomId((current) => {
      if (current !== roomId) return current;
      watchUnsubRef.current?.();
      watchUnsubRef.current = null;
      setViewingState(null);
      return null;
    });
  }, []);

  useEffect(() => {
    if (!activeRoomId) return;
    const unsubscribe = subscribeLiveTopic(activeRoomId, applyParticipantEvent);
    return unsubscribe;
  }, [activeRoomId, subscribeLiveTopic, applyParticipantEvent]);

  useEffect(() => {
    if (!activeRoomId) return;
    refreshParticipants();
    const interval = setInterval(() => refreshParticipants(), 15000);
    return () => clearInterval(interval);
  }, [activeRoomId, refreshParticipants]);

  const join = useCallback(
    async (roomId: string) => {
      if (connecting || (connected && activeRoomIdRef.current === roomId)) return;
      if (engineRef.current) {
        cleanupEngine();
      }
      activeRoomIdRef.current = roomId;
      setActiveRoomId(roomId);
      setConnecting(true);
      setLastMicrophoneError(null);
      try {
        const session = await liveApi.join(roomId);
        const role = (session.myRole?.toLowerCase() as LiveParticipantRole) ?? 'audience';
        setMyRole(role);

        const tokenDto = await liveApi.token(roomId);

        const engine = createAgoraRtcEngine();
        engineRef.current = engine;
        engine.initialize({ appId: tokenDto.appId, channelProfile: ChannelProfileType.ChannelProfileCommunication });

        const handler: IRtcEngineEventHandler = {
          onUserInfoUpdated: (uid, info) => {
            if (info.userAccount) accountsByUid.current.set(uid, info.userAccount);
          },
          onAudioVolumeIndication: (_connection, speakers) => {
            const levels = new Map<string, number>();
            for (const speaker of speakers) {
              const level = normalizeVolume(speaker.volume ?? 0);
              if (speaker.uid === 0 || speaker.uid === undefined) {
                levels.set(tokenDto.uid, level);
              } else {
                const account = accountsByUid.current.get(speaker.uid);
                if (account) levels.set(account, level);
              }
            }
            setSpeakingLevels(levels);
          },
          onError: (err, msg) => console.warn('[menzo/live] engine error', err, msg),
        };
        handlerRef.current = handler;
        engine.registerEventHandler(handler);
        engine.enableAudioVolumeIndication(1000, 3, false);

        // Un AUDIENCE nunca intenta capturar el micrófono ni pide el permiso — la única
        // protección real está en el token (subscriber vs publisher, decidido por el backend),
        // pero ni siquiera se intenta publicar salvo que el rol lo permita (ver sección 19).
        const canSpeakInitially = SPEAKING_ROLES.includes(role);
        engine.joinChannelWithUserAccount(tokenDto.token, tokenDto.channelName, tokenDto.uid, {
          channelProfile: ChannelProfileType.ChannelProfileCommunication,
          clientRoleType: ClientRoleType.ClientRoleBroadcaster,
          publishMicrophoneTrack: false,
          autoSubscribeAudio: true,
        });

        setConnected(true);
        await refreshParticipants();

        if (canSpeakInitially) {
          await enableLocalMic();
        }

        const room = findRoom(state.social, roomId);
        const roomLabel = room ? (room.type === 'direct' ? (room.peer?.displayName ?? room.name) : room.name) : 'Sala en vivo';
        requestNotificationPermission();
        startVoiceForegroundService(roomLabel);
      } catch (error) {
        console.warn('[menzo/live] join failed', error);
        cleanupEngine();
        activeRoomIdRef.current = null;
        setActiveRoomId(null);
        setMyRole(null);
      } finally {
        setConnecting(false);
      }
    },
    [connecting, connected, cleanupEngine, refreshParticipants, enableLocalMic, state.social]
  );

  const leave = useCallback(async () => {
    const roomId = activeRoomIdRef.current;
    cleanupEngine();
    activeRoomIdRef.current = null;
    setActiveRoomId(null);
    setMyRole(null);
    setParticipants([]);
    setSpeakingRequests([]);
    if (roomId) await liveApi.leave(roomId).catch(() => {});
  }, [cleanupEngine]);

  /** Flujo completo del botón de micrófono (ver sección 17 del pedido): ignora toques mientras
   * hay un cambio en curso, verifica el rol real (no confía en que el botón esté oculto), y si
   * el mic nunca se pudo activar (localAudioPublished=false) reintenta en vez de fallar en
   * silencio. */
  const toggleMute = useCallback(async () => {
    if (microphoneChanging) return;
    const role = myRoleRef.current;
    if (!role || !SPEAKING_ROLES.includes(role)) {
      setLastMicrophoneError('No tenés permiso para hablar en este LIVE.');
      return;
    }
    const roomId = activeRoomIdRef.current;
    const engine = engineRef.current;
    if (!roomId || !engine) return;

    setMicrophoneChanging(true);
    setLastMicrophoneError(null);
    try {
      if (!localAudioPublished) {
        await enableLocalMic();
        return;
      }
      const next = !mutedRef.current;
      engine.muteLocalAudioStream(next);
      setMuted(next);
      liveApi.setMicrophone(roomId, !next).catch(() => {});
    } catch (error) {
      console.warn('[menzo/live] toggleMute failed', error);
      setLastMicrophoneError('No pudimos cambiar el micrófono. Intentá de nuevo.');
    } finally {
      setMicrophoneChanging(false);
    }
  }, [microphoneChanging, localAudioPublished, enableLocalMic]);

  const startLive = useCallback(
    async (roomId: string, info?: { title?: string; description?: string; announcement?: string }) => {
      const dto = await liveApi.start(roomId, info);
      setViewingState(mapLiveSession(dto));
    },
    []
  );

  const endLive = useCallback(
    async (roomId: string) => {
      await liveApi.end(roomId);
      if (activeRoomIdRef.current === roomId) await leave();
    },
    [leave]
  );

  const updateLiveInfo = useCallback(
    async (roomId: string, info: { title?: string; description?: string; announcement?: string }) => {
      const dto = await liveApi.update(roomId, info);
      setViewingState(mapLiveSession(dto));
    },
    []
  );

  const requestToSpeak = useCallback(async () => {
    const roomId = activeRoomIdRef.current;
    if (!roomId) return;
    await liveApi.requestToSpeak(roomId);
    setMyRole('requested');
  }, []);

  const cancelSpeakRequest = useCallback(async () => {
    const roomId = activeRoomIdRef.current;
    if (!roomId) return;
    await liveApi.cancelSpeakRequest(roomId);
    setMyRole('audience');
  }, []);

  const approveSpeaking = useCallback(async (userId: string) => {
    const roomId = activeRoomIdRef.current;
    if (!roomId) return;
    await liveApi.approveSpeaking(roomId, userId);
  }, []);

  const rejectSpeaking = useCallback(async (userId: string) => {
    const roomId = activeRoomIdRef.current;
    if (!roomId) return;
    await liveApi.rejectSpeaking(roomId, userId);
  }, []);

  const demoteParticipant = useCallback(async (userId: string) => {
    const roomId = activeRoomIdRef.current;
    if (!roomId) return;
    await liveApi.demoteParticipant(roomId, userId);
  }, []);

  const muteParticipant = useCallback(async (userId: string) => {
    const roomId = activeRoomIdRef.current;
    if (!roomId) return;
    await liveApi.muteParticipant(roomId, userId);
  }, []);

  const removeParticipant = useCallback(async (userId: string) => {
    const roomId = activeRoomIdRef.current;
    if (!roomId) return;
    await liveApi.removeParticipant(roomId, userId);
  }, []);

  const canSpeak = myRole !== null && SPEAKING_ROLES.includes(myRole);

  const value = useMemo<VoiceRoomContextValue>(
    () => ({
      watchedRoomId,
      viewingState,
      watchRoom,
      unwatchRoom,
      activeRoomId,
      connected,
      connecting,
      myRole,
      canSpeak,
      muted,
      microphoneChanging,
      microphonePermission,
      localAudioPublished,
      lastMicrophoneError,
      permissionDenied: microphonePermission === 'denied',
      participants,
      speakingLevels,
      speakingRequests,
      join,
      leave,
      toggleMute,
      startLive,
      endLive,
      updateLiveInfo,
      requestToSpeak,
      cancelSpeakRequest,
      approveSpeaking,
      rejectSpeaking,
      demoteParticipant,
      muteParticipant,
      removeParticipant,
      refreshParticipants,
    }),
    [
      watchedRoomId,
      viewingState,
      watchRoom,
      unwatchRoom,
      activeRoomId,
      connected,
      connecting,
      myRole,
      canSpeak,
      muted,
      microphoneChanging,
      microphonePermission,
      localAudioPublished,
      lastMicrophoneError,
      participants,
      speakingLevels,
      speakingRequests,
      join,
      leave,
      toggleMute,
      startLive,
      endLive,
      updateLiveInfo,
      requestToSpeak,
      cancelSpeakRequest,
      approveSpeaking,
      rejectSpeaking,
      demoteParticipant,
      muteParticipant,
      removeParticipant,
      refreshParticipants,
    ]
  );

  return <VoiceRoomContext.Provider value={value}>{children}</VoiceRoomContext.Provider>;
}

export function useVoiceRoomContext() {
  const ctx = useContext(VoiceRoomContext);
  if (!ctx) throw new Error('useVoiceRoomContext must be used within a VoiceRoomProvider');
  return ctx;
}
