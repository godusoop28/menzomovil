import { useEffect, useState } from 'react';
import { StyleSheet, Text } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import Animated, { FadeInUp, FadeOutUp } from 'react-native-reanimated';

import { onSlowRequestChange } from '@/services/api';
import { Colors, Radius, Spacing, Typography } from '@/theme';

export function ServerWakingBanner() {
  const [visible, setVisible] = useState(false);
  const insets = useSafeAreaInsets();

  useEffect(() => onSlowRequestChange(setVisible), []);

  if (!visible) return null;

  return (
    <Animated.View
      entering={FadeInUp.duration(220)}
      exiting={FadeOutUp.duration(180)}
      style={[styles.wrap, { top: insets.top + Spacing.sm }]}
      pointerEvents="none">
      <Text style={styles.text}>Despertando a Menzo… puede tardar uno o dos minutos la primera vez.</Text>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  wrap: {
    position: 'absolute',
    left: Spacing.lg,
    right: Spacing.lg,
    alignSelf: 'center',
    backgroundColor: Colors.surfaceElevated,
    borderRadius: Radius.md,
    borderWidth: 1,
    borderColor: Colors.borderStrong,
    paddingVertical: Spacing.sm,
    paddingHorizontal: Spacing.md,
    zIndex: 100,
  },
  text: { ...Typography.label, color: Colors.textPrimary, textAlign: 'center' },
});
