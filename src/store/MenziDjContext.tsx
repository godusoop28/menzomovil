import { Client } from '@stomp/stompjs';
import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from 'react';
import { StyleSheet, View } from 'react-native';
import WebView, { type WebViewMessageEvent } from 'react-native-webview';

import { API_BASE_URL, getCachedSession, getMyRealId, mapMusicSession, mapYoutubeSearchResult, musicApi } from '@/services/api';
import { useVoiceRoomContext } from '@/store/VoiceRoomContext';
import type { MusicSessionSummary, YoutubeSearchResult } from '@/types';

import { MENZI_DJ_PLAYER_HTML, YT_PLAYER_STATE } from './menziDjPlayerHtml';

function wsUrl(): string {
  return API_BASE_URL.replace(/^http/, 'ws') + '/ws';
}

const DRIFT_CHECK_INTERVAL_MS = 15_000;
const DRIFT_THRESHOLD_SECONDS = 2;
const AUTOPLAY_CHECK_DELAY_MS = 1800;
const DEFAULT_VOLUME = 80;

type MenziDjContextValue = {
  session: MusicSessionSummary | null;
  loading: boolean;
  expanded: boolean;
  setExpanded: (value: boolean) => void;
  autoplayBlocked: boolean;
  unlockAutoplay: () => void;
  localMuted: boolean;
  localVolume: number;
  toggleLocalMute: () => void;
  setLocalVolume: (value: number) => void;
  refresh: () => Promise<void>;
  searchSongs: (q: string) => Promise<YoutubeSearchResult[]>;
  addToQueue: (videoId: string, playNow?: boolean) => Promise<void>;
  requestSong: (videoId: string) => Promise<void>;
  approveRequest: (id: string) => Promise<void>;
  rejectRequest: (id: string) => Promise<void>;
  play: () => Promise<void>;
  pauseTrack: () => Promise<void>;
  resumeTrack: () => Promise<void>;
  seek: (seconds: number) => Promise<void>;
  skip: () => Promise<void>;
  stopMusic: () => Promise<void>;
  setAllowRequests: (value: boolean) => Promise<void>;
  reorderQueue: (ids: string[]) => Promise<void>;
  removeQueueItem: (id: string) => Promise<void>;
  clearQueue: () => Promise<void>;
};

const MenziDjContext = createContext<MenziDjContextValue | null>(null);

/** Menzi DJ no transmite audio por Agora — el WebView con el reproductor OFICIAL de YouTube
 * (ver menziDjPlayerHtml.ts) vive montado una sola vez acá, sobre el Stack, igual que Agora en
 * VoiceRoomContext: sobrevive a cualquier navegación o minimizado. El ciclo de vida de la música
 * está atado al de la voz (activeRoomId de VoiceRoomContext) — no tiene sentido escuchar música
 * de un LIVE al que no estás conectado. */
