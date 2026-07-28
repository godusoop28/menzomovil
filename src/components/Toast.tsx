import { useEffect } from 'react';
import { StyleSheet, Text } from 'react-native';
import Animated, { FadeInDown, FadeOutDown } from 'react-native-reanimated';

import { Colors, Radius, Spacing, Typography } from '@/theme';

type Props = {
  message: string | null;
  onHide: () => void;
  duration?: number;
};

export function Toast({ message, onHide, duration = 2200 }: Props) {
  useEffect(() => {
    if (!message) return;
    const timer = setTimeout(onHide, duration);
    return () => clearTimeout(timer);
  }, [message, duration, onHide]);

  if (!message) return null;

  return (
    <Animated.View
      entering={FadeInDown.duration(220)}
      exiting={FadeOutDown.duration(180)}
      style={styles.wrap}
      pointerEvents="none">
      <Text style={styles.text}>{message}</Text>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  wrap: {
    position: 'absolute',
    bottom: 110,
    alignSelf: 'center',
    backgroundColor: Colors.surfaceElevated,
    borderRadius: Radius.pill,
    borderWidth: 1,
    borderColor: Colors.borderStrong,
    paddingVertical: Spacing.sm,
    paddingHorizontal: Spacing.lg,
    maxWidth: '86%',
  },
  text: { ...Typography.label, color: Colors.textPrimary, textAlign: 'center' },
});
