import { Ionicons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { Pressable, Share, StyleSheet, Text, View } from 'react-native';
import Animated, { useAnimatedStyle, useSharedValue, withSequence, withTiming } from 'react-native-reanimated';

import { AbstractArtwork } from './AbstractArtwork';
import { PollCard } from './PollCard';
import { UserAvatar } from './UserAvatar';
import { useAnimatedEntrance } from '@/hooks/useAnimatedEntrance';
import { useAppState } from '@/hooks/useAppState';
import { useHaptics } from '@/hooks/useHaptics';
import { LOCAL_USER_ID } from '@/store/localUser';
import { findUser } from '@/store/selectors';
import { Colors, Radius, Spacing, Typography } from '@/theme';
import type { Post } from '@/types';
import { relativeTime } from '@/utils/time';

const typeLabel: Record<Post['type'], string> = {
  text: '',
  image: 'Imagen',
  poll: 'Encuesta',
  question: 'Pregunta',
  event: 'Evento',
};

export function PostCard({ post }: { post: Post }) {
  const { state, actions } = useAppState();
  const { light, selection } = useHaptics();
  const author = findUser(state.social, post.authorId);
  const liked = post.likes.includes(LOCAL_USER_ID);
  const saved = post.bookmarkedBy.includes(LOCAL_USER_ID);
  const entrance = useAnimatedEntrance();
  const likeScale = useSharedValue(1);
  const likeStyle = useAnimatedStyle(() => ({ transform: [{ scale: likeScale.value }] }));

  if (!author) return null;

  async function handleShare() {
    try {
      await Share.share({ message: `${post.title ?? post.body.slice(0, 60)} — vía MENZO` });
    } catch {
      // user cancelled or share failed silently — no network dependency either way
    }
  }

  return (
    <Animated.View style={entrance}>
    <Pressable
      onPress={() => router.push(`/post/${post.id}`)}
      style={styles.card}
      accessibilityRole="button"
      accessibilityLabel={post.title ?? post.body}>
      <View style={styles.header}>
        <Pressable
          onPress={() => router.push(`/member/${author.id}`)}
          style={styles.authorRow}
          hitSlop={4}>
          <UserAvatar name={author.displayName} avatarUri={author.avatarUri} gradient={author.avatarGradient} size={42} showOnline online={author.isOnline} level={author.level} />
          <View>
            <Text style={styles.authorName}>{author.displayName}</Text>
            <Text style={styles.meta}>
              Nivel {author.level} · {relativeTime(post.createdAt)}
            </Text>
          </View>
        </Pressable>
        {!!typeLabel[post.type] && (
          <View style={styles.typeChip}>
            <Text style={styles.typeChipText}>{typeLabel[post.type]}</Text>
          </View>
        )}
      </View>

      {!!post.title && <Text style={styles.title}>{post.title}</Text>}
      <Text style={styles.body} numberOfLines={5}>
        {post.body}
      </Text>

      {post.abstractVisual && (
        <AbstractArtwork
          preset={post.abstractVisual.preset}
          caption={post.abstractVisual.caption}
          style={styles.visual}
        />
      )}

      {post.type === 'poll' && <PollCard post={post} />}

      {post.tags.length > 0 && (
        <View style={styles.tagsRow}>
          {post.tags.map((tag) => (
            <View key={tag} style={styles.tag}>
              <Text style={styles.tagText}>#{tag}</Text>
            </View>
          ))}
        </View>
      )}

      <View style={styles.actions}>
        <Pressable
          style={styles.actionButton}
          accessibilityRole="button"
          accessibilityLabel={liked ? 'Quitar me gusta' : 'Me gusta'}
          onPress={(e) => {
            e.stopPropagation();
            light();
            // eslint-disable-next-line react-hooks/immutability -- Reanimated shared values are mutated via `.value` by design
            likeScale.value = withSequence(withTiming(1.35, { duration: 110 }), withTiming(1, { duration: 140 }));
            actions.toggleLike(post.id);
          }}>
          <Animated.View style={likeStyle}>
            <Ionicons name={liked ? 'heart' : 'heart-outline'} size={20} color={liked ? Colors.coral : Colors.textMuted} />
          </Animated.View>
          <Text style={[styles.actionText, liked && { color: Colors.coral }]}>{post.likes.length}</Text>
        </Pressable>

        <Pressable
          style={styles.actionButton}
          accessibilityRole="button"
          accessibilityLabel="Comentarios"
          onPress={(e) => {
            e.stopPropagation();
            router.push(`/post/${post.id}`);
          }}>
          <Ionicons name="chatbubble-outline" size={18} color={Colors.textMuted} />
          <Text style={styles.actionText}>{post.commentCount}</Text>
        </Pressable>

        <Pressable
          style={styles.actionButton}
          accessibilityRole="button"
          accessibilityLabel={saved ? 'Quitar de guardados' : 'Guardar'}
          onPress={(e) => {
            e.stopPropagation();
            selection();
            actions.toggleBookmark(post.id);
          }}>
          <Ionicons name={saved ? 'bookmark' : 'bookmark-outline'} size={18} color={saved ? Colors.yellow : Colors.textMuted} />
        </Pressable>

        <Pressable
          style={styles.actionButton}
          accessibilityRole="button"
          accessibilityLabel="Compartir"
          onPress={(e) => {
            e.stopPropagation();
            handleShare();
          }}>
          <Ionicons name="share-outline" size={18} color={Colors.textMuted} />
        </Pressable>
      </View>
    </Pressable>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: Colors.surface,
    borderRadius: Radius.lg,
    borderWidth: 1,
    borderColor: Colors.borderSoft,
    padding: Spacing.lg,
    gap: Spacing.sm,
  },
  header: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  authorRow: { flexDirection: 'row', alignItems: 'center', gap: Spacing.sm, flexShrink: 1 },
  authorName: { ...Typography.bodyMedium, color: Colors.textPrimary },
  meta: { ...Typography.caption, color: Colors.textMuted },
  typeChip: { paddingVertical: 3, paddingHorizontal: 8, borderRadius: Radius.pill, backgroundColor: Colors.surfaceElevated },
  typeChipText: { ...Typography.caption, color: Colors.textSecondary },
  title: { ...Typography.h3, color: Colors.textPrimary },
  body: { ...Typography.body, color: Colors.textSecondary },
  visual: { height: 150, marginTop: 4 },
  tagsRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 6 },
  tag: { paddingVertical: 3, paddingHorizontal: 8, borderRadius: Radius.pill, backgroundColor: Colors.surfaceSecondary },
  tagText: { ...Typography.caption, color: Colors.cyan },
  actions: { flexDirection: 'row', alignItems: 'center', gap: Spacing.lg, marginTop: 4 },
  actionButton: { flexDirection: 'row', alignItems: 'center', gap: 4, minHeight: 32 },
  actionText: { ...Typography.caption, color: Colors.textMuted },
});
