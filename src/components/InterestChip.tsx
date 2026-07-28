import { Ionicons } from '@expo/vector-icons';
import { Pressable, StyleSheet, Text } from 'react-native';

import { useHaptics } from '@/hooks/useHaptics';
import { Colors, Radius, Spacing, Typography } from '@/theme';
import type { Interest } from '@/types';

type Props = {
  interest: Interest;
  selected: boolean;
  onToggle: (id: Interest['id']) => void;
  disabled?: boolean;
};

export function InterestChip({ interest, selected, onToggle, disabled }: Props) {
  const { selection } = useHaptics();
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityState={{ selected }}
      accessibilityLabel={interest.label}
      disabled={disabled && !selected}
      onPress={() => {
        selection();
        onToggle(interest.id);
      }}
      style={({ pressed }) => [
        styles.chip,
        selected && styles.chipSelected,
        disabled && !selected && styles.chipDisabled,
        { opacity: pressed ? 0.8 : 1 },
      ]}>
      <Ionicons
        name={interest.icon as never}
        size={16}
        color={selected ? Colors.textOnAccent : Colors.textSecondary}
      />
      <Text style={[styles.label, selected && styles.labelSelected]}>{interest.label}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  chip: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.xxs,
    paddingVertical: Spacing.sm,
    paddingHorizontal: Spacing.md,
    borderRadius: Radius.pill,
    borderWidth: 1,
    borderColor: Colors.borderSoft,
    backgroundColor: Colors.surfaceSecondary,
  },
  chipSelected: { backgroundColor: Colors.yellow, borderColor: Colors.yellow },
  chipDisabled: { opacity: 0.4 },
  label: { ...Typography.label, color: Colors.textSecondary },
  labelSelected: { color: Colors.textOnAccent },
});
