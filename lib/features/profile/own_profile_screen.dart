import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_text_styles.dart';
import '../home/post_card.dart';
import '../shared/menzo_avatar.dart';

final myPostsProvider = FutureProvider.family.autoDispose(
  (ref, String userId) => ref.watch(postRepositoryProvider).byAuthor(userId),
);

/// 1:1 con menzoweb/app/(app)/profile/page.tsx.
class OwnProfileScreen extends ConsumerWidget {
  const OwnProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authProvider).profile;
    if (profile == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final posts = ref.watch(myPostsProvider(profile.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(profile.displayName, style: AppTextStyles.h2()),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/profile/edit'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myPostsProvider(profile.id)),
        child: ListView(
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
            Center(child: Text(profile.displayName, style: AppTextStyles.h2())),
            Center(
              child: Text(
                '@${profile.username} · Nivel ${profile.level}',
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
                _Stat(
                  label: 'Seguidores',
                  value: profile.followers,
                  onTap: () =>
                      context.push('/connections/${profile.id}/followers'),
                ),
                _Stat(
                  label: 'Siguiendo',
                  value: profile.following,
                  onTap: () =>
                      context.push('/connections/${profile.id}/following'),
                ),
                _Stat(label: 'Reputación', value: profile.reputation),
              ],
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
              error: (e, st) => Text(
                'No pudimos cargar tus publicaciones.',
                style: AppTextStyles.body(color: AppColors.coral),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.onTap});
  final String label;
  final int value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text('$value', style: AppTextStyles.h3()),
          Text(label, style: AppTextStyles.caption()),
        ],
      ),
    );
  }
}
