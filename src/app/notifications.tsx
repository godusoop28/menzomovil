import { router } from 'expo-router';
import { useState } from 'react';
import { ScrollView, StyleSheet, Text, View } from 'react-native';

import { EmptyState } from '@/components/EmptyState';
import { IconButton } from '@/components/IconButton';
import { NotificationItem } from '@/components/NotificationItem';
import { ScreenContainer } from '@/components/ScreenContainer';
import { useAppState } from '@/hooks/useAppState';
import { Colors, Radius, Spacing, Typography } from '@/theme';
import type { Notification } from '@/types';

type Category = 'todo' | Notification['category'];

const categories: { value: Category; label: string }[] = [
  { value: 'todo', label: 'Todo' },
  { value: 'comentarios', label: 'Comentarios' },
  { value: 'likes', label: 'Likes' },
  { value: 'mensajes', label: 'Mensajes' },
  { value: 'eventos', label: 'Eventos' },
  { value: 'seguimientos', label: 'Seguimientos' },
];

export default function NotificationsScreen() {
  const { state, actions } = useAppState();
  const [category, setCategory] = useState<Category>('todo');

  const notifications = [...state.social.notifications]
    .filter((n) => category === 'todo' || n.category === category)
    .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());

  return (
    <ScreenContainer>
      <View style={styles.header}>
        <IconButton name="chevron-back" label="Volver" onPress={() => router.back()} />
        <Text style={styles.headerTitle}>Notificaciones</Text>
        <IconButton name="checkmark-done" label="Marcar todas como leídas" onPress={actions.markAllNotificationsRead} />
      </View>

      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.filterRow}>
        {categories.map((c) => (
          <Text
            key={c.value}
            onPress={() => setCategory(c.value)}
            accessibilityRole="button"
            accessibilityState={{ selected: category === c.value }}
            style={[styles.filterChip, category === c.value && styles.filterChipActive]}>
            {c.label}
          </Text>
        ))}
      </ScrollView>

      <ScrollView contentContainerStyle={styles.list} showsVerticalScrollIndicator={false}>
        {notifications.length === 0 ? (
          <EmptyState title="Todo está tranquilo por ahora." preset="midnight" />
        ) : (
          notifications.map((n) => <NotificationItem key={n.id} notification={n} />)
        )}
      </ScrollView>
    </ScreenContainer>
  );
}

const styles = StyleSheet.create({
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: Spacing.md,
    paddingTop: Spacing.xs,
  },
  headerTitle: { ...Typography.h3, color: Colors.textPrimary },
  filterRow: { gap: Spacing.sm, paddingHorizontal: Spacing.lg, paddingVertical: Spacing.md },
  filterChip: {
    ...Typography.label,
    color: Colors.textMuted,
    backgroundColor: Colors.surfaceSecondary,
    borderRadius: Radius.pill,
    paddingVertical: 8,
    paddingHorizontal: 14,
    overflow: 'hidden',
  },
  filterChipActive: { backgroundColor: Colors.surfaceSoft, color: Colors.textPrimary },
  list: { paddingHorizontal: Spacing.lg, gap: Spacing.sm, paddingBottom: Spacing.xxl },
});
