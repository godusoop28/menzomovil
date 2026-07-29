import { Ionicons } from '@expo/vector-icons';
import * as FileSystem from 'expo-file-system/legacy';
import { Image } from 'expo-image';
import * as ImagePicker from 'expo-image-picker';
import { router } from 'expo-router';
import { useEffect, useRef, useState } from 'react';
import { ActivityIndicator, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';

import { UserAvatar } from './UserAvatar';
import { useAppState } from '@/hooks/useAppState';
import { useToast } from '@/hooks/useToast';
import { useWallCommentsSocket } from '@/hooks/useWallCommentsSocket';
import { getMyRealId } from '@/services/api';
import { LOCAL_USER_ID } from '@/store/localUser';
import { findUser, wallCommentsForMessage } from '@/store/selectors';
import { Colors, Radius, Spacing, Typography } from '@/theme';
import type { WallComment, WallMessage } from '@/types';
import { relativeTime } from '@/utils/time';

export function WallMessageCard({ message }: { message: WallMessage }) {
  const { state, actions } = useAppState();
  const showToast = useToast();
  const author = findUser(state.social, message.authorId);
  const [expanded, setExpanded] = useState(false);
  const [draft, setDraft] = useState('');
  const [pendingImage, setPendingImage] = useState<string | undefined>();
  const [replyTo, setReplyTo] = useState<WallComment | null>(null);
  const [sending, setSending] = useState(false);
  const [hasMore, setHasMore] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const pageRef = useRef(0);

  const comments = wallCommentsForMessage(state.social, message.id);
  const isWallOwner = message.profileId === getMyRealId();

  useWallCommentsSocket(expanded ? message.id : undefined);

  useEffect(() => {
    if (!expanded) return;
    pageRef.current = 0;
    actions.loadWallComments(message.id, 0).then((result) => setHasMore(!!result?.hasNext));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [expanded, message.id]);

  if (!author) return null;

  async function pickImage() {
    const permission = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (!permission.granted) {
      showToast('Necesitamos acceso a tus fotos para adjuntar una imagen.');
      return;
    }
    const result = await ImagePicker.launchImageLibraryAsync({ mediaTypes: ['images'], quality: 0.8 });
    if (result.canceled || !result.assets?.[0]) return;
    try {
      const dir = `${FileSystem.documentDirectory}menzo-wall/`;
      await FileSystem.makeDirectoryAsync(dir, { intermediates: true }).catch(() => {});
      const dest = `${dir}img-${Date.now()}.jpg`;
      await FileSystem.copyAsync({ from: result.assets[0].uri, to: dest });
      setPendingImage(dest);
    } catch {
      setPendingImage(result.assets[0].uri);
    }
  }

  async function loadMore() {
    setLoadingMore(true);
    try {
      const nextPage = pageRef.current + 1;
      const result = await actions.loadWallComments(message.id, nextPage);
      pageRef.current = nextPage;
      setHasMore(!!result?.hasNext);
    } finally {
      setLoadingMore(false);
    }
  }

  async function submitComment() {
    const trimmed = draft.trim();
    if (!trimmed && !pendingImage) return;
    setSending(true);
    try {
      await actions.addWallComment(message.id, trimmed, { imageUri: pendingImage, parentCommentId: replyTo?.id });
      setDraft('');
      setPendingImage(undefined);
      setReplyTo(null);
    } finally {
      setSending(false);
    }
  }

  function parentAuthorName(comment: WallComment): string | null {
    if (!comment.parentCommentId) return null;
    const parent = comments.find((c) => c.id === comment.parentCommentId);
    if (!parent) return null;
    return findUser(state.social, parent.authorId)?.displayName ?? null;
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
        {!!message.body && <Text style={styles.body}>{message.body}</Text>}
        {message.imageUri && <Image source={{ uri: message.imageUri }} style={styles.messageImage} contentFit="cover" />}

        <Pressable onPress={() => setExpanded((v) => !v)} accessibilityRole="button">
          <Text style={styles.commentToggle}>
            {message.commentCount > 0 ? `${message.commentCount} comentarios` : 'Comentar'}
          </Text>
        </Pressable>

        {expanded && (
          <View style={styles.commentsWrap}>
            {hasMore && (
              <Pressable onPress={loadMore} disabled={loadingMore} style={styles.loadMoreButton}>
                {loadingMore ? (
                  <ActivityIndicator size="small" color={Colors.cyan} />
                ) : (
                  <Text style={styles.loadMoreLabel}>Cargar comentarios anteriores</Text>
                )}
              </Pressable>
            )}

            {comments.map((comment) => {
              const commentAuthor = findUser(state.social, comment.authorId);
              if (!commentAuthor) return null;
              const isMine = comment.authorId === LOCAL_USER_ID;
              const canDelete = isMine || isWallOwner;
              const replyingToName = parentAuthorName(comment);
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
                    {replyingToName && <Text style={styles.replyingTo}>Respondiendo a @{replyingToName}</Text>}
                    <Text style={styles.commentAuthor}>{commentAuthor.displayName}</Text>
                    {!!comment.body && <Text style={styles.commentBody}>{comment.body}</Text>}
                    {comment.imageUri && (
                      <Image source={{ uri: comment.imageUri }} style={styles.commentImage} contentFit="cover" />
                    )}
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
                      <Pressable onPress={() => setReplyTo(comment)} accessibilityRole="button">
                        <Text style={styles.replyButton}>Responder</Text>
                      </Pressable>
                      {canDelete && (
                        <Pressable
                          onPress={() => actions.deleteWallComment(comment.id, message.id)}
                          accessibilityRole="button">
                          <Text style={styles.deleteButton}>Borrar</Text>
                        </Pressable>
                      )}
                    </View>
                  </View>
                </Pressable>
              );
            })}

            {replyTo && (
              <View style={styles.replyPill}>
                <Text style={styles.replyPillText}>
                  Respondiendo a @{findUser(state.social, replyTo.authorId)?.displayName ?? '…'}
                </Text>
                <Pressable onPress={() => setReplyTo(null)} accessibilityRole="button" accessibilityLabel="Cancelar respuesta">
                  <Ionicons name="close" size={14} color={Colors.textMuted} />
                </Pressable>
              </View>
            )}

            {pendingImage && (
              <View style={styles.previewRow}>
                <Image source={{ uri: pendingImage }} style={styles.previewImage} contentFit="cover" />
                <Pressable onPress={() => setPendingImage(undefined)} accessibilityRole="button" accessibilityLabel="Quitar imagen">
                  <Ionicons name="close-circle" size={18} color={Colors.coral} />
                </Pressable>
              </View>
            )}

            <View style={styles.composer}>
              <Pressable onPress={pickImage} style={styles.attachButton} accessibilityRole="button" accessibilityLabel="Adjuntar imagen">
                <Ionicons name="image-outline" size={18} color={Colors.textMuted} />
              </Pressable>
              <TextInput
                value={draft}
                onChangeText={setDraft}
                placeholder={replyTo ? 'Escribe tu respuesta…' : 'Escribe un comentario…'}
                placeholderTextColor={Colors.textMuted}
                style={styles.composerInput}
              />
              <Pressable
                onPress={submitComment}
                disabled={(!draft.trim() && !pendingImage) || sending}
                style={styles.sendButton}
                accessibilityRole="button"
                accessibilityLabel="Enviar comentario">
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
  messageImage: { width: '100%', height: 180, borderRadius: Radius.sm, marginTop: Spacing.xs },
  commentToggle: { ...Typography.caption, color: Colors.cyan, fontWeight: '600', marginTop: 4 },
  commentsWrap: { gap: Spacing.sm, marginTop: Spacing.sm, borderTopWidth: 1, borderTopColor: Colors.borderSoft, paddingTop: Spacing.sm },
  loadMoreButton: { alignSelf: 'center', paddingVertical: 4 },
  loadMoreLabel: { ...Typography.caption, color: Colors.cyan, fontWeight: '600' },
  commentRow: { flexDirection: 'row', gap: Spacing.xs },
  commentBubble: { flex: 1, backgroundColor: Colors.surfaceSecondary, borderRadius: Radius.sm, padding: Spacing.sm, gap: 2 },
  replyingTo: { ...Typography.caption, color: Colors.textMuted, fontSize: 10 },
  commentAuthor: { ...Typography.label, color: Colors.textPrimary, fontSize: 12 },
  commentBody: { ...Typography.caption, color: Colors.textSecondary },
  commentImage: { width: '100%', height: 140, borderRadius: Radius.sm, marginTop: 4 },
  commentFooter: { flexDirection: 'row', alignItems: 'center', gap: Spacing.sm, marginTop: 2 },
  commentTime: { ...Typography.caption, color: Colors.textMuted, fontSize: 10 },
  commentLikeButton: { flexDirection: 'row', alignItems: 'center', gap: 3 },
  commentLikeCount: { ...Typography.caption, color: Colors.textMuted, fontSize: 10 },
  replyButton: { ...Typography.caption, color: Colors.textMuted, fontSize: 10, fontWeight: '600' },
  deleteButton: { ...Typography.caption, color: Colors.coral, fontSize: 10, fontWeight: '600' },
  replyPill: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: Colors.surfaceSecondary,
    borderRadius: Radius.sm,
    paddingHorizontal: Spacing.sm,
    paddingVertical: 6,
  },
  replyPillText: { ...Typography.caption, color: Colors.textMuted, fontSize: 11 },
  previewRow: { flexDirection: 'row', alignItems: 'center', gap: Spacing.xs },
  previewImage: { width: 44, height: 44, borderRadius: Radius.sm },
  composer: { flexDirection: 'row', alignItems: 'center', gap: Spacing.xs },
  attachButton: { width: 26, height: 26, alignItems: 'center', justifyContent: 'center' },
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
