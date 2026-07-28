import { Pressable, StyleSheet, Text, View } from 'react-native';

import { Colors, Typography } from '@/theme';

export function StatItem({ value, label, onPress }: { value: number | string; label: string; onPress?: () => void }) {
  if (onPress) {
    return (
      <Pressable style={styles.wrap} accessibilityRole="button" accessibilityLabel={`${value} ${label}`} onPress={onPress}>
        <Text style={styles.value}>{value}</Text>
        <Text style={styles.label}>{label}</Text>
      </Pressable>
    );
  }
  return (
    <View style={styles.wrap} accessibilityLabel={`${value} ${label}`}>
      <Text style={styles.value}>{value}</Text>
      <Text style={styles.label}>{label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { alignItems: 'center', minWidth: 64 },
  value: { ...Typography.h3, color: Colors.textPrimary },
  label: { ...Typography.caption, color: Colors.textMuted },
});
