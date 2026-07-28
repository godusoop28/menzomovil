import type { ReactNode } from 'react';
import { StyleSheet, View, type ImageSourcePropType, type StyleProp, type ViewStyle } from 'react-native';
import { SafeAreaView, type Edge } from 'react-native-safe-area-context';

import { MenzoImageBackground } from '@/components/common/MenzoImageBackground';
import { Colors } from '@/theme';

type Props = {
  children: ReactNode;
  style?: StyleProp<ViewStyle>;
  edges?: Edge[];
  background?: string;
  backgroundImage?: ImageSourcePropType;
  backgroundImageOverlay?: number;
};

export function ScreenContainer({
  children,
  style,
  edges = ['top', 'bottom'],
  background,
  backgroundImage,
  backgroundImageOverlay,
}: Props) {
  if (backgroundImage) {
    return (
      <MenzoImageBackground source={backgroundImage} overlayOpacity={backgroundImageOverlay} style={styles.root}>
        <SafeAreaView edges={edges} style={[styles.safeArea, style]}>
          {children}
        </SafeAreaView>
      </MenzoImageBackground>
    );
  }

  return (
    <View style={[styles.root, { backgroundColor: background ?? Colors.background }]}>
      <SafeAreaView edges={edges} style={[styles.safeArea, style]}>
        {children}
      </SafeAreaView>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1 },
  safeArea: { flex: 1 },
});
