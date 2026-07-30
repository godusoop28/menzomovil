import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/user_models.dart';
import '../home/post_card.dart';
import '../shared/gradient_button.dart';
import '../shared/menzo_avatar.dart';
import '../shared/menzo_toast.dart';

final memberProfileProvider = FutureProvider.family.autoDispose(
  (ref, String id) => ref.watch(userRepositoryProvider).getById(id),
);
final memberPostsProvider = FutureProvider.family.autoDispose(
  (ref, String id) => ref.watch(postRepositoryProvider).byAuthor(id),
);

/// 1:1 con menzoweb/app/(app)/member/[id]/page.tsx.
class MemberProfileScreen extends ConsumerStatefulWidget {
  const MemberProfileScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<MemberProfileScreen> createState() =>
      _MemberProfileScreenState();
}

class _MemberProfileScreenState extends ConsumerState<MemberProfileScreen> {
  bool _followBusy = false;

  Future<void> _toggleFollow(UserProfile profile) async {
    setState(() => _followBusy = true);
    try {
      if (profile.followedByMe) {
        await ref.read(userRepositoryProvider).unfollow(widget.id);
      } else {
        await ref.read(userRepositoryProvider).follow(widget.id);
      }
      ref.invalidate(memberProfileProvider(widget.id));
    } catch (_) {
      if (mounted)
        showMenzoToast(context, 'No pudimos actualizar el seguimiento.');
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(memberProfileProvider(widget.id));
    return Scaffold(
      appBar: AppBar(
        title: profileAsync.maybeWhen(
          data: (p) => Text(p.displayName, style: AppTextStyles.h2()),
          orElse: () => const SizedBox.shrink(),
        ),
      ),
      body: profileAsync.when(
        data: (profile) {
          final posts = ref.watch(memberPostsProvider(widget.id));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: MenzoAvatar(
                  name: profile.displayName,
                  avatarUri: profile.avatarUri,
                  gradient: gradientIdFromName(profile.avatarGradient),
                  size: 96,
                  level: profile.level,
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(profile.displayName, style: AppTextStyles.h2()),
              ),
              Center(
                child: Text(
                  '@${profile.username}',
                  style: AppTextStyles.caption(),
                ),
              ),
              if (profile.bio != null) ...[
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    profile.bio!,
                    style: AppTextStyles.body(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  GestureDetector(
                    onTap: () =>
                        context.push('/connections/${widget.id}/followers'),
                    child: Column(
                      children: [
                        Text('${profile.followers}', style: AppTextStyles.h3()),
                        const Text('Seguidores'),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () =>
                        context.push('/connections/${widget.id}/following'),
                    child: Column(
                      children: [
                        Text('${profile.following}', style: AppTextStyles.h3()),
                        const Text('Siguiendo'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GradientButton(
                label: profile.followedByMe ? 'Dejar de seguir' : 'Seguir',
                loading: _followBusy,
                onPressed: () => _toggleFollow(profile),
              ),
              const SizedBox(height: 20),
              Text('Publicaciones', style: AppTextStyles.label()),
              const SizedBox(height: 10),
              posts.when(
                data: (page) => Column(
                  children: page.items
                      .map(
                        (p) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: PostCard(post: p),
                        ),
                      )
                      .toList(),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => const SizedBox.shrink(),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Text(
            'No pudimos cargar este perfil.',
            style: AppTextStyles.body(color: AppColors.coral),
          ),
        ),
      ),
    );
  }
}
