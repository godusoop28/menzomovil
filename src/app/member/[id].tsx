import { router, useLocalSearchParams } from 'expo-router';
import { useEffect, useState } from 'react';
import { ScrollView, StyleSheet, Text, View } from 'react-native';

import { EmptyState } from '@/components/EmptyState';
import { IconButton } from '@/components/IconButton';
import { PostCard } from '@/components/PostCard';
import { ProfileHeader } from '@/components/ProfileHeader';
import { ScreenContainer } from '@/components/ScreenContainer';
import { SegmentedTabs } from '@/components/SegmentedTabs';
import { WallMessageCard } from '@/components/WallMessageCard';
import { useAppState } from '@/hooks/useAppState';
import { useToast } from '@/hooks/useToast';
import { LOCAL_USER_ID } from '@/store/localUser';
import { postsByAuthor, wallMessagesForProfile } from '@/store/selectors';
import { menzoAssets } from '@/constants/assets';
import { Colors, Spacing, Typography } from '@/theme';

type MemberTab = 'posts' | 'wall';

export default function MemberProfileScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const { state, actions } = useAppState();
  const showToast = useToast();
  const [tab, setTab] = useState<MemberTab>('posts');
  const [openingChat, setOpeningChat] = useState(false);

  async function handleMessage(userId: string) {
    if (openingChat) return;
    setOpeningChat(true);
    const roomId = await actions.openDirectMessage(userId);
    setOpeningChat(false);
    if (roomId) {
      router.push(`/chat/${roomId}`);
    } else {
      showToast('No pudimos abrir el chat. Inténtalo de nuevo.');
    }
  }

  const isSelf = id === LOCAL_USER_ID;
  const user = state.social.users.find((u) => u.id === id);

  useEffect(() => {
    if (id && !isSelf) {
      actions.addRecentlyViewed({ kind: 'member', id, at: new Date().toISOString() });
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id]);

  useEffect(() => {
    if (!id) return;
    if (!isSelf) actions.ensureUserLoaded(id);
    actions.loadProfileWall(id);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id]);

  if (!user) {
    return (
      <ScreenContainer>
        <View style={styles.header}>
          <IconButton name="chevron-back" label="Volver" onPress={() => router.back()} />
        </View>
        <EmptyState title="No encontramos este perfil" preset="eclipse" />
      </ScreenContainer>
    );
  }

  const isFollowing = state.social.following.includes(user.id);
  const posts = postsByAuthor(state.social, user.id);
  const wall = wallMessagesForProfile(state.social, user.id);

  const customBackgroundImage = user.backgroundUri
    ? { uri: user.backgroundUri }
    : user.backgroundColor
      ? undefined
      : menzoAssets.backgrounds.profile;

  return (
    <ScreenContainer
      backgroundImage={customBackgroundImage}
      backgroundImageOverlay={user.backgroundUri ? 0.72 : 0.78}
      background={!customBackgroundImage ? user.backgroundColor : undefined}>
      <View style={styles.header}>
        <IconButton name="chevron-back" label="Volver" onPress={() => router.back()} />
        {isSelf && <Text style={styles.visitorLabel}>Modo visitante</Text>}
      </View>

      <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={styles.scroll}>
        <ProfileHeader
          user={user}
          isOwnProfile={isSelf}
          isFollowing={isFollowing}
          hideActions={isSelf}
          onToggleFollow={() => actions.toggleFollow(user.id)}
          onMessage={() => handleMessage(user.id)}
          statsUserId={user.id}
        />

        <View style={styles.tabsWrap}>
          <SegmentedTabs
            value={tab}
            onChange={setTab}
            options={[
              { value: 'posts', label: 'Publicaciones' },
              { value: 'wall', label: 'Muro' },
            ]}
          />
        </View>

        <View style={styles.body}>
          {tab === 'posts' &&
            (posts.length === 0 ? (
              <EmptyState title={`${user.displayName} todavía no ha publicado nada`} preset="prism" />
            ) : (
              posts.map((post) => <PostCard key={post.id} post={post} />)
            ))}

          {tab === 'wall' &&
            (wall.length === 0 ? (
              <EmptyState title="Este muro todavía espera su primer recuerdo." preset="memory" />
            ) : (
              wall.map((message) => <WallMessageCard key={message.id} message={message} />)
            ))}
        </View>
      </ScrollView>
    </ScreenContainer>
  );
}

const styles = StyleSheet.create({
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: Spacing.md,
    paddingTop: Spacing.xs,
  },
  visitorLabel: { ...Typography.label, color: Colors.textMuted, marginRight: Spacing.md },
  scroll: { paddingBottom: Spacing.xxl },
  tabsWrap: { paddingHorizontal: Spacing.lg, marginTop: Spacing.lg },
  body: { paddingHorizontal: Spacing.lg, marginTop: Spacing.md, gap: Spacing.md },
});
