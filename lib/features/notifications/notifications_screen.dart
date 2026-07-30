import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/community_models.dart';
import '../shared/menzi_illustration_state.dart';

final notificationsListProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(notificationsRepositoryProvider).list(),
);

const _categoryIcons = {
  NotificationCategory.comentarios: Icons.mode_comment_outlined,
  NotificationCategory.likes: Icons.favorite_border,
  NotificationCategory.mensajes: Icons.chat_bubble_outline,
  NotificationCategory.eventos: Icons.calendar_month_outlined,
  NotificationCategory.seguimientos: Icons.person_add_alt_outlined,
};

/// 1:1 con menzoweb/app/(app)/notifications/page.tsx.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsListProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('Notificaciones', style: AppTextStyles.h2()),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(notificationsRepositoryProvider).markAllRead();
              ref.invalidate(notificationsListProvider);
            },
            child: const Text('Marcar todas'),
          ),
        ],
      ),
      body: notifications.when(
        data: (page) {
          if (page.items.isEmpty) {
            return ListView(
              children: const [
                MenziIllustrationState(
                  image: MenziIllustration.notifications,
                  title: 'Todo está tranquilo',
                  description:
                      'Aquí aparecerán tus mensajes, invitaciones y novedades.',
                ),
              ],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: page.items.length,
            itemBuilder: (context, i) {
              final n = page.items[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  onTap: () async {
                    await ref
                        .read(notificationsRepositoryProvider)
                        .markRead(n.id);
                    if (context.mounted) _openNotification(context, n);
                  },
                  leading: CircleAvatar(
                    backgroundColor: AppColors.surfaceElevated,
                    child: Icon(
                      _categoryIcons[n.category] ?? Icons.notifications,
                      color: AppColors.textSecondary,
                      size: 18,
                    ),
                  ),
                  title: Text(n.title, style: AppTextStyles.label()),
                  subtitle: Text(n.body, style: AppTextStyles.caption()),
                  trailing: n.read
                      ? null
                      : const Icon(
                          Icons.circle,
                          size: 8,
                          color: AppColors.coral,
                        ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Text(
            'No pudimos cargar tus notificaciones.',
            style: AppTextStyles.body(color: AppColors.coral),
          ),
        ),
      ),
    );
  }

  void _openNotification(BuildContext context, AppNotification n) {
    if (n.relatedPostId != null) {
      context.push('/post/${n.relatedPostId}');
    } else if (n.relatedRoomId != null) {
      context.push('/chat/${n.relatedRoomId}');
    } else if (n.relatedUserId != null) {
      context.push('/member/${n.relatedUserId}');
    } else if (n.relatedEventId != null) {
      context.push('/events/${n.relatedEventId}');
    }
  }
}
