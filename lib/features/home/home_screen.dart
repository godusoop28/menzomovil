import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/permissions/startup_permissions.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/community_context_provider.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/chat_models.dart';
import '../../data/models/communities_models.dart';
import '../chat/chat_room_tile.dart';
import '../chat/create_room_screen.dart';
import '../post/create_post_screen.dart';
import '../shared/app_shell.dart';
import '../shared/menzo_avatar.dart';
import '../shared/segmented_tabs.dart';
import 'post_card.dart';

final liveRoomsProvider = FutureProvider(
  (ref) => ref.watch(chatRepositoryProvider).liveRooms(
        communityId: ref.watch(communityContextProvider).activeCommunityId,
      ),
);
// ref.watch(communityContextProvider) hace que Riverpod recalcule solo (nuevo fetch, ya acotado
// a la comunidad activa) apenas cambia — nunca queda mezclado contenido de la comunidad anterior.
final feedProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(postRepositoryProvider).list(
        communityId: ref.watch(communityContextProvider).activeCommunityId,
      ),
);
final featuredPostsProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(postRepositoryProvider).featured(
        communityId: ref.watch(communityContextProvider).activeCommunityId,
      ),
);
final discoverRoomsProvider = FutureProvider.family.autoDispose(
  (ref, String sort) => ref.watch(chatRepositoryProvider).discover(
        sort: sort,
        communityId: ref.watch(communityContextProvider).activeCommunityId,
      ),
);

enum _HomeTab { recientes, destacados, descubrir }

