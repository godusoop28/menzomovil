import { router } from 'expo-router';
import { StyleSheet, Text, View } from 'react-native';

import { GradientButton } from '@/components/GradientButton';
import { IconButton } from '@/components/IconButton';
import { InterestChip } from '@/components/InterestChip';
import { ScreenContainer } from '@/components/ScreenContainer';
import { interests } from '@/data/mock/interests';
import { menzoAssets } from '@/constants/assets';
import { useOnboardingDraft } from '@/features/onboarding/OnboardingDraftContext';
import { Colors, Spacing, Typography } from '@/theme';

export default function OnboardingInterests() {
  const { draft, toggleInterest } = useOnboardingDraft();
  const canContinue = draft.interests.length >= 1;

  return (
    <ScreenContainer backgroundImage={menzoAssets.backgrounds.onboarding} backgroundImageOverlay={0.66}>
      <View style={styles.header}>
        <IconButton name="chevron-back" label="Volver" onPress={() => router.back()} />
      </View>
      <View style={styles.content}>
        <Text style={styles.title}>¿Qué te interesa?</Text>
        <Text style={styles.subtitle}>Elige entre 1 y 5 intereses.</Text>

        <View style={styles.grid}>
          {interests.map((interest) => (
            <InterestChip
              key={interest.id}
              interest={interest}
              selected={draft.interests.includes(interest.id)}
              onToggle={toggleInterest}
              disabled={draft.interests.length >= 5}
            />
          ))}
        </View>
      </View>
      <View style={styles.footer}>
        <GradientButton
          label="Continuar"
          onPress={() => router.push('/onboarding/confirm')}
          disabled={!canContinue}
        />
      </View>
    </ScreenContainer>
  );
}

const styles = StyleSheet.create({
  header: { paddingHorizontal: Spacing.md, paddingTop: Spacing.xs },
  content: { flex: 1, paddingHorizontal: Spacing.xl, gap: Spacing.md },
  title: { ...Typography.h1, color: Colors.textPrimary, marginTop: Spacing.sm },
  subtitle: { ...Typography.body, color: Colors.textSecondary },
  grid: { flexDirection: 'row', flexWrap: 'wrap', gap: Spacing.sm, marginTop: Spacing.md },
  footer: { paddingHorizontal: Spacing.xl, paddingBottom: Spacing.xl },
});