export function MenziDjProvider({ children }: { children: React.ReactNode }) {
  const voice = useVoiceRoomContext();
  const [session, setSession] = useState<MusicSessionSummary | null>(null);
  const [loading, setLoading] = useState(false);
  const [expanded, setExpanded] = useState(false);
  const [autoplayBlocked, setAutoplayBlocked] = useState(false);
  const [localMuted, setLocalMuted] = useState(false);
  const [localVolume, setLocalVolumeState] = useState(DEFAULT_VOLUME);
  const [playerReady, setPlayerReady] = useState(false);

  const roomIdRef = useRef<string | null>(null);
  const sessionRef = useRef<MusicSessionSummary | null>(null);
  const webviewRef = useRef<WebView>(null);
  const loadedVideoIdRef = useRef<string | null>(null);
  const playerReadyRef = useRef(false);
  const stompRef = useRef<Client | null>(null);
  const driftIntervalRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const autoplayTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const lastKnownPlayerStateRef = useRef<number>(YT_PLAYER_STATE.UNSTARTED);
  const pendingTimeRequestRef = useRef<((seconds: number) => void) | null>(null);

  useEffect(() => {
    roomIdRef.current = voice.activeRoomId;
  }, [voice.activeRoomId]);
  useEffect(() => {
    sessionRef.current = session;
  }, [session]);
  useEffect(() => {
    playerReadyRef.current = playerReady;
  }, [playerReady]);

  function sendCommand(cmd: string, args?: Record<string, unknown>) {
    webviewRef.current?.postMessage(JSON.stringify({ cmd, ...args }));
  }

  const applyLocalAudioState = useCallback(() => {
    if (localMuted) {
      sendCommand('mute');
    } else {
      sendCommand('unmute', { volume: localVolume });
    }
  }, [localMuted, localVolume]);

  const syncPlayerToSession = useCallback(
    (next: MusicSessionSummary | null) => {
      if (!next || !next.currentVideoId) return;
      if (loadedVideoIdRef.current !== next.currentVideoId) {
        loadedVideoIdRef.current = next.currentVideoId;
        sendCommand('load', { videoId: next.currentVideoId });
      }
      if (next.status === 'playing') {
        sendCommand('seek', { seconds: next.positionSeconds });
        sendCommand('play');
        applyLocalAudioState();
        if (autoplayTimeoutRef.current) clearTimeout(autoplayTimeoutRef.current);
        autoplayTimeoutRef.current = setTimeout(() => {
          if (lastKnownPlayerStateRef.current !== YT_PLAYER_STATE.PLAYING) {
            setAutoplayBlocked(true);
          }
        }, AUTOPLAY_CHECK_DELAY_MS);
      } else if (next.status === 'paused') {
        sendCommand('seek', { seconds: next.positionSeconds });
        sendCommand('pause');
      }
    },
    [applyLocalAudioState]
  );

  const refresh = useCallback(async () => {
    const roomId = roomIdRef.current;
    if (!roomId) return;
    setLoading(true);
    try {
      const dto = await musicApi.snapshot(roomId);
      const mapped = mapMusicSession(dto, getMyRealId());
      setSession(mapped);
      if (playerReadyRef.current) syncPlayerToSession(mapped);
    } catch {
      setSession(null);
    } finally {
      setLoading(false);
    }
  }, [syncPlayerToSession]);

  const handleMessage = useCallback(
    (event: WebViewMessageEvent) => {
      let msg: { type: string; state?: number; seconds?: number };
      try {
        msg = JSON.parse(event.nativeEvent.data);
      } catch {
        return;
      }
      if (msg.type === 'ready') {
        setPlayerReady(true);
        if (sessionRef.current) syncPlayerToSession(sessionRef.current);
      } else if (msg.type === 'stateChange' && typeof msg.state === 'number') {
        lastKnownPlayerStateRef.current = msg.state;
        if (msg.state === YT_PLAYER_STATE.PLAYING) setAutoplayBlocked(false);
      } else if (msg.type === 'time' && typeof msg.seconds === 'number') {
        pendingTimeRequestRef.current?.(msg.seconds);
        pendingTimeRequestRef.current = null;
      }
    },
    [syncPlayerToSession]
  );

  const unlockAutoplay = useCallback(() => {
    sendCommand('play');
    applyLocalAudioState();
    setAutoplayBlocked(false);
  }, [applyLocalAudioState]);

  const toggleLocalMute = useCallback(() => {
    setLocalMuted((prev) => {
      const next = !prev;
      if (next) sendCommand('mute');
      else sendCommand('unmute', { volume: localVolume });
      return next;
    });
  }, [localVolume]);

  const setLocalVolume = useCallback(
    (value: number) => {
      const clamped = Math.max(0, Math.min(100, value));
      setLocalVolumeState(clamped);
      if (!localMuted) sendCommand('volume', { volume: clamped });
    },
    [localMuted]
  );

  // ---- ciclo de vida: atado a estar conectado a la voz del LIVE ------------------------------
  useEffect(() => {
    const roomId = voice.activeRoomId;
    if (!roomId) {
      // Nada que preparar — si veníamos de una sala real, la función de limpieza de ESE run del
      // efecto (más abajo) ya reseteó todo antes de que este run (roomId=null) siquiera empiece.
      return;
    }

    refresh();

    const cachedSession = getCachedSession();
    const client = new Client({
      brokerURL: wsUrl(),
      connectHeaders: cachedSession ? { Authorization: `Bearer ${cachedSession.accessToken}` } : {},
      reconnectDelay: 3000,
      onConnect: () => {
        client.subscribe(`/topic/rooms/${roomId}/music`, () => {
          refresh();
        });
      },
    });
    client.activate();
    stompRef.current = client;

    driftIntervalRef.current = setInterval(() => {
      const current = sessionRef.current;
      if (!current || current.status !== 'playing') return;
      pendingTimeRequestRef.current = (localSeconds) => {
        const drift = Math.abs(localSeconds - current.positionSeconds);
        if (drift > DRIFT_THRESHOLD_SECONDS) {
          sendCommand('seek', { seconds: current.positionSeconds });
        }
      };
      sendCommand('getTime');
    }, DRIFT_CHECK_INTERVAL_MS);

    return () => {
      client.deactivate();
      stompRef.current = null;
      if (driftIntervalRef.current) clearInterval(driftIntervalRef.current);
      driftIntervalRef.current = null;
      if (autoplayTimeoutRef.current) clearTimeout(autoplayTimeoutRef.current);
      setSession(null);
      setExpanded(false);
      setPlayerReady(false);
      loadedVideoIdRef.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps -- refresh es estable (useCallback con deps propias); solo debe re-correr cuando cambia la sala de voz activa
  }, [voice.activeRoomId]);

  const searchSongs = useCallback(async (q: string): Promise<YoutubeSearchResult[]> => {
    const roomId = roomIdRef.current;
    if (!roomId) return [];
    const dtos = await musicApi.search(roomId, q);
    return dtos.map(mapYoutubeSearchResult);
  }, []);

  function currentVersion(): number | undefined {
    return sessionRef.current?.version;
  }

  const addToQueue = useCallback(
    async (videoId: string, playNow?: boolean) => {
      const roomId = roomIdRef.current;
      if (!roomId) return;
      const dto = await musicApi.addToQueue(roomId, { videoId, expectedVersion: currentVersion(), playNow });
      const mapped = mapMusicSession(dto, getMyRealId());
      setSession(mapped);
      syncPlayerToSession(mapped);
    },
    [syncPlayerToSession]
  );

  const requestSong = useCallback(
    async (videoId: string) => {
      const roomId = roomIdRef.current;
      if (!roomId) return;
      await musicApi.requestSong(roomId, { videoId });
      await refresh();
    },
    [refresh]
  );

  const approveRequest = useCallback(
    async (id: string) => {
      const roomId = roomIdRef.current;
      if (!roomId) return;
      await musicApi.approveRequest(roomId, id);
      await refresh();
    },
    [refresh]
  );

  const rejectRequest = useCallback(
    async (id: string) => {
      const roomId = roomIdRef.current;
      if (!roomId) return;
      await musicApi.rejectRequest(roomId, id);
      await refresh();
    },
    [refresh]
  );

  const applyControl = useCallback(
    async (action: (roomId: string, body: { expectedVersion?: number }) => Promise<import('@/services/api').MusicSessionDto>) => {
      const roomId = roomIdRef.current;
      if (!roomId) return;
      const dto = await action(roomId, { expectedVersion: currentVersion() });
      const mapped = mapMusicSession(dto, getMyRealId());
      setSession(mapped);
      syncPlayerToSession(mapped);
    },
    [syncPlayerToSession]
  );

  const play = useCallback(() => applyControl(musicApi.play), [applyControl]);
  const pauseTrack = useCallback(() => applyControl(musicApi.pause), [applyControl]);
  const resumeTrack = useCallback(() => applyControl(musicApi.resume), [applyControl]);
  const skip = useCallback(() => applyControl(musicApi.skip), [applyControl]);
  const stopMusic = useCallback(() => applyControl(musicApi.stop), [applyControl]);

  const seek = useCallback(
    async (seconds: number) => {
      const roomId = roomIdRef.current;
      if (!roomId) return;
      const dto = await musicApi.seek(roomId, { positionSeconds: Math.round(seconds), expectedVersion: currentVersion() });
      const mapped = mapMusicSession(dto, getMyRealId());
      setSession(mapped);
      syncPlayerToSession(mapped);
    },
    [syncPlayerToSession]
  );

  const setAllowRequests = useCallback(async (value: boolean) => {
    const roomId = roomIdRef.current;
    if (!roomId) return;
    const dto = await musicApi.updateSettings(roomId, { allowRequests: value });
    setSession(mapMusicSession(dto, getMyRealId()));
  }, []);

  const reorderQueue = useCallback(async (ids: string[]) => {
    const roomId = roomIdRef.current;
    if (!roomId) return;
    const dto = await musicApi.reorderQueue(roomId, { orderedQueueItemIds: ids, expectedVersion: currentVersion() });
    setSession(mapMusicSession(dto, getMyRealId()));
  }, []);

  const removeQueueItem = useCallback(
    async (id: string) => {
      const roomId = roomIdRef.current;
      if (!roomId) return;
      await musicApi.removeQueueItem(roomId, id);
      await refresh();
    },
    [refresh]
  );

  const clearQueue = useCallback(async () => {
    const roomId = roomIdRef.current;
    if (!roomId) return;
    await musicApi.clearQueue(roomId);
    await refresh();
  }, [refresh]);

  const hasTrack = !!session?.currentVideoId;

  const value = useMemo<MenziDjContextValue>(
    () => ({
      session,
      loading,
      expanded,
      setExpanded,
      autoplayBlocked,
      unlockAutoplay,
      localMuted,
      localVolume,
      toggleLocalMute,
      setLocalVolume,
      refresh,
      searchSongs,
      addToQueue,
      requestSong,
      approveRequest,
      rejectRequest,
      play,
      pauseTrack,
      resumeTrack,
      seek,
      skip,
      stopMusic,
      setAllowRequests,
      reorderQueue,
      removeQueueItem,
      clearQueue,
    }),
    [
      session,
      loading,
      expanded,
      autoplayBlocked,
      unlockAutoplay,
      localMuted,
      localVolume,
      toggleLocalMute,
      setLocalVolume,
      refresh,
      searchSongs,
      addToQueue,
      requestSong,
      approveRequest,
      rejectRequest,
      play,
      pauseTrack,
      resumeTrack,
      seek,
      skip,
      stopMusic,
      setAllowRequests,
      reorderQueue,
      removeQueueItem,
      clearQueue,
    ]
  );

  return (
    <MenziDjContext.Provider value={value}>
      {children}
      {/* WebView único para toda la app, montado siempre que haya una canción — sobrevive a
          cualquier navegación (ver comentario de arriba). Cuando no hay canción, tamaño 0. */}
      <View pointerEvents="box-none" style={StyleSheet.absoluteFill}>
        <View
          pointerEvents={hasTrack ? 'auto' : 'none'}
          style={
            !hasTrack
              ? { width: 0, height: 0, opacity: 0, position: 'absolute', top: 0, left: 0 }
              : expanded
                ? styles.frameExpanded
                : styles.frameMini
          }>
          <WebView
            ref={webviewRef}
            source={{ html: MENZI_DJ_PLAYER_HTML }}
            originWhitelist={['*']}
            allowsInlineMediaPlayback
            mediaPlaybackRequiresUserAction={false}
            javaScriptEnabled
            domStorageEnabled
            onMessage={handleMessage}
            style={styles.webview}
          />
        </View>
      </View>
    </MenziDjContext.Provider>
  );
}

const styles = StyleSheet.create({
  frameExpanded: {
    position: 'absolute',
    top: 60,
    right: 16,
    width: 200,
    height: 112,
    borderRadius: 16,
    overflow: 'hidden',
    backgroundColor: '#000',
    elevation: 10,
  },
  frameMini: {
    position: 'absolute',
    bottom: 170,
    left: 16,
    width: 1,
    height: 1,
    opacity: 0,
  },
  webview: { flex: 1, backgroundColor: '#000' },
});

export function useMenziDjContext() {
  const ctx = useContext(MenziDjContext);
  if (!ctx) throw new Error('useMenziDjContext must be used within a MenziDjProvider');
  return ctx;
}
