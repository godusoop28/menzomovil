import { Pressable, StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { useMenziDjContext } from '@/store/MenziDjContext';
import { Colors, Radius, Spacing, Typography } from '@/theme';

/** Igual que en web: WebViews también pueden bloquear el autoplay con sonido en algunos
 * dispositivos. Nunca se finge que está sonando mientras siga bloqueada. */
export function MenziDjAutoplayBar() {
  const { autoplayBlocked, unlockAutoplay } = useMenziDjContext();
  const insets = useSafeAreaInsets();
  if (!autoplayBlocked) return null;

  return (
    <View style={[styles.wrap, { top: insets.top + Spacing.xs }]} pointerEvents="box-none">
      <Pressable onPress={unlockAutoplay} style={styles.bar}>
        <View style={styles.dot} />
        <Text style={styles.label}>Menzi DJ está reproduciendo música · Toca para escuchar</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { position: 'absolute', left: Spacing.md, right: Spacing.md, zIndex: 95, alignItems: 'center' },
  bar: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.xs,
    backgroundColor: Colors.cyan,
    borderRadius: Radius.pill,
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.xs,
  },
  dot: { width: 6, height: 6, borderRadius: 3, backgroundColor: 'rgba(0,0,0,0.7)' },
  label: { ...Typography.caption, fontSize: 11, fontWeight: '700', color: '#000000' },
});
