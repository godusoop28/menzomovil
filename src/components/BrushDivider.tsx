import { LinearGradient } from 'expo-linear-gradient';
import { StyleSheet, View } from 'react-native';

import { Gradients, Spacing } from '@/theme';

export function BrushDivider({ gradient = 'fire' as keyof typeof Gradients }: { gradient?: keyof typeof Gradients }) {
  return (
    <View style={styles.wrap}>
      <LinearGradient
        colors={Gradients[gradient] as unknown as [string, string, ...string[]]}
        start={{ x: 0, y: 0.5 }}
        end={{ x: 1, y: 0.5 }}
        style={styles.line}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { paddingVertical: Spacing.sm },
  line: { height: 3, borderRadius: 2, width: 56, opacity: 0.7 },
});
