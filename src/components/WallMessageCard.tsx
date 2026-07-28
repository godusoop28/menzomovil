import { Ionicons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { useEffect, useState } from 'react';
import { Pressable, StyleSheet, Text, TextInput, View } from 'react-native';

import { UserAvatar } from './UserAvatar';
import { useAppState } from '@/hooks/useAppState';
import { findUser, wallCommentsForMessage } from '@/store/selectors';
import { Colors, Radius, Spacing, Typography } from '@/theme';
import type { WallMessage } from '@/types';
import { relativeTime } from '@/utils/time';

export function WallMessageCard({ message }: { message: WallMessage }) {
  const { state, actions } = useAppState();
  const author = findUser(state.social, message.authorId);
  const [expanded, setExpanded] = useState(false);
  const [draft, setDraft] = useState('');

  const comments = wallCommentsForMessage(state.social, message.id);

  useEffect(() => {
    if (expanded) actions.loadWallComments(message.id);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [expanded, message.id]);

  if (!author) return null;

  function submitComment() {
    const trimmed = draft.trim();
    if (!trimmed) return;
    actions.addWallComment(message.id, trimmed);
    setDraft('');
  }

  return (
    <View style={styles.card}>
      <Pressable onPress={() => router.push(`/member/${author.id}`)}>
        <UserAvatar name={author.displayName} avatarUri={author.avatarUri} gradient={author.avatarGradient} size={38} level={author.level} />
      </Pressable>
      <View style={styles.content}>
        <View style={styles.headerRow}>
          <Text style={styles.author}>{author.displayName}</Text>
          <Text style={styles.time}>{relativeTime(message.createdAt)}</Text>
        </View>
        <Text style={styles.body}>{message.body}</Text>

        <Pressable onPress={() => setExpanded((v) => !v)} accessibilityRole="button">
          <Text style={styles.commentToggle}>
            {message.commentCount > 0 ? `${message.commentCount} comentarios` : 'Comentar'}
          </Text>
        </Pressable>

        {expanded && (
          <View style={styles.commentsWrap}>
            {comments.map((comment) => {
              const commentAuthor = findUser(state.social, comment.authorId);
              if (!commentAuthor) return null;
              return (
                <Pressable
                  key={comment.id}
                  style={styles.commentRow}
                  onPress={() => router.push(`/member/${commentAuthor.id}`)}>
                  <UserAvatar
                    name={commentAuthor.displayName}
                    avatarUri={commentAuthor.avatarUri}
                    gradient={commentAuthor.avatarGradient}
                    size={26}
                  />
                  <View style={styles.commentBubble}>
                    <Text style={styles.commentAuthor}>{commentAuthor.displayName}</Text>
                    <Text style={styles.commentBody}>{comment.body}</Text>
                    <View style={styles.commentFooter}>
                      <Text style={styles.commentTime}>{relativeTime(comment.createdAt)}</Text>
                      <Pressable
                        onPress={() => actions.toggleWallCommentLike(comment.id, message.id)}
                        style={styles.commentLikeButton}
                        accessibilityRole="button"
                        accessibilityLabel="Me gusta">
                        <Ionicons
                          name={comment.likedByMe ? 'heart' : 'heart-outline'}
                          size={13}
                          color={comment.likedByMe ? Colors.coral : Colors.textMuted}
                        />
                        {comment.likeCount > 0 && <Text style={styles.commentLikeCount}>{comment.likeCount}</Text>}
                      </Pressable>
                    </View>
                  </View>
                </Pressable>
              );
            })}

            <View style={styles.composer}>
              <TextInput
                value={draft}
                onChangeText={setDraft}
                placeholder="Escribe un comentario…"
                placeholderTextColor={Colors.textMuted}
                style={styles.composerInput}
              />
              <Pressable onPress={submitComment} disabled={!draft.trim()} style={styles.sendButton} accessibilityRole="button" accessibilityLabel="Enviar comentario">
                <Ionicons name="send" size={14} color={Colors.textOnAccent} />
              </Pressable>
            </View>
          </View>
        )}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    flexDirection: 'row',
    gap: Spacing.sm,
    backgroundColor: Colors.surface,
    borderRadius: Radius.md,
    borderWidth: 1,
    borderColor: Colors.borderSoft,
    padding: Spacing.md,
  },
  content: { flex: 1, gap: 2 },
  headerRow: { flexDirection: 'row', justifyContent: 'space-between' },
  author: { ...Typography.bodyMedium, color: Colors.textPrimary },
  time: { ...Typography.caption, color: Colors.textMuted },
  body: { ...Typography.body, color: Colors.textSecondary },
  commentToggle: { ...Typography.caption, color: Colors.cyan, fontWeight: '600', marginTop: 4 },
  commentsWrap: { gap: Spacing.sm, marginTop: Spacing.sm, borderTopWidth: 1, borderTopColor: Colors.borderSoft, paddingTop: Spacing.sm },
  commentRow: { flexDirection: 'row', gap: Spacing.xs },
  commentBubble: { flex: 1, backgroundColor: Colors.surfaceSecondary, borderRadius: Radius.sm, padding: Spacing.sm, gap: 2 },
  commentAuthor: { ...Typography.label, color: Colors.textPrimary, fontSize: 12 },
  commentBody: { ...Typography.caption, color: Colors.textSecondary },
  commentFooter: { flexDirection: 'row', alignItems: 'center', gap: Spacing.sm, marginTop: 2 },
  commentTime: { ...Typography.caption, color: Colors.textMuted, fontSize: 10 },
  commentLikeButton: { flexDirection: 'row', alignItems: 'center', gap: 3 },
  commentLikeCount: { ...Typography.caption, color: Colors.textMuted, fontSize: 10 },
  composer: { flexDirection: 'row', alignItems: 'center', gap: Spacing.xs },
  composerInput: {
    ...Typography.caption,
    flex: 1,
    color: Colors.textPrimary,
    backgroundColor: Colors.surfaceSecondary,
    borderRadius: 999,
    paddingHorizontal: Spacing.sm,
    paddingVertical: 6,
  },
  sendButton: {
    width: 26,
    height: 26,
    borderRadius: 13,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: Colors.orange,
  },
});
