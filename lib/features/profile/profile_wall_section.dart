import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/user_models.dart';
import '../shared/menzo_avatar.dart';
import '../shared/menzo_toast.dart';

final wallProvider = FutureProvider.family.autoDispose(
  (ref, String userId) => ref.watch(userRepositoryProvider).wall(userId),
);

/// 1:1 con menzoweb/components/WallComposer.tsx + WallMessageCard.tsx — muro de un perfil,
/// compartido entre el perfil propio y el de otra persona.
class ProfileWallSection extends ConsumerStatefulWidget {
  const ProfileWallSection({super.key, required this.profileId});
  final String profileId;

  @override
  ConsumerState<ProfileWallSection> createState() => _ProfileWallSectionState();
}

class _ProfileWallSectionState extends ConsumerState<ProfileWallSection> {
  final _controller = TextEditingController();
  bool _posting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final body = _controller.text.trim();
    if (body.isEmpty) return;
    setState(() => _posting = true);
    try {
      await ref.read(userRepositoryProvider).postWall(widget.profileId, body);
      _controller.clear();
      ref.invalidate(wallProvider(widget.profileId));
    } catch (_) {
      if (mounted) showMenzoToast(context, 'No pudimos publicar en el muro.');
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wall = ref.watch(wallProvider(widget.profileId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Muro', style: AppTextStyles.label()),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                style: AppTextStyles.body(),
                decoration: const InputDecoration(
                  hintText: 'Escribe algo en este muro…',
                ),
                onSubmitted: (_) => _post(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _posting ? null : _post,
              icon: const Icon(Icons.send),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        wall.when(
          data: (page) => page.items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Todavía no hay nada en este muro.',
                    style: AppTextStyles.body(color: AppColors.textMuted),
                  ),
                )
              : Column(
                  children: page.items
                      .map((m) => _WallMessageTile(message: m))
                      .toList(),
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _WallMessageTile extends StatelessWidget {
  const _WallMessageTile({required this.message});
  final WallMessage message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MenzoAvatar(
            name: message.author.displayName,
            avatarUri: message.author.avatarUri,
            size: 32,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.author.displayName,
                  style: AppTextStyles.caption(color: AppColors.cyan),
                ),
                Text(message.body, style: AppTextStyles.body()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
