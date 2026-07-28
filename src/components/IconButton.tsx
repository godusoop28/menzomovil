import { Ionicons } from '@expo/vector-icons';
import { Pressable, StyleSheet, View } from 'react-native';

import { useHaptics } from '@/hooks/useHaptics';
import { Colors, MinTouchTarget, Radius } from '@/theme';

type Props = {
  name: keyof typeof Ionicons.glyphMap;
  onPress: () => void;
  size?: number;
  color?: string;
  label: string;
  badge?: number;
  variant?: 'ghost' | 'surface';
};

export function IconButton({ name, onPress, size = 20, color = Colors.textPrimary, label, badge, variant = 'ghost' }: Props) {
  const { selection } = useHaptics();
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={label}
      hitSlop={8}
      onPress={() => {
        selection();
        onPress();
      }}
      style={({ pressed }) => [
        styles.base,
        variant === 'surface' && styles.surface,
        { opacity: pressed ? 0.6 : 1 },
      ]}>
      <Ionicons name={name} size={size} color={color} />
      {!!badge && (
        <View style={styles.badge} accessibilityElementsHidden importantForAccessibility="no">
          <View style={styles.badgeDot} />
        </View>
      )}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  base: {
    width: MinTouchTarget,
    height: MinTouchTarget,
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: Radius.pill,
  },
  surface: { backgroundColor: Colors.surfaceSecondary, borderWidth: 1, borderColor: Colors.borderSoft },
  badge: { position: 'absolute', top: 8, right: 8 },
  badgeDot: { width: 9, height: 9, borderRadius: 5, backgroundColor: Colors.coral, borderWidth: 1.5, borderColor: Colors.background },
});
