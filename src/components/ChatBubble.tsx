import { Image } from 'expo-image';
import { router } from 'expo-router';
import { Pressable, StyleSheet, Text, View } from 'react-native';

import { UserAvatar } from './UserAvatar';
import { Colors, Radius, Spacing, Typography, useAccent } from '@/theme';
import type { DemoUser, Message } from '@/types';
import type { RoomRole } from '@/services/api/types';
import { relativeTime } from '@/utils/time';

const ROLE_BADGE: Partial<Record<RoomRole, string>> = { OWNER: ' 👑', CO_HOST: ' ⭐' };

type Props = {
  message: Message;
  author?: DemoUser;
  isOwn: boolean;
  role?: RoomRole;
  /** true si el mensaje anterior es del mismo autor, mismo día, y hace poco — oculta avatar/nombre
   * repetidos para que la conversación se lea como una sola racha, no mensajes sueltos. */
  grouped?: boolean;
};

export function ChatBubble({ message, author, isOwn, role, grouped }: Props) {
  const accent = useAccent();

  if (message.type === 'system') {
    return (
      <View style={styles.systemWrap}>
        <Text style={styles.systemText}>{message.body}</Text>
      </View>
    );
  }

  const badge = role ? ROLE_BADGE[role] : undefined;

  return (
    <View style={[styles.row, isOwn && styles.rowOwn, grouped && styles.rowGrouped]}>
      {grouped ? (
        <View style={styles.avatarSpacer} />
      ) : (
        <Pressable onPress={() => author && router.push(`/member/${author.id}`)} disabled={!author}>
          <UserAvatar
            name={author?.displayName ?? '?'}
            avatarUri={author?.avatarUri}
            gradient={author?.avatarGradient ?? 'fire'}
            size={30}
            level={author?.level}
          />
        </Pressable>
      )}
      <View style={[styles.bubble, isOwn ? [{ backgroundColor: accent.color }, styles.bubbleOwnTail] : [styles.bubbleOther, styles.bubbleOtherTail]]}>
        {!isOwn && !grouped && (
          <Pressable onPress={() => author && router.push(`/member/${author.id}`)} disabled={!author}>
            <Text style={styles.author}>
              {author?.displayName ?? 'Miembro'}
              {badge}
            </Text>
          </Pressable>
        )}
        {!!message.imageUri && (
          <Image source={{ uri: message.imageUri }} style={styles.image} contentFit="cover" />
        )}
        {!!message.body && (
          <Text style={[styles.body, isOwn && styles.bodyOwn]}>{message.body}</Text>
        )}
        <Text style={[styles.time, isOwn && styles.timeOwn]}>{relativeTime(message.createdAt)}</Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  systemWrap: { alignItems: 'center', marginVertical: Spacing.sm },
  systemText: {
    ...Typography.caption,
    color: Colors.textMuted,
    backgroundColor: Colors.surfaceSecondary,
    paddingVertical: 4,
    paddingHorizontal: 10,
    borderRadius: Radius.pill,
  },
  row: { flexDirection: 'row', gap: Spacing.xs, alignItems: 'flex-end', maxWidth: '86%' },
  rowOwn: { alignSelf: 'flex-end', flexDirection: 'row-reverse' },
  rowGrouped: { marginTop: -6 },
  avatarSpacer: { width: 30 },
  bubble: { borderRadius: Radius.md, paddingVertical: Spacing.sm, paddingHorizontal: Spacing.md, gap: 4 },
  bubbleOwnTail: { borderTopRightRadius: 4 },
  bubbleOther: { backgroundColor: Colors.surfaceSecondary },
  bubbleOtherTail: { borderTopLeftRadius: 4 },
  author: { ...Typography.caption, color: Colors.cyan, fontWeight: '700' },
  body: { ...Typography.body, color: Colors.textPrimary },
  bodyOwn: { color: Colors.textOnAccent },
  image: { width: 200, height: 150, borderRadius: Radius.sm },
  time: { ...Typography.caption, color: Colors.textMuted, fontSize: 10, alignSelf: 'flex-end' },
  timeOwn: { color: 'rgba(9,10,14,0.6)' },
});
