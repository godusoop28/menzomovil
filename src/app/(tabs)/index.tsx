import { router } from 'expo-router';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { Pressable, RefreshControl, ScrollView, StyleSheet, Text, View } from 'react-native';

import { AppHeader } from '@/components/AppHeader';
import { ChatRoomCard } from '@/components/ChatRoomCard';
import { CommunityHero } from '@/components/CommunityHero';
import { EmptyState } from '@/components/EmptyState';
import { FeaturedPostCard } from '@/components/FeaturedPostCard';
import { PostCard } from '@/components/PostCard';
import { ScreenContainer } from '@/components/ScreenContainer';
import { SegmentedTabs } from '@/components/SegmentedTabs';
import { MenzoImageBackground } from '@/components/common/MenzoImageBackground';
import { MenzoDrawerContent } from '@/components/navigation/MenzoDrawerContent';
import { menzoAssets } from '@/constants/assets';
import { useAppState } from '@/hooks/useAppState';
import { useHaptics } from '@/hooks/useHaptics';
import { useMenzoDrawer } from '@/hooks/useMenzoDrawer';
import { featuredPosts, onlineUsers, recentPosts } from '@/store/selectors';
import { BottomTabBarHeight, Colors, Radius, Spacing, Typography, useAccent } from '@/theme';

type HomeTab = 'recientes' | 'destacados' | 'descubrir';
type RoomSort = 'recent' | 'popular';

export default function HomeScreen() {
  const { state, actions } = useAppState();
  const [tab, setTab] = useState<HomeTab>('recientes');
  const [roomSort, setRoomSort] = useState<RoomSort>('recent');
  const [refreshing, setRefreshing] = useState(false);
  const [joiningId, setJoiningId] = useState<string | null>(null);
  const drawer = useMenzoDrawer();
  const accent = useAccent();
  const { selection } = useHaptics();

  const onRefresh = useCallback(async () => {
    setRefreshing(true);
    await actions.refreshSocial();
    setRefreshing(false);
  }, [actions]);

  const posts = recentPosts(state.social);
  const featured = featuredPosts(state.social);
  const onlineMembers = onlineUsers(state.social);
  const displayName = state.profile?.displayName ?? '';

  useEffect(() => {
    if (tab === 'descubrir') actions.loadDiscoverRooms(roomSort);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tab, roomSort]);

  const discoverRooms = useMemo(() => {
    const list = state.social.rooms.filter((r) => r.type === 'public');
    return [...list].sort((a, b) =>
      roomSort === 'popular'
        ? b.onlineCount - a.onlineCount
        : new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
    );
  }, [state.social.rooms, roomSort]);

  async function handleJoin(roomId: string) {
    setJoiningId(roomId);
    try {
      await actions.joinRoom(roomId);
    } finally {
      setJoiningId(null);
    }
  }

  return (
    <ScreenContainer edges={['top']}>
      <AppHeader onMenuPress={drawer.open} />
      <MenzoDrawerContent visible={drawer.visible} onClose={drawer.close} />

      <ScrollView
        showsVerticalScrollIndicator={false}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={Colors.textPrimary} />}
        contentContainerStyle={[styles.scroll, { paddingBottom: BottomTabBarHeight + Spacing.xl }]}>
        <View style={styles.greeting}>
          <Text style={styles.greetingTitle}>Bienvenido de vuelta, {displayName}</Text>
          <Text style={styles.greetingSubtitle}>Hay nuevas historias esperándote.</Text>
        </View>

        <CommunityHero previewMembers={onlineMembers} />

        <View style={styles.tabsWrap}>
          <SegmentedTabs
            value={tab}
            onChange={setTab}
            options={[
              { value: 'recientes', label: 'Recientes' },
              { value: 'destacados', label: 'Destacados' },
              { value: 'descubrir', label: 'Descubrir' },
            ]}
          />
        </View>

        {tab === 'recientes' && (
          <View style={styles.list}>
            {posts.length === 0 ? (
              <EmptyState title="Todavía no hay publicaciones" preset="memory" />
            ) : (
              posts.map((post) => <PostCard key={post.id} post={post} />)
            )}
          </View>
        )}

        {tab === 'destacados' && (
          <View style={styles.list}>
            {featured.length === 0 ? (
              <EmptyState title="Nada destacado todavía" preset="prism" />
            ) : (
              <>
                <MenzoImageBackground source={menzoAssets.banners.featured} style={styles.featuredBanner} overlayOpacity={0.3}>
                  <View style={styles.featuredBannerContent}>
                    <Text style={styles.featuredBannerLabel}>El reencuentro brilla más aquí</Text>
                    <Text style={styles.featuredBannerTitle}>Destacados</Text>
                  </View>
                </MenzoImageBackground>

                <FeaturedPostCard post={featured[0]} variant="hero" />
                <View style={styles.gridRow}>
                  {featured.slice(1, 3).map((post) => (
                    <FeaturedPostCard key={post.id} post={post} />
                  ))}
                </View>

                <Text style={styles.sectionTitle}>Elegidos por la comunidad</Text>
                <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.hScroll}>
                  {featured.map((post) => (
                    <FeaturedPostCard key={`chosen-${post.id}`} post={post} />
                  ))}
                </ScrollView>

                <Text style={styles.sectionTitle}>Recuerdos que regresaron</Text>
                <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.hScroll}>
                  {[...featured].reverse().map((post) => (
                    <FeaturedPostCard key={`memory-${post.id}`} post={post} />
                  ))}
                </ScrollView>
              </>
            )}
          </View>
        )}

        {tab === 'descubrir' && (
          <View style={styles.list}>
            <View style={styles.hangoutHeader}>
              <View style={styles.hangoutHeaderText}>
                <Text style={styles.hangoutTitle}>Descubrir salas</Text>
                <Text style={styles.hangoutSubtitle}>
                  Explora todas las salas públicas y únete a las que te llamen la atención.
                </Text>
              </View>
              <Pressable
                accessibilityRole="button"
                accessibilityLabel="Crear sala"
                onPress={() => {
                  selection();
                  router.push('/create/room');
                }}
                style={[styles.createPill, { backgroundColor: accent.color }]}>
                <Text style={styles.createPillLabel}>+ Crear sala</Text>
              </Pressable>
            </View>

            <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.filterRow}>
              {(
                [
                  { value: 'recent', label: 'Recientes' },
                  { value: 'popular', label: 'Populares' },
                ] as { value: RoomSort; label: string }[]
              ).map((filter) => (
                <Text
                  key={filter.value}
                  onPress={() => setRoomSort(filter.value)}
                  accessibilityRole="button"
                  accessibilityState={{ selected: roomSort === filter.value }}
                  style={[styles.filterChip, roomSort === filter.value && styles.filterChipActive]}>
                  {filter.label}
                </Text>
              ))}
            </ScrollView>

            {discoverRooms.length === 0 ? (
              <EmptyState title="No hay conversaciones activas. Enciende la primera." preset="storm" />
            ) : (
              discoverRooms.map((room) => (
                <ChatRoomCard key={room.id} room={room} onJoin={handleJoin} joining={joiningId === room.id} />
              ))
            )}

            <Text onPress={() => router.push('/events')} accessibilityRole="button" style={styles.eventsLink}>
              Ver eventos de la comunidad →
            </Text>
          </View>
        )}
      </ScrollView>
    </ScreenContainer>
  );
}

