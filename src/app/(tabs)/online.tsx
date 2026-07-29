import { useCallback, useMemo, useState } from 'react';
import { RefreshControl, ScrollView, StyleSheet, Text, View } from 'react-native';

import { AppHeader } from '@/components/AppHeader';
import { EmptyState } from '@/components/EmptyState';
import { InterestChip } from '@/components/InterestChip';
import { MemberCard } from '@/components/MemberCard';
import { ScreenContainer } from '@/components/ScreenContainer';
import { UserAvatar } from '@/components/UserAvatar';
import { MenzoImageBackground } from '@/components/common/MenzoImageBackground';
import { MenzoDrawerContent } from '@/components/navigation/MenzoDrawerContent';
import { menzoAssets } from '@/constants/assets';
import { interests } from '@/data/mock/interests';
import { useAppState } from '@/hooks/useAppState';
import { useMenzoDrawer } from '@/hooks/useMenzoDrawer';
import { onlineUsers } from '@/store/selectors';
import { BottomTabBarHeight, Colors, Radius, Spacing, Typography } from '@/theme';
import type { InterestId } from '@/types';

export default function OnlineScreen() {
  const { state, actions } = useAppState();
  const drawer = useMenzoDrawer();
  const [filter, setFilter] = useState<InterestId | null>(null);
  const [refreshing, setRefreshing] = useState(false);

  const onRefresh = useCallback(async () => {
    setRefreshing(true);
    await actions.refreshSocial();
    setRefreshing(false);
  }, [actions]);

  const online = onlineUsers(state.social);
  const filtered = filter ? online.filter((u) => u.interests.includes(filter)) : online;

  const recentlyReturned = useMemo(
    () =>
      [...online].sort((a, b) => new Date(b.joinedAt).getTime() - new Date(a.joinedAt).getTime()).slice(0, 6),
    [online]
  );

  const maybeRemember = useMemo(
    () => state.social.users.filter((u) => !u.isOnline).slice(0, 6),
    [state.social.users]
  );

  const recentActivity = useMemo(() => {
    return [...state.social.posts]
      .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())
      .slice(0, 6)
      .map((post) => ({
        id: post.id,
        userId: post.authorId,
        text: `publicó "${post.title ?? post.body.slice(0, 40)}"`,
      }));
  }, [state.social.posts]);

  return (
    <ScreenContainer edges={['top']}>
      <AppHeader onMenuPress={drawer.open} />
      <MenzoDrawerContent visible={drawer.visible} onClose={drawer.close} />

      <ScrollView
        showsVerticalScrollIndicator={false}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={Colors.textPrimary} />}
        contentContainerStyle={[styles.scroll, { paddingBottom: BottomTabBarHeight + Spacing.xl }]}>
        <MenzoImageBackground source={menzoAssets.banners.connections} style={styles.banner} overlayOpacity={0.35}>
          <View style={styles.bannerContent}>
            <Text style={styles.title}>Ahora mismo</Text>
            <Text style={styles.subtitle}>Estas personas mantienen encendida la comunidad.</Text>
            <View style={styles.countRow}>
              <View style={styles.onlineDot} />
              <Text style={styles.count}>{online.length} conectados</Text>
            </View>
          </View>
        </MenzoImageBackground>

        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.filterRow}>
          <InterestChip
            interest={{ id: 'nostalgia', label: 'Todos', icon: 'sparkles', gradient: 'fire' }}
            selected={filter === null}
            onToggle={() => setFilter(null)}
          />
          {interests.map((interest) => (
            <InterestChip
              key={interest.id}
              interest={interest}
              selected={filter === interest.id}
              onToggle={() => setFilter(interest.id)}
            />
          ))}
        </ScrollView>

        {filtered.length === 0 ? (
          <EmptyState title="Nadie con ese interés está conectado ahora" preset="storm" />
        ) : (
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.membersRow}>
            {filtered.map((user) => (
              <MemberCard key={user.id} user={user} variant="column" />
            ))}
          </ScrollView>
        )}

        <Text style={styles.sectionTitle}>Nuevos miembros</Text>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.membersRow}>
          {recentlyReturned.map((user) => (
            <MemberCard key={`returned-${user.id}`} user={user} variant="column" />
          ))}
        </ScrollView>

        <Text style={styles.sectionTitle}>Otros miembros</Text>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.membersRow}>
          {maybeRemember.map((user) => (
            <MemberCard key={`memory-${user.id}`} user={user} variant="column" />
          ))}
        </ScrollView>

        <Text style={styles.sectionTitle}>Actividad reciente</Text>
        <View style={styles.activityList}>
          {recentActivity.map((activity) => {
            const author = state.social.users.find((u) => u.id === activity.userId);
            if (!author) return null;
            return (
              <View key={activity.id} style={styles.activityRow}>
                <UserAvatar name={author.displayName} avatarUri={author.avatarUri} gradient={author.avatarGradient} size={34} level={author.level} />
                <Text style={styles.activityText}>
                  <Text style={styles.activityName}>{author.displayName} </Text>
                  {activity.text}
                </Text>
              </View>
            );
          })}
        </View>
      </ScrollView>
    </ScreenContainer>
  );
}

const styles = StyleSheet.create({
  scroll: { paddingHorizontal: Spacing.lg, gap: Spacing.md },
  banner: { borderRadius: Radius.xl, overflow: 'hidden', marginTop: Spacing.sm },
  bannerContent: { padding: Spacing.lg, gap: 4 },
  title: { ...Typography.h1, color: '#FFFFFF' },
  subtitle: { ...Typography.body, color: 'rgba(255,255,255,0.82)' },
  countRow: { flexDirection: 'row', alignItems: 'center', gap: 6, marginTop: 2 },
  onlineDot: { width: 8, height: 8, borderRadius: 4, backgroundColor: Colors.online },
  count: { ...Typography.label, color: '#FFFFFF' },
  filterRow: { gap: Spacing.sm, paddingVertical: Spacing.xs },
  membersRow: { gap: Spacing.md, paddingVertical: Spacing.xs },
  sectionTitle: { ...Typography.h3, color: Colors.textPrimary, marginTop: Spacing.sm },
  activityList: { gap: Spacing.sm },
  activityRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.sm,
    backgroundColor: Colors.surface,
    borderRadius: Radius.md,
    borderWidth: 1,
    borderColor: Colors.borderSoft,
    padding: Spacing.md,
  },
  activityText: { ...Typography.body, color: Colors.textSecondary, flex: 1 },
  activityName: { ...Typography.bodyMedium, color: Colors.textPrimary },
});
