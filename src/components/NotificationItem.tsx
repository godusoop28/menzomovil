import { Ionicons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { Pressable, StyleSheet, Text, View } from 'react-native';

import { useAppState } from '@/hooks/useAppState';
import { Colors, Radius, Spacing, Typography } from '@/theme';
import type { Notification } from '@/types';
import { relativeTime } from '@/utils/time';

const categoryIcon: Record<Notification['category'], keyof typeof Ionicons.glyphMap> = {
  comentarios: 'chatbubble-outline',
  likes: 'heart-outline',
  mensajes: 'mail-outline',
  eventos: 'calendar-outline',
  seguimientos: 'person-add-outline',
};

export function NotificationItem({ notification }: { notification: Notification }) {
  const { actions } = useAppState();

  function handlePress() {
    actions.markNotificationRead(notification.id);
    if (notification.relatedPostId) router.push(`/post/${notification.relatedPostId}`);
    else if (notification.relatedRoomId) router.push(`/chat/${notification.relatedRoomId}`);
    else if (notification.relatedUserId) router.push(`/member/${notification.relatedUserId}`);
    else if (notification.relatedEventId) router.push(`/events/${notification.relatedEventId}`);
  }

  return (
    <Pressable
      onPress={handlePress}
      style={[styles.card, !notification.read && styles.unread]}
      accessibilityRole="button"
      accessibilityLabel={notification.title}>
      <View style={styles.iconWrap}>
        <Ionicons name={categoryIcon[notification.category]} size={18} color={Colors.textSecondary} />
      </View>
      <View style={styles.content}>
        <Text style={styles.title}>{notification.title}</Text>
        <Text style={styles.body} numberOfLines={2}>
          {notification.body}
        </Text>
        <Text style={styles.time}>{relativeTime(notification.createdAt)}</Text>
      </View>
      {!notification.read && <View style={styles.dot} />}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  card: {
    flexDirection: 'row',
    gap: Spacing.sm,
    backgroundColor: Colors.surface,
    borderRadius: Radius.md,
    borderWidth: 1,
    borderColor: Colors.borderSoft,
    padding: Spacing.md,
    alignItems: 'flex-start',
  },
  unread: { borderColor: 'rgba(255,122,26,0.35)', backgroundColor: Colors.surfaceSecondary },
  iconWrap: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: Colors.surfaceElevated,
    alignItems: 'center',
    justifyContent: 'center',
  },
  content: { flex: 1, gap: 2 },
  title: { ...Typography.bodyMedium, color: Colors.textPrimary },
  body: { ...Typography.caption, color: Colors.textSecondary },
  time: { ...Typography.caption, color: Colors.textMuted, marginTop: 2 },
  dot: { width: 8, height: 8, borderRadius: 4, backgroundColor: Colors.coral, marginTop: 6 },
});
