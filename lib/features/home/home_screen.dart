import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/chat_models.dart';
import '../../data/models/community_models.dart';
import '../post/create_post_screen.dart';
import '../shared/app_shell.dart';
import '../shared/menzo_avatar.dart';
import 'post_card.dart';

final communityConfigProvider = FutureProvider(
  (ref) => ref.watch(communityRepositoryProvider).config(),
);
final liveRoomsProvider = FutureProvider(
  (ref) => ref.watch(chatRepositoryProvider).liveRooms(),
);
final feedProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(postRepositoryProvider).list(),
);

/// 1:1 con menzoweb/app/(app)/page.tsx — hero de comunidad, carrusel de LIVEs, feed.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final config = ref.watch(communityConfigProvider);
    final liveRooms = ref.watch(liveRoomsProvider);
    final feed = ref.watch(feedProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/branding/menzo-logo.png',
              width: 28,
              height: 28,
            ),
            const SizedBox(width: 8),
            Text('Menzo', style: AppTextStyles.h3()),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => showModalBottomSheet(
              context: context,
              backgroundColor: AppColors.surface,
              builder: (_) => const SecondaryNavSheet(),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(communityConfigProvider);
          ref.invalidate(liveRoomsProvider);
          ref.invalidate(feedProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            config.when(
              data: (c) => _CommunityHero(
                config: c,
                profileName: auth.profile?.displayName ?? '',
              ),
              loading: () => const SizedBox(height: 120),
              error: (e, st) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 20),
            liveRooms.when(
              data: (rooms) => rooms.isEmpty
                  ? const SizedBox.shrink()
                  : _LiveRoomsCarousel(rooms: rooms),
              loading: () => const SizedBox.shrink(),
              error: (e, st) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 20),
            Text('Para ti', style: AppTextStyles.h3()),
            const SizedBox(height: 12),
            feed.when(
              data: (page) => Column(
                children: page.items
                    .map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: PostCard(post: p),
                      ),
                    )
                    .toList(),
              ),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, st) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No pudimos cargar el feed.',
                  style: AppTextStyles.body(color: AppColors.coral),
                ),
              ),
            ),
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

class _CommunityHero extends StatelessWidget {
  const _CommunityHero({required this.config, required this.profileName});
  final CommunityConfig config;
  final String profileName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppGradients.linear(GradientId.community, angle: 120),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hola, $profileName',
            style: AppTextStyles.h2(color: Colors.black),
          ),
          const SizedBox(height: 4),
          Text(
            config.subtitle ?? 'Bienvenido a ${config.name}',
            style: AppTextStyles.body(color: Colors.black87),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.circle, size: 8, color: Colors.black87),
              const SizedBox(width: 6),
              Text(
                '${config.onlineCount} conectados · ${config.memberCount} miembros',
                style: AppTextStyles.caption(color: Colors.black87),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LiveRoomsCarousel extends StatelessWidget {
  const _LiveRoomsCarousel({required this.rooms});
  final List<ChatRoom> rooms;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: rooms.length,
        separatorBuilder: (context, i) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final room = rooms[i];
          return GestureDetector(
            onTap: () => context.push('/chat/${room.id}'),
            child: Container(
              width: 220,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: AppColors.coral.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  MenzoAvatar(
                    name:
                        room.liveSummary?.host?.displayName ?? room.name ?? '',
                    avatarUri: room.liveSummary?.host?.avatarUri,
                    size: 40,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.coral,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'EN VIVO',
                              style: AppTextStyles.caption(
                                color: AppColors.coral,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          room.name ?? '',
                          style: AppTextStyles.label(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${room.liveSummary?.participantCount ?? 0} escuchando',
                          style: AppTextStyles.caption(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
