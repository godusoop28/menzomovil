import { router } from 'expo-router';
import { ScrollView, StyleSheet, Text, View } from 'react-native';

import { EmptyState } from '@/components/EmptyState';
import { IconButton } from '@/components/IconButton';
import { MemberCard } from '@/components/MemberCard';
import { PostCard } from '@/components/PostCard';
import { ScreenContainer } from '@/components/ScreenContainer';
import { useAppState } from '@/hooks/useAppState';
import { findPost, findUser } from '@/store/selectors';
import { Colors, Spacing, Typography } from '@/theme';

export default function RecentlyViewedScreen() {
  const { state } = useAppState();
  const entries = state.social.recentlyViewed;

  return (
    <ScreenContainer>
      <View style={styles.header}>
        <IconButton name="chevron-back" label="Volver" onPress={() => router.back()} />
        <Text style={styles.headerTitle}>Vistos recientemente</Text>
        <View style={{ width: 44 }} />
      </View>
      <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
        {entries.length === 0 ? (
          <EmptyState title="Todavía no has visitado nada" description="Los perfiles y publicaciones que abras aparecerán aquí." preset="eclipse" />
        ) : (
          entries.map((entry) => {
            if (entry.kind === 'post') {
              const post = findPost(state.social, entry.id);
              return post ? <PostCard key={`${entry.kind}-${entry.id}`} post={post} /> : null;
            }
            const user = findUser(state.social, entry.id);
            return user ? <MemberCard key={`${entry.kind}-${entry.id}`} user={user} /> : null;
          })
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
