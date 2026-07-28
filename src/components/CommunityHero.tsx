import { router } from 'expo-router';
import { StyleSheet, Text, View } from 'react-native';

import { MenzoImageBackground } from './common/MenzoImageBackground';
import { SecondaryButton } from './SecondaryButton';
import { UserAvatar } from './UserAvatar';
import { communityConfig } from '@/config/community';
import { menzoAssets } from '@/constants/assets';
import { Colors, Radius, Spacing, Typography } from '@/theme';
import type { DemoUser } from '@/types';

type Props = { previewMembers: DemoUser[] };

export function CommunityHero({ previewMembers }: Props) {
  return (
    <View style={styles.wrap}>
      <MenzoImageBackground
        source={menzoAssets.banners.community}
        style={StyleSheet.absoluteFill}
        overlayOpacity={0.42}
      />
      <View style={styles.content}>
        <Text style={styles.name}>{communityConfig.name}</Text>
        <Text style={styles.subtitle}>{communityConfig.subtitle}</Text>
        <Text style={styles.description}>{communityConfig.description}</Text>

        <View style={styles.metaRow}>
          <Text style={styles.metaText}>
            {communityConfig.memberCount.toLocaleString('es-ES')} miembros
          </Text>
          <View style={styles.dot} />
          <Text style={styles.metaText}>{communityConfig.onlineCount} conectados</Text>
        </View>

        <View style={styles.footerRow}>
          <View style={styles.avatarStack}>
            {previewMembers.slice(0, 4).map((member, index) => (
              <View key={member.id} style={[styles.avatarOverlap, { left: index * 20 }]}>
                <UserAvatar name={member.displayName} gradient={member.avatarGradient} size={34} />
              </View>
            ))}
          </View>
          <SecondaryButton label="Ver comunidad" onPress={() => router.push('/about')} />
        </View>

        <View style={styles.tagsRow}>
          {communityConfig.tags.map((tag) => (
            <View key={tag} style={styles.tag}>
              <Text style={styles.tagText}>{tag}</Text>
            </View>
          ))}
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { borderRadius: Radius.xl, overflow: 'hidden', minHeight: 260 },
  content: { padding: Spacing.xl, gap: 6 },
  name: { ...Typography.h1, color: '#FFFFFF' },
  subtitle: { ...Typography.bodyMedium, color: 'rgba(255,255,255,0.85)' },
  description: { ...Typography.body, color: 'rgba(255,255,255,0.8)', marginTop: 4 },
  metaRow: { flexDirection: 'row', alignItems: 'center', gap: 8, marginTop: Spacing.sm },
  metaText: { ...Typography.caption, color: 'rgba(255,255,255,0.85)' },
  dot: { width: 4, height: 4, borderRadius: 2, backgroundColor: 'rgba(255,255,255,0.6)' },
  footerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginTop: Spacing.lg,
  },
  avatarStack: { flexDirection: 'row', width: 100, height: 34 },
  avatarOverlap: { position: 'absolute', borderRadius: 20, borderWidth: 2, borderColor: Colors.background },
  tagsRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginTop: Spacing.lg },
  tag: { paddingVertical: 5, paddingHorizontal: 10, borderRadius: Radius.pill, backgroundColor: 'rgba(255,255,255,0.14)' },
  tagText: { ...Typography.caption, color: '#FFFFFF', fontWeight: '600' },
});