const styles = StyleSheet.create({
  scroll: { paddingHorizontal: Spacing.lg, gap: Spacing.lg },
  featuredBanner: { borderRadius: 20, overflow: 'hidden' },
  featuredBannerContent: { padding: Spacing.lg, gap: 2 },
  featuredBannerLabel: { ...Typography.caption, color: 'rgba(255,255,255,0.85)', textTransform: 'uppercase', letterSpacing: 0.5 },
  featuredBannerTitle: { ...Typography.h1, color: '#FFFFFF' },
  greeting: { marginTop: Spacing.sm, gap: 2 },
  greetingTitle: { ...Typography.h2, color: Colors.textPrimary },
  greetingSubtitle: { ...Typography.body, color: Colors.textSecondary },
  tabsWrap: { marginTop: Spacing.xs },
  list: { gap: Spacing.md },
  gridRow: { flexDirection: 'row', gap: Spacing.md },
  sectionTitle: { ...Typography.h3, color: Colors.textPrimary, marginTop: Spacing.sm },
  hScroll: { gap: Spacing.md, paddingRight: Spacing.lg },
  hangoutHeader: { flexDirection: 'row', alignItems: 'flex-start', justifyContent: 'space-between', gap: Spacing.sm },
  hangoutHeaderText: { flex: 1, gap: 2 },
  createPill: { paddingHorizontal: Spacing.md, paddingVertical: 9, borderRadius: Radius.pill },
  createPillLabel: { ...Typography.label, fontSize: 13, fontWeight: '700', color: Colors.textOnAccent },
  hangoutTitle: { ...Typography.h2, color: Colors.textPrimary },
  hangoutSubtitle: { ...Typography.body, color: Colors.textSecondary, marginBottom: Spacing.xs },
  filterRow: { gap: Spacing.sm, paddingVertical: Spacing.xs },
  filterChip: {
    ...Typography.label,
    color: Colors.textMuted,
    backgroundColor: Colors.surfaceSecondary,
    borderRadius: 999,
    paddingVertical: 8,
    paddingHorizontal: 14,
    overflow: 'hidden',
  },
  filterChipActive: { backgroundColor: Colors.surfaceSoft, color: Colors.textPrimary },
  eventsLink: { ...Typography.label, color: Colors.cyan, textAlign: 'center', marginTop: Spacing.sm },
});
