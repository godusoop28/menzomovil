import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/native/bubble_preference.dart';
import '../../core/native/live_bubble_channel.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/user_models.dart';
import '../shared/menzi_illustration_state.dart';

final settingsProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(userRepositoryProvider).getSettings(),
);

/// 1:1 con menzoweb/app/(app)/settings/page.tsx.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  SettingsDto? _settings;
  bool _bubbleEnabled = false;

  @override
  void initState() {
    super.initState();
    BubblePreference.isEnabled().then((v) {
      if (mounted) setState(() => _bubbleEnabled = v);
    });
  }

  Future<void> _update(SettingsDto next) async {
    setState(() => _settings = next);
    try {
      await ref.read(userRepositoryProvider).updateSettings(next.toJson());
    } catch (_) {}
  }

  Future<void> _toggleBubble(bool value) async {
    setState(() => _bubbleEnabled = value);
    await BubblePreference.setEnabled(value);
    if (value) await LiveBubbleChannel.requestPermission();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(title: Text('Configuración', style: AppTextStyles.h2())),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const MenziIllustrationState(
            image: MenziIllustration.settings,
            title: 'Configuración',
            description:
                'Tu cuenta, privacidad y notificaciones en un solo lugar.',
            compact: true,
            size: MenziIllustrationSize.small,
          ),
          const SizedBox(height: 20),
          Text('Cuenta', style: AppTextStyles.caption()),
          const SizedBox(height: 8),
          ListTile(
            tileColor: AppColors.surfaceSecondary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            title: const Text('Editar perfil'),
            onTap: () => context.push('/profile/edit'),
          ),
          const SizedBox(height: 8),
          ListTile(
            tileColor: AppColors.surfaceSecondary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            title: const Text(
              'Cerrar sesión',
              style: TextStyle(color: AppColors.coral),
            ),
            onTap: () => ref.read(authProvider.notifier).logout(),
          ),
          const SizedBox(height: 20),
          Text('LIVE', style: AppTextStyles.caption()),
          const SizedBox(height: 8),
          _SwitchTile(
            label: 'Mantener audio y burbuja del LIVE al minimizar',
            value: _bubbleEnabled,
            onChanged: _toggleBubble,
          ),
          const SizedBox(height: 20),
          Text('Diagnóstico', style: AppTextStyles.caption()),
          const SizedBox(height: 8),
          ListTile(
            tileColor: AppColors.surfaceSecondary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            title: const Text('Diagnóstico de YouTube'),
            subtitle: const Text(
              'Prueba el reproductor aislado, sin LIVE ni Menzi DJ',
            ),
            onTap: () => context.push('/debug/youtube-player'),
          ),
          const SizedBox(height: 8),
          ListTile(
            tileColor: AppColors.surfaceSecondary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            title: const Text('Logs de Menzi DJ'),
            subtitle: const Text(
              'Registro interno de LIVE/Menzi DJ — sin depuración USB, exportable como TXT',
            ),
            onTap: () => context.push('/debug/menzi-dj-logs'),
          ),
          const SizedBox(height: 20),
          async.when(
            data: (settings) {
              _settings ??= settings;
              final s = _settings!;
              return Column(
                children: [
                  Text('Notificaciones', style: AppTextStyles.caption()),
                  const SizedBox(height: 8),
                  _SwitchTile(
                    label: 'Notificaciones activas',
                    value: s.notificationsEnabled,
                    onChanged: (v) =>
                        _update(s.copyWith(notificationsEnabled: v)),
                  ),
                  const SizedBox(height: 20),
                  Text('Privacidad', style: AppTextStyles.caption()),
                  const SizedBox(height: 8),
                  _SwitchTile(
                    label: 'Mostrar estado en línea',
                    value: s.showOnlineStatus,
                    onChanged: (v) => _update(s.copyWith(showOnlineStatus: v)),
                  ),
                  _SwitchTile(
                    label: 'Permitir visitas al perfil',
                    value: s.allowProfileVisits,
                    onChanged: (v) =>
                        _update(s.copyWith(allowProfileVisits: v)),
                  ),
                  _SwitchTile(
                    label: 'Mostrar intereses',
                    value: s.showInterests,
                    onChanged: (v) => _update(s.copyWith(showInterests: v)),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: SwitchListTile(
        activeThumbColor: AppColors.orange,
        title: Text(label, style: AppTextStyles.body()),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
