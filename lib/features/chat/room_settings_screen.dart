import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/chat_models.dart';
import '../shared/confirm_dialog.dart';
import '../shared/gradient_button.dart';
import '../shared/menzo_avatar.dart';
import '../shared/menzo_toast.dart';
import 'chat_room_screen.dart';
import 'room_members_screen.dart';

/// 1:1 con menzoweb/components/room/RoomSettingsPanel.tsx (versión simplificada) — edición de
/// info de la sala + gestión de miembros (promover/degradar/expulsar), solo para OWNER/CO_HOST.
class RoomSettingsScreen extends ConsumerStatefulWidget {
  const RoomSettingsScreen({super.key, required this.room});
  final ChatRoom room;

  @override
  ConsumerState<RoomSettingsScreen> createState() => _RoomSettingsScreenState();
}

class _RoomSettingsScreenState extends ConsumerState<RoomSettingsScreen> {
  late final _nameController = TextEditingController(
    text: widget.room.name ?? '',
  );
  late final _descriptionController = TextEditingController(
    text: widget.room.description ?? '',
  );
  bool _saving = false;

  String? _pendingAvatarPath;
  String? _pendingCoverPath;
  String? _pendingBackgroundPath;

  bool get _isOwner => widget.room.role == RoomRole.owner;
  bool get _canModerate =>
      widget.room.role == RoomRole.owner || widget.room.role == RoomRole.coHost;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(void Function(String path) onPicked) async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image != null) setState(() => onPicked(image.path));
  }

  Future<void> _saveInfo() async {
    setState(() => _saving = true);
    try {
      final uploads = ref.read(uploadsRepositoryProvider);
      final patch = <String, dynamic>{
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
      };
      if (_pendingAvatarPath != null) {
        patch['avatarUri'] = await uploads.ensureUploaded(_pendingAvatarPath);
      }
      if (_pendingCoverPath != null) {
        patch['coverUri'] = await uploads.ensureUploaded(_pendingCoverPath);
      }
      if (_pendingBackgroundPath != null) {
        patch['backgroundUri'] = await uploads.ensureUploaded(
          _pendingBackgroundPath,
        );
      }
      await ref.read(chatRepositoryProvider).updateRoom(widget.room.id, patch);
      ref.invalidate(roomProvider(widget.room.id));
      if (mounted) {
        setState(() {
          _pendingAvatarPath = null;
          _pendingCoverPath = null;
          _pendingBackgroundPath = null;
        });
        showMenzoToast(context, 'Sala actualizada.');
      }
    } catch (_) {
      if (mounted) showMenzoToast(context, 'No pudimos guardar los cambios.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteRoom() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Eliminar sala',
      description:
          'Esta acción no se puede deshacer. Se borran los mensajes y el historial de la sala.',
      confirmLabel: 'Eliminar',
      danger: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(chatRepositoryProvider).deleteRoom(widget.room.id);
      if (mounted) {
        context.pop();
        context.go('/chat');
      }
    } catch (_) {
      if (mounted) showMenzoToast(context, 'No pudimos eliminar la sala.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(roomMembersProvider(widget.room.id));
    return Scaffold(
      appBar: AppBar(
        title: Text('Configuración de la sala', style: AppTextStyles.h2()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Información', style: AppTextStyles.caption()),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            style: AppTextStyles.body(),
            decoration: const InputDecoration(hintText: 'Nombre'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _descriptionController,
            style: AppTextStyles.body(),
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Descripción'),
          ),
          if (_canModerate) ...[
            const SizedBox(height: 24),
            Text('Apariencia', style: AppTextStyles.caption()),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ImagePickerTile(
                  label: 'Avatar',
                  circular: true,
                  size: 84,
                  imagePath: _pendingAvatarPath,
                  imageUrl: widget.room.avatarUri,
                  fallback: widget.room.name ?? '',
                  onTap: () => _pickImage((p) => _pendingAvatarPath = p),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _ImagePickerTile(
                    label: 'Portada',
                    description: 'Aparece en la sala y en el LIVE',
                    size: 84,
                    imagePath: _pendingCoverPath,
                    imageUrl: widget.room.coverUri,
                    fallback: widget.room.name ?? '',
                    onTap: () => _pickImage((p) => _pendingCoverPath = p),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ImagePickerTile(
              label: 'Fondo del chat',
              description: 'Se muestra detrás de los mensajes',
              size: 100,
              wide: true,
              imagePath: _pendingBackgroundPath,
              imageUrl: widget.room.backgroundUri,
              fallback: widget.room.name ?? '',
              onTap: () => _pickImage((p) => _pendingBackgroundPath = p),
            ),
          ],
          const SizedBox(height: 16),
          GradientButton(
            label: 'Guardar',
            loading: _saving,
            onPressed: _saveInfo,
          ),
          const SizedBox(height: 24),
          Text('Miembros', style: AppTextStyles.caption()),
          const SizedBox(height: 8),
          members.when(
            data: (list) => Column(
              children: list
                  .map(
                    (m) => _MemberRow(
                      roomId: widget.room.id,
                      member: m,
                      isOwner: _isOwner,
                    ),
                  )
                  .toList(),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Text(
              'No pudimos cargar los miembros.',
              style: AppTextStyles.body(color: AppColors.coral),
            ),
          ),
          if (_isOwner) ...[
            const SizedBox(height: 32),
            Text(
              'Zona de peligro',
              style: AppTextStyles.caption(color: AppColors.coral),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _deleteRoom,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.coral,
                side: const BorderSide(color: AppColors.coral),
              ),
              child: const Text('Eliminar sala'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Selector de imagen reutilizable para avatar/portada/fondo de la sala — 1:1 con
/// `ImagePickerRow` de menzoweb/components/room/RoomSettingsPanel.tsx (`AppearanceSection`).
class _ImagePickerTile extends StatelessWidget {
  const _ImagePickerTile({
    required this.label,
    required this.imagePath,
    required this.imageUrl,
    required this.fallback,
    required this.onTap,
    this.description,
    this.size = 84,
    this.circular = false,
    this.wide = false,
  });

  final String label;
  final String? description;
  final String? imagePath;
  final String? imageUrl;
  final String fallback;
  final VoidCallback onTap;
  final double size;
  final bool circular;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    Widget image;
    if (imagePath != null) {
      image = Image.file(File(imagePath!), fit: BoxFit.cover);
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      image = Image.network(imageUrl!, fit: BoxFit.cover);
    } else {
      image = Container(
        color: AppColors.surfaceSecondary,
        alignment: Alignment.center,
        child: Icon(
          circular ? Icons.groups_outlined : Icons.image_outlined,
          color: AppColors.textMuted,
        ),
      );
    }

    final preview = ClipRRect(
      borderRadius: BorderRadius.circular(circular ? size / 2 : AppRadius.md),
      child: SizedBox(
        width: wide ? double.infinity : size,
        height: size,
        child: image,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label()),
        if (description != null) ...[
          const SizedBox(height: 2),
          Text(description!, style: AppTextStyles.caption()),
        ],
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Stack(
            alignment: Alignment.center,
            children: [
              preview,
              Container(
                width: wide ? double.infinity : size,
                height: size,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(
                    circular ? size / 2 : AppRadius.md,
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.camera_alt_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MemberRow extends ConsumerStatefulWidget {
  const _MemberRow({
    required this.roomId,
    required this.member,
    required this.isOwner,
  });
  final String roomId;
  final RoomMember member;
  final bool isOwner;

  @override
  ConsumerState<_MemberRow> createState() => _MemberRowState();
}

class _MemberRowState extends ConsumerState<_MemberRow> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(roomMembersProvider(widget.roomId));
    } catch (_) {
      if (mounted) showMenzoToast(context, 'No pudimos completar la acción.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.member;
    final repo = ref.read(chatRepositoryProvider);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          MenzoAvatar(
            name: m.user.displayName,
            avatarUri: m.user.avatarUri,
            size: 36,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(m.user.displayName, style: AppTextStyles.label()),
                Text(switch (m.role) {
                  RoomRole.owner => 'Anfitrión',
                  RoomRole.coHost => 'Coanfitrión',
                  RoomRole.member => 'Miembro',
                }, style: AppTextStyles.caption()),
              ],
            ),
          ),
          if (_busy)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (widget.isOwner && m.role != RoomRole.owner)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
              onSelected: (action) {
                switch (action) {
                  case 'promote':
                    _run(() => repo.promote(widget.roomId, m.user.id));
                  case 'demote':
                    _run(() => repo.demote(widget.roomId, m.user.id));
                  case 'kick':
                    _run(() => repo.kick(widget.roomId, m.user.id));
                }
              },
              itemBuilder: (context) => [
                if (m.role == RoomRole.member)
                  const PopupMenuItem(
                    value: 'promote',
                    child: Text('Hacer coanfitrión'),
                  ),
                if (m.role == RoomRole.coHost)
                  const PopupMenuItem(
                    value: 'demote',
                    child: Text('Quitar coanfitrión'),
                  ),
                const PopupMenuItem(value: 'kick', child: Text('Expulsar')),
              ],
            ),
        ],
      ),
    );
  }
}
