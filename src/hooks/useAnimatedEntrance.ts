import { useEffect } from 'react';
import { useAnimatedStyle, useSharedValue, withDelay, withTiming } from 'react-native-reanimated';

import { useAppState } from './useAppState';

export function useAnimatedEntrance(delay = 0) {
  const { state } = useAppState();
  const animationsEnabled = state.settings.animationsEnabled;
  const opacity = useSharedValue(animationsEnabled ? 0 : 1);
  const translateY = useSharedValue(animationsEnabled ? 10 : 0);

  useEffect(() => {
    if (!animationsEnabled) {
      opacity.value = 1;
      translateY.value = 0;
      return;
    }
    opacity.value = withDelay(delay, withTiming(1, { duration: 320 }));
    translateY.value = withDelay(delay, withTiming(0, { duration: 320 }));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [animationsEnabled, delay]);

  return useAnimatedStyle(() => ({
    opacity: opacity.value,
    transform: [{ translateY: translateY.value }],
  }));
}
