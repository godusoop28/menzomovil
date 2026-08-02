import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/user_models.dart';
import '../shared/menzo_avatar.dart';
import '../shared/reason_dialog.dart';

/// 1:1 con menzoweb/app/(app)/admin/users/page.tsx.
class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<UserProfile> _results = [];
  bool _loading = false;
  bool _searched = false;

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value));
  }

  Future<void> _search(String query) async {
    setState(() {
      _loading = true;
      _searched = true;
    });
    try {
      final page = await ref.read(adminRepositoryProvider).searchUsers(query);
      if (!mounted) return;
      setState(() => _results = page.items);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _suspend(UserProfile user) async {
    final reason = await showReasonDialog(
      context,
      title: 'Suspender a ${user.displayName}',
      description: 'El motivo queda registrado en el log de moderación, visible para el usuario maestro.',
    );
    if (reason == null) return;
    try {
      await ref.read(adminRepositoryProvider).suspendUser(user.id, reason);
    } catch (_) {}
  }

  Future<void> _unsuspend(UserProfile user) async {
    final reason = await showReasonDialog(
      context,
      title: 'Reactivar a ${user.displayName}',
      description: 'El motivo queda registrado en el log de moderación.',
    );
    if (reason == null) return;
    try {
      await ref.read(adminRepositoryProvider).unsuspendUser(user.id, reason);
    } catch (_) {}
  }

  Future<void> _delete(UserProfile user) async {
    final reason = await showReasonDialog(
      context,
      title: 'Eliminar la cuenta de ${user.displayName}',
      description: 'Esta acción es permanente: la cuenta queda inutilizable y sus datos personales se anonimizan. '
          'Sus publicaciones y mensajes en salas públicas siguen visibles.',
      confirmLabel: 'Eliminar',
    );
    if (reason == null) return;
    try {
      await ref.read(adminRepositoryProvider).deleteAccount(user.id, reason);
      if (!mounted) return;
      setState(() => _results.removeWhere((u) => u.id == user.id));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isMaster = ref.watch(authProvider).profile?.globalRole == GlobalRole.master;

    return Scaffold(
      appBar: AppBar(title: Text('Usuarios', style: AppTextStyles.h2())),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              onChanged: _onChanged,
              style: AppTextStyles.body(),
              decoration: const InputDecoration(hintText: 'Buscar por nombre o usuario…'),
            ),
            const SizedBox(height: 12),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (!_loading && _searched && _results.isEmpty)
              Text('Sin resultados.', style: AppTextStyles.body(color: AppColors.textMuted)),
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, i) {
                  final user = _results[i];
                  return ListTile(
                    leading: MenzoAvatar(
                      name: user.displayName,
                      avatarUri: user.avatarUri,
                      gradient: gradientIdFromName(user.avatarGradient),
                      size: 40,
                    ),
                    title: Text(user.displayName, style: AppTextStyles.label()),
                    subtitle: Text(
                      '@${user.username} · ${globalRoleToJson(user.globalRole)}',
                      style: AppTextStyles.caption(),
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'suspend') _suspend(user);
                        if (value == 'unsuspend') _unsuspend(user);
                        if (value == 'delete') _delete(user);
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'suspend', child: Text('Suspender')),
                        const PopupMenuItem(value: 'unsuspend', child: Text('Reactivar')),
                        if (isMaster)
                          const PopupMenuItem(value: 'delete', child: Text('Eliminar cuenta')),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
