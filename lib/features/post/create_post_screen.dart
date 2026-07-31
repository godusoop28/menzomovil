import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/image_prep.dart';
import '../home/home_screen.dart';
import '../shared/gradient_button.dart';
import '../shared/menzo_toast.dart';
import '../shared/segmented_tabs.dart';

enum _ComposeMode { text, image, poll }

/// 1:1 con menzoweb/components/CreatePostComposer.tsx — texto / imagen / encuesta.
class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  _ComposeMode _mode = _ComposeMode.text;
  final _bodyController = TextEditingController();
  final _titleController = TextEditingController();
  final List<TextEditingController> _pollOptions = [
    TextEditingController(),
    TextEditingController(),
  ];
  String? _imagePath;
  bool _posting = false;

  @override
  void dispose() {
    _bodyController.dispose();
    _titleController.dispose();
    for (final c in _pollOptions) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null) return;
    final path = await prepareImageForUpload(image);
    if (mounted) setState(() => _imagePath = path);
  }

  Future<void> _submit() async {
    final body = _bodyController.text.trim();
    if (body.isEmpty) {
      showMenzoToast(context, 'Escribe algo antes de publicar.');
      return;
    }
    if (_mode == _ComposeMode.poll) {
      final options = _pollOptions
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      if (options.length < 2) {
        showMenzoToast(context, 'Agrega al menos 2 opciones para la encuesta.');
        return;
      }
    }
    setState(() => _posting = true);
    try {
      String? uploadedUri;
      if (_mode == _ComposeMode.image && _imagePath != null) {
        uploadedUri = await ref
            .read(uploadsRepositoryProvider)
            .upload(File(_imagePath!));
      }
      await ref.read(postRepositoryProvider).create({
        'type': switch (_mode) {
          _ComposeMode.text => 'text',
          _ComposeMode.image => 'image',
          _ComposeMode.poll => 'poll',
        },
        if (_titleController.text.trim().isNotEmpty)
          'title': _titleController.text.trim(),
        'body': body,
        if (uploadedUri != null) 'imageUri': uploadedUri,
        if (_mode == _ComposeMode.poll)
          'pollOptions': _pollOptions
              .map((c) => c.text.trim())
              .where((t) => t.isNotEmpty)
              .toList(),
      });
      ref.invalidate(feedProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted)
        showMenzoToast(context, 'No pudimos publicar. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Nueva publicación', style: AppTextStyles.h2()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedTabs<_ComposeMode>(
              options: _ComposeMode.values,
              value: _mode,
              onChanged: (m) => setState(() => _mode = m),
              labelBuilder: (m) => switch (m) {
                _ComposeMode.text => 'Texto',
                _ComposeMode.image => 'Imagen',
                _ComposeMode.poll => 'Encuesta',
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              style: AppTextStyles.body(),
              decoration: const InputDecoration(hintText: 'Título (opcional)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _bodyController,
              style: AppTextStyles.body(),
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: '¿Qué quieres compartir?',
              ),
            ),
            if (_mode == _ComposeMode.image) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    image: _imagePath != null
                        ? DecorationImage(
                            image: FileImage(File(_imagePath!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: _imagePath == null
                      ? const Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 32,
                          color: AppColors.textMuted,
                        )
                      : null,
                ),
              ),
            ],
            if (_mode == _ComposeMode.poll) ...[
              const SizedBox(height: 12),
              ..._pollOptions.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: entry.value,
                    style: AppTextStyles.body(),
                    decoration: InputDecoration(
                      hintText: 'Opción ${entry.key + 1}',
                    ),
                  ),
                ),
              ),
              if (_pollOptions.length < 5)
                TextButton.icon(
                  onPressed: () =>
                      setState(() => _pollOptions.add(TextEditingController())),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar opción'),
                ),
            ],
            const SizedBox(height: 20),
            GradientButton(
              label: 'Publicar',
              loading: _posting,
              onPressed: _submit,
              size: GradientButtonSize.lg,
            ),
          ],
        ),
      ),
    );
  }
}
