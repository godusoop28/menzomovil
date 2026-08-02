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
    // La portada usa la primera imagen/gif de los bloques si no hay `imageUri` legacy — el resto
    // de los bloques solo se ven al entrar al post (ver PostBlockRenderer en
    // post_detail_screen.dart).
    final coverImage =
        post.imageUri ??
        post.blocks
            .firstWhere(
              (b) => b.type == PostBlockType.image || b.type == PostBlockType.gif,
              orElse: () => const PostBlock(id: '', type: PostBlockType.divider),
            )
            .url;

    if (widget.fullContent) {
      return _FullPostCard(
        post: post,
        coverImage: coverImage,
        voting: _voting,
        onVote: _vote,
        onToggleLike: _toggleLike,
        onToggleBookmark: _toggleBookmark,
      );
    }
    return _CompactPostCard(
      post: post,
      coverImage: coverImage,
      voting: _voting,
      onVote: _vote,
      onToggleLike: _toggleLike,
      onToggleBookmark: _toggleBookmark,
    );
  }
}

/// Tarjeta estilo revista del feed — 1:1 con la versión web rediseñada de PostCard.tsx: portada
/// a sangre completa (foto real, o un panel de color plano cuando no hay ninguna) con
/// título/tipo superpuestos sobre un degradado oscuro, en vez de la tarjeta plana de antes.
class _CompactPostCard extends StatelessWidget {
  const _CompactPostCard({
    required this.post,
    required this.coverImage,
    required this.voting,
    required this.onVote,
    required this.onToggleLike,
    required this.onToggleBookmark,
  });

  final Post post;
  final String? coverImage;
  final bool voting;
  final ValueChanged<String> onVote;
  final VoidCallback onToggleLike;
  final VoidCallback onToggleBookmark;

  @override
  Widget build(BuildContext context) {
    final gradientId = gradientIdFromName(post.gradient);
    return GestureDetector(
      onTap: () => context.push('/post/${post.id}'),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 180,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (coverImage != null)
                    CachedNetworkImage(imageUrl: coverImage!, fit: BoxFit.cover)
                  else
                    DecoratedBox(
                      decoration: BoxDecoration(gradient: AppGradients.linear(gradientId)),
                    ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.15),
                          Colors.black.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (post.type != PostType.text)
                          Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(
                              _typeLabel(post.type),
                              style: AppTextStyles.caption(color: Colors.white).copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        if (post.title != null)
                          Text(
                            post.title!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.h3(
                              color: Colors.white,
                            ).copyWith(fontWeight: FontWeight.bold),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      MenzoAvatar(
                        name: post.author.displayName,
                        avatarUri: post.author.avatarUri,
                        gradient: gradientIdFromName(post.author.avatarGradient),
                        size: 30,
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
                  const SizedBox(height: 8),
                  Text(
                    post.body,
                    style: AppTextStyles.body(color: AppColors.textSecondary),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (post.type == PostType.poll && post.pollOptions.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _PollOptions(options: post.pollOptions, disabled: voting, onVote: onVote),
                  ],
                  const SizedBox(height: 10),
                  _PostActionsRow(
                    post: post,
                    onToggleLike: onToggleLike,
                    onToggleBookmark: onToggleBookmark,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vista de detalle — sin el header de portada a sangre completa (acá se lee el post entero, no
/// se está hojeando el feed), pero con el mismo tratamiento de bloques/acciones.
class _FullPostCard extends StatelessWidget {
  const _FullPostCard({
    required this.post,
    required this.coverImage,
    required this.voting,
    required this.onVote,
    required this.onToggleLike,
    required this.onToggleBookmark,
  });

  final Post post;
  final String? coverImage;
  final bool voting;
  final ValueChanged<String> onVote;
  final VoidCallback onToggleLike;
  final VoidCallback onToggleBookmark;

  @override
  Widget build(BuildContext context) {
    final hasBlocks = post.blocks.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MenzoAvatar(
                name: post.author.displayName,
                avatarUri: post.author.avatarUri,
                gradient: gradientIdFromName(post.author.avatarGradient),
                size: 34,
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
          if (post.title != null) Text(post.title!, style: AppTextStyles.h3()),
          if (hasBlocks)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: PostBlockRenderer(blocks: post.blocks),
            )
          else
            Text(
              post.body,
              style: AppTextStyles.body(color: AppColors.textSecondary),
            ),
          if (post.type == PostType.poll && post.pollOptions.isNotEmpty) ...[
            const SizedBox(height: 10),
            _PollOptions(options: post.pollOptions, disabled: voting, onVote: onVote),
          ] else if (!hasBlocks && coverImage != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: CachedNetworkImage(
                imageUrl: coverImage!,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
          const SizedBox(height: 10),
          _PostActionsRow(post: post, onToggleLike: onToggleLike, onToggleBookmark: onToggleBookmark),
        ],
      ),
    );
  }
}

String _typeLabel(PostType type) => switch (type) {
  PostType.image => 'Imagen',
  PostType.poll => 'Encuesta',
  PostType.question => 'Pregunta',
  PostType.event => 'Evento',
  PostType.text => '',
};

class _PostActionsRow extends StatelessWidget {
  const _PostActionsRow({
    required this.post,
    required this.onToggleLike,
    required this.onToggleBookmark,
  });

  final Post post;
  final VoidCallback onToggleLike;
  final VoidCallback onToggleBookmark;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onToggleLike,
          child: Row(
            children: [
              Icon(
                post.likedByMe ? Icons.favorite : Icons.favorite_border,
                size: 18,
                color: post.likedByMe ? AppColors.coral : AppColors.textMuted,
              ),
              const SizedBox(width: 4),
              Text('${post.likeCount}', style: AppTextStyles.caption()),
            ],
          ),
        ),
        const SizedBox(width: 16),
        const Icon(Icons.mode_comment_outlined, size: 17, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text('${post.commentCount}', style: AppTextStyles.caption()),
        const Spacer(),
        GestureDetector(
          onTap: onToggleBookmark,
          child: Icon(
            post.bookmarkedByMe ? Icons.bookmark : Icons.bookmark_border,
            size: 18,
            color: post.bookmarkedByMe ? AppColors.orange : AppColors.textMuted,
          ),
        ),
      ],
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
