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
import '../shared/menzo_avatar.dart';

/// 1:1 con menzoweb/components/PostCard.tsx (versión simplificada — sin AbstractArtwork
/// generado, se usa un degradado de marca de respaldo cuando no hay imagen).
class PostCard extends ConsumerStatefulWidget {
  const PostCard({super.key, required this.post});
  final Post post;

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  late Post _post = widget.post;

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

  @override
  Widget build(BuildContext context) {
    final post = _post;
    return GestureDetector(
      onTap: () => context.push('/post/${post.id}'),
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
            Text(
              post.body,
              style: AppTextStyles.body(color: AppColors.textSecondary),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            if (post.imageUri != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: CachedNetworkImage(
                  imageUrl: post.imageUri!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ] else
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
              ],
            ),
          ],
        ),
      ),
    );
  }
}
