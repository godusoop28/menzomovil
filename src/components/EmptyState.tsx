import { Ionicons } from '@expo/vector-icons';
import { Image } from 'expo-image';
import { StyleSheet, Text, View, type ImageSourcePropType } from 'react-native';

import { AbstractArtwork } from './AbstractArtwork';
import { Colors, Radius, Spacing, Typography } from '@/theme';
import type { AbstractVisualPreset } from '@/types';

type Props = {
  icon?: keyof typeof Ionicons.glyphMap;
  title: string;
  description?: string;
  preset?: AbstractVisualPreset;
  image?: ImageSourcePropType;
};

export function EmptyState({ icon = 'sparkles-outline', title, description, preset = 'memory', image }: Props) {
  return (
    <View style={styles.wrap}>
      {image ? (
        <Image source={image} style={styles.image} contentFit="contain" />
      ) : (
        <>
          <AbstractArtwork preset={preset} style={styles.art} dim />
          <View style={styles.iconWrap}>
            <Ionicons name={icon} size={26} color={Colors.textSecondary} />
          </View>
        </>
      )}
      <Text style={styles.title}>{title}</Text>
      {!!description && <Text style={styles.description}>{description}</Text>}
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { alignItems: 'center', justifyContent: 'center', paddingVertical: Spacing.xxl, paddingHorizontal: Spacing.xl, gap: Spacing.sm },
  art: { position: 'absolute', top: 0, left: 0, right: 0, height: 120, borderRadius: 0, opacity: 0.5 },
  image: { width: 140, height: 140, borderRadius: Radius.lg, marginBottom: Spacing.sm },
  iconWrap: {
    width: 52,
    height: 52,
    borderRadius: 26,
    backgroundColor: Colors.surfaceElevated,
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: Spacing.xxl,
    borderWidth: 1,
    borderColor: Colors.borderSoft,
  },
  title: { ...Typography.h3, color: Colors.textPrimary, textAlign: 'center' },
  description: { ...Typography.body, color: Colors.textMuted, textAlign: 'center' },
});
