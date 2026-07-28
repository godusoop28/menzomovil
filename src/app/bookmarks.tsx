import { router } from 'expo-router';
import { ScrollView, StyleSheet, Text, View } from 'react-native';

import { EmptyState } from '@/components/EmptyState';
import { IconButton } from '@/components/IconButton';
import { PostCard } from '@/components/PostCard';
import { ScreenContainer } from '@/components/ScreenContainer';
import { useAppState } from '@/hooks/useAppState';
import { LOCAL_USER_ID } from '@/store/localUser';
import { savedPosts } from '@/store/selectors';
import { Colors, Spacing, Typography } from '@/theme';

export default function BookmarksScreen() {
  const { state } = useAppState();
  const posts = savedPosts(state.social, LOCAL_USER_ID);

  return (
    <ScreenContainer>
      <View style={styles.header}>
        <IconButton name="chevron-back" label="Volver" onPress={() => router.back()} />
        <Text style={styles.headerTitle}>Guardados</Text>
        <View style={{ width: 44 }} />
      </View>
      <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
        {posts.length === 0 ? (
          <EmptyState title="Todavía no has guardado ningún recuerdo." preset="eclipse" />
        ) : (
          posts.map((post) => <PostCard key={post.id} post={post} />)
        )}
      </ScrollView>
    </ScreenContainer>
  );
}

const styles = StyleSheet.create({
  header: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: Spacing.md, paddingTop: Spacing.xs },
  headerTitle: { ...Typography.h3, color: Colors.textPrimary },
  content: { padding: Spacing.lg, gap: Spacing.md, paddingBottom: Spacing.xxl },
});
