import { router } from 'expo-router';
import { useState } from 'react';
import { KeyboardAvoidingView, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';

import { GradientButton } from '@/components/GradientButton';
import { IconButton } from '@/components/IconButton';
import { ScreenContainer } from '@/components/ScreenContainer';
import { menzoAssets } from '@/constants/assets';
import { useOnboardingDraft } from '@/features/onboarding/OnboardingDraftContext';
import { useAppState } from '@/hooks/useAppState';
import { useHaptics } from '@/hooks/useHaptics';
import { useKeyboardBehavior } from '@/hooks/useKeyboardOffset';
import { ApiError } from '@/services/api';
import { Colors, Spacing, Typography } from '@/theme';

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export default function OnboardingAccount() {
  const { draft, setEmail, setPassword } = useOnboardingDraft();
  const { actions } = useAppState();
  const { success } = useHaptics();
  const behavior = useKeyboardBehavior();

  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const emailValid = EMAIL_PATTERN.test(draft.email.trim());
  const passwordValid = draft.password.length >= 8;
  const valid = emailValid && passwordValid;

  async function handleContinue() {
    if (!valid || submitting) return;
    setSubmitting(true);
    setError(null);
    try {
      await actions.register(draft.email.trim().toLowerCase(), draft.password);
      success();
      router.push('/onboarding/name');
    } catch (e) {
      if (e instanceof ApiError && e.status === 409) {
        setError('Ese correo ya tiene una cuenta. Inicia sesión en su lugar.');
      } else if (e instanceof ApiError) {
        setError(e.message);
      } else {
        setError('No pudimos conectar con Menzo. Revisa tu conexión e inténtalo de nuevo.');
      }
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <ScreenContainer backgroundImage={menzoAssets.backgrounds.onboarding} backgroundImageOverlay={0.66}>
      <View style={styles.header}>
        <IconButton name="chevron-back" label="Volver" onPress={() => router.back()} />
      </View>
      <KeyboardAvoidingView behavior={behavior} style={styles.flex}>
        <View style={styles.content}>
          <Text style={styles.title}>Crea tu cuenta</Text>
          <Text style={styles.subtitle}>La necesitas para guardar tu perfil y volver a entrar después.</Text>

          <View style={styles.fieldWrap}>
            <Text style={styles.label}>Correo</Text>
            <TextInput
              value={draft.email}
              onChangeText={setEmail}
              placeholder="tu@correo.com"
              placeholderTextColor={Colors.textMuted}
              style={styles.input}
              keyboardType="email-address"
              autoCapitalize="none"
              autoCorrect={false}
              accessibilityLabel="Correo electrónico"
            />
          </View>

          <View style={styles.fieldWrap}>
            <Text style={styles.label}>Contraseña</Text>
            <TextInput
              value={draft.password}
              onChangeText={setPassword}
              placeholder="Mínimo 8 caracteres"
              placeholderTextColor={Colors.textMuted}
              style={styles.input}
              secureTextEntry
              accessibilityLabel="Contraseña"
            />
          </View>

          {!!error && <Text style={styles.error}>{error}</Text>}

          <Pressable onPress={() => router.push('/login')} accessibilityRole="button">
            <Text style={styles.loginLink}>¿Ya tienes cuenta? Inicia sesión</Text>
          </Pressable>
        </View>

        <View style={styles.footer}>
          <GradientButton label="Continuar" onPress={handleContinue} disabled={!valid} loading={submitting} />
        </View>
      </KeyboardAvoidingView>
    </ScreenContainer>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  header: { paddingHorizontal: Spacing.md, paddingTop: Spacing.xs },
  content: { flex: 1, paddingHorizontal: Spacing.xl, paddingTop: Spacing.md, gap: Spacing.md },
  title: { ...Typography.h1, color: Colors.textPrimary },
  subtitle: { ...Typography.body, color: Colors.textSecondary },
  fieldWrap: { gap: 6, marginTop: Spacing.sm },
  label: { ...Typography.label, color: Colors.textMuted },
  input: {
    ...Typography.body,
    color: Colors.textPrimary,
    backgroundColor: Colors.surfaceSecondary,
    borderRadius: 14,
    borderWidth: 1,
    borderColor: Colors.borderSoft,
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
  },
  error: { ...Typography.caption, color: Colors.coral, marginTop: Spacing.xs },
  loginLink: { ...Typography.label, color: Colors.cyan, marginTop: Spacing.md },
  footer: { paddingHorizontal: Spacing.xl, paddingBottom: Spacing.xl },
});
