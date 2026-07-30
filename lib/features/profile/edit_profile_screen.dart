import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_text_styles.dart';
import '../shared/gradient_button.dart';
import '../shared/menzo_avatar.dart';
import '../shared/menzo_toast.dart';

/// 1:1 con menzoweb/app/(app)/profile/edit/page.tsx.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final _nameController = TextEditingController(
    text: ref.read(authProvider).profile?.displayName ?? '',
  );
  late final _bioController = TextEditingController(
    text: ref.read(authProvider).profile?.bio ?? '',
  );
  String? _pendingAvatarUri;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image != null) setState(() => _pendingAvatarUri = image.path);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final patch = <String, dynamic>{
        'displayName': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
      };
      if (_pendingAvatarUri != null) {
        patch['avatarUri'] = await ref
            .read(uploadsRepositoryProvider)
            .ensureUploaded(_pendingAvatarUri);
      }
      final updated = await ref.read(userRepositoryProvider).updateMe(patch);
      ref.read(authProvider.notifier).setProfile(updated);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) showMenzoToast(context, 'No pudimos guardar tus cambios.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authProvider).profile;
    return Scaffold(
      appBar: AppBar(title: Text('Editar perfil', style: AppTextStyles.h2())),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickAvatar,
                child: MenzoAvatar(
                  name: _nameController.text,
                  avatarUri: _pendingAvatarUri ?? profile?.avatarUri,
                  gradient: gradientIdFromName(profile?.avatarGradient),
                  size: 100,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Nombre', style: AppTextStyles.caption()),
            const SizedBox(height: 6),
            TextField(
              controller: _nameController,
              style: AppTextStyles.body(),
              maxLength: 20,
            ),
            const SizedBox(height: 12),
            Text('Biografía', style: AppTextStyles.caption()),
            const SizedBox(height: 6),
            TextField(
              controller: _bioController,
              style: AppTextStyles.body(),
              maxLines: 3,
              maxLength: 160,
            ),
            const SizedBox(height: 24),
            GradientButton(
              label: 'Guardar cambios',
              loading: _saving,
              onPressed: _save,
              size: GradientButtonSize.lg,
            ),
          ],
        ),
      ),
    );
  }
}
