import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/chat_models.dart';
import '../shared/menzi_illustration_state.dart';
import 'chat_room_tile.dart';

final myRoomsProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(chatRepositoryProvider).myRooms(),
);

/// 1:1 con menzoweb/app/(app)/chat/page.tsx — lista de DMs + salas unidas.
class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = ref.watch(myRoomsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('Chats', style: AppTextStyles.h2()),
        actions: [
          IconButton(
            icon: const Icon(Icons.groups_2_outlined),
            tooltip: 'Chats públicos',
            onPressed: () => context.push('/chat/public'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myRoomsProvider),
        child: rooms.when(
          data: (list) {
            if (list.isEmpty) {
              return ListView(
                children: const [
                  MenziIllustrationState(
                    image: MenziIllustration.chat,
                    title: 'Todavía no hay chats',
                    description:
                        'Únete a una sala pública o inicia una conversación directa para empezar.',
                  ),
                ],
              );
            }
            final favorites = list.where((r) => r.favorite).toList();
            final directs = list
                .where((r) => !r.favorite && r.type == ChatRoomType.direct)
                .toList();
            final publics = list
                .where((r) => !r.favorite && r.type == ChatRoomType.public)
                .toList();
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (favorites.isNotEmpty) ..._section('Favoritos', favorites),
                if (directs.isNotEmpty)
                  ..._section('Mensajes directos', directs),
                if (publics.isNotEmpty) ..._section('Salas públicas', publics),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(
            child: Text(
              'No pudimos cargar tus chats.',
              style: AppTextStyles.body(color: AppColors.coral),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _section(String title, List<ChatRoom> rooms) => [
    Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(title, style: AppTextStyles.label()),
    ),
    ...rooms.map(
      (r) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ChatRoomTile(room: r),
      ),
    ),
    const SizedBox(height: 12),
  ];
}
