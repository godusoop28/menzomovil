import { Platform } from 'react-native';

export const FontFamily = {
  display: Platform.select({ ios: 'SpaceGrotesk_700Bold', android: 'SpaceGrotesk_700Bold', default: 'System' }),
  displayBlack: Platform.select({ ios: 'SpaceGrotesk_700Bold', android: 'SpaceGrotesk_700Bold', default: 'System' }),
  heading: Platform.select({ ios: 'SpaceGrotesk_600SemiBold', android: 'SpaceGrotesk_600SemiBold', default: 'System' }),
  body: Platform.select({ ios: 'Inter_400Regular', android: 'Inter_400Regular', default: 'System' }),
  bodyMedium: Platform.select({ ios: 'Inter_500Medium', android: 'Inter_500Medium', default: 'System' }),
  bodySemiBold: Platform.select({ ios: 'Inter_600SemiBold', android: 'Inter_600SemiBold', default: 'System' }),
  label: Platform.select({ ios: 'Inter_600SemiBold', android: 'Inter_600SemiBold', default: 'System' }),
};

export const Typography = {
  display: { fontFamily: FontFamily.displayBlack, fontSize: 38, lineHeight: 44, fontWeight: '800' as const },
  h1: { fontFamily: FontFamily.display, fontSize: 30, lineHeight: 36, fontWeight: '700' as const },
  h2: { fontFamily: FontFamily.heading, fontSize: 24, lineHeight: 30, fontWeight: '700' as const },
  h3: { fontFamily: FontFamily.heading, fontSize: 19, lineHeight: 25, fontWeight: '600' as const },
  body: { fontFamily: FontFamily.body, fontSize: 16, lineHeight: 23, fontWeight: '400' as const },
  bodyMedium: { fontFamily: FontFamily.bodyMedium, fontSize: 16, lineHeight: 23, fontWeight: '500' as const },
  caption: { fontFamily: FontFamily.body, fontSize: 13, lineHeight: 18, fontWeight: '400' as const },
  label: { fontFamily: FontFamily.label, fontSize: 14, lineHeight: 18, fontWeight: '600' as const },
};

export const FontsToLoad = {
  SpaceGrotesk_600SemiBold: 'SpaceGrotesk_600SemiBold',
  SpaceGrotesk_700Bold: 'SpaceGrotesk_700Bold',
  Inter_400Regular: 'Inter_400Regular',
  Inter_500Medium: 'Inter_500Medium',
  Inter_600SemiBold: 'Inter_600SemiBold',
};
