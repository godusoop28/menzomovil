import { createContext, useCallback, useContext, useEffect, useRef, useState } from 'react';
import { PermissionsAndroid, Platform } from 'react-native';
import {
  ChannelProfileType,
  ClientRoleType,
  createAgoraRtcEngine,
  type IRtcEngine,
  type IRtcEngineEventHandler,
} from 'react-native-agora';

import { startVoiceForegroundService, stopVoiceForegroundService } from '../../modules/voice-foreground-service';
import { getMyRealId, mapUserSummary, voiceApi } from '@/services/api';
import { findRoom } from '@/store/selectors';
import { useAppState } from '@/store/AppStateContext';
import type { DemoUser } from '@/types';

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

type VoiceRoomContextValue = {
  activeRoomId: string | null;
  connected: boolean;
  connecting: boolean;
  muted: boolean;
  participants: DemoUser[];
  speakingLevels: Map<string, number>;
  permissionDenied: boolean;
  join: (roomId: string) => Promise<void>;
  leave: () => Promise<void>;
  toggleMute: () => void;
};

const VoiceRoomContext = createContext<VoiceRoomContextValue | null>(null);

/** Antes esto era un hook (`useVoiceRoom(roomId)`) instanciado directamente en la pantalla de
 * chat — el engine de Agora vivía y moría con esa pantalla, así que Expo Router la desmontaba al
 * navegar a otra ruta y la voz se cortaba aunque la sala siguiera en vivo. Ahora es un Provider
 * montado una sola vez en src/app/_layout.tsx, por encima del Stack — el engine sobrevive a
 * cualquier navegación entre pantallas. */
export function VoiceRoomProvider({ children }: { children: React.ReactNode }) {
  const { state } = useAppState();
  const [activeRoomId, setActiveRoomId] = useState<string | null>(null);
  const [connected, setConnected] = useState(false);
  const [connecting, setConnecting] = useState(false);
  const [muted, setMuted] = useState(false);
  const [participants, setParticipants] = useState<DemoUser[]>([]);
  const [speakingLevels, setSpeakingLevels] = useState<Map<string, number>>(new Map());
  const [permissionDenied, setPermissionDenied] = useState(false);
  const engineRef = useRef<IRtcEngine | null>(null);
  const handlerRef = useRef<IRtcEngineEventHandler | null>(null);
  const accountsByUid = useRef<Map<number, string>>(new Map());
  const activeRoomIdRef = useRef<string | null>(null);

  const refreshParticipants = useCallback(async (roomId: string) => {
    try {
      const dto = await voiceApi.participants(roomId);
      const myRealId = getMyRealId();
      setParticipants(dto.participants.map((p) => mapUserSummary(p, myRealId)));
    } catch (error) {
      console.warn('[menzo/voice] participants failed', error);
    }
  }, []);

  useEffect(() => {
    if (!activeRoomId) return;
    // eslint-disable-next-line react-hooks/set-state-in-effect -- fetch-then-poll on room change, same pattern used elsewhere in this app
    refreshParticipants(activeRoomId);
    const interval = setInterval(() => refreshParticipants(activeRoomId), 5000);
    return () => clearInterval(interval);
  }, [activeRoomId, refreshParticipants]);

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
  }, []);

  const join = useCallback(
    async (roomId: string) => {
      if (connecting || (connected && activeRoomIdRef.current === roomId)) return;
      // Si ya estaba en otra sala, salir de esa primero — solo se puede estar en un live a la vez.
      if (engineRef.current) {
        cleanupEngine();
      }
      setConnecting(true);
      setPermissionDenied(false);
      try {
        const hasPermission = await ensureMicPermission();
        if (!hasPermission) {
          setPermissionDenied(true);
          return;
        }

        activeRoomIdRef.current = roomId;
        setActiveRoomId(roomId);

        const { appId, channelName, token, uid } = await voiceApi.getToken(roomId);

        const engine = createAgoraRtcEngine();
        engineRef.current = engine;
        engine.initialize({ appId, channelProfile: ChannelProfileType.ChannelProfileCommunication });

        const handler: IRtcEngineEventHandler = {
          onUserInfoUpdated: (uid, info) => {
            if (info.userAccount) accountsByUid.current.set(uid, info.userAccount);
          },
          onAudioVolumeIndication: (_connection, speakers) => {
            const levels = new Map<string, number>();
            for (const speaker of speakers) {
              const level = normalizeVolume(speaker.volume ?? 0);
              if (speaker.uid === 0 || speaker.uid === undefined) {
                levels.set(uid, level);
              } else {
                const account = accountsByUid.current.get(speaker.uid);
                if (account) levels.set(account, level);
              }
            }
            setSpeakingLevels(levels);
          },
          onError: (err, msg) => console.warn('[menzo/voice] engine error', err, msg),
        };
        handlerRef.current = handler;
        engine.registerEventHandler(handler);
        engine.enableAudioVolumeIndication(1000, 3, false);

        engine.joinChannelWithUserAccount(token, channelName, uid, {
          channelProfile: ChannelProfileType.ChannelProfileCommunication,
          clientRoleType: ClientRoleType.ClientRoleBroadcaster,
          publishMicrophoneTrack: true,
          autoSubscribeAudio: true,
        });

        await voiceApi.join(roomId);
        setConnected(true);
        setMuted(false);
        refreshParticipants(roomId);

        const room = findRoom(state.social, roomId);
        const roomLabel = room ? (room.type === 'direct' ? (room.peer?.displayName ?? room.name) : room.name) : 'Sala de voz';
        requestNotificationPermission();
        startVoiceForegroundService(roomLabel);
      } catch (error) {
        console.warn('[menzo/voice] join failed', error);
        cleanupEngine();
        activeRoomIdRef.current = null;
        setActiveRoomId(null);
      } finally {
        setConnecting(false);
      }
    },
    [connecting, connected, cleanupEngine, refreshParticipants, state.social]
  );

  const leave = useCallback(async () => {
    const roomId = activeRoomIdRef.current;
    cleanupEngine();
    activeRoomIdRef.current = null;
    setActiveRoomId(null);
    if (roomId) {
      await voiceApi.leave(roomId).catch(() => {});
    }
  }, [cleanupEngine]);

  const toggleMute = useCallback(() => {
    if (!engineRef.current) return;
    const next = !muted;
    engineRef.current.muteLocalAudioStream(next);
    setMuted(next);
  }, [muted]);

  return (
    <VoiceRoomContext.Provider
      value={{
        activeRoomId,
        connected,
        connecting,
        muted,
        participants,
        speakingLevels,
        permissionDenied,
        join,
        leave,
        toggleMute,
      }}>
      {children}
    </VoiceRoomContext.Provider>
  );
}

export function useVoiceRoomContext() {
  const ctx = useContext(VoiceRoomContext);
  if (!ctx) throw new Error('useVoiceRoomContext must be used within a VoiceRoomProvider');
  return ctx;
}
