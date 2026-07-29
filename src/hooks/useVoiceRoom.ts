import { useCallback, useEffect, useRef, useState } from 'react';
import { PermissionsAndroid, Platform } from 'react-native';
import {
  ChannelProfileType,
  ClientRoleType,
  createAgoraRtcEngine,
  type IRtcEngine,
  type IRtcEngineEventHandler,
} from 'react-native-agora';

import { getMyRealId, mapUserSummary, voiceApi } from '@/services/api';
import type { DemoUser } from '@/types';

const SPEAKING_VOLUME_THRESHOLD = 20; // AudioVolumeInfo.volume va de 0 a 255.

async function ensureMicPermission(): Promise<boolean> {
  if (Platform.OS !== 'android') return true;
  const granted = await PermissionsAndroid.request(PermissionsAndroid.PERMISSIONS.RECORD_AUDIO);
  return granted === PermissionsAndroid.RESULTS.GRANTED;
}

export function useVoiceRoom(roomId: string | undefined) {
  const [connected, setConnected] = useState(false);
  const [connecting, setConnecting] = useState(false);
  const [muted, setMuted] = useState(false);
  const [participants, setParticipants] = useState<DemoUser[]>([]);
  const [speakingUserIds, setSpeakingUserIds] = useState<Set<string>>(new Set());
  const [permissionDenied, setPermissionDenied] = useState(false);
  const engineRef = useRef<IRtcEngine | null>(null);
  const handlerRef = useRef<IRtcEngineEventHandler | null>(null);
  const accountsByUid = useRef<Map<number, string>>(new Map());

  const refreshParticipants = useCallback(async () => {
    if (!roomId) return;
    try {
      const dto = await voiceApi.participants(roomId);
      const myRealId = getMyRealId();
      setParticipants(dto.participants.map((p) => mapUserSummary(p, myRealId)));
    } catch (error) {
      console.warn('[menzo/voice] participants failed', error);
    }
  }, [roomId]);

  useEffect(() => {
    if (!roomId) return;
    // eslint-disable-next-line react-hooks/set-state-in-effect -- fetch-then-poll on mount, same pattern used for messages/wall comments elsewhere in this app
    refreshParticipants();
    const interval = setInterval(refreshParticipants, 5000);
    return () => clearInterval(interval);
  }, [roomId, refreshParticipants]);

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
    setConnected(false);
    setSpeakingUserIds(new Set());
  }, []);

  const join = useCallback(async () => {
    if (!roomId || connecting || connected) return;
    setConnecting(true);
    setPermissionDenied(false);
    try {
      const hasPermission = await ensureMicPermission();
      if (!hasPermission) {
        setPermissionDenied(true);
        return;
      }

      const { appId, channelName, token, uid } = await voiceApi.getToken(roomId);

      const engine = createAgoraRtcEngine();
      engineRef.current = engine;
      engine.initialize({ appId, channelProfile: ChannelProfileType.ChannelProfileCommunication });

      const handler: IRtcEngineEventHandler = {
        onUserInfoUpdated: (uid, info) => {
          if (info.userAccount) accountsByUid.current.set(uid, info.userAccount);
        },
        onAudioVolumeIndication: (_connection, speakers) => {
          const speaking = new Set<string>();
          for (const speaker of speakers) {
            if ((speaker.volume ?? 0) <= SPEAKING_VOLUME_THRESHOLD) continue;
            if (speaker.uid === 0 || speaker.uid === undefined) {
              speaking.add(uid);
            } else {
              const account = accountsByUid.current.get(speaker.uid);
              if (account) speaking.add(account);
            }
          }
          setSpeakingUserIds(speaking);
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
      refreshParticipants();
    } catch (error) {
      console.warn('[menzo/voice] join failed', error);
      cleanupEngine();
    } finally {
      setConnecting(false);
    }
  }, [roomId, connecting, connected, refreshParticipants, cleanupEngine]);

  const leave = useCallback(async () => {
    cleanupEngine();
    if (roomId) {
      await voiceApi.leave(roomId).catch(() => {});
      refreshParticipants();
    }
  }, [cleanupEngine, roomId, refreshParticipants]);

  const toggleMute = useCallback(() => {
    if (!engineRef.current) return;
    const next = !muted;
    engineRef.current.muteLocalAudioStream(next);
    setMuted(next);
  }, [muted]);

  // Salir de la voz si el usuario navega fuera de la sala sin tocar "Salir".
  useEffect(() => {
    return () => {
      if (engineRef.current) {
        cleanupEngine();
        if (roomId) voiceApi.leave(roomId).catch(() => {});
      }
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [roomId]);

  return { connected, connecting, muted, participants, speakingUserIds, permissionDenied, join, leave, toggleMute };
}
