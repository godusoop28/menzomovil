import { router, useLocalSearchParams } from 'expo-router';
import { useEffect, useState } from 'react';
import { ScrollView, StyleSheet, Text, View } from 'react-native';

import { EmptyState } from '@/components/EmptyState';
import { IconButton } from '@/components/IconButton';
import { MemberCard } from '@/components/MemberCard';
import { ScreenContainer } from '@/components/ScreenContainer';
import { getMyRealId, mapDemoUser, usersApi } from '@/services/api';
import { Colors, Spacing, Typography } from '@/theme';
import type { DemoUser } from '@/types';

export default function FollowersScreen() {
  const { userId } = useLocalSearchParams<{ userId?: string }>();
  const targetId = userId ?? getMyRealId() ?? undefined;
  const [users, setUsers] = useState<DemoUser[] | null>(targetId ? null : []);

  useEffect(() => {
    if (!targetId) return;
    usersApi
      .followers(targetId)
      .then((dtos) => setUsers(dtos.map((dto) => mapDemoUser(dto, getMyRealId()))))
      .catch((error) => {
        console.warn('[menzo/api] load followers failed', error);
        setUsers([]);
      });
  }, [targetId]);

  return (
    <ScreenContainer>
      <View style={styles.header}>
        <IconButton name="chevron-back" label="Volver" onPress={() => router.back()} />
        <Text style={styles.headerTitle}>Seguidores</Text>
        <View style={{ width: 44 }} />
      </View>
      <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
        {users === null ? (
          <Text style={styles.loading}>Cargando…</Text>
        ) : users.length === 0 ? (
          <EmptyState title="Todavía no tiene seguidores" preset="storm" />
        ) : (
          users.map((user) => <MemberCard key={user.id} user={user} />)
        )}
      </ScrollView>
    </ScreenContainer>
  );
}

const styles = StyleSheet.create({
  header: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: Spacing.md, paddingTop: Spacing.xs },
  headerTitle: { ...Typography.h3, color: Colors.textPrimary },
  content: { padding: Spacing.lg, gap: Spacing.sm, paddingBottom: Spacing.xxl },
  loading: { ...Typography.body, color: Colors.textMuted, textAlign: 'center', marginTop: Spacing.xl },
});
