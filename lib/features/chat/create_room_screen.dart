import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_text_styles.dart';
import '../shared/gradient_button.dart';
import '../shared/menzo_toast.dart';
import 'chat_list_screen.dart';

/// 1:1 con el formulario de creación de sala en menzoweb/app/(app)/chat/page.tsx.
class CreateRoomScreen extends ConsumerStatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  ConsumerState<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends ConsumerState<CreateRoomScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _topicController = TextEditingController();
  bool _creating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showMenzoToast(context, 'Ponle un nombre a tu sala.');
      return;
    }
    setState(() => _creating = true);
    try {
      final room = await ref.read(chatRepositoryProvider).createRoom({
        'name': name,
        if (_descriptionController.text.trim().isNotEmpty)
          'description': _descriptionController.text.trim(),
        if (_topicController.text.trim().isNotEmpty)
          'topic': _topicController.text.trim(),
      });
      ref.invalidate(myRoomsProvider);
      if (mounted) {
        context.pop();
        context.push('/chat/${room.id}');
      }
    } catch (_) {
      if (mounted) showMenzoToast(context, 'No pudimos crear la sala.');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Crear sala', style: AppTextStyles.h2())),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              style: AppTextStyles.body(),
              decoration: const InputDecoration(hintText: 'Nombre de la sala'),
              maxLength: 40,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _topicController,
              style: AppTextStyles.body(),
              decoration: const InputDecoration(hintText: 'Tema (opcional)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descriptionController,
              style: AppTextStyles.body(),
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Descripción (opcional)',
              ),
            ),
            const SizedBox(height: 20),
            GradientButton(
              label: 'Crear sala',
              loading: _creating,
              onPressed: _submit,
              size: GradientButtonSize.lg,
            ),
          ],
        ),
      ),
    );
  }
}
