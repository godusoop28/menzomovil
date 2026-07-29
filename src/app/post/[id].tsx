import { Ionicons } from '@expo/vector-icons';
import { router, useLocalSearchParams } from 'expo-router';
import { useEffect, useState } from 'react';
import { KeyboardAvoidingView, Pressable, ScrollView, Share, StyleSheet, Text, TextInput, View } from 'react-native';

import { AbstractArtwork } from '@/components/AbstractArtwork';
import { EmptyState } from '@/components/EmptyState';
import { GradientButton } from '@/components/GradientButton';
import { IconButton } from '@/components/IconButton';
import { PollCard } from '@/components/PollCard';
import { ScreenContainer } from '@/components/ScreenContainer';
import { UserAvatar } from '@/components/UserAvatar';
import { useAppState } from '@/hooks/useAppState';
import { useHaptics } from '@/hooks/useHaptics';
import { useKeyboardBehavior } from '@/hooks/useKeyboardOffset';
import { LOCAL_USER_ID } from '@/store/localUser';
import { commentsForPost, findEvent, findPost, findUser } from '@/store/selectors';
import { Colors, Radius, Spacing, Typography } from '@/theme';
import { relativeTime } from '@/utils/time';

export default function PostDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const { state, actions } = useAppState();
  const { light, selection, success } = useHaptics();
  const behavior = useKeyboardBehavior();
  const [commentDraft, setCommentDraft] = useState('');

  const post = findPost(state.social, id);

  useEffect(() => {
    if (id) actions.addRecentlyViewed({ kind: 'post', id, at: new Date().toISOString() });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id]);

  useEffect(() => {
    if (!id) return;
    actions.ensurePostLoaded(id);
    actions.loadPostComments(id);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id]);

  if (!post) {
    return (
      <ScreenContainer>
        <View style={styles.header}>
          <IconButton name="chevron-back" label="Volver" onPress={() => router.back()} />
        </View>
        <EmptyState title="Esta publicación ya no está disponible" preset="storm" />
      </ScreenContainer>
    );
  }

  const author = findUser(state.social, post.authorId);
  const liked = post.likes.includes(LOCAL_USER_ID);
  const saved = post.bookmarkedBy.includes(LOCAL_USER_ID);
  const comments = commentsForPost(state.social, post.id);
  const event = post.eventId ? findEvent(state.social, post.eventId) : undefined;

  function submitComment() {
    const trimmed = commentDraft.trim();
    if (!trimmed) return;
    actions.addComment(post!.id, trimmed);
    setCommentDraft('');
    success();
  }

  return (
    <ScreenContainer edges={['top', 'bottom']}>
      <View style={styles.header}>
        <IconButton name="chevron-back" label="Volver" onPress={() => router.back()} />
        <IconButton
          name="share-outline"
          label="Compartir"
          onPress={() => Share.share({ message: `${post.title ?? post.body.slice(0, 60)} — vía MENZO` })}
        />
      </View>

      <KeyboardAvoidingView behavior={behavior} style={styles.flex} keyboardVerticalOffset={100}>
        <ScrollView contentContainerStyle={styles.scroll} showsVerticalScrollIndicator={false}>
          {author && (
            <Pressable style={styles.authorRow} onPress={() => router.push(`/member/${author.id}`)}>
              <UserAvatar name={author.displayName} avatarUri={author.avatarUri} gradient={author.avatarGradient} size={48} showOnline online={author.isOnline} level={author.level} />
              <View>
                <Text style={styles.authorName}>{author.displayName}</Text>
                <Text style={styles.meta}>
                  Nivel {author.level} · {relativeTime(post.createdAt)}
                </Text>
              </View>
            </Pressable>
          )}

          {!!post.title && <Text style={styles.title}>{post.title}</Text>}
          <Text style={styles.body}>{post.body}</Text>

          {post.abstractVisual && (
            <AbstractArtwork preset={post.abstractVisual.preset} caption={post.abstractVisual.caption} style={styles.visual} />
          )}

          {post.type === 'poll' && <PollCard post={post} />}

          {event && (
            <View style={styles.eventCard}>
              <Text style={styles.eventTitle}>{event.title}</Text>
              <Text style={styles.eventMeta}>
                {event.date} · {event.time} · {event.kind}
              </Text>
              <GradientButton
                label={event.attendees.includes(LOCAL_USER_ID) ? 'Asistencia confirmada' : 'Confirmar asistencia'}
                onPress={() => actions.attendEvent(event.id)}
                gradient={event.attendees.includes(LOCAL_USER_ID) ? 'community' : 'fire'}
                size="md"
              />
            </View>
          )}

          {post.tags.length > 0 && (
            <View style={styles.tagsRow}>
              {post.tags.map((tag) => (
                <View key={tag} style={styles.tag}>
                  <Text style={styles.tagText}>#{tag}</Text>
                </View>
              ))}
            </View>
          )}

          <View style={styles.actionsRow}>
            <Pressable
              style={styles.actionButton}
              onPress={() => {
                light();
                actions.toggleLike(post.id);
              }}>
              <Ionicons name={liked ? 'heart' : 'heart-outline'} size={22} color={liked ? Colors.coral : Colors.textMuted} />
              <Text style={styles.actionText}>{post.likes.length}</Text>
            </Pressable>
            <Pressable
              style={styles.actionButton}
              onPress={() => {
                selection();
                actions.toggleBookmark(post.id);
              }}>
              <Ionicons name={saved ? 'bookmark' : 'bookmark-outline'} size={20} color={saved ? Colors.yellow : Colors.textMuted} />
              <Text style={styles.actionText}>{saved ? 'Guardado' : 'Guardar'}</Text>
            </Pressable>
          </View>

          <View style={styles.commentsSection}>
            <Text style={styles.commentsTitle}>Comentarios</Text>
            {comments.length === 0 ? (
              <EmptyState title="Sé el primero en comentar" preset="community" />
            ) : (
              comments.map((comment) => {
                const commentAuthor = findUser(state.social, comment.authorId);
                if (!commentAuthor) return null;
                return (
                  <Pressable
                    key={comment.id}
                    style={styles.commentRow}
                    onPress={() => router.push(`/member/${commentAuthor.id}`)}>
                    <UserAvatar name={commentAuthor.displayName} avatarUri={commentAuthor.avatarUri} gradient={commentAuthor.avatarGradient} size={34} level={commentAuthor.level} />
                    <View style={styles.commentBubble}>
                      <Text style={styles.commentAuthor}>{commentAuthor.displayName}</Text>
                      <Text style={styles.commentBody}>{comment.body}</Text>
                      <Text style={styles.commentTime}>{relativeTime(comment.createdAt)}</Text>
                    </View>
                  </Pressable>
                );
              })
            )}
          </View>
        </ScrollView>

        <View style={styles.commentInputRow}>
          <TextInput
            value={commentDraft}
            onChangeText={setCommentDraft}
            placeholder="Escribe algo…"
            placeholderTextColor={Colors.textMuted}
            style={styles.commentInput}
          />
          <IconButton name="send" label="Enviar comentario" onPress={submitComment} variant="surface" />
        </View>
      </KeyboardAvoidingView>
    </ScreenContainer>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  header: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: Spacing.md, paddingTop: Spacing.xs },
  scroll: { padding: Spacing.lg, gap: Spacing.md, paddingBottom: Spacing.xl },
  authorRow: { flexDirection: 'row', alignItems: 'center', gap: Spacing.sm },
  authorName: { ...Typography.bodyMedium, color: Colors.textPrimary },
  meta: { ...Typography.caption, color: Colors.textMuted },
  title: { ...Typography.h2, color: Colors.textPrimary },
  body: { ...Typography.body, color: Colors.textSecondary },
  visual: { height: 200 },
  eventCard: {
    backgroundColor: Colors.surfaceSecondary,
    borderRadius: Radius.lg,
    borderWidth: 1,
    borderColor: Colors.borderSoft,
    padding: Spacing.lg,
    gap: Spacing.sm,
  },
  eventTitle: { ...Typography.h3, color: Colors.textPrimary },
  eventMeta: { ...Typography.caption, color: Colors.textMuted },
  tagsRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 6 },
  tag: { paddingVertical: 3, paddingHorizontal: 8, borderRadius: Radius.pill, backgroundColor: Colors.surfaceSecondary },
  tagText: { ...Typography.caption, color: Colors.cyan },
  actionsRow: { flexDirection: 'row', gap: Spacing.xl, borderTopWidth: 1, borderTopColor: Colors.borderSoft, paddingTop: Spacing.md },
  actionButton: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  actionText: { ...Typography.bodyMedium, color: Colors.textSecondary },
  commentsSection: { gap: Spacing.sm, marginTop: Spacing.sm },
  commentsTitle: { ...Typography.h3, color: Colors.textPrimary },
  commentRow: { flexDirection: 'row', gap: Spacing.sm },
  commentBubble: { flex: 1, backgroundColor: Colors.surface, borderRadius: Radius.md, borderWidth: 1, borderColor: Colors.borderSoft, padding: Spacing.sm, gap: 2 },
  commentAuthor: { ...Typography.label, color: Colors.textPrimary },
  commentBody: { ...Typography.body, color: Colors.textSecondary },
  commentTime: { ...Typography.caption, color: Colors.textMuted },
  commentInputRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.sm,
    paddingHorizontal: Spacing.lg,
    paddingVertical: Spacing.sm,
    borderTopWidth: 1,
    borderTopColor: Colors.borderSoft,
  },
  commentInput: {
    flex: 1,
    ...Typography.body,
    color: Colors.textPrimary,
    backgroundColor: Colors.surfaceSecondary,
    borderRadius: Radius.pill,
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
  },
});
