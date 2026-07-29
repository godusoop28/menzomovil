import { LinearGradient } from 'expo-linear-gradient';
import { router } from 'expo-router';
import { useState } from 'react';
import { ScrollView, StyleSheet, Text, View } from 'react-native';

import { BadgeChip } from '@/components/BadgeChip';
import { GradientButton } from '@/components/GradientButton';
import { InterestChip } from '@/components/InterestChip';
import { ScreenContainer } from '@/components/ScreenContainer';
import { UserAvatar } from '@/components/UserAvatar';
import { auraById } from '@/data/mock/auras';
import { badgeById } from '@/data/mock/badges';
import { interestById } from '@/data/mock/interests';
import { useOnboardingDraft } from '@/features/onboarding/OnboardingDraftContext';
import { useHaptics } from '@/hooks/useHaptics';
import { useToast } from '@/hooks/useToast';
import { ApiError } from '@/services/api';
import { useAppState } from '@/store/AppStateContext';
import { Colors, Gradients, Radius, Spacing, Typography } from '@/theme';

const newcomerBadge = badgeById('recien-llegado')!;

export default function OnboardingConfirm() {
  const { draft } = useOnboardingDraft();
  const { actions } = useAppState();
  const { success } = useHaptics();
  const showToast = useToast();
  const [submitting, setSubmitting] = useState(false);
  const aura = auraById(draft.aura);

  async function handleEnter() {
    if (submitting) return;
    setSubmitting(true);
    try {
      await actions.completeOnboarding({
        displayName: draft.displayName,
        aura: draft.aura,
        avatarUri: draft.avatarUri,
        avatarGradient: draft.avatarGradient,
        interests: draft.interests,
      });
      success();
      router.replace('/(tabs)');
    } catch (e) {
      const message =
        e instanceof ApiError ? e.message : 'No pudimos completar tu perfil. Inténtalo de nuevo.';
      showToast(message);
      setSubmitting(false);
    }
  }

  return (
    <ScreenContainer>
      <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
        <Text style={styles.title}>Tu perfil está listo.</Text>
        <Text style={styles.subtitle}>Bienvenido a Menzo, {draft.displayName}.</Text>

        <LinearGradient
          colors={Gradients[aura.gradient] as unknown as [string, string, ...string[]]}
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 1 }}
          style={styles.card}>
          <View style={styles.cardOverlay}>
            <UserAvatar
              name={draft.displayName}
              avatarUri={draft.avatarUri}
              gradient={draft.avatarGradient}
              size={96}
              showOnline
              online
            />
            <Text style={styles.cardName}>{draft.displayName}</Text>
            <Text style={styles.cardStatus}>Nuevo en Menzo · Aura {aura.name}</Text>
            <BadgeChip badge={newcomerBadge} />
          </View>
        </LinearGradient>

        <View style={styles.interestsWrap}>
          <Text style={styles.sectionLabel}>Intereses</Text>
          <View style={styles.chipsRow}>
            {draft.interests.map((id) => {
              const interest = interestById(id);
              if (!interest) return null;
              return (
                <InterestChip
                  key={id}
                  interest={interest}
                  selected
                  onToggle={() => {}}
                  disabled
                />
              );
            })}
          </View>
        </View>
      </ScrollView>
      <View style={styles.footer}>
        <GradientButton label="Entrar a Menzo" onPress={handleEnter} loading={submitting} />
      </View>
    </ScreenContainer>
  );
}

const styles = StyleSheet.create({
  content: { paddingHorizontal: Spacing.xl, paddingTop: Spacing.xxl, gap: Spacing.lg, paddingBottom: Spacing.xl },
  title: { ...Typography.display, fontSize: 32, color: Colors.textPrimary },
  subtitle: { ...Typography.body, color: Colors.textSecondary },
  card: { borderRadius: Radius.xl, padding: 2 },
  cardOverlay: {
    borderRadius: Radius.xl - 2,
    backgroundColor: 'rgba(3,5,9,0.32)',
    alignItems: 'center',
    padding: Spacing.xxl,
    gap: 6,
  },
  cardName: { ...Typography.h2, color: '#FFFFFF', marginTop: Spacing.sm },
  cardStatus: { ...Typography.caption, color: 'rgba(255,255,255,0.75)', marginBottom: Spacing.sm },
  interestsWrap: { gap: Spacing.sm },
  sectionLabel: { ...Typography.label, color: Colors.textMuted, textTransform: 'uppercase', letterSpacing: 0.5 },
  chipsRow: { flexDirection: 'row', flexWrap: 'wrap', gap: Spacing.sm },
  footer: { paddingHorizontal: Spacing.xl, paddingBottom: Spacing.xl },
});
