import { router, useLocalSearchParams } from 'expo-router';
import { useCallback, useEffect, useState } from 'react';
import { ActivityIndicator, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';

import { EmptyState } from '@/components/EmptyState';
import { IconButton } from '@/components/IconButton';
import { ScreenContainer } from '@/components/ScreenContainer';
import { UserAvatar } from '@/components/UserAvatar';
import { useAppState } from '@/hooks/useAppState';
import { useToast } from '@/hooks/useToast';
import { ApiError, chatApi, getMyRealId, mapDemoUser, mapUserSummary, usersApi } from '@/services/api';
import type { BanDto, RoomMemberDto } from '@/services/api/types';
import { findRoom } from '@/store/selectors';
import { Colors, Radius, Spacing, Typography } from '@/theme';
import type { ChatRoomRole, DemoUser, RoomBan, RoomMember } from '@/types';

const ROLE_LABEL: Record<ChatRoomRole, string> = { owner: '👑 Anfitrión', co_host: '⭐ Coanfitrión', member: 'Miembro' };

export default function RoomMembersScreen() {
  const { roomId } = useLocalSearchParams<{ roomId: string }>();
  const { state } = useAppState();
  const showToast = useToast();
  const room = findRoom(state.social, roomId);
  const myRole = room?.role ?? null;
  const canModerate = myRole === 'owner' || myRole === 'co_host';
  const myRealId = getMyRealId();

  const [members, setMembers] = useState<RoomMember[] | null>(null);
  const [bans, setBans] = useState<RoomBan[] | null>(null);
  const [busyUserId, setBusyUserId] = useState<string | null>(null);
  const [inviteQuery, setInviteQuery] = useState('');
  const [inviteResults, setInviteResults] = useState<DemoUser[]>([]);
  const [inviting, setInviting] = useState(false);

  const loadMembers = useCallback(() => {
    if (!roomId) return;
    chatApi
      .members(roomId)
      .then((dtos: RoomMemberDto[]) =>
        setMembers(
          dtos.map((dto) => ({ user: mapUserSummary(dto.user, myRealId), role: dto.role.toLowerCase() as ChatRoomRole, joinedAt: dto.joinedAt }))
        )
      )
      .catch((error) => {
        console.warn('[menzo/api] load members failed', error);
        setMembers([]);
      });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [roomId]);

  const loadBans = useCallback(() => {
    if (!roomId || !canModerate) return;
    chatApi
      .bans(roomId)
      .then((dtos: BanDto[]) =>
        setBans(dtos.map((dto) => ({ user: mapUserSummary(dto.user, myRealId), reason: dto.reason, createdAt: dto.createdAt, bannedBy: null })))
      )
      .catch(() => setBans([]));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [roomId, canModerate]);

  useEffect(() => {
    loadMembers();
  }, [loadMembers]);

  useEffect(() => {
    loadBans();
  }, [loadBans]);

  async function runAction(action: () => Promise<void>, userId: string, refresh: () => void = loadMembers) {
    setBusyUserId(userId);
    try {
      await action();
      refresh();
    } catch (error) {
      showToast(error instanceof ApiError ? error.message : 'No se pudo completar la acción.');
    } finally {
      setBusyUserId(null);
    }
  }

  async function handleSearch() {
    const query = inviteQuery.trim();
    if (!query || !roomId) return;
    try {
      const page = await usersApi.search(query, 0, 10);
      setInviteResults(page.items.map((dto) => mapDemoUser(dto, myRealId)));
    } catch (error) {
      console.warn('[menzo/api] user search failed', error);
    }
  }

  async function handleInvite(userId: string) {
    if (!roomId) return;
    setInviting(true);
    try {
      await chatApi.invite(roomId, userId);
      setInviteResults((prev) => prev.filter((u) => u.id !== userId));
      loadMembers();
      showToast('Se agregó a la sala.');
    } catch (error) {
      showToast(error instanceof ApiError ? error.message : 'No se pudo invitar a este usuario.');
    } finally {
      setInviting(false);
    }
  }

  return (
    <ScreenContainer>
      <View style={styles.header}>
        <IconButton name="chevron-back" label="Volver" onPress={() => router.back()} />
        <View style={styles.headerText}>
          <Text style={styles.headerTitle}>Miembros</Text>
          {!!room && (
            <Text style={styles.headerSubtitle} numberOfLines={1}>
              {room.name}
            </Text>
          )}
        </View>
        <View style={{ width: 44 }} />
      </View>

      <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
        {canModerate && (
          <View style={styles.inviteCard}>
            <Text style={styles.inviteTitle}>Invitar personas</Text>
            <View style={styles.inviteRow}>
              <TextInput
                value={inviteQuery}
                onChangeText={setInviteQuery}
                onSubmitEditing={handleSearch}
                placeholder="Buscar por nombre o usuario…"
                placeholderTextColor={Colors.textMuted}
                style={styles.inviteInput}
              />
              <Pressable onPress={handleSearch} style={styles.inviteSearchButton} accessibilityRole="button" accessibilityLabel="Buscar">
                <Text style={{ color: Colors.textPrimary }}>🔍</Text>
              </Pressable>
            </View>
            {inviteResults.map((user) => (
              <View key={user.id} style={styles.inviteResultRow}>
                <UserAvatar name={user.displayName} avatarUri={user.avatarUri} gradient={user.avatarGradient} size={32} />
                <Text style={styles.inviteResultName} numberOfLines={1}>
                  {user.displayName}
                </Text>
                <Pressable
                  onPress={() => handleInvite(user.id)}
                  disabled={inviting}
                  style={[styles.inviteButton, { backgroundColor: Colors.cyan }]}>
                  <Text style={styles.inviteButtonLabel}>Invitar</Text>
                </Pressable>
              </View>
            ))}
          </View>
        )}

        {members === null ? (
          <Text style={styles.loading}>Cargando…</Text>
        ) : members.length === 0 ? (
          <EmptyState title="Sin miembros" preset="storm" />
        ) : (
          members.map((member) => {
            const isSelf = member.user.id === myRealId;
            const canAct = canModerate && !isSelf && !(myRole === 'co_host' && member.role !== 'member');
            const canPromoteOrDemote = myRole === 'owner' && !isSelf && member.role !== 'owner';
            const busy = busyUserId === member.user.id;
            return (
              <View key={member.user.id} style={styles.memberRow}>
                <UserAvatar name={member.user.displayName} avatarUri={member.user.avatarUri} gradient={member.user.avatarGradient} size={40} />
                <View style={styles.memberInfo}>
                  <Text style={styles.memberName} numberOfLines={1}>
                    {member.user.displayName}
                  </Text>
                  <Text style={styles.memberRole}>{ROLE_LABEL[member.role]}</Text>
                </View>
                {(canPromoteOrDemote || canAct) && (
                  <View style={styles.memberActions}>
                    {canPromoteOrDemote && member.role === 'member' && (
                      <Pressable
                        disabled={busy}
                        onPress={() => runAction(() => chatApi.promote(roomId, member.user.id), member.user.id)}
                        style={styles.actionButton}>
                        <Text style={styles.actionButtonLabel}>Coanfitrión</Text>
                      </Pressable>
                    )}
                    {canPromoteOrDemote && member.role === 'co_host' && (
                      <Pressable
                        disabled={busy}
                        onPress={() => runAction(() => chatApi.demote(roomId, member.user.id), member.user.id)}
                        style={styles.actionButton}>
                        <Text style={styles.actionButtonLabel}>Quitar</Text>
                      </Pressable>
                    )}
                    {canAct && (
                      <>
                        <Pressable
                          disabled={busy}
                          onPress={() => runAction(() => chatApi.kick(roomId, member.user.id), member.user.id)}
                          style={styles.actionButton}>
                          <Text style={styles.actionButtonLabel}>Expulsar</Text>
                        </Pressable>
                        <Pressable
                          disabled={busy}
                          onPress={() =>
                            runAction(() => chatApi.ban(roomId, member.user.id), member.user.id, () => {
                              loadMembers();
                              loadBans();
                            })
                          }
                          style={styles.banButton}>
                          <Text style={styles.banButtonLabel}>Banear</Text>
                        </Pressable>
                      </>
                    )}
                    {busy && <ActivityIndicator size="small" color={Colors.textMuted} />}
                  </View>
                )}
              </View>
            );
          })
        )}

        {canModerate && !!bans?.length && (
          <View style={styles.bansSection}>
            <Text style={styles.bansTitle}>Baneados</Text>
            {bans.map((ban) => (
              <View key={ban.user.id} style={styles.memberRow}>
                <UserAvatar name={ban.user.displayName} avatarUri={ban.user.avatarUri} gradient={ban.user.avatarGradient} size={36} />
                <View style={styles.memberInfo}>
                  <Text style={styles.memberName} numberOfLines={1}>
                    {ban.user.displayName}
                  </Text>
                  {!!ban.reason && (
                    <Text style={styles.memberRole} numberOfLines={1}>
                      {ban.reason}
                    </Text>
                  )}
                </View>
                <Pressable
                  disabled={busyUserId === ban.user.id}
                  onPress={() => runAction(() => chatApi.unban(roomId, ban.user.id), ban.user.id, loadBans)}
                  style={styles.actionButton}>
                  <Text style={styles.actionButtonLabel}>Desbanear</Text>
                </Pressable>
              </View>
            ))}
          </View>
        )}
      </ScrollView>
    </ScreenContainer>
  );
}

const styles = StyleSheet.create({
  header: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: Spacing.md, paddingTop: Spacing.xs },
  headerText: { flex: 1, alignItems: 'center' },
  headerTitle: { ...Typography.h3, color: Colors.textPrimary },
  headerSubtitle: { ...Typography.caption, color: Colors.textMuted },
  content: { padding: Spacing.lg, gap: Spacing.sm, paddingBottom: Spacing.xxl },
  loading: { ...Typography.body, color: Colors.textMuted, textAlign: 'center', marginTop: Spacing.xl },
  inviteCard: {
    gap: Spacing.sm,
    borderRadius: Radius.lg,
    borderWidth: 1,
    borderColor: Colors.borderSoft,
    backgroundColor: Colors.surface,
    padding: Spacing.md,
    marginBottom: Spacing.sm,
  },
  inviteTitle: { ...Typography.label, color: Colors.textPrimary },
  inviteRow: { flexDirection: 'row', gap: Spacing.sm },
  inviteInput: {
    flex: 1,
    ...Typography.body,
    color: Colors.textPrimary,
    backgroundColor: Colors.surfaceSecondary,
    borderRadius: Radius.md,
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
  },
  inviteSearchButton: {
    width: 40,
    height: 40,
    borderRadius: Radius.md,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: Colors.surfaceSecondary,
  },
  inviteResultRow: { flexDirection: 'row', alignItems: 'center', gap: Spacing.sm },
  inviteResultName: { ...Typography.body, color: Colors.textPrimary, flex: 1 },
  inviteButton: { borderRadius: Radius.pill, paddingHorizontal: Spacing.sm, paddingVertical: 5 },
  inviteButtonLabel: { ...Typography.caption, fontWeight: '700', color: '#000000' },
  memberRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.sm,
    borderRadius: Radius.lg,
    borderWidth: 1,
    borderColor: Colors.borderSoft,
    backgroundColor: Colors.surface,
    padding: Spacing.sm,
  },
  memberInfo: { flex: 1, minWidth: 0 },
  memberName: { ...Typography.body, color: Colors.textPrimary },
  memberRole: { ...Typography.caption, color: Colors.textMuted },
  memberActions: { flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'flex-end', gap: 6, maxWidth: 150 },
  actionButton: { borderRadius: Radius.pill, paddingHorizontal: Spacing.sm, paddingVertical: 5, backgroundColor: Colors.surfaceSecondary },
  actionButtonLabel: { ...Typography.caption, fontWeight: '600', color: Colors.textPrimary },
  banButton: { borderRadius: Radius.pill, paddingHorizontal: Spacing.sm, paddingVertical: 5, backgroundColor: 'rgba(251,113,133,0.15)' },
  banButtonLabel: { ...Typography.caption, fontWeight: '600', color: Colors.coral },
  bansSection: { gap: Spacing.sm, marginTop: Spacing.sm },
  bansTitle: { ...Typography.label, color: Colors.textMuted },
});
