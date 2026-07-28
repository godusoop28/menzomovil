import { Stack } from 'expo-router';

import { OnboardingDraftProvider } from '@/features/onboarding/OnboardingDraftContext';
import { Colors } from '@/theme';

export default function OnboardingLayout() {
  return (
    <OnboardingDraftProvider>
      <Stack
        screenOptions={{
          headerShown: false,
          contentStyle: { backgroundColor: Colors.background },
          animation: 'fade',
          gestureEnabled: true,
        }}
      />
    </OnboardingDraftProvider>
  );
}
