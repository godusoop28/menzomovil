import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';

final moderationLogProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(adminRepositoryProvider).moderationLog(),
);

/// MASTER-only — el router ya bloquea /admin entero para globalRole == user; esta pantalla en sí
/// solo llega desde el dashboard, que no ofrece este link salvo para MASTER. Si el backend
/// igual rebota con 403 (p. ej. LEADER navegó acá a mano), el FutureProvider cae en error y se
/// muestra el estado vacío/erróneo — sin crash.
class AdminModerationLogScreen extends ConsumerWidget {
  const AdminModerationLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(moderationLogProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Log de moderación', style: AppTextStyles.h2())),
      body: log.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Text('No pudimos cargar el log.', style: AppTextStyles.body(color: AppColors.textMuted)),
        ),
        data: (page) {
          if (page.items.isEmpty) {
            return Center(
              child: Text('Sin actividad todavía.', style: AppTextStyles.body(color: AppColors.textMuted)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: page.items.length,
            itemBuilder: (context, i) {
              final action = page.items[i];
              return Card(
                color: AppColors.surface,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  side: const BorderSide(color: AppColors.borderSoft),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(action.actor.displayName, style: AppTextStyles.label()),
                          Text(_formatDate(action.createdAt), style: AppTextStyles.caption()),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${action.actionType.name} · ${action.targetType}',
                        style: AppTextStyles.body(),
                      ),
                      const SizedBox(height: 4),
                      Text(action.reason, style: AppTextStyles.caption()),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} '
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
