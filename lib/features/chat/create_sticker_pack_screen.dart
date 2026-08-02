import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';

/// 1:1 con menzoweb/app/(app)/stickers/create/page.tsx. Cualquier usuario logueado puede crear un
/// pack — se vuelve público y usable por cualquier otro en el instante en que se crea, sin paso
/// de "agregar a mi bandeja" (ver StickerRepository).
class CreateStickerPackScreen extends ConsumerStatefulWidget {
  const CreateStickerPackScreen({super.key});

  @override
  ConsumerState<CreateStickerPackScreen> createState() => _CreateStickerPackScreenState();
}

class _CreateStickerPackScreenState extends ConsumerState<CreateStickerPackScreen> {
  final _nameController = TextEditingController();
  final _paths = <String>[];
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // A propósito, NO usa prepareImageForUpload: esa función re-comprime todo lo que no sea .gif
  // como JPEG (ver image_prep.dart), lo que aplanaría la transparencia de un PNG — crítico para
  // stickers, que dependen de fondo transparente. Se sube el archivo elegido tal cual.
  Future<void> _addImages() async {
    final picked = await ImagePicker().pickMultiImage();
    if (picked.isEmpty) return;
    if (!mounted) return;
    setState(() => _paths.addAll(picked.map((f) => f.path).take(30 - _paths.length)));
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _paths.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final uploadsRepo = ref.read(uploadsRepositoryProvider);
      final imageUrls = <String>[];
      for (final path in _paths) {
        imageUrls.add(await uploadsRepo.upload(File(path)));
      }
      await ref.read(stickerRepositoryProvider).createPack(name, imageUrls);
      if (!mounted) return;
      context.pop();
    } catch (_) {
      if (mounted) setState(() => _error = 'No pudimos crear el pack — probá de nuevo.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _nameController.text.trim().isNotEmpty && _paths.isNotEmpty && !_saving;

    return Scaffold(
      appBar: AppBar(title: Text('Nuevo pack de stickers', style: AppTextStyles.h2())),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              maxLength: 60,
              onChanged: (_) => setState(() {}),
              style: AppTextStyles.body(),
              decoration: const InputDecoration(hintText: 'Nombre del pack'),
            ),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: _paths.length + 1,
                itemBuilder: (context, i) {
                  if (i == _paths.length) {
                    return GestureDetector(
                      onTap: _addImages,
                      child: DottedBorderBox(
                        child: const Icon(Icons.add, color: AppColors.textMuted),
                      ),
                    );
                  }
                  final path = _paths[i];
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: Image.file(File(path), fit: BoxFit.contain, width: double.infinity, height: double.infinity),
                      ),
                      Positioned(
                        right: 4,
                        top: 4,
                        child: GestureDetector(
                          onTap: () => setState(() => _paths.removeAt(i)),
                          child: const CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.black54,
                            child: Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: AppTextStyles.body(color: AppColors.coral)),
              ),
            ElevatedButton(
              onPressed: canSave ? _save : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.coral,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
              ),
              child: Text(_saving ? 'Creando…' : 'Crear pack'),
            ),
          ],
        ),
      ),
    );
  }
}

class DottedBorderBox extends StatelessWidget {
  const DottedBorderBox({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderStrong),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}
