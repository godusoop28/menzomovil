import { Pressable, StyleSheet, Text, View } from 'react-native';

import { IconButton } from '@/components/IconButton';
import { MenzoLogo } from '@/components/MenzoLogo';
import { UserAvatar } from '@/components/UserAvatar';
import { Colors, Spacing, Typography } from '@/theme';
import type { UserProfile } from '@/types';

type Props = {
  profile: UserProfile | null;
  onPressProfile: () => void;
  onPressSearch: () => void;
};

export function DrawerProfileHeader({ profile, onPressProfile, onPressSearch }: Props) {
  const xpToNext = profile ? 500 - (profile.xp % 500) : 0;
  const progress = profile ? 100 - (xpToNext / 500) * 100 : 0;

  return (
    <View style={styles.wrap}>
      <View style={styles.topRow}>
        <MenzoLogo size={30} />
        <IconButton name="search" label="Buscar" onPress={onPressSearch} />
      </View>

      <Pressable
        style={styles.profileTouchable}
        accessibilityRole="button"
        accessibilityLabel="Ver mi perfil"
        onPress={onPressProfile}>
        {profile ? (
          <>
            <UserAvatar
              name={profile.displayName}
              avatarUri={profile.avatarUri}
              gradient={profile.avatarGradient}
              size={72}
              showOnline
              online={profile.isOnline}
            />
            <Text style={styles.name}>{profile.displayName}</Text>
            <Text style={styles.status}>{profile.statusText}</Text>
            <View style={styles.levelRow}>
              <Text style={styles.levelText}>Nivel {profile.level}</Text>
              <View style={styles.xpTrack}>
                <View style={[styles.xpFill, { width: `${progress}%` }]} />
              </View>
            </View>
          </>
        ) : (
          <View style={styles.skeletonWrap}>
            <View style={styles.skeletonAvatar} />
            <View style={styles.skeletonLine} />
          </View>
        )}
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { paddingHorizontal: Spacing.lg, paddingBottom: Spacing.lg, gap: Spacing.sm },
  topRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  profileTouchable: { alignItems: 'flex-start', gap: 2, marginTop: Spacing.sm },
  name: { ...Typography.h2, color: '#FFFFFF', marginTop: Spacing.sm },
  status: { ...Typography.caption, color: 'rgba(255,255,255,0.65)', marginBottom: 4 },
  levelRow: { flexDirection: 'row', alignItems: 'center', gap: Spacing.sm, marginTop: Spacing.xs, width: '100%' },
  levelText: { ...Typography.label, color: Colors.yellow },
  xpTrack: { flex: 1, height: 5, borderRadius: 3, backgroundColor: 'rgba(255,255,255,0.16)', overflow: 'hidden' },
  xpFill: { height: 5, backgroundColor: Colors.yellow },
  skeletonWrap: { width: '100%', alignItems: 'flex-start', gap: Spacing.sm },
  skeletonAvatar: { width: 72, height: 72, borderRadius: 36, backgroundColor: 'rgba(255,255,255,0.12)' },
  skeletonLine: { width: 120, height: 14, borderRadius: 7, backgroundColor: 'rgba(255,255,255,0.12)' },
});
