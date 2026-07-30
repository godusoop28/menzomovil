import { Ionicons } from '@expo/vector-icons';
import { Image } from 'expo-image';
import { useEffect, useState } from 'react';
import {
  ActivityIndicator,
  type GestureResponderEvent,
  Modal,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { ApiError } from '@/services/api';
import { useMenziDjContext } from '@/store/MenziDjContext';
import { Colors, Radius, Spacing, Typography } from '@/theme';
import type { ChatRoomRole, MusicSessionSummary, QueueItem, YoutubeSearchResult } from '@/types';
import { useToast } from '@/hooks/useToast';

type Tab = 'search' | 'queue' | 'requests' | 'history';

function formatDuration(seconds: number | null): string {
  if (seconds == null) return '';
  const m = Math.floor(seconds / 60);
  const s = Math.floor(seconds % 60)
    .toString()
    .padStart(2, '0');
  return `${m}:${s}`;
}

function useDisplayPosition(session: MusicSessionSummary | null): number {
  // Misma técnica que en menzoweb: una clave derivada agrupa todo lo que debe reiniciar el
  // contador visual, y se reajusta durante el render (no en un efecto) para evitar el
  // re-render en cascada que el linter de hooks marca como set-state-in-effect.
  const key = `${session?.musicSessionId ?? ''}:${session?.positionSeconds ?? 0}:${session?.status ?? ''}:${session?.currentVideoId ?? ''}`;
  const [syncedKey, setSyncedKey] = useState(key);
  const [displayed, setDisplayed] = useState(session?.positionSeconds ?? 0);
  if (key !== syncedKey) {
    setSyncedKey(key);
    setDisplayed(session?.positionSeconds ?? 0);
  }

  useEffect(() => {
    if (!session || session.status !== 'playing') return;
    const base = session.positionSeconds;
    const startedAt = Date.now();
    const interval = setInterval(() => {
      setDisplayed(base + Math.floor((Date.now() - startedAt) / 1000));
    }, 1000);
    return () => clearInterval(interval);
    // eslint-disable-next-line react-hooks/exhaustive-deps -- la clave `key` ya cubre estas mismas dependencias
  }, [session?.musicSessionId, session?.positionSeconds, session?.status, session?.currentVideoId]);
  return displayed;
}

/** Panel completo de Menzi DJ (buscar, cola, solicitudes, historial) — equivalente móvil de
 * menzoweb/components/music/MenziDjPanel.tsx. El reproductor real (WebView) no vive acá; sigue
 * montado en MenziDjContext y solo se agranda en una esquina mientras este panel está abierto. */
export function MenziDjPanel({ visible, roomRole, onClose }: { visible: boolean; roomRole: ChatRoomRole | null; onClose: () => void }) {
  const music = useMenziDjContext();
  const insets = useSafeAreaInsets();
  const canModerate = roomRole === 'owner' || roomRole === 'co_host';
  const [tab, setTab] = useState<Tab>('search');
  const showToast = useToast();

  useEffect(() => {
    if (!visible) return;
    music.setExpanded(true);
    return () => music.setExpanded(false);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [visible]);

  const session = music.session;
  const displayPosition = useDisplayPosition(session);

  async function handlePlayPause() {
    try {
      if (session?.status === 'playing') await music.pauseTrack();
      else await music.resumeTrack();
    } catch (error) {
      showToast(error instanceof ApiError ? error.message : 'No pudimos controlar la música.');
    }
  }

  async function handleSkip() {
    try {
      await music.skip();
    } catch (error) {
      showToast(error instanceof ApiError ? error.message : 'No pudimos saltar la canción.');
    }
  }

  async function handleStop() {
    try {
      await music.stopMusic();
    } catch (error) {
      showToast(error instanceof ApiError ? error.message : 'No pudimos detener la música.');
    }
  }

  return (
    <Modal visible={visible} animationType="slide" onRequestClose={onClose} presentationStyle="pageSheet">
      <View style={[styles.screen, { paddingTop: insets.top }]}>
        <View style={styles.header}>
          <View>
            <Text style={styles.headerTitle}>Menzi DJ</Text>
            <Text style={styles.headerSubtitle}>Música sincronizada para todos en el live</Text>
          </View>
          <Pressable onPress={onClose} accessibilityLabel="Cerrar" hitSlop={8} style={styles.closeButton}>
            <Ionicons name="close" size={20} color={Colors.textPrimary} />
          </Pressable>
        </View>

        <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
          <View style={styles.nowPlaying}>
            <View style={styles.nowPlayingThumbWrap}>
              {session?.currentThumbnailUrl ? (
                <Image source={{ uri: session.currentThumbnailUrl }} style={styles.nowPlayingThumb} contentFit="cover" />
              ) : (
                <View style={[styles.nowPlayingThumb, styles.thumbFallback]}>
                  <Ionicons name="musical-notes" size={22} color={Colors.textMuted} />
                </View>
              )}
            </View>
            <View style={styles.nowPlayingText}>
              <Text style={styles.nowPlayingTitle} numberOfLines={1}>
                {session?.currentTitle || 'Nada sonando todavía'}
              </Text>
              <Text style={styles.nowPlayingChannel} numberOfLines={1}>
                {session?.currentChannelTitle || 'Busca una canción para empezar'}
              </Text>
              {!!session?.currentVideoId && (
                <>
                  <View style={styles.progressTrack}>
                    <View
                      style={[
                        styles.progressFill,
                        {
                          width: session.durationSeconds
                            ? `${Math.min(100, (displayPosition / session.durationSeconds) * 100)}%`
                            : '0%',
                        },
                      ]}
                    />
                  </View>
                  <Text style={styles.progressLabel}>
                    {formatDuration(displayPosition)} / {formatDuration(session.durationSeconds)}
                  </Text>
                </>
              )}
            </View>
          </View>

          <View style={styles.controlsRow}>
            {canModerate && !!session?.currentVideoId && (
              <>
                <Pressable
                  onPress={handlePlayPause}
                  accessibilityLabel={session.status === 'playing' ? 'Pausar' : 'Reproducir'}
                  style={[styles.controlButton, styles.controlButtonPrimary]}>
                  <Ionicons name={session.status === 'playing' ? 'pause' : 'play'} size={18} color="#000000" />
                </Pressable>
                <Pressable onPress={handleSkip} accessibilityLabel="Siguiente" style={styles.controlButton}>
                  <Ionicons name="play-skip-forward" size={18} color={Colors.textPrimary} />
                </Pressable>
                <Pressable onPress={handleStop} accessibilityLabel="Detener" style={[styles.controlButton, styles.controlButtonDanger]}>
                  <Ionicons name="stop" size={18} color={Colors.coral} />
                </Pressable>
              </>
            )}
            <Pressable
              onPress={music.toggleLocalMute}
              accessibilityLabel={music.localMuted ? 'Activar música (solo para ti)' : 'Silenciar música (solo para ti)'}
              style={styles.controlButton}>
              <Ionicons name={music.localMuted ? 'volume-mute' : 'volume-high'} size={18} color={Colors.textPrimary} />
            </Pressable>
            {!music.localMuted && <LocalVolumeStrip value={music.localVolume} onChange={music.setLocalVolume} />}
          </View>

          <View style={styles.tabsRow}>
            <TabButton active={tab === 'search'} onPress={() => setTab('search')} label="Buscar" />
            <TabButton active={tab === 'queue'} onPress={() => setTab('queue')} label={`Cola${session ? ` (${session.queue.length})` : ''}`} />
            {canModerate && (
              <TabButton
                active={tab === 'requests'}
                onPress={() => setTab('requests')}
                label={`Solicitudes${session && session.pendingRequests.length > 0 ? ` (${session.pendingRequests.length})` : ''}`}
              />
            )}
            <TabButton active={tab === 'history'} onPress={() => setTab('history')} label="Historial" />
          </View>

          {tab === 'search' && <SearchTab canModerate={canModerate} />}
          {tab === 'queue' && <QueueTab session={session} canModerate={canModerate} />}
          {tab === 'requests' && canModerate && <RequestsTab session={session} />}
          {tab === 'history' && <HistoryTab session={session} />}
        </ScrollView>
      </View>
    </Modal>
  );
}

function LocalVolumeStrip({ value, onChange }: { value: number; onChange: (value: number) => void }) {
  const [width, setWidth] = useState(0);

  function handleTouch(e: GestureResponderEvent) {
    if (!width) return;
    const x = Math.max(0, Math.min(width, e.nativeEvent.locationX));
    onChange(Math.round((x / width) * 100));
  }

  return (
    <View
      style={styles.volumeStrip}
      onLayout={(e) => setWidth(e.nativeEvent.layout.width)}
      onStartShouldSetResponder={() => true}
      onMoveShouldSetResponder={() => true}
      onResponderGrant={handleTouch}
      onResponderMove={handleTouch}>
      <View style={[styles.volumeFill, { width: `${value}%` }]} />
    </View>
  );
}

function TabButton({ active, onPress, label }: { active: boolean; onPress: () => void; label: string }) {
  return (
    <Pressable onPress={onPress} style={[styles.tabButton, active && styles.tabButtonActive]}>
      <Text style={[styles.tabButtonLabel, active && styles.tabButtonLabelActive]}>{label}</Text>
    </Pressable>
  );
}

function SearchTab({ canModerate }: { canModerate: boolean }) {
  const music = useMenziDjContext();
  const showToast = useToast();
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<YoutubeSearchResult[] | null>(null);
  // Distinto de `results` a propósito: un error de red/YouTube nunca debe verse como "sin
  // resultados" (results=[]) — antes el catch hacía setResults([]) y la búsqueda fallida se
  // mostraba idéntica a una búsqueda real sin coincidencias, ocultando el error real.
  const [searchError, setSearchError] = useState<string | null>(null);
  const [searching, setSearching] = useState(false);
  const [busyVideoId, setBusyVideoId] = useState<string | null>(null);

  function messageForSearchError(error: unknown): string {
    if (error instanceof ApiError) {
      if (error.code === 'YOUTUBE_QUOTA_EXCEEDED') return 'Se alcanzó el límite de búsquedas de música por hoy. Intenta más tarde.';
      if (error.code === 'YOUTUBE_NOT_CONFIGURED' || error.code === 'YOUTUBE_AUTH_ERROR') return 'La búsqueda de música no está disponible en este momento.';
      if (error.code === 'YOUTUBE_TIMEOUT') return 'YouTube tardó demasiado en responder. Intenta de nuevo.';
      if (error.code === 'LIVE_NOT_ACTIVE') return 'El LIVE ya no está activo.';
      return error.message;
    }
    return 'No pudimos buscar música en este momento.';
  }

  async function handleSearch() {
    const trimmed = query.trim();
    if (trimmed.length < 3) {
      showToast('Escribe al menos 3 caracteres para buscar.');
      return;
    }
    setSearching(true);
    setSearchError(null);
    try {
      const found = await music.searchSongs(trimmed);
      setResults(found);
    } catch (error) {
      setSearchError(messageForSearchError(error));
    } finally {
      setSearching(false);
    }
  }

  async function handleAction(videoId: string, playNow: boolean) {
    setBusyVideoId(videoId);
    try {
      await music.addToQueue(videoId, playNow);
      showToast(playNow ? 'Reproduciendo ahora.' : 'Se agregó a la cola.');
    } catch (error) {
      showToast(error instanceof ApiError ? error.message : 'No pudimos agregar esa canción.');
    } finally {
      setBusyVideoId(null);
    }
  }

  async function handleRequest(videoId: string) {
    setBusyVideoId(videoId);
    try {
      await music.requestSong(videoId);
      showToast('Solicitud enviada.');
    } catch (error) {
      showToast(error instanceof ApiError ? error.message : 'No pudimos enviar tu solicitud.');
    } finally {
      setBusyVideoId(null);
    }
  }

  return (
    <View style={styles.tabContent}>
      <View style={styles.searchRow}>
        <TextInput
          value={query}
          onChangeText={setQuery}
          onSubmitEditing={handleSearch}
          placeholder="Busca una canción o pega un enlace"
          placeholderTextColor={Colors.textMuted}
          returnKeyType="search"
          style={styles.searchInput}
        />
        <Pressable onPress={handleSearch} disabled={searching} style={styles.searchButton}>
          {searching ? <ActivityIndicator size="small" color="#000000" /> : <Ionicons name="search" size={16} color="#000000" />}
        </Pressable>
      </View>
      {!searching && searchError && (
        <View style={styles.searchErrorBox}>
          <Text style={styles.searchErrorLabel}>{searchError}</Text>
          <Pressable onPress={handleSearch} style={styles.searchErrorRetry}>
            <Text style={styles.searchErrorRetryLabel}>Reintentar</Text>
          </Pressable>
        </View>
      )}
      {!searching && !searchError && results !== null && results.length === 0 && (
        <Text style={styles.emptyLabel}>No encontramos canciones con esa búsqueda.</Text>
      )}
      <View style={styles.listGap}>
        {!searchError &&
          results?.map((r) => (
          <View key={r.videoId} style={styles.row}>
            <View style={styles.rowThumbWrap}>
              {r.thumbnailUrl ? (
                <Image source={{ uri: r.thumbnailUrl }} style={styles.rowThumb} contentFit="cover" />
              ) : (
                <View style={[styles.rowThumb, styles.thumbFallback]} />
              )}
            </View>
            <View style={styles.rowText}>
              <Text style={styles.rowTitle} numberOfLines={1}>
                {r.title}
              </Text>
              <Text style={styles.rowSubtitle} numberOfLines={1}>
                {r.channelTitle} · {formatDuration(r.durationSeconds)}
              </Text>
            </View>
            {canModerate ? (
              <View style={styles.rowActions}>
                <Pressable
                  onPress={() => handleAction(r.videoId, true)}
                  disabled={busyVideoId === r.videoId}
                  accessibilityLabel="Reproducir ahora"
                  style={[styles.smallIconButton, styles.smallIconButtonPrimary]}>
                  <Ionicons name="play" size={13} color="#000000" />
                </Pressable>
                <Pressable
                  onPress={() => handleAction(r.videoId, false)}
                  disabled={busyVideoId === r.videoId}
                  accessibilityLabel="Agregar a la cola"
                  style={styles.smallIconButton}>
                  <Ionicons name="add" size={15} color={Colors.textPrimary} />
                </Pressable>
              </View>
            ) : (
              <Pressable
                onPress={() => handleRequest(r.videoId)}
                disabled={busyVideoId === r.videoId}
                style={styles.requestButton}>
                <Text style={styles.requestButtonLabel}>Solicitar</Text>
              </Pressable>
            )}
          </View>
        ))}
      </View>
    </View>
  );
}

function QueueTab({ session, canModerate }: { session: MusicSessionSummary | null; canModerate: boolean }) {
  const music = useMenziDjContext();
  const showToast = useToast();
  const [busyId, setBusyId] = useState<string | null>(null);

  async function handleRemove(id: string) {
    setBusyId(id);
    try {
      await music.removeQueueItem(id);
    } catch (error) {
      showToast(error instanceof ApiError ? error.message : 'No pudimos quitar esa canción.');
    } finally {
      setBusyId(null);
    }
  }

  if (!session || session.queue.length === 0) {
    return (
      <View style={styles.tabContent}>
        <Text style={styles.emptyLabel}>La cola está vacía.</Text>
      </View>
    );
  }

  return (
    <View style={[styles.tabContent, styles.listGap]}>
      {session.queue.map((item, index) => (
        <View key={item.id} style={styles.row}>
          <Text style={styles.rowIndex}>{index + 1}</Text>
          <View style={styles.rowThumbWrap}>
            {item.thumbnailUrl ? (
              <Image source={{ uri: item.thumbnailUrl }} style={styles.rowThumb} contentFit="cover" />
            ) : (
              <View style={[styles.rowThumb, styles.thumbFallback]} />
            )}
          </View>
          <View style={styles.rowText}>
            <Text style={styles.rowTitle} numberOfLines={1}>
              {item.title}
            </Text>
            <Text style={styles.rowSubtitle} numberOfLines={1}>
              {item.channelTitle} · {formatDuration(item.durationSeconds)}
              {item.requestedBy && ` · pedida por ${item.requestedBy.displayName}`}
            </Text>
          </View>
          {canModerate && (
            <Pressable
              onPress={() => handleRemove(item.id)}
              disabled={busyId === item.id}
              accessibilityLabel="Quitar de la cola"
              style={[styles.smallIconButton, styles.smallIconButtonDanger]}>
              <Ionicons name="trash-outline" size={14} color={Colors.coral} />
            </Pressable>
          )}
        </View>
      ))}
    </View>
  );
}

function RequestsTab({ session }: { session: MusicSessionSummary | null }) {
  const music = useMenziDjContext();
  const showToast = useToast();
  const [busyId, setBusyId] = useState<string | null>(null);

  async function respond(id: string, approve: boolean) {
    setBusyId(id);
    try {
      if (approve) await music.approveRequest(id);
      else await music.rejectRequest(id);
    } catch (error) {
      showToast(error instanceof ApiError ? error.message : 'No pudimos procesar la solicitud.');
    } finally {
      setBusyId(null);
    }
  }

  if (!session || session.pendingRequests.length === 0) {
    return (
      <View style={styles.tabContent}>
        <Text style={styles.emptyLabel}>No hay solicitudes pendientes.</Text>
      </View>
    );
  }

  return (
    <View style={[styles.tabContent, styles.listGap]}>
      {session.pendingRequests.map((item) => (
        <View key={item.id} style={styles.row}>
          <View style={styles.rowThumbWrap}>
            {item.thumbnailUrl ? (
              <Image source={{ uri: item.thumbnailUrl }} style={styles.rowThumb} contentFit="cover" />
            ) : (
              <View style={[styles.rowThumb, styles.thumbFallback]} />
            )}
          </View>
          <View style={styles.rowText}>
            <Text style={styles.rowTitle} numberOfLines={1}>
              {item.title}
            </Text>
            <Text style={styles.rowSubtitle} numberOfLines={1}>
              {item.requestedBy?.displayName ?? 'Alguien'} solicitó esta canción
            </Text>
          </View>
          <View style={styles.rowActions}>
            <Pressable
              onPress={() => respond(item.id, true)}
              disabled={busyId === item.id}
              accessibilityLabel="Aprobar"
              style={[styles.smallIconButton, styles.smallIconButtonApprove]}>
              <Ionicons name="checkmark" size={15} color="#000000" />
            </Pressable>
            <Pressable
              onPress={() => respond(item.id, false)}
              disabled={busyId === item.id}
              accessibilityLabel="Rechazar"
              style={styles.smallIconButton}>
              <Ionicons name="trash-outline" size={14} color={Colors.textPrimary} />
            </Pressable>
          </View>
        </View>
      ))}
    </View>
  );
}

function HistoryTab({ session }: { session: MusicSessionSummary | null }) {
  if (!session || session.history.length === 0) {
    return (
      <View style={styles.tabContent}>
        <Text style={styles.emptyLabel}>Todavía no sonó ninguna canción.</Text>
      </View>
    );
  }
  return (
    <View style={[styles.tabContent, styles.listGap]}>
      {session.history.map((item) => (
        <HistoryRow key={item.id} item={item} />
      ))}
    </View>
  );
}

function HistoryRow({ item }: { item: QueueItem }) {
  return (
    <View style={[styles.row, styles.historyRow]}>
      <View style={styles.rowThumbWrap}>
        {item.thumbnailUrl ? (
          <Image source={{ uri: item.thumbnailUrl }} style={styles.rowThumb} contentFit="cover" />
        ) : (
          <View style={[styles.rowThumb, styles.thumbFallback]} />
        )}
      </View>
      <View style={styles.rowText}>
        <Text style={styles.rowTitle} numberOfLines={1}>
          {item.title}
        </Text>
        <Text style={styles.rowSubtitle} numberOfLines={1}>
          {item.channelTitle} · {item.status === 'skipped' ? 'saltada' : 'reproducida'}
        </Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: Colors.background },
  header: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    justifyContent: 'space-between',
    paddingHorizontal: Spacing.lg,
    paddingTop: Spacing.sm,
    paddingBottom: Spacing.md,
    borderBottomWidth: 1,
    borderBottomColor: Colors.borderSoft,
  },
  headerTitle: { ...Typography.h3, color: Colors.textPrimary },
  headerSubtitle: { ...Typography.caption, color: Colors.textMuted, marginTop: 2 },
  closeButton: {
    width: 32,
    height: 32,
    borderRadius: 16,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: Colors.surfaceSecondary,
  },
  content: { padding: Spacing.lg, gap: Spacing.md },
  nowPlaying: { flexDirection: 'row', gap: Spacing.sm, backgroundColor: Colors.surfaceSecondary, borderRadius: Radius.lg, padding: Spacing.sm },
  nowPlayingThumbWrap: { width: 64, height: 64, borderRadius: Radius.md, overflow: 'hidden' },
  nowPlayingThumb: { width: '100%', height: '100%' },
  thumbFallback: { backgroundColor: '#000', alignItems: 'center', justifyContent: 'center' },
  nowPlayingText: { flex: 1, minWidth: 0, justifyContent: 'center', gap: 3 },
  nowPlayingTitle: { ...Typography.label, color: Colors.textPrimary, fontWeight: '600' },
  nowPlayingChannel: { ...Typography.caption, color: Colors.textMuted },
  progressTrack: { height: 4, borderRadius: 2, backgroundColor: Colors.surfaceElevated, overflow: 'hidden', marginTop: 4 },
  progressFill: { height: '100%', borderRadius: 2, backgroundColor: Colors.cyan },
  progressLabel: { ...Typography.caption, fontSize: 10, color: Colors.textMuted, marginTop: 2 },
  controlsRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: Spacing.sm },
  controlButton: {
    width: 44,
    height: 44,
    borderRadius: 22,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: Colors.surfaceSecondary,
  },
  controlButtonPrimary: { backgroundColor: Colors.orange },
  controlButtonDanger: { backgroundColor: 'rgba(255,79,69,0.15)' },
  volumeStrip: { flex: 1, height: 4, borderRadius: 2, backgroundColor: Colors.surfaceElevated, overflow: 'hidden' },
  volumeFill: { height: '100%', backgroundColor: Colors.cyan },
  tabsRow: { flexDirection: 'row', gap: Spacing.xxs, borderBottomWidth: 1, borderBottomColor: Colors.borderSoft, paddingBottom: Spacing.sm },
  tabButton: { borderRadius: 999, paddingHorizontal: Spacing.sm, paddingVertical: 6 },
  tabButtonActive: { backgroundColor: Colors.surfaceElevated },
  tabButtonLabel: { ...Typography.caption, fontSize: 12, fontWeight: '600', color: Colors.textMuted },
  tabButtonLabelActive: { color: Colors.textPrimary },
  tabContent: { gap: Spacing.sm },
  emptyLabel: { ...Typography.body, color: Colors.textMuted, textAlign: 'center', paddingVertical: Spacing.lg },
  searchErrorBox: { alignItems: 'center', gap: Spacing.xs, paddingVertical: Spacing.lg },
  searchErrorLabel: { ...Typography.body, color: Colors.coral, textAlign: 'center' },
  searchErrorRetry: { borderRadius: 999, paddingHorizontal: Spacing.md, paddingVertical: 6, backgroundColor: Colors.surfaceSecondary },
  searchErrorRetryLabel: { ...Typography.caption, fontSize: 12, fontWeight: '600', color: Colors.textPrimary },
  searchRow: { flexDirection: 'row', gap: Spacing.xs },
  searchInput: {
    ...Typography.body,
    flex: 1,
    color: Colors.textPrimary,
    backgroundColor: Colors.surfaceSecondary,
    borderRadius: Radius.lg,
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
  },
  searchButton: {
    width: 40,
    height: 40,
    borderRadius: Radius.lg,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: Colors.orange,
  },
  listGap: { gap: Spacing.xs },
  row: { flexDirection: 'row', alignItems: 'center', gap: Spacing.sm, backgroundColor: Colors.surfaceSecondary, borderRadius: Radius.lg, padding: Spacing.xs },
  historyRow: { opacity: 0.8 },
  rowIndex: { width: 16, textAlign: 'center', ...Typography.caption, color: Colors.textMuted },
  rowThumbWrap: { width: 44, height: 44, borderRadius: Radius.sm, overflow: 'hidden' },
  rowThumb: { width: '100%', height: '100%' },
  rowText: { flex: 1, minWidth: 0, gap: 1 },
  rowTitle: { ...Typography.label, color: Colors.textPrimary },
  rowSubtitle: { ...Typography.caption, color: Colors.textMuted },
  rowActions: { flexDirection: 'row', gap: 6 },
  smallIconButton: {
    width: 32,
    height: 32,
    borderRadius: 16,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: Colors.surfaceElevated,
  },
  smallIconButtonPrimary: { backgroundColor: Colors.orange },
  smallIconButtonDanger: { backgroundColor: 'rgba(255,79,69,0.15)' },
  smallIconButtonApprove: { backgroundColor: Colors.green },
  requestButton: { borderRadius: 999, paddingHorizontal: Spacing.sm, paddingVertical: 8, backgroundColor: Colors.cyan },
  requestButtonLabel: { ...Typography.caption, fontSize: 12, fontWeight: '700', color: '#000000' },
});
