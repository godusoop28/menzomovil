import { useEffect, useState } from 'react';
import { Animated, StyleSheet, View } from 'react-native';

import { UserAvatar } from './UserAvatar';
import { Gradients } from '@/theme';

type Props = {
  name: string;
  avatarUri?: string;
  gradient?: keyof typeof Gradients;
  size?: number;
  level: number;
  accentColor: string;
};

/** El avatar de cada miembro en vivo — una "bola de sonido" que crece y brilla según el volumen
 * real que reporta Agora, en vez de un anillo fijo de "está hablando". */
export function VoiceAvatarBubble({ name, avatarUri, gradient, size = 40, level, accentColor }: Props) {
  const [scale] = useState(() => new Animated.Value(1));
  const [glow] = useState(() => new Animated.Value(0));

  useEffect(() => {
    Animated.parallel([
      Animated.timing(scale, { toValue: 1 + level * 0.22, duration: 220, useNativeDriver: true }),
      Animated.timing(glow, { toValue: level, duration: 220, useNativeDriver: true }),
    ]).start();
  }, [level, scale, glow]);

  const glowSize = size * 1.6;

  return (
    <View style={[styles.wrap, { width: glowSize, height: glowSize }]}>
      <Animated.View
        pointerEvents="none"
        style={[
          styles.glow,
          {
            width: glowSize,
            height: glowSize,
            borderRadius: glowSize / 2,
            backgroundColor: accentColor,
            opacity: glow.interpolate({ inputRange: [0, 1], outputRange: [0, 0.35] }),
            transform: [{ scale: glow.interpolate({ inputRange: [0, 1], outputRange: [0.75, 1] }) }],
          },
        ]}
      />
      <Animated.View style={{ transform: [{ scale }] }}>
        <UserAvatar name={name} avatarUri={avatarUri} gradient={gradient} size={size} />
      </Animated.View>
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { alignItems: 'center', justifyContent: 'center' },
  glow: { position: 'absolute' },
});
