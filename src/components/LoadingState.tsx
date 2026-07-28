import { ActivityIndicator, StyleSheet, Text, View } from 'react-native';

import { Colors, Typography, useAccent } from '@/theme';

export function LoadingState({ label = 'Cargando…' }: { label?: string }) {
  const accent = useAccent();
  return (
    <View style={styles.wrap}>
      <ActivityIndicator color={accent.color} />
      <Text style={styles.label}>{label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { flex: 1, alignItems: 'center', justifyContent: 'center', gap: 12, backgroundColor: Colors.background },
  label: { ...Typography.body, color: Colors.textMuted },
});
