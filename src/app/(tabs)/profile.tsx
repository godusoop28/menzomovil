import { router } from 'expo-router';
import { useEffect, useState } from 'react';
import { KeyboardAvoidingView, RefreshControl, ScrollView, StyleSheet, Text, View } from 'react-native';

import { AppHeader } from '@/components/AppHeader';
import { EmptyState } from '@/components/EmptyState';
import { IconButton } from '@/components/IconButton';
import { PostCard } from '@/components/PostCard';
import { ProfileHeader } from '@/components/ProfileHeader';
import { ScreenContainer } from '@/components/ScreenContainer';
import { SegmentedTabs } from '@/components/SegmentedTabs';
import { MenzoDrawerContent } from '@/components/navigation/MenzoDrawerContent';
import { useMenzoDrawer } from '@/hooks/useMenzoDrawer';
import { WallComposer } from '@/components/WallComposer';
import { WallMessageCard } from '@/components/WallMessageCard';
import { useAppState } from '@/hooks/useAppState';
import { useKeyboardBehavior } from '@/hooks/useKeyboardOffset';
import { getMyRealId } from '@/services/api';
import { LOCAL_USER_ID } from '@/store/localUser';
import { postsByAuthor, savedPosts, wallMessagesForProfile } from '@/store/selectors';
import { menzoAssets } from '@/constants/assets';
import { BottomTabBarHeight, Colors, Spacing, Typography } from '@/theme';

type ProfileTab = 'posts' | 'wall' | 'saved';

export default function OwnProfileScreen() {
  const { state, actions } = useAppState();
  const drawer = useMenzoDrawer();
  const [tab, setTab] = useState<ProfileTab>('posts');
  const [refreshing, setRefreshing] = useState(false);
  const behavior = useKeyboardBehavior();

  useEffect(() => {
    actions.loadProfileWall(LOCAL_USER_ID);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  if (!state.profile) return null;

  const profile = state.profile;
  const myPosts = postsByAuthor(state.social, LOCAL_USER_ID);
  const myWall = wallMessagesForProfile(state.social, LOCAL_USER_ID);
  const mySaved = savedPosts(state.social, LOCAL_USER_ID);
  // Si el caché de social.users aún no trae mi propio perfil (o quedó
  // desactualizado, p. ej. justo después de cambiar la foto), se usa
  // state.profile como fuente de verdad para no mostrar nada o algo viejo.
  const localUserDemo =
    state.social.users.find((u) => u.id === LOCAL_USER_ID) ?? { ...profile, activityStatus: profile.statusText };

  async function onRefresh() {
    setRefreshing(true);
    try {
      await Promise.all([actions.refreshProfile(), actions.loadProfileWall(LOCAL_USER_ID), actions.refreshSocial()]);
    } catch (error) {
      console.warn('[menzo/profile] refresh failed', error);
    } finally {
      setRefreshing(false);
    }
  }

  const customBackgroundImage = profile.backgroundUri
    ? { uri: profile.backgroundUri }
    : profile.backgroundColor
      ? undefined
      : menzoAssets.backgrounds.profile;

  return (
    <ScreenContainer
      edges={['top']}
      backgroundImage={customBackgroundImage}
      backgroundImageOverlay={profile.backgroundUri ? 0.72 : 0.78}
      background={!customBackgroundImage ? profile.backgroundColor : undefined}>
      <AppHeader
        onMenuPress={drawer.open}
        right={<IconButton name="settings-outline" label="Configuración" onPress={() => router.push('/settings')} />}
      />
      <MenzoDrawerContent visible={drawer.visible} onClose={drawer.close} />

      <KeyboardAvoidingView behavior={behavior} style={styles.flex}>
        <ScrollView
          showsVerticalScrollIndicator={false}
          contentContainerStyle={{ paddingBottom: BottomTabBarHeight + Spacing.xl }}
          refreshControl={
            <RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={Colors.textPrimary} />
          }>
          {localUserDemo && <ProfileHeader user={localUserDemo} isOwnProfile statsUserId={getMyRealId() ?? undefined} />}

          <View style={styles.tabsWrap}>
            <SegmentedTabs
              value={tab}
              onChange={setTab}
              options={[
                { value: 'posts', label: 'Publicaciones' },
                { value: 'wall', label: 'Muro' },
                { value: 'saved', label: 'Guardados' },
              ]}
            />
          </View>

          <View style={styles.body}>
            {tab === 'posts' &&
              (myPosts.length === 0 ? (
                <EmptyState title="Todavía no has publicado nada" preset="prism" />
              ) : (
                myPosts.map((post) => <PostCard key={post.id} post={post} />)
              ))}

            {tab === 'wall' && (
              <View style={styles.wallWrap}>
                <Text style={styles.wallTitle}>Muro</Text>
                <Text style={styles.wallSubtitle}>Deja una señal de que estuviste aquí.</Text>
                <WallComposer profileId={LOCAL_USER_ID} placeholder={`Escribe algo para ${profile.displayName}…`} />
                {myWall.length === 0 ? (
                  <EmptyState title="Este muro todavía espera su primer recuerdo." preset="memory" />
                ) : (
                  myWall.map((message) => <WallMessageCard key={message.id} message={message} />)
                )}
              </View>
            )}

            {tab === 'saved' &&
              (mySaved.length === 0 ? (
                <EmptyState title="Todavía no has guardado ningún recuerdo." preset="eclipse" />
              ) : (
                mySaved.map((post) => <PostCard key={post.id} post={post} />)
              ))}
          </View>
        </ScrollView>
      </KeyboardAvoidingView>
    </ScreenContainer>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  tabsWrap: { paddingHorizontal: Spacing.lg, marginTop: Spacing.lg },
  body: { paddingHorizontal: Spacing.lg, marginTop: Spacing.md, gap: Spacing.md },
  wallWrap: { gap: Spacing.md },
  wallTitle: { ...Typography.h3, color: Colors.textPrimary },
  wallSubtitle: { ...Typography.caption, color: Colors.textMuted, marginTop: -8 },
});
