import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/user_models.dart';
import '../shared/menzo_avatar.dart';
import '../shared/reason_dialog.dart';

const _assignableRoles = [GlobalRole.user, GlobalRole.curator, GlobalRole.leader];

/// 1:1 con menzoweb/app/(app)/admin/roles/page.tsx. MASTER es fijo (una sola cuenta
/// configurada) y nunca se asigna acá.
class AdminRolesScreen extends ConsumerStatefulWidget {
  const AdminRolesScreen({super.key});

  @override
  ConsumerState<AdminRolesScreen> createState() => _AdminRolesScreenState();
}

class _AdminRolesScreenState extends ConsumerState<AdminRolesScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<UserProfile> _results = [];
  bool _loading = false;

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
    setState(() => _loading = true);
    try {
      final page = await ref.read(adminRepositoryProvider).searchUsers(query);
      if (!mounted) return;
      setState(() => _results = page.items);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changeRole(UserProfile user, GlobalRole role) async {
    final reason = await showReasonDialog(
      context,
      title: 'Cambiar el rol de ${user.displayName} a ${globalRoleToJson(role)}',
      description: 'El motivo queda registrado en el log de moderación.',
    );
    if (reason == null) return;
    try {
      await ref.read(adminRepositoryProvider).changeRole(user.id, role, reason);
      if (!mounted) return;
      // UserProfile es inmutable sin copyWith propio (ver user_models.dart) — re-buscar es más
      // simple que reconstruirlo a mano acá.
      await _search(_controller.text);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Roles', style: AppTextStyles.h2())),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'MASTER es fijo (una sola cuenta configurada) y nunca se asigna acá.',
              style: AppTextStyles.caption(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              onChanged: _onChanged,
              style: AppTextStyles.body(),
              decoration: const InputDecoration(hintText: 'Buscar por nombre o usuario…'),
            ),
            const SizedBox(height: 12),
            if (_loading) const Center(child: CircularProgressIndicator()),
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
                    subtitle: Text('@${user.username}', style: AppTextStyles.caption()),
                    trailing: user.globalRole == GlobalRole.master
                        ? Text('MASTER', style: AppTextStyles.caption())
                        : DropdownButton<GlobalRole>(
                            value: user.globalRole,
                            underline: const SizedBox.shrink(),
                            items: _assignableRoles
                                .map(
                                  (role) => DropdownMenuItem(
                                    value: role,
                                    child: Text(globalRoleToJson(role)),
                                  ),
                                )
                                .toList(),
                            onChanged: (role) {
                              if (role != null && role != user.globalRole) {
                                _changeRole(user, role);
                              }
                            },
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
