import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/post_models.dart';
import '../post/post_block_renderer.dart';
import '../shared/menzo_avatar.dart';

/// 1:1 con menzoweb/components/PostCard.tsx (versión simplificada — sin AbstractArtwork
/// generado, se usa un degradado de marca de respaldo cuando no hay imagen).
///
/// `fullContent` distingue la tarjeta compacta del feed (preview truncado a 4 líneas, portada
/// única) de la vista de detalle (`PostDetailScreen`, que reusa este mismo widget en vez de
/// duplicar el header/like/bookmark row) — ahí sí se ve el post entero vía [PostBlockRenderer].
class PostCard extends ConsumerStatefulWidget {
  const PostCard({super.key, required this.post, this.fullContent = false});
  final Post post;
  final bool fullContent;

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  late Post _post = widget.post;
  bool _voting = false;

  Future<void> _toggleLike() async {
    final repo = ref.read(postRepositoryProvider);
    final wasLiked = _post.likedByMe;
    setState(
      () => _post = _post.copyWith(
        likedByMe: !wasLiked,
        likeCount: _post.likeCount + (wasLiked ? -1 : 1),
      ),
    );
    try {
      if (wasLiked) {
        await repo.unlike(_post.id);
      } else {
        await repo.like(_post.id);
      }
    } catch (_) {
      setState(
        () => _post = _post.copyWith(
          likedByMe: wasLiked,
          likeCount: widget.post.likeCount,
        ),
      );
    }
  }

  Future<void> _toggleBookmark() async {
    final repo = ref.read(postRepositoryProvider);
    final wasBookmarked = _post.bookmarkedByMe;
    setState(() => _post = _post.copyWith(bookmarkedByMe: !wasBookmarked));
    try {
      if (wasBookmarked) {
        await repo.unbookmark(_post.id);
      } else {
        await repo.bookmark(_post.id);
      }
    } catch (_) {
      setState(() => _post = _post.copyWith(bookmarkedByMe: wasBookmarked));
    }
  }

  Future<void> _vote(String optionId) async {
    if (_voting) return;
    setState(() => _voting = true);
    try {
      final updated = await ref
          .read(postRepositoryProvider)
          .vote(_post.id, optionId);
      if (mounted) setState(() => _post = updated);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _voting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    // Preview compacto para la tarjeta, no el post completo — `post.body` ya es un excerpt de
    // solo texto derivado server-side de `blocks` (ver PostService.deriveBodyFromBlocks en el
    // backend), así que sigue sirviendo tal cual acá. La portada usa la primera imagen/gif de los
    // bloques si no hay `imageUri` legacy — el resto de los bloques solo se ven al entrar al post
    // (ver PostBlockRenderer en post_detail_screen.dart).
    final coverImage =
        post.imageUri ??
        post.blocks
            .firstWhere(
              (b) => b.type == PostBlockType.image || b.type == PostBlockType.gif,
              orElse: () => const PostBlock(id: '', type: PostBlockType.divider),
            )
            .url;
    return GestureDetector(
      onTap: widget.fullContent ? null : () => context.push('/post/${post.id}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                MenzoAvatar(
                  name: post.author.displayName,
                  avatarUri: post.author.avatarUri,
                  size: 32,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    post.author.displayName,
                    style: AppTextStyles.label(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (post.title != null)
              Text(post.title!, style: AppTextStyles.h3()),
            if (widget.fullContent && post.blocks.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: PostBlockRenderer(blocks: post.blocks),
              )
            else
              Text(
                post.body,
                style: AppTextStyles.body(color: AppColors.textSecondary),
                maxLines: widget.fullContent ? null : 4,
                overflow: widget.fullContent ? TextOverflow.visible : TextOverflow.ellipsis,
              ),
            if (post.type == PostType.poll && post.pollOptions.isNotEmpty) ...[
              const SizedBox(height: 10),
              _PollOptions(
                options: post.pollOptions,
                disabled: _voting,
                onVote: _vote,
              ),
            ] else if (!(widget.fullContent && post.blocks.isNotEmpty) && coverImage != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: CachedNetworkImage(
                  imageUrl: coverImage,
                  height: widget.fullContent ? null : 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ] else if (!(widget.fullContent && post.blocks.isNotEmpty) && coverImage == null)
              Container(
                margin: const EdgeInsets.only(top: 10),
                height: 6,
                decoration: BoxDecoration(
                  gradient: AppGradients.linear(
                    gradientIdFromName(post.gradient),
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                GestureDetector(
                  onTap: _toggleLike,
                  child: Row(
                    children: [
                      Icon(
                        post.likedByMe ? Icons.favorite : Icons.favorite_border,
                        size: 18,
                        color: post.likedByMe
                            ? AppColors.coral
                            : AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text('${post.likeCount}', style: AppTextStyles.caption()),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(
                  Icons.mode_comment_outlined,
                  size: 17,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Text('${post.commentCount}', style: AppTextStyles.caption()),
                const Spacer(),
                GestureDetector(
                  onTap: _toggleBookmark,
                  child: Icon(
                    post.bookmarkedByMe
                        ? Icons.bookmark
                        : Icons.bookmark_border,
                    size: 18,
                    color: post.bookmarkedByMe
                        ? AppColors.orange
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 1:1 con menzoweb/components/PollCard.tsx — barra de progreso por opción, deshabilitada tras
/// votar (`votedByMe` en cualquier opción implica que ya voté en esta encuesta).
class _PollOptions extends StatelessWidget {
  const _PollOptions({
    required this.options,
    required this.disabled,
    required this.onVote,
  });
  final List<PollOption> options;
  final bool disabled;
  final ValueChanged<String> onVote;

  @override
  Widget build(BuildContext context) {
    final totalVotes = options.fold<int>(0, (sum, o) => sum + o.voteCount);
    final alreadyVoted = options.any((o) => o.votedByMe);
    return Column(
      children: options.map((option) {
        final ratio = totalVotes == 0 ? 0.0 : option.voteCount / totalVotes;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: (disabled || alreadyVoted) ? null : () => onVote(option.id),
            child: Stack(
              children: [
                Container(
                  height: 40,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                if (alreadyVoted)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: ratio.clamp(0.0, 1.0),
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: option.votedByMe
                              ? AppColors.orange.withValues(alpha: 0.5)
                              : AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          option.label,
                          style: AppTextStyles.body(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (alreadyVoted)
                        Text(
                          '${(ratio * 100).round()}%',
                          style: AppTextStyles.caption(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
