export type EffectIntensity = 'suave' | 'normal' | 'alta';

export type AppSettings = {
  theme: 'medianoche' | 'amoled';
  effectIntensity: EffectIntensity;
  hapticsEnabled: boolean;
  animationsEnabled: boolean;
  showSimulatedActivity: boolean;
  confirmationsEnabled: boolean;
  showOnlineStatus: boolean;
  allowProfileVisits: boolean;
  showInterests: boolean;
};

export const defaultSettings: AppSettings = {
  theme: 'medianoche',
  effectIntensity: 'normal',
  hapticsEnabled: true,
  animationsEnabled: true,
  showSimulatedActivity: true,
  confirmationsEnabled: true,
  showOnlineStatus: true,
  allowProfileVisits: true,
  showInterests: true,
};
