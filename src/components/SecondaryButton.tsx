import { Pressable, StyleSheet, Text } from 'react-native';

import { useHaptics } from '@/hooks/useHaptics';
import { Colors, Radius, Spacing, Typography } from '@/theme';

type Props = {
  label: string;
  onPress: () => void;
  disabled?: boolean;
  tone?: 'default' | 'danger';
};

export function SecondaryButton({ label, onPress, disabled, tone = 'default' }: Props) {
  const { selection } = useHaptics();
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={label}
      accessibilityState={{ disabled }}
      disabled={disabled}
      onPress={() => {
        selection();
        onPress();
      }}
      style={({ pressed }) => [
        styles.base,
        tone === 'danger' && styles.danger,
        { opacity: disabled ? 0.4 : pressed ? 0.75 : 1 },
      ]}>
      <Text style={[styles.label, tone === 'danger' && styles.dangerLabel]}>{label}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  base: {
    minHeight: 52,
    borderRadius: Radius.pill,
    borderWidth: 1,
    borderColor: Colors.borderStrong,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: Spacing.xl,
    backgroundColor: Colors.surfaceSecondary,
  },
  danger: { borderColor: 'rgba(251,113,133,0.4)', backgroundColor: 'rgba(251,113,133,0.08)' },
  label: { ...Typography.label, fontSize: 16, color: Colors.textPrimary },
  dangerLabel: { color: Colors.danger },
});
