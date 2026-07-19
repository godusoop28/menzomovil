import { createContext, useContext, useMemo, useState } from 'react';

import { auraById } from '@/data/mock/auras';
import type { GradientId } from '@/theme';
import type { AuraId, InterestId } from '@/types';

type OnboardingDraft = {
  email: string;
  password: string;
  displayName: string;
  aura: AuraId;
  avatarUri?: string;
  avatarGradient: GradientId;
  interests: InterestId[];
};

type OnboardingDraftContextValue = {
  draft: OnboardingDraft;
  setEmail: (value: string) => void;
  setPassword: (value: string) => void;
  setDisplayName: (value: string) => void;
  setAura: (id: AuraId) => void;
  setAvatarUri: (uri: string | undefined) => void;
  toggleInterest: (id: InterestId) => void;
};

const initialDraft: OnboardingDraft = {
  email: '',
  password: '',
  displayName: '',
  aura: 'fuego',
  avatarUri: undefined,
  avatarGradient: 'fire',
  interests: [],
};

const OnboardingDraftContext = createContext<OnboardingDraftContextValue | null>(null);

export function OnboardingDraftProvider({ children }: { children: React.ReactNode }) {
  const [draft, setDraft] = useState<OnboardingDraft>(initialDraft);

  const value = useMemo<OnboardingDraftContextValue>(
    () => ({
      draft,
      setEmail: (value) => setDraft((d) => ({ ...d, email: value })),
      setPassword: (value) => setDraft((d) => ({ ...d, password: value })),
      setDisplayName: (value) => setDraft((d) => ({ ...d, displayName: value })),
      setAura: (id) => setDraft((d) => ({ ...d, aura: id, avatarGradient: auraById(id).gradient })),
      setAvatarUri: (uri) => setDraft((d) => ({ ...d, avatarUri: uri })),
      toggleInterest: (id) =>
        setDraft((d) => {
          const has = d.interests.includes(id);
          if (has) return { ...d, interests: d.interests.filter((i) => i !== id) };
          if (d.interests.length >= 5) return d;
          return { ...d, interests: [...d.interests, id] };
        }),
    }),
    [draft]
  );

  return <OnboardingDraftContext.Provider value={value}>{children}</OnboardingDraftContext.Provider>;
}

export function useOnboardingDraft() {
  const ctx = useContext(OnboardingDraftContext);
  if (!ctx) throw new Error('useOnboardingDraft must be used within OnboardingDraftProvider');
  return ctx;
}
