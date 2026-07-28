import { router } from 'expo-router';
import { Pressable, StyleSheet, Text, View } from 'react-native';

import { UserAvatar } from './UserAvatar';
import { Colors, Radius, Spacing, Typography } from '@/theme';
import type { DemoUser } from '@/types';

type Props = { user: DemoUser; variant?: 'row' | 'column' };

export function MemberCard({ user, variant = 'row' }: Props) {
  const isColumn = variant === 'column';
  return (
    <Pressable
      onPress={() => router.push(`/member/${user.id}`)}
      style={[styles.wrap, isColumn ? styles.column : styles.row]}
      accessibilityRole="button"
      accessibilityLabel={`Perfil de ${user.displayName}`}>
      <UserAvatar
        name={user.displayName}
        avatarUri={user.avatarUri}
        gradient={user.avatarGradient}
        size={isColumn ? 68 : 50}
        showOnline
        online={user.isOnline}
        level={user.level}
      />
      <View style={isColumn ? styles.columnText : styles.rowText}>
        <Text style={styles.name} numberOfLines={1}>
          {user.displayName}
        </Text>
        <Text style={styles.status} numberOfLines={1}>
          {user.isOnline ? user.activityStatus : 'Desconectado'}
        </Text>
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  wrap: { alignItems: 'center' },
  row: {
    flexDirection: 'row',
    gap: Spacing.sm,
    backgroundColor: Colors.surface,
    borderRadius: Radius.lg,
    borderWidth: 1,
    borderColor: Colors.borderSoft,
    padding: Spacing.md,
    alignItems: 'center',
  },
  column: { width: 88, gap: 6 },
  rowText: { flex: 1, gap: 2 },
  columnText: { alignItems: 'center', gap: 2 },
  name: { ...Typography.bodyMedium, color: Colors.textPrimary, textAlign: 'center' },
  status: { ...Typography.caption, color: Colors.textMuted, textAlign: 'center' },
});
