import { Image } from 'expo-image';
import { LinearGradient } from 'expo-linear-gradient';
import { router } from 'expo-router';
import { StyleSheet, Text, View } from 'react-native';

import { BadgeChip } from './BadgeChip';
import { GradientButton } from './GradientButton';
import { SecondaryButton } from './SecondaryButton';
import { StatItem } from './StatItem';
import { UserAvatar } from './UserAvatar';
import { auraById } from '@/data/mock/auras';
import { badgeById } from '@/data/mock/badges';
import { Colors, Gradients, Radius, Spacing, Typography } from '@/theme';
import type { DemoUser } from '@/types';
import { formatJoinDate } from '@/utils/time';

type Props = {
  user: DemoUser;
  isOwnProfile: boolean;
  isFollowing?: boolean;
  onToggleFollow?: () => void;
  onMessage?: () => void;
  hideActions?: boolean;
};

export function ProfileHeader({ user, isOwnProfile, isFollowing, onToggleFollow, onMessage, hideActions }: Props) {
  const aura = auraById(user.aura);
  const xpToNext = 500 - (user.xp % 500);

  return (
    <View style={styles.wrap}>
      {user.coverUri ? (
        <Image source={{ uri: user.coverUri }} style={styles.banner} contentFit="cover" />
      ) : (
        <LinearGradient
          colors={Gradients[aura.gradient] as unknown as [string, string, ...string[]]}
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 1 }}
          style={styles.banner}
        />
      )}
      <View style={styles.content}>
        <View style={styles.avatarRow}>
          <UserAvatar
            name={user.displayName}
            avatarUri={user.avatarUri}
            gradient={user.avatarGradient}
            size={92}
            showOnline
            online={user.isOnline}
          />
          {hideActions ? null : isOwnProfile ? (
            <SecondaryButton label="Editar perfil" onPress={() => router.push('/edit-profile')} />
          ) : (
            <View style={styles.actionsRow}>
              <View style={styles.followButton}>
                <GradientButton
                  label={isFollowing ? 'Siguiendo' : 'Seguir'}
                  onPress={onToggleFollow ?? (() => {})}
                  gradient={isFollowing ? 'community' : 'fire'}
                  size="md"
                  fullWidth={false}
                />
              </View>
              <SecondaryButton label="Mensaje" onPress={onMessage ?? (() => {})} />
            </View>
          )}
        </View>

        <Text style={styles.name}>{user.displayName}</Text>
        <Text style={styles.status}>{user.statusText}</Text>

        <View style={styles.levelRow}>
          <Text style={styles.levelText}>Nivel {user.level}</Text>
          <View style={styles.xpBarTrack}>
            <View style={[styles.xpBarFill, { width: `${100 - (xpToNext / 500) * 100}%` }]} />
          </View>
        </View>

        <View style={styles.statsRow}>
          <StatItem value={user.reputation} label="Reputación" />
          <StatItem value={user.following} label="Siguiendo" />
          <StatItem value={user.followers} label="Seguidores" />
          <StatItem value={user.visitors} label="Visitantes" />
        </View>

        {!!user.bio && <Text style={styles.bio}>{user.bio}</Text>}
        <Text style={styles.joined}>Miembro desde {formatJoinDate(user.joinedAt)}</Text>

        {user.badges.length > 0 && (
          <View style={styles.badgesRow}>
            {user.badges.map((id) => {
              const badge = badgeById(id);
              return badge ? <BadgeChip key={id} badge={badge} compact /> : null;
            })}
          </View>
        )}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { marginBottom: Spacing.md },
  banner: { height: 96, borderTopLeftRadius: Radius.xl, borderTopRightRadius: Radius.xl },
  content: { paddingHorizontal: Spacing.xl, marginTop: -46, gap: 4 },
  avatarRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-end' },
  actionsRow: { flexDirection: 'row', gap: Spacing.xs },
  followButton: { minWidth: 120 },
  name: { ...Typography.h2, color: Colors.textPrimary, marginTop: Spacing.sm },
  status: { ...Typography.caption, color: Colors.textSecondary, marginTop: 2 },
  levelRow: { flexDirection: 'row', alignItems: 'center', gap: Spacing.sm, marginTop: Spacing.sm },
  levelText: { ...Typography.label, color: Colors.yellow },
  xpBarTrack: { flex: 1, height: 6, borderRadius: 3, backgroundColor: Colors.surfaceSecondary, overflow: 'hidden' },
  xpBarFill: { height: 6, backgroundColor: Colors.yellow },
  statsRow: { flexDirection: 'row', justifyContent: 'space-between', marginTop: Spacing.lg },
  bio: { ...Typography.body, color: Colors.textSecondary, marginTop: Spacing.md },
  joined: { ...Typography.caption, color: Colors.textMuted, marginTop: 4 },
  badgesRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 6, marginTop: Spacing.md },
});
