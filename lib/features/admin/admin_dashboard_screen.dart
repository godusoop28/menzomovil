import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/user_models.dart';

/// 1:1 con menzoweb/app/(app)/admin/page.tsx.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authProvider).profile;
    final isMaster = profile?.globalRole == GlobalRole.master;

    final links = <(IconData, String, String, String)>[
      (Icons.people_outline, 'Usuarios', 'Buscar cuentas, suspender o eliminar.', '/admin/users'),
      (Icons.visibility_off_outlined, 'Publicaciones', 'Buscar, ocultar o eliminar publicaciones.', '/admin/posts'),
      (Icons.workspace_premium_outlined, 'Roles', 'Asignar o revocar Curador/Líder.', '/admin/roles'),
      if (isMaster)
        (Icons.history, 'Log de moderación', 'Historial completo de acciones de staff, con motivo.', '/admin/moderation-log'),
    ];

    return Scaffold(
      appBar: AppBar(title: Text('Panel de administración', style: AppTextStyles.h2())),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            isMaster
                ? 'Control total, excepto lectura de chats privados.'
                : 'Herramientas de moderación de la comunidad.',
            style: AppTextStyles.caption(),
          ),
          const SizedBox(height: 16),
          ...links.map(
            (item) => Card(
              color: AppColors.surface,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                side: const BorderSide(color: AppColors.borderSoft),
              ),
              child: ListTile(
                onTap: () => context.push(item.$4),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(color: AppColors.surfaceSecondary, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Icon(item.$1, size: 20, color: AppColors.textPrimary),
                ),
                title: Text(item.$2, style: AppTextStyles.label()),
                subtitle: Text(item.$3, style: AppTextStyles.caption()),
              ),
            ),
          ),
          if (!isMaster) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Text(
                'Toda acción con motivo queda registrada y es visible para el usuario maestro.',
                style: AppTextStyles.caption(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
