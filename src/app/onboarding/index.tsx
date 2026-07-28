import { LinearGradient } from 'expo-linear-gradient';
import { Image } from 'expo-image';
import { router } from 'expo-router';
import { useEffect } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import Animated, {
  Easing,
  useAnimatedStyle,
  useSharedValue,
  withDelay,
  withRepeat,
  withSequence,
  withTiming,
} from 'react-native-reanimated';

import { ScreenContainer } from '@/components/ScreenContainer';
import { menzoAssets } from '@/constants/assets';
import { Colors, Spacing, Typography } from '@/theme';

const SPARKS = [
  { top: '18%', left: '20%', delay: 300, size: 5 },
  { top: '28%', left: '80%', delay: 550, size: 4 },
  { top: '68%', left: '16%', delay: 700, size: 3 },
  { top: '74%', left: '84%', delay: 450, size: 5 },
] as const;

export default function OnboardingSplash() {
  const scale = useSharedValue(0.85);
  const opacity = useSharedValue(0);
  const textOpacity = useSharedValue(0);
  const textTranslateY = useSharedValue(8);
  const haloPulse = useSharedValue(0.9);

  useEffect(() => {
    scale.value = withTiming(1, { duration: 700, easing: Easing.out(Easing.cubic) });
    opacity.value = withTiming(1, { duration: 700 });
    textOpacity.value = withDelay(250, withTiming(1, { duration: 550 }));
    textTranslateY.value = withDelay(250, withTiming(0, { duration: 550, easing: Easing.out(Easing.cubic) }));
    haloPulse.value = withRepeat(withSequence(withTiming(1.08, { duration: 1400 }), withTiming(0.9, { duration: 1400 })), -1, true);

    const timer = setTimeout(() => {
      router.replace('/onboarding/intro');
    }, 2200);
    return () => clearTimeout(timer);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const logoStyle = useAnimatedStyle(() => ({
    opacity: opacity.value,
    transform: [{ scale: scale.value }],
  }));

  const haloStyle = useAnimatedStyle(() => ({
    transform: [{ scale: haloPulse.value }],
  }));

  const textStyle = useAnimatedStyle(() => ({
    opacity: textOpacity.value,
    transform: [{ translateY: textTranslateY.value }],
  }));

  return (
    <ScreenContainer backgroundImage={menzoAssets.backgrounds.onboarding} backgroundImageOverlay={0.84}>
      <View style={styles.center}>
        {SPARKS.map((spark, index) => (
          <Spark key={index} {...spark} />
        ))}

        <View style={styles.haloWrap}>
          <Animated.View style={[styles.halo, haloStyle]}>
            <LinearGradient
              colors={['rgba(255,122,26,0.36)', 'rgba(139,92,246,0.18)', 'rgba(3,5,9,0)']}
              style={StyleSheet.absoluteFill}
            />
          </Animated.View>
          <Animated.View style={logoStyle}>
            <Image source={menzoAssets.branding.splashMark} style={styles.mark} contentFit="contain" />
          </Animated.View>
        </View>

        <Animated.View style={textStyle}>
          <Text style={styles.wordmark}>MENZO</Text>
          <Text style={styles.tagline}>Volver también es avanzar.</Text>
        </Animated.View>
      </View>
    </ScreenContainer>
  );
}

function Spark({ top, left, delay, size }: { top: string; left: string; delay: number; size: number }) {
  const opacity = useSharedValue(0);

  useEffect(() => {
    opacity.value = withDelay(
      delay,
      withRepeat(withSequence(withTiming(1, { duration: 900 }), withTiming(0.25, { duration: 900 })), -1, true)
    );
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const style = useAnimatedStyle(() => ({ opacity: opacity.value }));

  return (
    <Animated.View
      style={[
        styles.spark,
        style,
        { top: top as never, left: left as never, width: size, height: size, borderRadius: size / 2 },
      ]}
    />
  );
}

const styles = StyleSheet.create({
  center: { flex: 1, alignItems: 'center', justifyContent: 'center', gap: Spacing.xl },
  haloWrap: { alignItems: 'center', justifyContent: 'center' },
  halo: {
    position: 'absolute',
    width: 300,
    height: 300,
    borderRadius: 150,
    overflow: 'hidden',
  },
  mark: { width: 168, height: 152 },
  wordmark: { ...Typography.display, fontSize: 34, color: Colors.textPrimary, textAlign: 'center', letterSpacing: 4 },
  tagline: { ...Typography.h3, color: Colors.textSecondary, textAlign: 'center', marginTop: Spacing.xs },
  spark: { position: 'absolute', backgroundColor: Colors.cyan },
});
