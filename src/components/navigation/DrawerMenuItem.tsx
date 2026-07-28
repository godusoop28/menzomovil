import { Ionicons } from '@expo/vector-icons';
import { Pressable, StyleSheet, Text, View } from 'react-native';

import { useHaptics } from '@/hooks/useHaptics';
import { Colors, Radius, Spacing, Typography } from '@/theme';

type Props = {
  label: string;
  icon: keyof typeof Ionicons.glyphMap;
  color: string;
  active?: boolean;
  onPress: () => void;
};

export function DrawerMenuItem({ label, icon, color, active, onPress }: Props) {
  const { selection } = useHaptics();

  return (
    <Pressable
      onPress={() => {
        selection();
        onPress();
      }}
      accessibilityRole="button"
      accessibilityLabel={label}
      accessibilityState={{ selected: !!active }}
      style={({ pressed }) => [styles.row, active && styles.rowActive, { opacity: pressed ? 0.8 : 1 }]}>
      {active && <View style={[styles.activeBar, { backgroundColor: color }]} />}
      <View style={[styles.iconWrap, { backgroundColor: color, opacity: active ? 1 : 0.82 }]}>
        <Ionicons name={icon} size={18} color="#FFFFFF" />
      </View>
      <Text style={[styles.label, active && styles.labelActive]}>{label}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.md,
    paddingVertical: Spacing.sm + 2,
    paddingHorizontal: Spacing.md,
    borderRadius: Radius.md,
    marginHorizontal: Spacing.sm,
  },
  rowActive: { backgroundColor: 'rgba(255,255,255,0.09)' },
  activeBar: {
    position: 'absolute',
    left: 0,
    top: 6,
    bottom: 6,
    width: 3,
    borderRadius: 2,
  },
  iconWrap: {
    width: 38,
    height: 38,
    borderRadius: 19,
    alignItems: 'center',
    justifyContent: 'center',
  },
  label: { ...Typography.bodyMedium, fontSize: 17, color: Colors.textSecondary },
  labelActive: { color: Colors.textPrimary, fontWeight: '700' },
});
