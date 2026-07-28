import { LinearGradient } from 'expo-linear-gradient';
import type { ReactNode } from 'react';
import { ActivityIndicator, Pressable, StyleSheet, Text, View } from 'react-native';

import { useHaptics } from '@/hooks/useHaptics';
import { Colors, Gradients, Radius, Spacing, Typography, useAccent } from '@/theme';

type Props = {
  label: string;
  onPress: () => void;
  disabled?: boolean;
  loading?: boolean;
  gradient?: keyof typeof Gradients;
  icon?: ReactNode;
  fullWidth?: boolean;
  size?: 'md' | 'lg';
};

export function GradientButton({
  label,
  onPress,
  disabled,
  loading,
  gradient,
  icon,
  fullWidth = true,
  size = 'lg',
}: Props) {
  const { medium } = useHaptics();
  const accent = useAccent();
  const isDisabled = disabled || loading;
  const gradientColors = gradient ? Gradients[gradient] : accent.gradient;

  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={label}
      accessibilityState={{ disabled: isDisabled }}
      disabled={isDisabled}
      onPress={() => {
        medium();
        onPress();
      }}
      style={({ pressed }) => [
        fullWidth && styles.fullWidth,
        { opacity: isDisabled ? 0.45 : pressed ? 0.88 : 1 },
      ]}>
      <LinearGradient
        colors={gradientColors as unknown as [string, string, ...string[]]}
        start={{ x: 0, y: 0 }}
        end={{ x: 1, y: 1 }}
        style={[styles.base, size === 'md' && styles.md]}>
        {loading ? (
          <ActivityIndicator color={Colors.textOnAccent} />
        ) : (
          <View style={styles.content}>
            {icon}
            <Text style={styles.label}>{label}</Text>
          </View>
        )}
      </LinearGradient>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  fullWidth: { width: '100%' },
  base: {
    minHeight: 56,
    borderRadius: Radius.pill,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: Spacing.xl,
  },
  md: { minHeight: 48 },
  content: { flexDirection: 'row', alignItems: 'center', gap: Spacing.xs },
  label: { ...Typography.label, fontSize: 16, color: Colors.textOnAccent },
});
