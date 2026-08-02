import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/post_models.dart';
import '../home/home_screen.dart';
import '../shared/gradient_button.dart';
import '../shared/menzo_toast.dart';
import '../shared/segmented_tabs.dart';
import 'block_editor.dart';

enum _ComposeMode { text, image, poll }

bool _hasRealContent(List<PostBlock> blocks) => blocks.any(
  (b) =>
      ((b.type == PostBlockType.paragraph || b.type == PostBlockType.heading) &&
          (b.text?.trim().isNotEmpty ?? false)) ||
      b.type == PostBlockType.image ||
      b.type == PostBlockType.gif,
);

/// 1:1 con menzoweb/components/CreatePostComposer.tsx — texto / imagen / encuesta. Texto e
/// imagen comparten el mismo editor de bloques (ver BlockEditor) desde acá, igual que en web.
class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  _ComposeMode _mode = _ComposeMode.text;
  final _titleController = TextEditingController();
  final _pollQuestionController = TextEditingController();
  final List<TextEditingController> _pollOptions = [
    TextEditingController(),
    TextEditingController(),
  ];
  List<PostBlock> _blocks = [];
  bool _posting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _pollQuestionController.dispose();
    for (final c in _pollOptions) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_mode == _ComposeMode.poll) {
      final question = _pollQuestionController.text.trim();
      if (question.isEmpty) {
        showMenzoToast(context, 'Escribe algo antes de publicar.');
        return;
      }
      final options = _pollOptions
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      if (options.length < 2) {
        showMenzoToast(context, 'Agrega al menos 2 opciones para la encuesta.');
        return;
      }
    } else if (!_hasRealContent(_blocks)) {
      showMenzoToast(context, 'Escribe algo antes de publicar.');
      return;
    }
    setState(() => _posting = true);
    try {
      final hasMedia = _blocks.any(
        (b) => b.type == PostBlockType.image || b.type == PostBlockType.gif,
      );
      await ref.read(postRepositoryProvider).create({
        'type': switch (_mode) {
          _ComposeMode.text => hasMedia ? 'image' : 'text',
          _ComposeMode.image => hasMedia ? 'image' : 'text',
          _ComposeMode.poll => 'poll',
        },
        if (_titleController.text.trim().isNotEmpty)
          'title': _titleController.text.trim(),
        'body': _mode == _ComposeMode.poll ? _pollQuestionController.text.trim() : '',
        if (_mode != _ComposeMode.poll)
          'blocks': _blocks.map((b) => b.toJson()).toList(),
        if (_mode == _ComposeMode.poll)
          'pollOptions': _pollOptions
              .map((c) => c.text.trim())
              .where((t) => t.isNotEmpty)
              .toList(),
      });
      ref.invalidate(feedProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        showMenzoToast(context, 'No pudimos publicar. Intenta de nuevo.');
      }
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
            if (_mode == _ComposeMode.poll) ...[
              TextField(
                controller: _pollQuestionController,
                style: AppTextStyles.body(),
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'Escribe tu pregunta'),
              ),
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
            ] else
              BlockEditor(
                blocks: _blocks,
                onChanged: (blocks) => setState(() => _blocks = blocks),
              ),
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
