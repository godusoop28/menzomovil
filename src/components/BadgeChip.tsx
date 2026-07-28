import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { StyleSheet, Text } from 'react-native';

import { Gradients, Radius, Spacing, Typography } from '@/theme';
import type { Badge } from '@/types';

export function BadgeChip({ badge, compact }: { badge: Badge; compact?: boolean }) {
  return (
    <LinearGradient
      colors={Gradients[badge.gradient] as unknown as [string, string, ...string[]]}
      start={{ x: 0, y: 0 }}
      end={{ x: 1, y: 1 }}
      style={[styles.chip, compact && styles.compact]}>
      <Ionicons name={badge.icon as never} size={compact ? 12 : 14} color="#FFFFFF" />
      {!compact && <Text style={styles.label}>{badge.name}</Text>}
    </LinearGradient>
  );
}

const styles = StyleSheet.create({
  chip: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingVertical: 6,
    paddingHorizontal: Spacing.sm,
    borderRadius: Radius.pill,
  },
  compact: { paddingVertical: 4, paddingHorizontal: 8 },
  label: { ...Typography.caption, color: '#FFFFFF', fontWeight: '700' },
});
