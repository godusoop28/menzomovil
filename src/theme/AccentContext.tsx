import { createContext, useContext, useMemo } from 'react';

import { auraById } from '@/data/mock/auras';
import { useAppState } from '@/store/AppStateContext';

import { Gradients, type GradientId } from './colors';

type AccentContextValue = {
  color: string;
  gradient: (typeof Gradients)[GradientId];
  gradientId: GradientId;
};

const DEFAULT_GRADIENT_ID: GradientId = 'fire';

const AccentContext = createContext<AccentContextValue | null>(null);

export function AccentProvider({ children }: { children: React.ReactNode }) {
  const { state } = useAppState();
  const auraId = state.profile?.aura;

  const value = useMemo<AccentContextValue>(() => {
    const gradientId = auraId ? auraById(auraId).gradient : DEFAULT_GRADIENT_ID;
    const gradient = Gradients[gradientId];
    return { color: gradient[0], gradient, gradientId };
  }, [auraId]);

  return <AccentContext.Provider value={value}>{children}</AccentContext.Provider>;
}

export function useAccent() {
  const ctx = useContext(AccentContext);
  if (!ctx) throw new Error('useAccent must be used within an AccentProvider');
  return ctx;
}
