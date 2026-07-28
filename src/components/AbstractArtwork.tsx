import { LinearGradient } from 'expo-linear-gradient';
import { StyleSheet, Text, View, type StyleProp, type ViewStyle } from 'react-native';

import { Gradients, Radius } from '@/theme';
import type { AbstractVisualPreset } from '@/types';

const presetGradient: Record<AbstractVisualPreset, keyof typeof Gradients> = {
  fire: 'fire',
  storm: 'connection',
  eclipse: 'midnight',
  rebirth: 'community',
  prism: 'creative',
  midnight: 'midnight',
  memory: 'community',
  community: 'community',
};

function hashSeed(value: string) {
  let h = 0;
  for (let i = 0; i < value.length; i += 1) {
    h = (h * 31 + value.charCodeAt(i)) >>> 0;
  }
  return h || 1;
}

function mulberry32(seed: number) {
  let a = seed;
  return () => {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

type Shape = { top: string; left: string; size: number; rotate: string; opacity: number; circle: boolean };

function buildShapes(preset: string, count: number): Shape[] {
  const rand = mulberry32(hashSeed(preset));
  return Array.from({ length: count }, (_, i) => ({
    top: `${Math.round(rand() * 80)}%`,
    left: `${Math.round(rand() * 80)}%`,
    size: 26 + Math.round(rand() * 90),
    rotate: `${Math.round(rand() * 60 - 30)}deg`,
    opacity: 0.08 + rand() * 0.14,
    circle: i % 2 === 0,
  }));
}

type Props = {
  preset: AbstractVisualPreset;
  style?: StyleProp<ViewStyle>;
  radius?: number;
  caption?: string;
  dim?: boolean;
};

export function AbstractArtwork({ preset, style, radius = Radius.lg, caption, dim }: Props) {
  const gradientId = presetGradient[preset];
  const shapes = buildShapes(preset, 6);

  return (
    <View style={[styles.wrap, { borderRadius: radius }, style]}>
      <LinearGradient
        colors={Gradients[gradientId] as unknown as [string, string, ...string[]]}
        start={{ x: 0.1, y: 0 }}
        end={{ x: 0.9, y: 1 }}
        style={StyleSheet.absoluteFill}
      />
      {dim && <View style={[StyleSheet.absoluteFill, styles.dimOverlay]} />}
      {shapes.map((shape, index) => (
        <View
          key={index}
          style={[
            styles.shape,
            {
              top: shape.top as never,
              left: shape.left as never,
              width: shape.size,
              height: shape.size,
              borderRadius: shape.circle ? shape.size / 2 : 6,
              transform: [{ rotate: shape.rotate }],
              backgroundColor: `rgba(255,255,255,${shape.opacity})`,
            },
          ]}
        />
      ))}
      {caption && (
        <View style={styles.captionWrap}>
          <Text style={styles.caption} numberOfLines={1}>
            {caption}
          </Text>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { overflow: 'hidden', position: 'relative' },
  shape: { position: 'absolute' },
  dimOverlay: { backgroundColor: 'rgba(3,5,9,0.35)' },
  captionWrap: { position: 'absolute', bottom: 12, left: 14 },
  caption: { color: '#F7F8FC', fontSize: 12, fontWeight: '600', opacity: 0.85 },
});
