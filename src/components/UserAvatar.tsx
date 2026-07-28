import { LinearGradient } from 'expo-linear-gradient';
import { Image } from 'expo-image';
import { StyleSheet, Text, View } from 'react-native';

import { OnlineIndicator } from './OnlineIndicator';
import { Colors, Gradients, levelTier } from '@/theme';

type Props = {
  name: string;
  avatarUri?: string;
  gradient?: keyof typeof Gradients;
  size?: number;
  online?: boolean;
  showOnline?: boolean;
  level?: number;
};

export function UserAvatar({ name, avatarUri, gradient = 'fire', size = 48, online, showOnline, level }: Props) {
  const initial = name.trim().charAt(0).toUpperCase() || '?';
  const tier = level !== undefined ? levelTier(level) : null;
  const ringWidth = tier ? Math.max(2, Math.round(size * 0.07)) : 0;
  const photoSize = size - ringWidth * 2;

  return (
    <View style={{ width: size, height: size }}>
      {tier &&
        (tier.gradient ? (
          <LinearGradient
            colors={Gradients[tier.gradient] as unknown as [string, string, ...string[]]}
            start={{ x: 0, y: 0 }}
            end={{ x: 1, y: 1 }}
            style={[
              styles.ring,
              { width: size, height: size, borderRadius: size / 2 },
              tier.glow && { shadowColor: tier.color, shadowOpacity: 0.7, shadowRadius: 6, shadowOffset: { width: 0, height: 0 } },
            ]}
          />
        ) : (
          <View
            style={[
              styles.ring,
              { width: size, height: size, borderRadius: size / 2, backgroundColor: tier.color },
              tier.glow && { shadowColor: tier.color, shadowOpacity: 0.7, shadowRadius: 6, shadowOffset: { width: 0, height: 0 } },
            ]}
          />
        ))}
      <View
        style={[
          styles.wrap,
          {
            width: photoSize,
            height: photoSize,
            borderRadius: photoSize / 2,
            top: ringWidth,
            left: ringWidth,
          },
        ]}>
        {avatarUri ? (
          <Image source={{ uri: avatarUri }} style={StyleSheet.absoluteFill} contentFit="cover" />
        ) : (
          <LinearGradient
            colors={Gradients[gradient] as unknown as [string, string, ...string[]]}
            start={{ x: 0, y: 0 }}
            end={{ x: 1, y: 1 }}
            style={StyleSheet.absoluteFill}>
            <Text style={[styles.initial, { fontSize: photoSize * 0.4 }]}>{initial}</Text>
          </LinearGradient>
        )}
      </View>
      {showOnline && (
        <View style={[styles.indicatorWrap, { width: size * 0.32, height: size * 0.32 }]}>
          <OnlineIndicator online={!!online} size={size * 0.32} />
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  ring: { position: 'absolute', top: 0, left: 0 },
  wrap: { position: 'absolute', overflow: 'hidden', backgroundColor: Colors.surfaceElevated, alignItems: 'center', justifyContent: 'center' },
  initial: { color: '#FFFFFF', fontWeight: '700', textAlign: 'center' },
  indicatorWrap: { position: 'absolute', bottom: -1, right: -1 },
});
