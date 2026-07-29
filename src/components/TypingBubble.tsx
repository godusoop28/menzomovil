import { useEffect, useState } from 'react';
import { Animated, StyleSheet, Text, View } from 'react-native';

import { UserAvatar } from './UserAvatar';
import { Colors, Radius, Spacing, Typography } from '@/theme';
import type { TypingUser } from '@/hooks/useRoomSocket';

function TypingDot({ delay }: { delay: number }) {
  const [offset] = useState(() => new Animated.Value(0));

  useEffect(() => {
    const loop = Animated.loop(
      Animated.sequence([
        Animated.delay(delay),
        Animated.timing(offset, { toValue: 1, duration: 360, useNativeDriver: true }),
        Animated.timing(offset, { toValue: 0, duration: 360, useNativeDriver: true }),
        Animated.delay(1200 - delay),
      ])
    );
    loop.start();
    return () => loop.stop();
  }, [delay, offset]);

  return (
    <Animated.View
      style={[
        styles.dot,
        { transform: [{ translateY: offset.interpolate({ inputRange: [0, 1], outputRange: [0, -3] }) }] },
      ]}
    />
  );
}

export function TypingBubble({ typingUsers }: { typingUsers: TypingUser[] }) {
  if (typingUsers.length === 0) return null;

  const label =
    typingUsers.length === 1
      ? `${typingUsers[0].displayName} está escribiendo`
      : typingUsers.length === 2
        ? `${typingUsers[0].displayName} y ${typingUsers[1].displayName} están escribiendo`
        : 'Varias personas están escribiendo';

  return (
    <View style={styles.row}>
      <UserAvatar name={typingUsers[0].displayName} size={30} gradient="fire" />
      <View style={styles.bubble}>
        <View style={styles.dots}>
          <TypingDot delay={0} />
          <TypingDot delay={150} />
          <TypingDot delay={300} />
        </View>
        <Text style={styles.label}>{label}</Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: 'row', gap: Spacing.xs, alignItems: 'flex-end', maxWidth: '86%' },
  bubble: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.xs,
    backgroundColor: Colors.surfaceSecondary,
    borderRadius: Radius.md,
    borderTopLeftRadius: 4,
    paddingVertical: Spacing.sm,
    paddingHorizontal: Spacing.md,
  },
  dots: { flexDirection: 'row', gap: 4 },
  dot: { width: 6, height: 6, borderRadius: 3, backgroundColor: Colors.textMuted },
  label: { ...Typography.caption, color: Colors.textMuted },
});
