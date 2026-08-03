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
///
/// Además de imágenes/colores (apariencia), edita themeConfig (fondos adicionales de feed/chat,
/// estilo de encabezado/tarjetas, decoraciones) y navigationConfig (secciones visibles, orden,
/// etiquetas) — ambos JSONB de shape libre en el backend, 1:1 con la versión web.
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

const _themeImageSlots = [
  ('navBackgroundUrl', 'Fondo del menú/navegación'),
  ('feedBackgroundUrl', 'Fondo del feed'),
  ('chatBackgroundUrl', 'Fondo de la bandeja de mensajes'),
];

const _headerStyles = ['default', 'compact', 'banner', 'minimal'];
const _cardStyles = ['rounded', 'square', 'flat', 'elevated'];

const _navSectionDefaults = [
  ('home', 'Inicio', 1),
  ('posts', 'Publicaciones', 2),
  ('blogs', 'Blogs', 3),
  ('chats', 'Chats', 4),
  ('live', 'LIVE', 5),
  ('members', 'Miembros', 6),
  ('events', 'Eventos', 7),
  ('about', 'Información', 8),
];

class _CommunityAppearanceScreenState extends ConsumerState<CommunityAppearanceScreen> {
  CommunityDetail? _community;
  final Map<String, String> _images = {};
  final Map<String, TextEditingController> _colorControllers = {
    for (final (key, _) in _colorSlots) key: TextEditingController(),
  };
  final Map<String, String> _themeImages = {};
  String _headerStyle = _headerStyles.first;
  String _cardStyle = _cardStyles.first;
  final List<String> _decorations = [];
  final _decorationUrlController = TextEditingController();
  final Map<String, Map<String, dynamic>> _nav = {};
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
    _decorationUrlController.dispose();
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

        final theme = detail.themeConfig;
        _themeImages['navBackgroundUrl'] = (theme['navBackgroundUrl'] as String?) ?? '';
        _themeImages['feedBackgroundUrl'] = (theme['feedBackgroundUrl'] as String?) ?? '';
        _themeImages['chatBackgroundUrl'] = (theme['chatBackgroundUrl'] as String?) ?? '';
        _headerStyle = (theme['headerStyle'] as String?) ?? _headerStyles.first;
        _cardStyle = (theme['cardStyle'] as String?) ?? _cardStyles.first;
        _decorations
          ..clear()
          ..addAll((theme['decorations'] as List?)?.cast<String>() ?? const []);

