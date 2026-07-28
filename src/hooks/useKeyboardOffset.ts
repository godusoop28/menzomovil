import { Platform } from 'react-native';

export function useKeyboardBehavior() {
  return Platform.OS === 'ios' ? 'padding' : undefined;
}
