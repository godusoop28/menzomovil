import { Pressable, StyleSheet, Text, View } from 'react-native';

import { useHaptics } from '@/hooks/useHaptics';
import { Colors, Radius, Spacing, Typography, useAccent } from '@/theme';

type Props<T extends string> = {
  options: { value: T; label: string }[];
  value: T;
  onChange: (value: T) => void;
};

export function SegmentedTabs<T extends string>({ options, value, onChange }: Props<T>) {
  const { selection } = useHaptics();
  const accent = useAccent();
  return (
    <View style={styles.wrap} accessibilityRole="tablist">
      {options.map((option) => {
        const active = option.value === value;
        return (
          <Pressable
            key={option.value}
            accessibilityRole="tab"
            accessibilityState={{ selected: active }}
            onPress={() => {
              if (!active) {
                selection();
                onChange(option.value);
              }
            }}
            style={[styles.item, active && styles.itemActive]}>
            <Text style={[styles.label, active && { color: accent.color }]}>{option.label}</Text>
          </Pressable>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: {
    flexDirection: 'row',
    backgroundColor: Colors.surfaceSecondary,
    borderRadius: Radius.pill,
    padding: 4,
    borderWidth: 1,
    borderColor: Colors.borderSoft,
  },
  item: { flex: 1, paddingVertical: Spacing.sm, alignItems: 'center', borderRadius: Radius.pill },
  itemActive: { backgroundColor: Colors.surfaceSoft },
  label: { ...Typography.label, color: Colors.textMuted },
});
