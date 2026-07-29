import { Ionicons } from '@expo/vector-icons';
import { Image } from 'expo-image';
import { LinearGradient } from 'expo-linear-gradient';
import { router } from 'expo-router';
import { ActivityIndicator, Pressable, StyleSheet, Text, View } from 'react-native';

import { UserAvatar } from './UserAvatar';
import { useAppState } from '@/hooks/useAppState';
import { useHaptics } from '@/hooks/useHaptics';
import { messagesForRoom } from '@/store/selectors';
import { Colors, Gradients, Radius, Spacing, Typography } from '@/theme';
import type { ChatRoom } from '@/types';
import { relativeTime } from '@/utils/time';

type Props = {
  room: ChatRoom;
  compact?: boolean;
  /** Si se pasa, las salas públicas sin unirse muestran un botón "Unirse" en vez de la estrella. */
  onJoin?: (roomId: string) => void;
  joining?: boolean;
};

export function ChatRoomCard({ room, compact, onJoin, joining }: Props) {
  const { state, actions } = useAppState();
  const { selection } = useHaptics();
  const messages = messagesForRoom(state.social, room.id);
  const last = messages[messages.length - 1];
  const title = room.type === 'direct' ? room.peer?.displayName ?? room.name : room.name;
  const isOnline = room.type === 'direct' ? !!room.peer?.isOnline : room.onlineCount > 0;
  const lastMessagePreview = last
    ? last.body || (last.imageUri ? '📷 Foto' : '')
    : room.lastMessage
      ? room.lastMessage.body || (room.lastMessage.hasImage ? '📷 Foto' : '')
      : room.description;
  const lastMessageTime = last?.createdAt ?? room.lastMessage?.createdAt;

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
        <View style={styles.publicIconWrap}>
          <View>
            {room.coverUri ? (
              <Image source={{ uri: room.coverUri }} style={styles.icon} contentFit="cover" />
            ) : (
              <LinearGradient
                colors={Gradients[room.gradient] as unknown as [string, string, ...string[]]}
                start={{ x: 0, y: 0 }}
                end={{ x: 1, y: 1 }}
                style={styles.icon}>
                <Ionicons name={room.icon as never} size={22} color="#FFFFFF" />
              </LinearGradient>
            )}
            {room.live && (
              <View style={styles.liveBadge}>
                <Text style={styles.liveBadgeLabel}>Live</Text>
              </View>
            )}
          </View>
          <Text style={styles.publicIconCaption} numberOfLines={1}>
            Sala pública
          </Text>
        </View>
      )}

      <View style={styles.info}>
        <View style={styles.titleRow}>
          <Text style={styles.name} numberOfLines={1}>
            {title}
          </Text>
          {!!lastMessageTime && <Text style={styles.time}>{relativeTime(lastMessageTime)}</Text>}
        </View>
        <Text style={styles.lastMessage} numberOfLines={1}>
          {lastMessagePreview}
        </Text>
        <View style={styles.metaRow}>
          <View style={[styles.onlineDot, !isOnline && styles.onlineDotOffline]} />
          <Text style={styles.meta}>
            {room.type === 'direct'
              ? room.peer?.isOnline
                ? 'En línea'
                : 'Desconectado'
              : `${room.onlineCount} conectados · ${room.memberIds.length} miembros`}
          </Text>
        </View>
      </View>

      {onJoin && room.type === 'public' && !room.joined ? (
        <Pressable
          hitSlop={8}
          disabled={joining}
          accessibilityRole="button"
          accessibilityLabel="Unirse a la sala"
          style={styles.joinButton}
          onPress={(e) => {
            e.stopPropagation();
            selection();
            onJoin(room.id);
          }}>
          {joining ? <ActivityIndicator size="small" color={Colors.textPrimary} /> : <Text style={styles.joinButtonLabel}>Unirse</Text>}
        </Pressable>
      ) : (
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
      )}
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
  publicIconWrap: { alignItems: 'center', gap: 3 },
  icon: { width: 48, height: 48, borderRadius: Radius.md, alignItems: 'center', justifyContent: 'center' },
  liveBadge: {
    position: 'absolute',
    bottom: -6,
    left: 0,
    right: 0,
    alignItems: 'center',
  },
  liveBadgeLabel: {
    ...Typography.caption,
    fontSize: 8,
    fontWeight: '800',
    textTransform: 'uppercase',
    letterSpacing: 0.4,
    color: '#FFFFFF',
    backgroundColor: Colors.coral,
    borderRadius: 999,
    paddingHorizontal: 6,
    paddingVertical: 1,
    overflow: 'hidden',
  },
  publicIconCaption: { ...Typography.caption, fontSize: 8, textTransform: 'uppercase', letterSpacing: 0.4, color: Colors.textMuted },
  info: { flex: 1, gap: 2 },
  titleRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  name: { ...Typography.bodyMedium, color: Colors.textPrimary, flexShrink: 1 },
  time: { ...Typography.caption, color: Colors.textMuted },
  lastMessage: { ...Typography.caption, color: Colors.textSecondary },
  metaRow: { flexDirection: 'row', alignItems: 'center', gap: 4, marginTop: 2 },
  onlineDot: { width: 6, height: 6, borderRadius: 3, backgroundColor: Colors.online },
  onlineDotOffline: { backgroundColor: Colors.offline },
  meta: { ...Typography.caption, color: Colors.textMuted, fontSize: 11 },
  joinButton: {
    paddingHorizontal: Spacing.sm,
    paddingVertical: 6,
    borderRadius: 999,
    borderWidth: 1,
    borderColor: Colors.borderStrong,
  },
  joinButtonLabel: { ...Typography.caption, color: Colors.textPrimary, fontWeight: '600' },
});
