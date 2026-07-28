import { LinearGradient } from 'expo-linear-gradient';
import type { ReactNode } from 'react';
import { ImageBackground, StyleSheet, View, type ImageSourcePropType, type StyleProp, type ViewStyle } from 'react-native';

type Props = {
  source: ImageSourcePropType;
  children?: ReactNode;
  style?: StyleProp<ViewStyle>;
  overlayOpacity?: number;
  edgeFade?: boolean;
  resizeMode?: 'cover' | 'contain';
};

export function MenzoImageBackground({
  source,
  children,
  style,
  overlayOpacity = 0.72,
  edgeFade = true,
  resizeMode = 'cover',
}: Props) {
  return (
    <ImageBackground source={source} resizeMode={resizeMode} style={[styles.fill, style]}>
      <View style={[StyleSheet.absoluteFill, { backgroundColor: `rgba(7,9,13,${overlayOpacity})` }]} />
      {edgeFade && (
        <LinearGradient
          colors={['rgba(7,9,13,0.15)', 'rgba(7,9,13,0.35)', 'rgba(7,9,13,0.85)']}
          locations={[0, 0.55, 1]}
          style={StyleSheet.absoluteFill}
        />
      )}
      {children}
    </ImageBackground>
  );
}

const styles = StyleSheet.create({
  fill: { flex: 1 },
});
