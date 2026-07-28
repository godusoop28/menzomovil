import { router } from 'expo-router';
import { Pressable, StyleSheet, Text, View } from 'react-native';

import { GradientButton } from '@/components/GradientButton';
import { MenzoLogo } from '@/components/MenzoLogo';
import { ScreenContainer } from '@/components/ScreenContainer';
import { menzoAssets } from '@/constants/assets';
import { Colors, Spacing, Typography } from '@/theme';

export default function OnboardingIntro() {
  return (
    <ScreenContainer backgroundImage={menzoAssets.backgrounds.onboarding} backgroundImageOverlay={0.4}>
      <View style={styles.content}>
        <MenzoLogo size={64} />
        <View style={styles.textWrap}>
          <Text style={styles.title}>Hay nombres que nunca se olvidan.</Text>
          <Text style={styles.subtitle}>
            Elige cómo quieres que tus antiguos amigos vuelvan a encontrarte.
          </Text>
        </View>
      </View>
      <View style={styles.footer}>
        <GradientButton
          label="Comenzar el reencuentro"
          onPress={() => router.push('/onboarding/account')}
        />
        <Pressable onPress={() => router.push('/login')} accessibilityRole="button" style={styles.loginLink}>
          <Text style={styles.loginLinkText}>¿Ya tienes cuenta? Inicia sesión</Text>
        </Pressable>
      </View>
    </ScreenContainer>
  );
}

const styles = StyleSheet.create({
  content: { flex: 1, justifyContent: 'center', paddingHorizontal: Spacing.xl, gap: Spacing.xl },
  textWrap: { gap: Spacing.sm },
  title: { ...Typography.display, fontSize: 34, color: Colors.textPrimary },
  subtitle: { ...Typography.body, color: Colors.textSecondary },
  footer: { paddingHorizontal: Spacing.xl, paddingBottom: Spacing.xl, gap: Spacing.md },
  loginLink: { alignItems: 'center' },
  loginLinkText: { ...Typography.label, color: Colors.cyan },
});
