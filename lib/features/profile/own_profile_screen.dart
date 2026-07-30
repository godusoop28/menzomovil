import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';
import '../home/post_card.dart';
import '../post/create_post_screen.dart';
import '../shared/menzo_avatar.dart';
import '../shared/segmented_tabs.dart';
import 'profile_wall_section.dart';

final myPostsProvider = FutureProvider.family.autoDispose(
  (ref, String userId) => ref.watch(postRepositoryProvider).byAuthor(userId),
);
final savedPostsProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(postRepositoryProvider).bookmarked(),
);

enum _ProfileTab { posts, wall, saved }

/// 1:1 con menzoweb/app/(app)/profile/page.tsx.
class OwnProfileScreen extends ConsumerStatefulWidget {
  const OwnProfileScreen({super.key});

  @override
  ConsumerState<OwnProfileScreen> createState() => _OwnProfileScreenState();
}

class _OwnProfileScreenState extends ConsumerState<OwnProfileScreen> {
  _ProfileTab _tab = _ProfileTab.posts;

  @override
  Widget build(BuildContext context) {
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
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      'assets/backgrounds/background-profile.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                  const Positioned.fill(
                    child: ColoredBox(color: Color(0x8007090D)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 24,
                      horizontal: 16,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MenzoAvatar(
                          name: profile.displayName,
                          avatarUri: profile.avatarUri,
                          gradient: gradientIdFromName(profile.avatarGradient),
                          size: 96,
                          level: profile.level,
                        ),
                        const SizedBox(height: 12),
                        Text(profile.displayName, style: AppTextStyles.h2()),
                        Text(
                          '@${profile.username} · Nivel ${profile.level}',
                          style: AppTextStyles.caption(),
                        ),
                        if (profile.bio != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            profile.bio!,
                            style: AppTextStyles.body(
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _Stat(
                              label: 'Seguidores',
                              value: profile.followers,
                              onTap: () => context.push(
                                '/connections/${profile.id}/followers',
                              ),
                            ),
                            _Stat(
                              label: 'Siguiendo',
                              value: profile.following,
                              onTap: () => context.push(
                                '/connections/${profile.id}/following',
                              ),
                            ),
                            _Stat(
                              label: 'Reputación',
                              value: profile.reputation,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SegmentedTabs<_ProfileTab>(
              value: _tab,
              options: _ProfileTab.values,
              onChanged: (t) => setState(() => _tab = t),
              labelBuilder: (t) => switch (t) {
                _ProfileTab.posts => 'Publicaciones',
                _ProfileTab.wall => 'Muro',
                _ProfileTab.saved => 'Guardados',
              },
            ),
            const SizedBox(height: 16),
            switch (_tab) {
              _ProfileTab.posts => posts.when(
                data: (page) => page.items.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Todavía no publicaste nada.',
                          style: AppTextStyles.body(color: AppColors.textMuted),
                        ),
                      )
                    : Column(
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
              _ProfileTab.wall => ProfileWallSection(profileId: profile.id),
              _ProfileTab.saved =>
                ref
                    .watch(savedPostsProvider)
                    .when(
                      data: (page) => page.items.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Text(
                                'No guardaste ninguna publicación todavía.',
                                style: AppTextStyles.body(
                                  color: AppColors.textMuted,
                                ),
                              ),
                            )
                          : Column(
                              children: page.items
                                  .map(
                                    (p) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: PostCard(post: p),
                                    ),
                                  )
                                  .toList(),
                            ),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, st) => Text(
                        'No pudimos cargar tus guardados.',
                        style: AppTextStyles.body(color: AppColors.coral),
                      ),
                    ),
            },
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const CreatePostScreen()),
        ),
        backgroundColor: AppColors.orange,
        child: const Icon(Icons.add, color: Colors.black),
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
