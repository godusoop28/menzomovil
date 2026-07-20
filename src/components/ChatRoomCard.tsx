import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { router } from 'expo-router';
import { Pressable, StyleSheet, Text, View } from 'react-native';

import { UserAvatar } from './UserAvatar';
import { useAppState } from '@/hooks/useAppState';
import { useHaptics } from '@/hooks/useHaptics';
import { messagesForRoom } from '@/store/selectors';
import { Colors, Gradients, Radius, Spacing, Typography } from '@/theme';
import type { ChatRoom } from '@/types';
import { relativeTime } from '@/utils/time';

export function ChatRoomCard({ room, compact }: { room: ChatRoom; compact?: boolean }) {
  const { state, actions } = useAppState();
  const { selection } = useHaptics();
  const messages = messagesForRoom(state.social, room.id);
  const last = messages[messages.length - 1];
  const title = room.type === 'direct' ? room.peer?.displayName ?? room.name : room.name;

  return (
    <Pressable
      onPress={() => router.push(`/chat/${room.id}`)}
      style={[styles.card, compact && styles.compact]}
      accessibilityRole="button"
      accessibilityLabel={title}>
      {room.type === 'direct' && room.peer ? (
        <UserAvatar
          name={room.peer.displayName}
          avatarUri={room.peer.avatarUri}
          gradient={room.peer.avatarGradient}
          size={48}
          showOnline
          online={room.peer.isOnline}
        />
      ) : (
        <LinearGradient
          colors={Gradients[room.gradient] as unknown as [string, string, ...string[]]}
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 1 }}
          style={styles.icon}>
          <Ionicons name={room.icon as never} size={22} color="#FFFFFF" />
        </LinearGradient>
      )}

      <View style={styles.info}>
        <View style={styles.titleRow}>
          <Text style={styles.name} numberOfLines={1}>
            {title}
          </Text>
          {!!last && <Text style={styles.time}>{relativeTime(last.createdAt)}</Text>}
        </View>
        <Text style={styles.lastMessage} numberOfLines={1}>
          {last ? last.body : room.description}
        </Text>
        <View style={styles.metaRow}>
          <View style={styles.onlineDot} />
          <Text style={styles.meta}>
            {room.type === 'direct'
              ? room.peer?.isOnline
                ? 'En línea'
                : 'Desconectado'
              : `${room.onlineCount} conectados · ${room.memberIds.length} miembros`}
          </Text>
        </View>
      </View>

      <Pressable
        hitSlop={8}
        accessibilityRole="button"
        accessibilityLabel={room.favorite ? 'Quitar de favoritos' : 'Marcar como favorito'}
        onPress={(e) => {
          e.stopPropagation();
          selection();
          actions.toggleFavoriteRoom(room.id);
        }}>
        <Ionicons
          name={room.favorite ? 'star' : 'star-outline'}
          size={20}
          color={room.favorite ? Colors.yellow : Colors.textMuted}
        />
      </Pressable>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  card: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.sm,
    backgroundColor: Colors.surface,
    borderRadius: Radius.lg,
    borderWidth: 1,
    borderColor: Colors.borderSoft,
    padding: Spacing.md,
  },
  compact: { width: 220 },
  icon: { width: 48, height: 48, borderRadius: Radius.md, alignItems: 'center', justifyContent: 'center' },
  info: { flex: 1, gap: 2 },
  titleRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  name: { ...Typography.bodyMedium, color: Colors.textPrimary, flexShrink: 1 },
  time: { ...Typography.caption, color: Colors.textMuted },
  lastMessage: { ...Typography.caption, color: Colors.textSecondary },
  metaRow: { flexDirection: 'row', alignItems: 'center', gap: 4, marginTop: 2 },
  onlineDot: { width: 6, height: 6, borderRadius: 3, backgroundColor: Colors.online },
  meta: { ...Typography.caption, color: Colors.textMuted, fontSize: 11 },
});
