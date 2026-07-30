import { Ionicons } from '@expo/vector-icons';
import { Image } from 'expo-image';
import { router, usePathname } from 'expo-router';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { useMenziDjContext } from '@/store/MenziDjContext';
import { useVoiceRoomContext } from '@/store/VoiceRoomContext';
import { Colors, Radius, Spacing, Typography } from '@/theme';

/** Barra flotante minimizada de Menzi DJ — equivalente móvil de MenziDjPlayerHost.tsx en web.
 * El WebView del reproductor real vive montado en MenziDjContext (invisible mientras esté
 * minimizado); esto es solo la superficie táctil con la info de "sonando ahora" + controles
 * rápidos. Tocarla lleva de vuelta a la sala del live (igual que en web, el panel completo de
 * buscar/cola se abre desde el botón "Música" dentro de esa pantalla, no desde acá). Se oculta
 * en la propia pantalla de esa sala, igual que PersistentVoiceBubble — ahí ya hay un botón
 * "Música" en el header para abrir el panel completo. */
export function MenziDjMiniBar() {
  const music = useMenziDjContext();
  const voice = useVoiceRoomContext();
  const insets = useSafeAreaInsets();
  const pathname = usePathname();

  const hasTrack = !!music.session?.currentVideoId;
  const hiddenOnThisScreen = pathname === `/chat/${voice.activeRoomId}`;
  if (!hasTrack || music.expanded || !voice.activeRoomId || hiddenOnThisScreen) return null;

  const canModerate = voice.myRole === 'host' || voice.myRole === 'co_host';
  const isPlaying = music.session?.status === 'playing';

  return (
    <View style={[styles.wrap, { bottom: insets.bottom + Spacing.xl + 64 }]}>
      <Pressable
        onPress={() => {
          router.push(`/chat/${voice.activeRoomId}`);
          music.setExpanded(true);
        }}
        style={styles.pill}>
        <View style={styles.thumbWrap}>
          {music.session?.currentThumbnailUrl ? (
            <Image source={{ uri: music.session.currentThumbnailUrl }} style={styles.thumb} contentFit="cover" />
          ) : (
            <View style={[styles.thumb, styles.thumbFallback]}>
              <Ionicons name="musical-notes" size={16} color={Colors.cyan} />
            </View>
          )}
        </View>
        <View style={styles.textWrap}>
          <Text style={styles.label}>MENZI DJ</Text>
          <Text style={styles.title} numberOfLines={1}>
            {music.session?.currentTitle || 'Reproduciendo…'}
          </Text>
        </View>
        {canModerate && (
          <Pressable
            onPress={(e) => {
              e.stopPropagation();
              if (isPlaying) music.pauseTrack();
              else music.resumeTrack();
            }}
            hitSlop={8}
            accessibilityLabel={isPlaying ? 'Pausar' : 'Reproducir'}
            style={styles.iconButton}>
            <Ionicons name={isPlaying ? 'pause' : 'play'} size={15} color={Colors.textPrimary} />
          </Pressable>
        )}
        <Pressable
          onPress={(e) => {
            e.stopPropagation();
            music.toggleLocalMute();
          }}
          hitSlop={8}
          accessibilityLabel={music.localMuted ? 'Activar música' : 'Silenciar música (solo para ti)'}
          style={styles.iconButton}>
          <Ionicons name={music.localMuted ? 'volume-mute' : 'volume-high'} size={15} color={Colors.textPrimary} />
        </Pressable>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { position: 'absolute', left: Spacing.md, right: Spacing.md, zIndex: 85 },
  pill: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.xs,
    backgroundColor: Colors.surfaceElevated,
    borderRadius: Radius.pill,
    borderWidth: 1,
    borderColor: Colors.borderStrong,
    paddingVertical: Spacing.xxs,
    paddingHorizontal: Spacing.xxs,
    shadowColor: '#000',
    shadowOpacity: 0.35,
    shadowRadius: 10,
    shadowOffset: { width: 0, height: 4 },
    elevation: 8,
  },
  thumbWrap: { width: 36, height: 36, borderRadius: 10, overflow: 'hidden' },
  thumb: { width: '100%', height: '100%' },
  thumbFallback: { backgroundColor: '#000', alignItems: 'center', justifyContent: 'center' },
  textWrap: { flex: 1, minWidth: 0 },
  label: { ...Typography.caption, color: Colors.cyan, fontWeight: '700', fontSize: 10, letterSpacing: 0.5 },
  title: { ...Typography.label, color: Colors.textPrimary },
  iconButton: {
    width: 32,
    height: 32,
    borderRadius: 16,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: Colors.surfaceSoft,
  },
});
