export const Colors = {
  background: '#07090D',
  backgroundDeep: '#030509',
  surface: '#11141B',
  surfaceSecondary: '#171B24',
  surfaceElevated: '#1E2330',
  surfaceSoft: '#242A36',

  border: '#292F3D',
  borderSoft: 'rgba(255,255,255,0.08)',
  borderStrong: 'rgba(255,255,255,0.16)',

  textPrimary: '#F7F8FC',
  textSecondary: '#B3BAC8',
  textMuted: '#767F91',
  textOnAccent: '#090A0E',

  orange: '#FF7A1A',
  yellow: '#FFBE2E',
  coral: '#FF4F45',
  red: '#F43F5E',
  blue: '#3478F6',
  cyan: '#22D3EE',
  purple: '#8B5CF6',
  violet: '#A855F7',
  green: '#68D391',

  success: '#4ADE80',
  warning: '#FBBF24',
  danger: '#FB7185',
  online: '#4ADE80',
  offline: '#6B7280',
} as const;

export const AmoledColors = {
  ...Colors,
  background: '#000000',
  backgroundDeep: '#000000',
  surface: '#0A0A0C',
  surfaceSecondary: '#0F0F13',
  surfaceElevated: '#15151A',
  surfaceSoft: '#1A1A21',
};

export type ColorTheme = typeof Colors;

export const Gradients = {
  fire: ['#FFBE2E', '#FF7A1A', '#FF4F45'] as const,
  connection: ['#3478F6', '#22D3EE'] as const,
  midnight: ['#8B5CF6', '#3478F6', '#22D3EE'] as const,
  creative: ['#FF4F45', '#A855F7', '#3478F6'] as const,
  community: ['#68D391', '#22D3EE', '#3478F6'] as const,
};

export type GradientId = keyof typeof Gradients;

export type LevelTier = {
  color: string;
  gradient?: GradientId;
  glow?: boolean;
};

export function levelTier(level: number): LevelTier {
  if (level >= 30) return { color: Colors.yellow, gradient: 'fire', glow: true };
  if (level >= 20) return { color: Colors.orange, gradient: 'fire' };
  if (level >= 10) return { color: Colors.purple, gradient: 'midnight' };
  if (level >= 5) return { color: Colors.cyan };
  return { color: Colors.borderStrong };
}
