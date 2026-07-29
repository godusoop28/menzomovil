import { router } from 'expo-router';
import { useCallback, useState } from 'react';
import { Pressable, RefreshControl, ScrollView, StyleSheet, Text, View } from 'react-native';

import { AppHeader } from '@/components/AppHeader';
import { ChatRoomCard } from '@/components/ChatRoomCard';
import { EmptyState } from '@/components/EmptyState';
import { IconButton } from '@/components/IconButton';
import { ScreenContainer } from '@/components/ScreenContainer';
import { MenzoDrawerContent } from '@/components/navigation/MenzoDrawerContent';
import { useMenzoDrawer } from '@/hooks/useMenzoDrawer';
import { useHaptics } from '@/hooks/useHaptics';
import { useAppState } from '@/hooks/useAppState';
import { menzoAssets } from '@/constants/assets';
import { BottomTabBarHeight, Colors, Radius, Spacing, Typography, useAccent } from '@/theme';

export default function ChatsScreen() {
  const { state, actions } = useAppState();
  const drawer = useMenzoDrawer();
  const accent = useAccent();
  const { selection } = useHaptics();
  const [refreshing, setRefreshing] = useState(false);

  const myRooms = state.social.rooms.filter((r) => r.type === 'direct' || r.joined);
  const favoriteRooms = myRooms.filter((r) => r.favorite);
  const directRooms = myRooms.filter((r) => !r.favorite && r.type === 'direct');
  const publicRooms = myRooms.filter((r) => !r.favorite && r.type === 'public');

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
});
