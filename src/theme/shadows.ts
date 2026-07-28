import { Platform } from 'react-native';

function shadow(color: string, elevation: number, opacity: number, radius: number) {
  return Platform.select({
    android: { elevation },
    default: {
      shadowColor: color,
      shadowOpacity: opacity,
      shadowRadius: radius,
      shadowOffset: { width: 0, height: Math.round(radius / 2) },
    },
  });
}

export const Shadows = {
  card: shadow('#000000', 6, 0.28, 14),
  elevated: shadow('#000000', 12, 0.36, 22),
  glow: (color: string) => shadow(color, 10, 0.45, 20),
};
