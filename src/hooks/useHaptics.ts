import * as Haptics from 'expo-haptics';
import { useCallback } from 'react';

import { useAppState } from './useAppState';

export function useHaptics() {
  const { state } = useAppState();
  const enabled = state.settings.hapticsEnabled;

  const light = useCallback(() => {
    if (enabled) Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
  }, [enabled]);

  const medium = useCallback(() => {
    if (enabled) Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
  }, [enabled]);

  const success = useCallback(() => {
    if (enabled) Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
  }, [enabled]);

  const selection = useCallback(() => {
    if (enabled) Haptics.selectionAsync();
  }, [enabled]);

  return { light, medium, success, selection };
}