        final nav = detail.navigationConfig;
        for (final (key, label, order) in _navSectionDefaults) {
          final existing = nav[key] as Map?;
          _nav[key] = existing != null
              ? {
                  'enabled': existing['enabled'] as bool? ?? true,
                  'order': existing['order'] as int? ?? order,
                  'label': existing['label'] as String? ?? label,
                }
              : {'enabled': true, 'order': order, 'label': label};
        }
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
    // COMMUNITY_CURATOR+ — igual que CommunityPermissionEvaluator.requireCanEditAppearance en
    // el backend (curador, moderador, admin u owner).
    final isCommunityStaff =
        role == CommunityRole.curator ||
        role == CommunityRole.moderator ||
        role == CommunityRole.admin ||
        role == CommunityRole.owner;
    return isGlobalStaff || isCommunityStaff;
  }

  Future<String?> _uploadImage() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null) return null;
    try {
      return await ref.read(uploadsRepositoryProvider).upload(File(image.path));
    } catch (_) {
      if (mounted) setState(() => _error = 'No pudimos subir la imagen.');
      return null;
    }
  }

  Future<void> _pickImage(String key) async {
    final url = await _uploadImage();
    if (url != null && mounted) setState(() => _images[key] = url);
  }

  Future<void> _pickThemeImage(String key) async {
    final url = await _uploadImage();
    if (url != null && mounted) setState(() => _themeImages[key] = url);
  }

  Future<void> _pickDecoration() async {
    final url = await _uploadImage();
    if (url != null && mounted) setState(() => _decorations.add(url));
  }

  void _addDecorationUrl() {
    final url = _decorationUrlController.text.trim();
    if (url.isEmpty) return;
    setState(() {
      _decorations.add(url);
      _decorationUrlController.clear();
    });
  }

  Future<void> _save() async {
    if (_community == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(communitiesRepositoryProvider);
      await repo.updateAppearance(_community!.id, {
        ..._images,
        for (final (key, _) in _colorSlots) key: _colorControllers[key]!.text.trim(),
      });
      await repo.updateTheme(_community!.id, {
        if (_themeImages['navBackgroundUrl']?.isNotEmpty ?? false)
          'navBackgroundUrl': _themeImages['navBackgroundUrl'],
        if (_themeImages['feedBackgroundUrl']?.isNotEmpty ?? false)
          'feedBackgroundUrl': _themeImages['feedBackgroundUrl'],
        if (_themeImages['chatBackgroundUrl']?.isNotEmpty ?? false)
          'chatBackgroundUrl': _themeImages['chatBackgroundUrl'],
        'headerStyle': _headerStyle,
        'cardStyle': _cardStyle,
        'decorations': _decorations,
      });
      await repo.updateNavigation(_community!.id, _nav);
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

    final sortedNavKeys = _nav.keys.toList()
      ..sort((a, b) => (_nav[a]!['order'] as int).compareTo(_nav[b]!['order'] as int));

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

          const SizedBox(height: 8),
          Text('Fondos adicionales', style: AppTextStyles.label().copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 8),
          for (final (key, label) in _themeImageSlots)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  CommunityBadge(iconUrl: _themeImages[key], color: _community!.primaryColor, size: 56),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: AppTextStyles.body()),
                        TextButton(onPressed: () => _pickThemeImage(key), child: const Text('Cambiar')),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),
          Text('Estilo', style: AppTextStyles.label().copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DropdownButtonFormField<String>(
              initialValue: _headerStyle,
              decoration: const InputDecoration(labelText: 'Encabezado'),
              items: _headerStyles
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _headerStyle = v ?? _headerStyle),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DropdownButtonFormField<String>(
              initialValue: _cardStyle,
              decoration: const InputDecoration(labelText: 'Tarjetas'),
              items: _cardStyles
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _cardStyle = v ?? _cardStyle),
            ),
          ),

          const SizedBox(height: 8),
          Text('Decoraciones', style: AppTextStyles.label().copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 4),
          Text(
            'Marcos, insignias, separadores o fondos de temporada — imágenes sueltas usables en la comunidad.',
            style: AppTextStyles.caption(),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _decorations.length; i++)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: CommunityBadge(iconUrl: _decorations[i], size: 64),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () => setState(() => _decorations.removeAt(i)),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(onPressed: _pickDecoration, child: const Text('Subir imagen')),
              Expanded(
                child: TextField(
                  controller: _decorationUrlController,
                  decoration: const InputDecoration(hintText: 'o pegá una URL'),
                ),
              ),
              TextButton(onPressed: _addDecorationUrl, child: const Text('Agregar')),
            ],
          ),

          const SizedBox(height: 8),
          Text('Navegación', style: AppTextStyles.label().copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 8),
          for (final key in sortedNavKeys)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Checkbox(
                    value: _nav[key]!['enabled'] as bool,
                    onChanged: (v) => setState(() => _nav[key]!['enabled'] = v ?? true),
                  ),
                  Expanded(
                    child: TextFormField(
                      initialValue: _nav[key]!['label'] as String,
                      decoration: const InputDecoration(isDense: true),
                      onChanged: (v) => _nav[key]!['label'] = v,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 56,
                    child: TextFormField(
                      initialValue: '${_nav[key]!['order']}',
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(isDense: true),
                      onChanged: (v) => _nav[key]!['order'] = int.tryParse(v) ?? _nav[key]!['order'],
                    ),
                  ),
                ],
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
