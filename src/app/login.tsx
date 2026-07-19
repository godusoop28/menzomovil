import { router } from 'expo-router';
import { useState } from 'react';
import { KeyboardAvoidingView, StyleSheet, Text, TextInput, View } from 'react-native';

import { GradientButton } from '@/components/GradientButton';
import { IconButton } from '@/components/IconButton';
import { MenzoLogo } from '@/components/MenzoLogo';
import { ScreenContainer } from '@/components/ScreenContainer';
import { useAppState } from '@/hooks/useAppState';
import { useHaptics } from '@/hooks/useHaptics';
import { useKeyboardBehavior } from '@/hooks/useKeyboardOffset';
import { ApiError } from '@/services/api';
import { Colors, Spacing, Typography } from '@/theme';

export default function LoginScreen() {
  const { actions } = useAppState();
  const { success } = useHaptics();
  const behavior = useKeyboardBehavior();

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const valid = email.trim().length > 3 && password.length > 0;

  async function handleLogin() {
    if (!valid || submitting) return;
    setSubmitting(true);
    setError(null);
    try {
      const onboardingCompleted = await actions.login(email.trim().toLowerCase(), password);
      success();
      // Si el perfil no está completo, va directo a poner su nombre: ya tiene
      // cuenta, no debe pasar por la pantalla de "crear cuenta" del onboarding.
      router.replace(onboardingCompleted ? '/(tabs)' : '/onboarding/name');
    } catch (e) {
      if (e instanceof ApiError && e.status === 401) {
        setError('Correo o contraseña incorrectos.');
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
    <ScreenContainer>
      <View style={styles.header}>
        <IconButton name="chevron-back" label="Volver" onPress={() => router.back()} />
      </View>
      <KeyboardAvoidingView behavior={behavior} style={styles.flex}>
        <View style={styles.content}>
          <MenzoLogo size={56} />
          <Text style={styles.title}>Bienvenido de vuelta</Text>
          <Text style={styles.subtitle}>Inicia sesión con la cuenta que ya creaste en Menzo.</Text>

          <View style={styles.fieldWrap}>
            <Text style={styles.label}>Correo</Text>
            <TextInput
              value={email}
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
              value={password}
              onChangeText={setPassword}
              placeholder="Tu contraseña"
              placeholderTextColor={Colors.textMuted}
              style={styles.input}
              secureTextEntry
              accessibilityLabel="Contraseña"
            />
          </View>

          {!!error && <Text style={styles.error}>{error}</Text>}
        </View>

        <View style={styles.footer}>
          <GradientButton label="Iniciar sesión" onPress={handleLogin} disabled={!valid} loading={submitting} />
        </View>
      </KeyboardAvoidingView>
    </ScreenContainer>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  header: { paddingHorizontal: Spacing.md, paddingTop: Spacing.xs },
  content: { flex: 1, paddingHorizontal: Spacing.xl, paddingTop: Spacing.md, gap: Spacing.md },
  title: { ...Typography.h1, color: Colors.textPrimary, marginTop: Spacing.md },
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
  footer: { paddingHorizontal: Spacing.xl, paddingBottom: Spacing.xl },
});
