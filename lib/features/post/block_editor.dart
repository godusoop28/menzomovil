import 'dart:io';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/image_prep.dart';
import '../../data/models/gif_models.dart';
import '../../data/models/post_models.dart';
import 'gif_picker_sheet.dart';

const _maxBlocks = 40;

String _newId() =>
    'b-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}';

/// Editor de bloques hecho a mano (sin appflowy_editor/super_editor — ninguno mapea limpio a
/// este contrato JSON de 5 tipos) — un `ReorderableListView` (widget estándar de Flutter) más
/// filas por tipo. 1:1 con menzoweb/components/post/BlockEditor.tsx.
///
/// Las imágenes/GIFs se suben de inmediato al agregarse — cada bloque en `blocks` siempre tiene
/// una URL https ya resuelta; mientras un archivo sube se muestra como una fila temporal aparte,
/// fuera de `blocks`, para que "Publicar" nunca pueda mandar un bloque a medio subir.
class BlockEditor extends ConsumerStatefulWidget {
  const BlockEditor({
    super.key,
    required this.blocks,
    required this.onChanged,
  });

  final List<PostBlock> blocks;
  final ValueChanged<List<PostBlock>> onChanged;

  @override
  ConsumerState<BlockEditor> createState() => _BlockEditorState();
}

class _BlockEditorState extends ConsumerState<BlockEditor> {
  final Map<String, TextEditingController> _controllers = {};
  bool _uploading = false;
  String? _uploadPreviewPath;
  bool _uploadError = false;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(PostBlock block) {
    return _controllers.putIfAbsent(
      block.id,
      () => TextEditingController(text: block.text ?? ''),
    );
  }

  void _addBlock(PostBlock block) {
    widget.onChanged([...widget.blocks, block]);
  }

  void _updateText(String id, String text) {
    widget.onChanged([
      for (final b in widget.blocks) if (b.id == id) b.copyWith(text: text) else b,
    ]);
  }

  void _removeBlock(String id) {
    _controllers.remove(id)?.dispose();
    widget.onChanged(widget.blocks.where((b) => b.id != id).toList());
  }

  void _reorder(int oldIndex, int newIndex) {
    final next = [...widget.blocks];
    if (newIndex > oldIndex) newIndex -= 1;
    final moved = next.removeAt(oldIndex);
    next.insert(newIndex, moved);
    widget.onChanged(next);
  }

  Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null) return;
    final path = await prepareImageForUpload(image);
    if (!mounted) return;
    setState(() {
      _uploading = true;
      _uploadPreviewPath = path;
      _uploadError = false;
    });
    try {
      final url = await ref.read(uploadsRepositoryProvider).upload(File(path));
      final isGif = path.toLowerCase().endsWith('.gif');
      _addBlock(PostBlock(
        id: _newId(),
        type: isGif ? PostBlockType.gif : PostBlockType.image,
        url: url,
      ));
    } catch (_) {
      if (mounted) setState(() => _uploadError = true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _pickGif() {
    showGifPickerSheet(
      context: context,
      onPick: (GifResult gif) {
        _addBlock(PostBlock(id: _newId(), type: PostBlockType.gif, url: gif.url));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final atLimit = widget.blocks.length >= _maxBlocks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: widget.blocks.length,
          onReorder: _reorder,
          itemBuilder: (context, i) {
            final block = widget.blocks[i];
            return Padding(
              key: ValueKey(block.id),
              padding: const EdgeInsets.only(bottom: 8),
              child: _BlockRow(
                index: i,
                block: block,
                controller: block.type == PostBlockType.paragraph || block.type == PostBlockType.heading
                    ? _controllerFor(block)
                    : null,
                onChangedText: (text) => _updateText(block.id, text),
                onRemove: () => _removeBlock(block.id),
              ),
            );
          },
        ),
        if (_uploading || _uploadError)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _uploading
                ? Container(
                    height: 160,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      image: _uploadPreviewPath != null
                          ? DecorationImage(
                              image: FileImage(File(_uploadPreviewPath!)),
                              fit: BoxFit.cover,
                              opacity: 0.4,
                            )
                          : null,
                      color: AppColors.surfaceSecondary,
                    ),
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(),
                  )
                : Text(
                    'No pudimos subir esa imagen. Probá de nuevo.',
                    style: AppTextStyles.caption(color: AppColors.coral),
                  ),
          ),
        if (!atLimit)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _AddChip(
                label: 'Párrafo',
                icon: Icons.add,
                onTap: () => _addBlock(PostBlock(id: _newId(), type: PostBlockType.paragraph, text: '')),
              ),
              _AddChip(
                label: 'Título',
                icon: Icons.add,
                onTap: () => _addBlock(PostBlock(id: _newId(), type: PostBlockType.heading, text: '')),
              ),
              _AddChip(
                label: 'Imagen',
                icon: Icons.image_outlined,
                onTap: _uploading ? null : _pickImage,
              ),
              _AddChip(label: 'GIF', icon: Icons.gif_box_outlined, onTap: _pickGif),
              _AddChip(
                label: 'Separador',
                icon: Icons.horizontal_rule,
                onTap: () => _addBlock(PostBlock(id: _newId(), type: PostBlockType.divider)),
              ),
            ],
          ),
      ],
    );
  }
}

class _AddChip extends StatelessWidget {
  const _AddChip({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: AppColors.textSecondary),
      label: Text(label, style: AppTextStyles.caption(color: AppColors.textSecondary)),
      backgroundColor: AppColors.surfaceSecondary,
      onPressed: onTap,
    );
  }
}

class _BlockRow extends StatelessWidget {
  const _BlockRow({
    required this.index,
    required this.block,
    required this.controller,
    required this.onChangedText,
    required this.onRemove,
  });

  final int index;
  final PostBlock block;
  final TextEditingController? controller;
  final ValueChanged<String> onChangedText;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _content(context)),
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.drag_handle, size: 18, color: AppColors.textMuted),
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 16),
            tooltip: 'Eliminar bloque',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            color: AppColors.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context) {
    switch (block.type) {
      case PostBlockType.paragraph:
        return TextField(
          controller: controller,
          onChanged: (v) => onChangedText(v.length > 2000 ? v.substring(0, 2000) : v),
          style: AppTextStyles.body(),
          maxLines: 4,
          minLines: 2,
          decoration: const InputDecoration(hintText: 'Escribí un párrafo…', border: InputBorder.none),
        );
      case PostBlockType.heading:
        return TextField(
          controller: controller,
          onChanged: (v) => onChangedText(v.length > 150 ? v.substring(0, 150) : v),
          style: AppTextStyles.h3(),
          decoration: const InputDecoration(hintText: 'Título de sección…', border: InputBorder.none),
        );
      case PostBlockType.image:
      case PostBlockType.gif:
        if (block.url == null) return const SizedBox.shrink();
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: CachedNetworkImage(imageUrl: block.url!, height: 180, fit: BoxFit.cover, width: double.infinity),
        );
      case PostBlockType.divider:
        return Row(
          children: [
            const Expanded(child: Divider(color: AppColors.borderSoft)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('Separador', style: AppTextStyles.caption()),
            ),
            const Expanded(child: Divider(color: AppColors.borderSoft)),
          ],
        );
    }
  }
}
