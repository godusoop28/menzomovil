import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { Pressable, StyleSheet, Text, View } from 'react-native';

import { useHaptics } from '@/hooks/useHaptics';
import { Gradients, Radius, Spacing, Typography } from '@/theme';
import type { Aura } from '@/types';

type Props = {
  aura: Aura;
  selected: boolean;
  onSelect: (id: Aura['id']) => void;
};

export function AuraCard({ aura, selected, onSelect }: Props) {
  const { selection } = useHaptics();
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityState={{ selected }}
      accessibilityLabel={`Aura ${aura.name}`}
      onPress={() => {
        selection();
        onSelect(aura.id);
      }}
      style={({ pressed }) => [styles.card, { opacity: pressed ? 0.9 : 1 }]}>
      <LinearGradient
        colors={Gradients[aura.gradient] as unknown as [string, string, ...string[]]}
        start={{ x: 0, y: 0 }}
        end={{ x: 1, y: 1 }}
        style={[styles.gradient, selected && styles.gradientSelected]}>
        <View style={styles.textWrap}>
          <Text style={styles.name}>{aura.name}</Text>
          <Text style={styles.description}>{aura.description}</Text>
        </View>
        {selected && (
          <View style={styles.check}>
            <Ionicons name="checkmark-circle" size={26} color="#FFFFFF" />
          </View>
        )}
      </LinearGradient>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  card: { width: '100%' },
  gradient: {
    borderRadius: Radius.lg,
    padding: Spacing.lg,
    minHeight: 88,
    justifyContent: 'center',
    borderWidth: 2,
    borderColor: 'transparent',
  },
  gradientSelected: { borderColor: '#FFFFFF' },
  textWrap: { gap: 2 },
  name: { ...Typography.h3, color: '#FFFFFF' },
  description: { ...Typography.caption, color: 'rgba(255,255,255,0.85)' },
  check: { position: 'absolute', top: Spacing.md, right: Spacing.md },
});
