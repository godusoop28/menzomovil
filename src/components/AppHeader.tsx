import { router } from 'expo-router';
import type { ReactNode } from 'react';
import { StyleSheet, Text, View } from 'react-native';

import { IconButton } from './IconButton';
import { MenzoLogo } from './MenzoLogo';
import { useAppState } from '@/hooks/useAppState';
import * as selectors from '@/store/selectors';
import { Colors, Spacing, Typography } from '@/theme';

type Props = {
  showLogo?: boolean;
  onMenuPress?: () => void;
  right?: ReactNode;
};

export function AppHeader({ showLogo = true, onMenuPress, right }: Props) {
  const { state } = useAppState();
  const unread = selectors.unreadNotificationCount(state.social);

  return (
    <View style={styles.wrap}>
      <View style={styles.left}>
        {onMenuPress && <IconButton name="menu" label="Abrir menú" onPress={onMenuPress} />}
        {showLogo && (
          <View style={styles.brand}>
            <MenzoLogo size={30} />
            <Text style={styles.brandText}>MENZO</Text>
          </View>
        )}
      </View>
      <View style={styles.right}>
        {right ?? (
          <>
            <IconButton name="search" label="Buscar" onPress={() => router.push('/search')} />
            <IconButton
              name="notifications-outline"
              label="Notificaciones"
              onPress={() => router.push('/notifications')}
              badge={unread}
            />
          </>
        )}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
  },
  left: { flexDirection: 'row', alignItems: 'center', gap: Spacing.sm },
  brand: { flexDirection: 'row', alignItems: 'center', gap: Spacing.xs },
  brandText: { ...Typography.h3, color: Colors.textPrimary, letterSpacing: 1 },
  right: { flexDirection: 'row', alignItems: 'center', gap: Spacing.xxs },
});
