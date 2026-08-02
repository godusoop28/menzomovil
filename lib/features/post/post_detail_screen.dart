import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/post_models.dart';
import '../home/post_card.dart';
import '../shared/menzo_avatar.dart';
import '../shared/menzo_toast.dart';

final postProvider = FutureProvider.family.autoDispose(
  (ref, String id) => ref.watch(postRepositoryProvider).getById(id),
);
final postCommentsProvider = FutureProvider.family.autoDispose(
  (ref, String id) => ref.watch(postRepositoryProvider).comments(id),
);

/// 1:1 con menzoweb/app/(app)/post/[id]/page.tsx — detalle + comentarios + votación de encuesta.
class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _commentController = TextEditingController();
  bool _sending = false;

  Future<void> _addComment() async {
    final body = _commentController.text.trim();
    if (body.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(postRepositoryProvider).addComment(widget.id, body);
      _commentController.clear();
      ref.invalidate(postCommentsProvider(widget.id));
      ref.invalidate(postProvider(widget.id));
    } catch (_) {
      if (mounted)
        showMenzoToast(context, 'No pudimos publicar tu comentario.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _vote(String optionId) async {
    try {
      await ref.read(postRepositoryProvider).vote(widget.id, optionId);
      ref.invalidate(postProvider(widget.id));
    } catch (_) {
      if (mounted) showMenzoToast(context, 'No pudimos registrar tu voto.');
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final post = ref.watch(postProvider(widget.id));
    final comments = ref.watch(postCommentsProvider(widget.id));

    return Scaffold(
      appBar: AppBar(),
      body: Column(
        children: [
          Expanded(
            child: post.when(
              data: (p) => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  PostCard(post: p, fullContent: true),
                  if (p.type == PostType.poll && p.pollOptions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ...p.pollOptions.map((o) {
                      final total = p.pollOptions.fold<int>(
                        0,
                        (sum, e) => sum + e.voteCount,
                      );
                      final pct = total == 0 ? 0.0 : o.voteCount / total;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GestureDetector(
                          onTap: () => _vote(o.id),
                          child: Stack(
                            children: [
                              Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceSecondary,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.md,
                                  ),
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: pct,
                                child: Container(
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: o.votedByMe
                                        ? AppColors.cyan
                                        : AppColors.surfaceSoft,
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.md,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          o.label,
                                          style: AppTextStyles.body(),
                                        ),
                                      ),
                                      Text(
                                        '${(pct * 100).round()}%',
                                        style: AppTextStyles.caption(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                  const Divider(height: 32, color: AppColors.borderSoft),
                  Text('Comentarios', style: AppTextStyles.label()),
                  const SizedBox(height: 10),
                  comments.when(
                    data: (page) => Column(
                      children: page.items
                          .map(
                            (c) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  MenzoAvatar(
                                    name: c.author.displayName,
                                    avatarUri: c.author.avatarUri,
                                    size: 32,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceSecondary,
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.md,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            c.author.displayName,
                                            style: AppTextStyles.caption(
                                              color: AppColors.cyan,
                                            ),
                                          ),
                                          Text(
                                            c.body,
                                            style: AppTextStyles.body(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, st) => const SizedBox.shrink(),
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(
                child: Text(
                  'No pudimos cargar esta publicación.',
                  style: AppTextStyles.body(color: AppColors.coral),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        hintText: 'Escribe un comentario…',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sending ? null : _addComment,
                    icon: const Icon(Icons.send),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.orange,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
