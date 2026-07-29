import { router } from 'expo-router';
import { useState } from 'react';
import { KeyboardAvoidingView, StyleSheet, Text, TextInput, View } from 'react-native';

import { BadgeChip } from '@/components/BadgeChip';
import { GradientButton } from '@/components/GradientButton';
import { ScreenContainer } from '@/components/ScreenContainer';
import { UserAvatar } from '@/components/UserAvatar';
import { badgeById } from '@/data/mock/badges';
import { menzoAssets } from '@/constants/assets';
import { useOnboardingDraft } from '@/features/onboarding/OnboardingDraftContext';
import { useHaptics } from '@/hooks/useHaptics';
import { useKeyboardBehavior } from '@/hooks/useKeyboardOffset';
import { Colors, Radius, Spacing, Typography } from '@/theme';
import { NAME_MAX, NAME_MIN, collapseSpaces, isValidDisplayName } from '@/utils/validation';

const founderBadge = badgeById('fundador')!;

export default function OnboardingName() {
  const { draft, setDisplayName } = useOnboardingDraft();
  const { success } = useHaptics();
  const [localName, setLocalName] = useState(draft.displayName);
  const behavior = useKeyboardBehavior();

  const trimmed = collapseSpaces(localName).trim();
  const valid = isValidDisplayName(localName);

  function handleContinue() {
    if (!valid) return;
    success();
    setDisplayName(trimmed);
    router.push('/onboarding/aura');
  }

  return (
    <ScreenContainer backgroundImage={menzoAssets.backgrounds.onboarding} backgroundImageOverlay={0.66}>
      <KeyboardAvoidingView behavior={behavior} style={styles.flex}>
        <View style={styles.content}>
          <Text style={styles.title}>¿Cómo quieres que te conozcan?</Text>
          <Text style={styles.subtitle}>
            Puede ser tu apodo de siempre, tu nombre actual o una identidad completamente nueva.
          </Text>

          <View style={styles.fieldWrap}>
            <TextInput
              value={localName}
              onChangeText={(text) => setLocalName(text.slice(0, NAME_MAX))}
              placeholder="Tu nombre visible"
              placeholderTextColor={Colors.textMuted}
              style={styles.input}
              maxLength={NAME_MAX}
              accessibilityLabel="Nombre visible"
              autoFocus
            />
            <Text style={styles.counter}>
              {trimmed.length}/{NAME_MAX}
            </Text>
          </View>
          {localName.length > 0 && !valid && (
            <Text style={styles.hint}>Usa entre {NAME_MIN} y {NAME_MAX} caracteres.</Text>
          )}

          {trimmed.length >= NAME_MIN && (
            <View style={styles.preview}>
              <UserAvatar name={trimmed} gradient="fire" size={64} />
              <View style={styles.previewText}>
                <Text style={styles.previewName}>{trimmed}</Text>
                <Text style={styles.previewStatus}>Nuevo en Menzo</Text>
                <View style={styles.badgeRow}>
                  <BadgeChip badge={founderBadge} compact />
                </View>
              </View>
            </View>
          )}
        </View>

        <View style={styles.footer}>
          <GradientButton label="Ese soy yo" onPress={handleContinue} disabled={!valid} />
        </View>
      </KeyboardAvoidingView>
    </ScreenContainer>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  content: { flex: 1, paddingHorizontal: Spacing.xl, paddingTop: Spacing.xxl, gap: Spacing.md },
  title: { ...Typography.h1, color: Colors.textPrimary },
  subtitle: { ...Typography.body, color: Colors.textSecondary },
  fieldWrap: { marginTop: Spacing.lg },
  input: {
    ...Typography.h2,
    color: Colors.textPrimary,
    borderBottomWidth: 2,
    borderBottomColor: Colors.borderStrong,
    paddingVertical: Spacing.sm,
  },
  counter: { ...Typography.caption, color: Colors.textMuted, textAlign: 'right', marginTop: 4 },
  hint: { ...Typography.caption, color: Colors.coral },
  preview: {
    flexDirection: 'row',
    gap: Spacing.md,
    backgroundColor: Colors.surfaceSecondary,
    borderRadius: Radius.lg,
    borderWidth: 1,
    borderColor: Colors.borderSoft,
    padding: Spacing.lg,
    marginTop: Spacing.lg,
    alignItems: 'center',
  },
  previewText: { flex: 1, gap: 3 },
  previewName: { ...Typography.h3, color: Colors.textPrimary },
  previewStatus: { ...Typography.caption, color: Colors.textMuted },
  badgeRow: { flexDirection: 'row', marginTop: 4 },
  footer: { paddingHorizontal: Spacing.xl, paddingBottom: Spacing.xl },
});
