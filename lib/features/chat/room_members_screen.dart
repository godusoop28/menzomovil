import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/chat_models.dart';
import '../shared/menzo_avatar.dart';

final roomMembersProvider = FutureProvider.family.autoDispose(
  (ref, String roomId) => ref.watch(chatRepositoryProvider).members(roomId),
);

/// 1:1 con menzoweb/app/(app)/chat/[id]/members/page.tsx (versión simplificada — sin
/// moderación inline; los kick/ban/promote quedan en las acciones del backend disponibles vía
/// ChatRepository para una futura pantalla de administración más completa).
class RoomMembersScreen extends ConsumerWidget {
  const RoomMembersScreen({super.key, required this.roomId});
  final String roomId;

  String _roleLabel(RoomRole role) => switch (role) {
    RoomRole.owner => 'Anfitrión',
    RoomRole.coHost => 'Coanfitrión',
    RoomRole.member => 'Miembro',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(roomMembersProvider(roomId));
    return Scaffold(
      appBar: AppBar(title: Text('Miembros', style: AppTextStyles.h2())),
      body: members.when(
        data: (list) => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (context, i) {
            final member = list[i];
            return ListTile(
              onTap: () => context.push('/member/${member.user.id}'),
              leading: MenzoAvatar(
                name: member.user.displayName,
                avatarUri: member.user.avatarUri,
                size: 40,
                showOnline: true,
                online: member.user.isOnline,
              ),
              title: Text(
                member.user.displayName,
                style: AppTextStyles.label(),
              ),
              subtitle: Text(
                _roleLabel(member.role),
                style: AppTextStyles.caption(),
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Text(
            'No pudimos cargar los miembros.',
            style: AppTextStyles.body(color: AppColors.coral),
          ),
        ),
      ),
    );
  }
}
