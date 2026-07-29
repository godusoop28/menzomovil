import { router } from 'expo-router';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { Pressable, RefreshControl, ScrollView, StyleSheet, Text, View } from 'react-native';

import { AppHeader } from '@/components/AppHeader';
import { ChatRoomCard } from '@/components/ChatRoomCard';
import { EmptyState } from '@/components/EmptyState';
import { IconButton } from '@/components/IconButton';
import { ScreenContainer } from '@/components/ScreenContainer';
import { SegmentedTabs } from '@/components/SegmentedTabs';
import { MenzoDrawerContent } from '@/components/navigation/MenzoDrawerContent';
import { useMenzoDrawer } from '@/hooks/useMenzoDrawer';
import { useHaptics } from '@/hooks/useHaptics';
import { useAppState } from '@/hooks/useAppState';
import { menzoAssets } from '@/constants/assets';
import { BottomTabBarHeight, Colors, Radius, Spacing, Typography, useAccent } from '@/theme';

type ChatsTab = 'mine' | 'public';
type RoomSort = 'recent' | 'popular';

export default function ChatsScreen() {
  const { state, actions } = useAppState();
  const drawer = useMenzoDrawer();
  const accent = useAccent();
  const { selection } = useHaptics();
  const [refreshing, setRefreshing] = useState(false);
  const [tab, setTab] = useState<ChatsTab>('mine');
  const [roomSort, setRoomSort] = useState<RoomSort>('recent');
  const [joiningId, setJoiningId] = useState<string | null>(null);

  const myRooms = state.social.rooms.filter((r) => r.type === 'direct' || r.joined);
  const favoriteRooms = myRooms.filter((r) => r.favorite);
  const directRooms = myRooms.filter((r) => !r.favorite && r.type === 'direct');
  const publicRooms = myRooms.filter((r) => !r.favorite && r.type === 'public');

  useEffect(() => {
    if (tab === 'public') actions.loadDiscoverRooms(roomSort);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tab, roomSort]);

  const discoverRooms = useMemo(() => {
    const list = state.social.rooms.filter((r) => r.type === 'public');
    return [...list].sort((a, b) =>
      roomSort === 'popular' ? b.onlineCount - a.onlineCount : new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
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

  const onRefresh = useCallback(async () => {
    setRefreshing(true);
    await actions.refreshSocial();
    setRefreshing(false);
  }, [actions]);

  return (
    <ScreenContainer edges={['top']}>
      <AppHeader
        onMenuPress={drawer.open}
        right={
          <>
            <IconButton name="search" label="Buscar" onPress={() => router.push('/search')} />
            <IconButton name="add-circle-outline" label="Crear" onPress={() => router.push('/create')} />
          </>
        }
      />
      <MenzoDrawerContent visible={drawer.visible} onClose={drawer.close} />

      <ScrollView
        showsVerticalScrollIndicator={false}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={Colors.textPrimary} />}
        contentContainerStyle={[styles.scroll, { paddingBottom: BottomTabBarHeight + Spacing.xl }]}>
        <View style={styles.titleRow}>
          <Text style={styles.title}>Mis chats</Text>
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

        <SegmentedTabs
          value={tab}
          onChange={setTab}
          options={[
            { value: 'mine', label: 'Mis chats' },
            { value: 'public', label: 'Públicos' },
          ]}
        />

        {tab === 'mine' ? (
          <>
            {favoriteRooms.length > 0 && (
              <View style={styles.section}>
                <Text style={styles.sectionTitle}>Favoritos</Text>
                <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.hRow}>
                  {favoriteRooms.map((room) => (
                    <ChatRoomCard key={room.id} room={room} compact />
                  ))}
                </ScrollView>
              </View>
            )}

            {directRooms.length > 0 && (
              <View style={styles.section}>
                <Text style={styles.sectionTitle}>Mensajes directos</Text>
                <View style={styles.list}>
                  {directRooms.map((room) => (
                    <ChatRoomCard key={room.id} room={room} />
                  ))}
                </View>
              </View>
            )}

            <View style={styles.section}>
              <Text style={styles.sectionTitle}>Salas públicas</Text>
              <View style={styles.list}>
                {publicRooms.length === 0 ? (
                  <EmptyState title="Tus próximas historias comienzan aquí." image={menzoAssets.illustrations.chat} />
                ) : (
                  publicRooms.map((room) => <ChatRoomCard key={room.id} room={room} />)
                )}
              </View>
            </View>
          </>
        ) : (
          <View style={styles.section}>
            <View style={styles.sortRow}>
              <Pressable onPress={() => setRoomSort('recent')} style={[styles.sortChip, roomSort === 'recent' && styles.sortChipActive]}>
                <Text style={[styles.sortChipLabel, roomSort === 'recent' && styles.sortChipLabelActive]}>Recientes</Text>
              </Pressable>
              <Pressable onPress={() => setRoomSort('popular')} style={[styles.sortChip, roomSort === 'popular' && styles.sortChipActive]}>
                <Text style={[styles.sortChipLabel, roomSort === 'popular' && styles.sortChipLabelActive]}>Populares</Text>
              </Pressable>
            </View>
            <View style={styles.list}>
              {discoverRooms.length === 0 ? (
                <EmptyState title="No hay salas activas. Enciende la primera." image={menzoAssets.illustrations.chat} />
              ) : (
                discoverRooms.map((room) => (
                  <ChatRoomCard key={room.id} room={room} onJoin={handleJoin} joining={joiningId === room.id} />
                ))
              )}
            </View>
          </View>
        )}
      </ScrollView>
    </ScreenContainer>
  );
}

const styles = StyleSheet.create({
  scroll: { paddingHorizontal: Spacing.lg, gap: Spacing.lg },
  titleRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: Spacing.sm, marginTop: Spacing.sm },
  title: { ...Typography.h1, color: Colors.textPrimary },
  section: { gap: Spacing.sm },
  sectionTitle: { ...Typography.h3, color: Colors.textPrimary },
  hRow: { gap: Spacing.md, paddingVertical: Spacing.xs },
  list: { gap: Spacing.sm },
  createPill: { paddingHorizontal: Spacing.md, paddingVertical: 9, borderRadius: Radius.pill },
  createPillLabel: { ...Typography.label, fontSize: 13, fontWeight: '700', color: Colors.textOnAccent },
  sortRow: { flexDirection: 'row', gap: Spacing.sm },
  sortChip: { borderRadius: Radius.pill, paddingHorizontal: Spacing.md, paddingVertical: 6 },
  sortChipActive: { backgroundColor: Colors.surfaceSoft },
  sortChipLabel: { ...Typography.caption, fontWeight: '600', color: Colors.textMuted },
  sortChipLabelActive: { color: Colors.textPrimary },
});
