import { router } from 'expo-router';
import { ScrollView, StyleSheet, Text, View } from 'react-native';

import { AuraCard } from '@/components/AuraCard';
import { GradientButton } from '@/components/GradientButton';
import { IconButton } from '@/components/IconButton';
import { ScreenContainer } from '@/components/ScreenContainer';
import { auras } from '@/data/mock/auras';
import { menzoAssets } from '@/constants/assets';
import { useOnboardingDraft } from '@/features/onboarding/OnboardingDraftContext';
import { Colors, Spacing, Typography } from '@/theme';

export default function OnboardingAura() {
  const { draft, setAura } = useOnboardingDraft();

  return (
    <ScreenContainer backgroundImage={menzoAssets.backgrounds.onboarding} backgroundImageOverlay={0.66}>
      <View style={styles.header}>
        <IconButton name="chevron-back" label="Volver" onPress={() => router.back()} />
      </View>
      <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
        <Text style={styles.title}>Elige tu aura</Text>
        <Text style={styles.subtitle}>El color que va a acompañar tu perfil por Menzo.</Text>

        <View style={styles.list}>
          {auras.map((aura) => (
            <AuraCard key={aura.id} aura={aura} selected={draft.aura === aura.id} onSelect={setAura} />
          ))}
        </View>
      </ScrollView>
      <View style={styles.footer}>
        <GradientButton label="Continuar" onPress={() => router.push('/onboarding/avatar')} />
      </View>
    </ScreenContainer>
  );
}

const styles = StyleSheet.create({
  header: { paddingHorizontal: Spacing.md, paddingTop: Spacing.xs },
  content: { paddingHorizontal: Spacing.xl, gap: Spacing.sm, paddingBottom: Spacing.xl },
  title: { ...Typography.h1, color: Colors.textPrimary, marginTop: Spacing.sm },
  subtitle: { ...Typography.body, color: Colors.textSecondary, marginBottom: Spacing.md },
  list: { gap: Spacing.md },
  footer: { paddingHorizontal: Spacing.xl, paddingBottom: Spacing.xl },
});
