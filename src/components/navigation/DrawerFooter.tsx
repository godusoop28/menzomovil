import { StyleSheet, Text, View } from 'react-native';

import { Spacing, Typography } from '@/theme';

export function DrawerFooter() {
  return (
    <View style={styles.wrap}>
      <Text style={styles.brand}>MENZO</Text>
      <Text style={styles.tagline}>Message. Connect. Meet.</Text>
      <Text style={styles.meta}>Versión 1.0.0 · Prototipo local</Text>
      <Text style={styles.meta}>Datos locales de demostración</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: {
    paddingHorizontal: Spacing.lg,
    paddingTop: Spacing.md,
    paddingBottom: Spacing.sm,
    borderTopWidth: 1,
    borderTopColor: 'rgba(255,255,255,0.08)',
    gap: 2,
  },
  brand: { ...Typography.label, color: 'rgba(255,255,255,0.85)', letterSpacing: 2 },
  tagline: { ...Typography.caption, color: 'rgba(255,255,255,0.55)' },
  meta: { ...Typography.caption, color: 'rgba(255,255,255,0.35)', fontSize: 11, marginTop: 4 },
});
