import { router } from 'expo-router';
import { Pressable, StyleSheet, Text, View } from 'react-native';

import { AbstractArtwork } from './AbstractArtwork';
import { UserAvatar } from './UserAvatar';
import { useAppState } from '@/hooks/useAppState';
import { findUser } from '@/store/selectors';
import { Colors, Radius, Spacing, Typography } from '@/theme';
import type { Post } from '@/types';

type Props = { post: Post; variant?: 'hero' | 'medium' };

export function FeaturedPostCard({ post, variant = 'medium' }: Props) {
  const { state } = useAppState();
  const author = findUser(state.social, post.authorId);
  const isHero = variant === 'hero';

  return (
    <Pressable
      onPress={() => router.push(`/post/${post.id}`)}
      style={[styles.card, isHero ? styles.hero : styles.medium]}
      accessibilityRole="button"
      accessibilityLabel={post.title ?? post.body}>
      <AbstractArtwork
        preset={post.abstractVisual?.preset ?? 'prism'}
        style={StyleSheet.absoluteFill}
        radius={Radius.lg}
        dim
      />
      <View style={styles.badge}>
        <Text style={styles.badgeText}>Destacado</Text>
      </View>
      <View style={styles.content}>
        {!!post.title && (
          <Text style={styles.title} numberOfLines={isHero ? 3 : 2}>
            {post.title}
          </Text>
        )}
        {author && (
          <View style={styles.authorRow}>
            <UserAvatar name={author.displayName} avatarUri={author.avatarUri} gradient={author.avatarGradient} size={24} level={author.level} />
            <Text style={styles.authorName}>{author.displayName}</Text>
          </View>
        )}
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  card: { borderRadius: Radius.lg, overflow: 'hidden', justifyContent: 'flex-end' },
  hero: { height: 200, width: '100%' },
  medium: { height: 150, width: 220 },
  badge: {
    position: 'absolute',
    top: Spacing.sm,
    left: Spacing.sm,
    backgroundColor: 'rgba(255,190,46,0.92)',
    paddingVertical: 3,
    paddingHorizontal: 8,
    borderRadius: Radius.pill,
  },
  badgeText: { ...Typography.caption, fontWeight: '700', color: Colors.textOnAccent },
  content: { padding: Spacing.md, gap: 6 },
  title: { ...Typography.h3, color: '#FFFFFF' },
  authorRow: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  authorName: { ...Typography.caption, color: 'rgba(255,255,255,0.9)' },
});
