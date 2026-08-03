import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/communities_models.dart';
import '../../data/models/user_models.dart';
import 'community_badge.dart';

/// COMMUNITY_ADMIN+ de esta comunidad, o cuenta global LEADER+ — ver
/// CommunityPermissionEvaluator.requireCanEditAppearance en menzoapi (el backend re-valida
/// siempre; esta pantalla solo evita ofrecer los controles donde de todos modos rebotaría).
class CommunityAppearanceScreen extends ConsumerStatefulWidget {
  const CommunityAppearanceScreen({super.key, required this.slug});
  final String slug;

  @override
  ConsumerState<CommunityAppearanceScreen> createState() => _CommunityAppearanceScreenState();
}

const _imageSlots = [
  ('iconUrl', 'Icono'),
  ('logoUrl', 'Logo'),
  ('coverUrl', 'Portada'),
  ('bannerUrl', 'Banner'),
  ('backgroundUrl', 'Fondo'),
];

const _colorSlots = [
  ('primaryColor', 'Color primario'),
  ('secondaryColor', 'Color secundario'),
  ('accentColor', 'Color de acento'),
];

class _CommunityAppearanceScreenState extends ConsumerState<CommunityAppearanceScreen> {
  CommunityDetail? _community;
  final Map<String, String> _images = {};
  final Map<String, TextEditingController> _colorControllers = {
    for (final (key, _) in _colorSlots) key: TextEditingController(),
  };
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _colorControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final detail = await ref.read(communitiesRepositoryProvider).getBySlug(widget.slug);
      if (!mounted) return;
      setState(() {
        _community = detail;
        _images['iconUrl'] = detail.iconUrl ?? '';
        _images['logoUrl'] = detail.logoUrl ?? '';
        _images['coverUrl'] = detail.coverUrl ?? '';
        _images['bannerUrl'] = detail.bannerUrl ?? '';
        _images['backgroundUrl'] = detail.backgroundUrl ?? '';
        _colorControllers['primaryColor']!.text = detail.primaryColor ?? '';
        _colorControllers['secondaryColor']!.text = detail.secondaryColor ?? '';
        _colorControllers['accentColor']!.text = detail.accentColor ?? '';
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'No pudimos cargar esta comunidad.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _canEdit(UserProfile? profile) {
    if (_community == null) return false;
    final globalRole = profile?.globalRole;
    final isGlobalStaff = globalRole == GlobalRole.leader || globalRole == GlobalRole.master;
    final role = _community!.myMembership?.communityRole;
    final isCommunityAdmin = role == CommunityRole.admin || role == CommunityRole.owner;
    return isGlobalStaff || isCommunityAdmin;
  }

  Future<void> _pickImage(String key) async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null) return;
    try {
      final url = await ref.read(uploadsRepositoryProvider).upload(File(image.path));
      if (mounted) setState(() => _images[key] = url);
    } catch (_) {
      if (mounted) setState(() => _error = 'No pudimos subir la imagen.');
    }
  }

  Future<void> _save() async {
    if (_community == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(communitiesRepositoryProvider).updateAppearance(_community!.id, {
        ..._images,
        for (final (key, _) in _colorSlots) key: _colorControllers[key]!.text.trim(),
      });
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) setState(() => _error = 'No pudimos guardar los cambios.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authProvider).profile;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_community == null) {
      return Scaffold(
        body: Center(child: Text(_error ?? 'Comunidad no encontrada.', style: AppTextStyles.body())),
      );
    }
    if (!_canEdit(profile)) {
      return Scaffold(
        appBar: AppBar(title: Text('Apariencia', style: AppTextStyles.h2())),
        body: Center(
          child: Text(
            'No tenés permisos para editar la apariencia de ${_community!.name}.',
            style: AppTextStyles.body(color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Apariencia de ${_community!.name}', style: AppTextStyles.h2())),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Imágenes', style: AppTextStyles.label().copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 8),
          for (final (key, label) in _imageSlots)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  CommunityBadge(iconUrl: _images[key], color: _community!.primaryColor, size: 56),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: AppTextStyles.body()),
                        TextButton(onPressed: () => _pickImage(key), child: const Text('Cambiar')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text('Colores', style: AppTextStyles.label().copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 8),
          for (final (key, label) in _colorSlots)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                controller: _colorControllers[key],
                decoration: InputDecoration(labelText: label, hintText: '#RRGGBB'),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!, style: AppTextStyles.body(color: AppColors.coral)),
            ),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.coral,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
            ),
            child: Text(_saving ? 'Guardando…' : 'Guardar cambios'),
          ),
        ],
      ),
    );
  }
}
