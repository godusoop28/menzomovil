import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/community_context_provider.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'chat_room_tile.dart';

final discoverRoomsProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(chatRepositoryProvider).discover(
        communityId: ref.watch(communityContextProvider).activeCommunityId,
      ),
);

/// 1:1 con menzoweb/app/(app)/chat/public/page.tsx.
class ChatPublicScreen extends ConsumerStatefulWidget {
  const ChatPublicScreen({super.key});

  @override
  ConsumerState<ChatPublicScreen> createState() => _ChatPublicScreenState();
}

class _ChatPublicScreenState extends ConsumerState<ChatPublicScreen> {
  final _joining = <String>{};

  Future<void> _join(String roomId) async {
    setState(() => _joining.add(roomId));
    try {
      await ref.read(chatRepositoryProvider).join(roomId);
      ref.invalidate(discoverRoomsProvider);
    } finally {
      if (mounted) setState(() => _joining.remove(roomId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final rooms = ref.watch(discoverRoomsProvider);
    return Scaffold(
      appBar: AppBar(title: Text('Chats públicos', style: AppTextStyles.h2())),
      body: rooms.when(
        data: (list) => list.isEmpty
            ? Center(
                child: Text(
                  'No hay salas activas. Enciende la primera.',
                  style: AppTextStyles.body(color: AppColors.textMuted),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (context, i) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final room = list[i];
                  return ChatRoomTile(
                    room: room,
                    onJoin: room.joined ? null : () => _join(room.id),
                    joining: _joining.contains(room.id),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Text(
            'No pudimos cargar las salas.',
            style: AppTextStyles.body(color: AppColors.coral),
          ),
        ),
      ),
    );
  }
}
