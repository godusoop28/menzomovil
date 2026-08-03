import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/community_context_provider.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../chat/chat_room_tile.dart';
import '../home/post_card.dart';
import '../shared/menzo_avatar.dart';

/// 1:1 con menzoweb/app/(app)/search/page.tsx — búsqueda combinada de miembros/salas/posts.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          style: AppTextStyles.body(),
          decoration: const InputDecoration(
            hintText: 'Busca miembros, salas o publicaciones',
            border: InputBorder.none,
          ),
          onSubmitted: (v) => setState(() => _query = v.trim()),
          onChanged: (v) => setState(() => _query = v.trim()),
        ),
      ),
      body: _query.length < 2
          ? Center(
              child: Text(
                'Escribe para buscar',
                style: AppTextStyles.body(color: AppColors.textMuted),
              ),
            )
          : _SearchResults(query: _query),
    );
  }
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults({required this.query});
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final communityId = ref.watch(communityContextProvider).activeCommunityId;
    final membersFuture = ref.watch(userRepositoryProvider).search(query);
    final roomsFuture = ref.watch(chatRepositoryProvider).discover(communityId: communityId);
    final postsFuture = ref
        .watch(postRepositoryProvider)
        .search(query, communityId: communityId);

    return FutureBuilder(
      future: (membersFuture, roomsFuture, postsFuture).wait,
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final members = snapshot.data!.$1.items;
        final rooms = snapshot.data!.$2
            .where(
              (r) => (r.name ?? '').toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
        final posts = snapshot.data!.$3.items;

        if (members.isEmpty && rooms.isEmpty && posts.isEmpty) {
          return Center(
            child: Text(
              'No encontramos nada con ese nombre.',
              style: AppTextStyles.body(color: AppColors.textMuted),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (members.isNotEmpty) ...[
              Text('Miembros', style: AppTextStyles.label()),
              const SizedBox(height: 8),
              ...members.map(
                (u) => ListTile(
                  onTap: () => context.push('/member/${u.id}'),
                  leading: MenzoAvatar(
                    name: u.displayName,
                    avatarUri: u.avatarUri,
                    size: 36,
                  ),
                  title: Text(u.displayName, style: AppTextStyles.label()),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (rooms.isNotEmpty) ...[
              Text('Salas', style: AppTextStyles.label()),
              const SizedBox(height: 8),
              ...rooms.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ChatRoomTile(room: r),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (posts.isNotEmpty) ...[
              Text('Publicaciones', style: AppTextStyles.label()),
              const SizedBox(height: 8),
              ...posts.map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: PostCard(post: p),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
