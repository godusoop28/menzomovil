import { Image } from 'expo-image';
import { StyleSheet, Text, View } from 'react-native';

import { UserAvatar } from './UserAvatar';
import { Colors, Radius, Spacing, Typography, useAccent } from '@/theme';
import type { DemoUser, Message } from '@/types';
import { relativeTime } from '@/utils/time';

type Props = {
  message: Message;
  author?: DemoUser;
  isOwn: boolean;
};

export function ChatBubble({ message, author, isOwn }: Props) {
  const accent = useAccent();

  if (message.type === 'system') {
    return (
      <View style={styles.systemWrap}>
        <Text style={styles.systemText}>{message.body}</Text>
      </View>
    );
  }

  return (
    <View style={[styles.row, isOwn && styles.rowOwn]}>
      <UserAvatar
        name={author?.displayName ?? '?'}
        avatarUri={author?.avatarUri}
        gradient={author?.avatarGradient ?? 'fire'}
        size={30}
        level={author?.level}
      />
      <View style={[styles.bubble, isOwn ? [{ backgroundColor: accent.color }, styles.bubbleOwnTail] : [styles.bubbleOther, styles.bubbleOtherTail]]}>
        {!isOwn && <Text style={styles.author}>{author?.displayName ?? 'Miembro'}</Text>}
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