/// 1:1 con menzoweb/app/(app)/page.tsx — hero de comunidad, carrusel de LIVEs, pestañas
/// Recientes/Destacados/Descubrir.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  _HomeTab _tab = _HomeTab.recientes;
  String _roomSort = 'recent';
  final _joining = <String>{};
  Timer? _liveRoomsTimer;

  @override
  void initState() {
    super.initState();
    requestStartupPermissions();
    // `liveRoomsProvider` es un FutureProvider de una sola pasada — sin refrescarlo, el
    // carrusel de "en vivo" nunca se enteraba de un LIVE que otro usuario inició mientras esta
    // pantalla ya estaba abierta. 1:1 con el `setInterval(loadLiveRooms, 15000)` de
    // menzoweb/app/(app)/page.tsx.
    _liveRoomsTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => ref.invalidate(liveRoomsProvider),
    );
  }

  @override
  void dispose() {
    _liveRoomsTimer?.cancel();
    super.dispose();
  }

  Future<void> _joinRoom(String roomId) async {
    setState(() => _joining.add(roomId));
    try {
      await ref.read(chatRepositoryProvider).join(roomId);
      ref.invalidate(discoverRoomsProvider(_roomSort));
    } finally {
      if (mounted) setState(() => _joining.remove(roomId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final liveRooms = ref.watch(liveRoomsProvider);
    final feed = ref.watch(feedProvider);
    final activeCommunityDetail = ref.watch(communityContextProvider).activeCommunityDetail;
    final feedBackgroundUrl =
        (activeCommunityDetail?.themeConfig['feedBackgroundUrl'] as String?) ?? activeCommunityDetail?.backgroundUrl;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () =>
              ref.read(shellScaffoldKeyProvider).currentState?.openDrawer(),
        ),
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
        ],
      ),
      body: Container(
        decoration: (feedBackgroundUrl != null && feedBackgroundUrl.isNotEmpty)
            ? BoxDecoration(
                image: DecorationImage(
                  image: CachedNetworkImageProvider(feedBackgroundUrl),
                  fit: BoxFit.cover,
                  colorFilter: const ColorFilter.mode(Color(0xE0070A0D), BlendMode.darken),
                  onError: (_, _) {},
                ),
              )
            : null,
        child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(liveRoomsProvider);
          ref.invalidate(feedProvider);
          ref.invalidate(featuredPostsProvider);
          ref.invalidate(discoverRoomsProvider(_roomSort));
          await ref.read(communityContextProvider.notifier).refreshActiveDetail();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            activeCommunityDetail == null
                ? const SizedBox.shrink()
                : _CommunityHero(
                    community: activeCommunityDetail,
                    profileName: auth.profile?.displayName ?? '',
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
            SegmentedTabs<_HomeTab>(
              value: _tab,
              options: _HomeTab.values,
              onChanged: (t) => setState(() => _tab = t),
              labelBuilder: (t) => switch (t) {
                _HomeTab.recientes => 'Recientes',
                _HomeTab.destacados => 'Destacados',
                _HomeTab.descubrir => 'Descubrir',
              },
            ),
            const SizedBox(height: 16),
            switch (_tab) {
              _HomeTab.recientes => feed.when(
                data: (page) => page.items.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Text(
                          'Todavía no hay publicaciones.',
                          style: AppTextStyles.body(color: AppColors.textMuted),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : Column(
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
              _HomeTab.destacados =>
                ref
                    .watch(featuredPostsProvider)
                    .when(
                      data: (page) => page.items.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              child: Text(
                                'Nada destacado todavía.',
                                style: AppTextStyles.body(
                                  color: AppColors.textMuted,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.xl,
                                  ),
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: Image.asset(
                                          'assets/banners/banner-featured.png',
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      const Positioned.fill(
                                        child: ColoredBox(
                                          color: Color(0x4D07090D),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'LO MEJOR DE LA SEMANA',
                                              style: AppTextStyles.caption(
                                                color: Colors.white70,
                                              ),
                                            ),
                                            Text(
                                              'Destacados',
                                              style: AppTextStyles.h2(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ...page.items.map(
                                  (p) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: PostCard(post: p),
                                  ),
                                ),
                              ],
                            ),
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, st) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No pudimos cargar los destacados.',
                          style: AppTextStyles.body(color: AppColors.coral),
                        ),
                      ),
                    ),
              _HomeTab.descubrir => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Descubrir salas', style: AppTextStyles.h3()),
                            Text(
                              'Explora todas las salas públicas de la comunidad.',
                              style: AppTextStyles.caption(),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const CreateRoomScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Crear sala'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _SortChip(
                        label: 'Recientes',
                        active: _roomSort == 'recent',
                        onTap: () => setState(() => _roomSort = 'recent'),
                      ),
                      const SizedBox(width: 8),
                      _SortChip(
                        label: 'Populares',
                        active: _roomSort == 'popular',
                        onTap: () => setState(() => _roomSort = 'popular'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ref
                      .watch(discoverRoomsProvider(_roomSort))
                      .when(
                        data: (rooms) => rooms.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 24,
                                ),
                                child: Text(
                                  'No hay salas activas. Enciende la primera.',
                                  style: AppTextStyles.body(
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              )
                            : Column(
                                children: rooms
                                    .map(
                                      (room) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: ChatRoomTile(
                                          room: room,
                                          onJoin: room.joined
                                              ? null
                                              : () => _joinRoom(room.id),
                                          joining: _joining.contains(room.id),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (e, st) => Text(
                          'No pudimos cargar las salas.',
                          style: AppTextStyles.body(color: AppColors.coral),
                        ),
                      ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: () => context.push('/events'),
                      child: Text(
                        'Ver eventos de la comunidad →',
                        style: AppTextStyles.label(color: AppColors.cyan),
                      ),
                    ),
                  ),
                ],
              ),
            },
          ],
        ),
        ),
      ),
      floatingActionButton: _tab == _HomeTab.recientes
          ? FloatingActionButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const CreatePostScreen(),
                ),
              ),
              backgroundColor: AppColors.orange,
              child: const Icon(Icons.add, color: Colors.black),
            )
          : null,
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.surfaceSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption(
            color: active ? AppColors.textPrimary : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _CommunityHero extends StatelessWidget {
  const _CommunityHero({required this.community, required this.profileName});
  final CommunityDetail community;
  final String profileName;

  @override
  Widget build(BuildContext context) {
    final heroImage = (community.coverUrl?.isNotEmpty ?? false)
        ? community.coverUrl
        : (community.bannerUrl?.isNotEmpty ?? false)
            ? community.bannerUrl
            : null;
    final primary = _parseHeroColor(community.primaryColor) ?? const Color(0xFFE74C3C);
    final secondary = _parseHeroColor(community.secondaryColor) ?? const Color(0xFF2C3E50);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Stack(
        children: [
          Positioned.fill(
            child: heroImage != null
                ? CachedNetworkImage(
                    imageUrl: heroImage,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [primary, secondary],
                        ),
                      ),
                    ),
                  )
                : DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [primary, secondary],
                      ),
                    ),
                  ),
          ),
          const Positioned.fill(child: ColoredBox(color: Color(0x6B07090D))),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hola, $profileName',
                  style: AppTextStyles.h2(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  (community.shortDescription?.isNotEmpty ?? false)
                      ? community.shortDescription!
                      : 'Bienvenido a ${community.name}',
                  style: AppTextStyles.body(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.circle, size: 8, color: Colors.white70),
                    const SizedBox(width: 6),
                    Text(
                      '${community.onlineMemberCount} conectados · ${community.memberCount} miembros',
                      style: AppTextStyles.caption(color: Colors.white70),
                    ),
                  ],
                ),
                if (community.tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: community.tags
                        .map(
                          (tag) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              tag,
                              style: AppTextStyles.caption(color: Colors.white),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
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

Color? _parseHeroColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  try {
    return Color(int.parse(hex.replaceFirst('#', '0xFF')));
  } catch (_) {
    return null;
  }
}
