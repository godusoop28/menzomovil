import { router } from 'expo-router';
import { ScrollView, StyleSheet, Text, View } from 'react-native';

import { EmptyState } from '@/components/EmptyState';
import { IconButton } from '@/components/IconButton';
import { PostCard } from '@/components/PostCard';
import { ScreenContainer } from '@/components/ScreenContainer';
import { useAppState } from '@/hooks/useAppState';
import { recentPosts } from '@/store/selectors';
import { Colors, Spacing, Typography } from '@/theme';

export default function RecentScreen() {
  const { state } = useAppState();
  const posts = recentPosts(state.social);

  return (
    <ScreenContainer>
      <View style={styles.header}>
        <IconButton name="chevron-back" label="Volver" onPress={() => router.back()} />
        <Text style={styles.headerTitle}>Lo más reciente</Text>
        <View style={{ width: 44 }} />
      </View>
      <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
        {posts.length === 0 ? (
          <EmptyState title="Todavía no hay publicaciones" preset="memory" />
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
