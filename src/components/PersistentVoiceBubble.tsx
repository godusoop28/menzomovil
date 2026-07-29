import { Ionicons } from '@expo/vector-icons';
import { router, usePathname } from 'expo-router';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import Animated, { FadeIn, FadeOut } from 'react-native-reanimated';

import { UserAvatar } from './UserAvatar';
import { BottomTabBarHeight, Colors, Radius, Spacing, Typography, useAccent } from '@/theme';
import { useVoiceRoomContext } from '@/store/VoiceRoomContext';

/** "Chat head" flotante estilo Messenger — se muestra en cualquier pantalla mientras haya una
 * sala de voz activa, salvo en la propia pantalla de esa sala (ahí ya se ve la barra de voz
 * completa). Vive por encima del Stack en _layout.tsx, así que sobrevive a la navegación entre
 * tabs y pantallas — es justo lo que el VoiceRoomProvider hace posible. */
export function PersistentVoiceBubble() {
  const { activeRoomId, connected, muted, participants, leave, toggleMute } = useVoiceRoomContext();
  const pathname = usePathname();
  const insets = useSafeAreaInsets();
  const accent = useAccent();

  const hiddenOnThisScreen = pathname === `/chat/${activeRoomId}`;
  if (!connected || !activeRoomId || hiddenOnThisScreen) return null;

  const first = participants[0];
  const label = first ? first.displayName : 'En vivo';

  return (
    <Animated.View
      entering={FadeIn.duration(200)}
      exiting={FadeOut.duration(160)}
      style={[styles.wrap, { bottom: BottomTabBarHeight + insets.bottom + Spacing.sm }]}>
      <Pressable
        onPress={() => router.push(`/chat/${activeRoomId}`)}
        accessibilityLabel={`Volver a la sala en vivo: ${label}`}
        style={styles.pill}>
        <View style={styles.avatarWrap}>
          {first ? (
            <UserAvatar name={first.displayName} avatarUri={first.avatarUri} gradient={first.avatarGradient} size={40} />
          ) : (
            <View style={[styles.avatarFallback, { backgroundColor: accent.color }]}>
              <Ionicons name="mic" size={18} color={Colors.textOnAccent} />
            </View>
          )}
          <View style={styles.liveDot} />
        </View>
        <View style={styles.textWrap}>
          <Text style={styles.live}>EN VIVO</Text>
          <Text style={styles.name} numberOfLines={1}>
            {label}
          </Text>
        </View>
        <Pressable
          onPress={toggleMute}
          hitSlop={8}
          accessibilityLabel={muted ? 'Activar micrófono' : 'Silenciar micrófono'}
          style={[styles.iconButton, muted && styles.iconButtonActive]}>
          <Ionicons name={muted ? 'mic-off' : 'mic'} size={16} color={muted ? Colors.coral : Colors.textPrimary} />
        </Pressable>
        <Pressable onPress={leave} hitSlop={8} accessibilityLabel="Salir del live" style={styles.iconButton}>
          <Ionicons name="close" size={16} color={Colors.textPrimary} />
        </Pressable>
      </Pressable>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  wrap: {
    position: 'absolute',
    right: Spacing.md,
    left: Spacing.md,
    zIndex: 90,
  },
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
  avatarWrap: { position: 'relative' },
  avatarFallback: { width: 40, height: 40, borderRadius: 20, alignItems: 'center', justifyContent: 'center' },
  liveDot: {
    position: 'absolute',
    bottom: -1,
    right: -1,
    width: 12,
    height: 12,
    borderRadius: 6,
    backgroundColor: Colors.coral,
    borderWidth: 2,
    borderColor: Colors.surfaceElevated,
  },
  textWrap: { flex: 1, minWidth: 0 },
  live: { ...Typography.caption, color: Colors.coral, fontWeight: '700', fontSize: 10, letterSpacing: 0.5 },
  name: { ...Typography.label, color: Colors.textPrimary },
  iconButton: {
    width: 32,
    height: 32,
    borderRadius: 16,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: Colors.surfaceSoft,
  },
  iconButtonActive: { backgroundColor: 'rgba(255,79,69,0.16)' },
});
