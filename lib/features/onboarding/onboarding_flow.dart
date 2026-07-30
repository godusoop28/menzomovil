import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';
import '../shared/gradient_button.dart';
import '../shared/menzo_avatar.dart';
import '../shared/menzo_image_background.dart';
import '../shared/menzo_toast.dart';
import 'onboarding_draft_provider.dart';

final aurasProvider = FutureProvider(
  (ref) => ref.watch(userRepositoryProvider).auras(),
);
final interestsProvider = FutureProvider(
  (ref) => ref.watch(userRepositoryProvider).interests(),
);

/// Wizard de 5 pasos (nombre → aura → avatar → intereses → confirmar) — 1:1 con
/// menzoweb/app/onboarding/*.
class OnboardingFlowScreen extends ConsumerWidget {
  const OnboardingFlowScreen({super.key, required this.step});
  final String step;

  int get _index =>
      onboardingSteps.indexOf(step).clamp(0, onboardingSteps.length - 1);

  void _goToStep(BuildContext context, int index) {
    if (index < 0 || index >= onboardingSteps.length) return;
    context.go('/onboarding/${onboardingSteps[index]}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: MenzoImageBackground(
        imagePath: 'assets/backgrounds/background-onboarding.png',
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Row(
                  children: List.generate(onboardingSteps.length, (i) {
                    final active = i <= _index;
                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        height: 4,
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.orange
                              : AppColors.surfaceSoft,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: switch (step) {
                    'name' => _NameStep(
                      onNext: () => _goToStep(context, _index + 1),
                    ),
                    'aura' => _AuraStep(
                      onNext: () => _goToStep(context, _index + 1),
                      onBack: () => _goToStep(context, _index - 1),
                    ),
                    'avatar' => _AvatarStep(
                      onNext: () => _goToStep(context, _index + 1),
                      onBack: () => _goToStep(context, _index - 1),
                    ),
                    'interests' => _InterestsStep(
                      onNext: () => _goToStep(context, _index + 1),
                      onBack: () => _goToStep(context, _index - 1),
                    ),
                    _ => _ConfirmStep(
                      onBack: () => _goToStep(context, _index - 1),
                    ),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NameStep extends ConsumerStatefulWidget {
  const _NameStep({required this.onNext});
  final VoidCallback onNext;

  @override
  ConsumerState<_NameStep> createState() => _NameStepState();
}

class _NameStepState extends ConsumerState<_NameStep> {
  late final _controller = TextEditingController(
    text: ref.read(onboardingDraftProvider).displayName,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('¿Cómo te llamamos?', style: AppTextStyles.h1()),
        const SizedBox(height: 8),
        Text(
          'Este es el nombre que van a ver los demás en Menzo.',
          style: AppTextStyles.body(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _controller,
          style: AppTextStyles.body(),
          decoration: const InputDecoration(hintText: 'Tu nombre'),
          maxLength: 20,
        ),
        const Spacer(),
        GradientButton(
          label: 'Continuar',
          size: GradientButtonSize.lg,
          onPressed: () {
            final trimmed = _controller.text.trim();
            if (trimmed.length < 2) {
              showMenzoToast(context, 'Escribe al menos 2 caracteres.');
              return;
            }
            ref.read(onboardingDraftProvider.notifier).setDisplayName(trimmed);
            widget.onNext();
          },
        ),
      ],
    );
  }
}

class _AuraStep extends ConsumerWidget {
  const _AuraStep({required this.onNext, required this.onBack});
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auras = ref.watch(aurasProvider);
    final selected = ref.watch(onboardingDraftProvider).aura;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Elegí tu aura', style: AppTextStyles.h1()),
        const SizedBox(height: 8),
        Text(
          'Define el color y el estilo que te va a acompañar en Menzo.',
          style: AppTextStyles.body(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: auras.when(
            data: (options) => GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.6,
              ),
              itemCount: options.length,
              itemBuilder: (context, i) {
                final option = options[i];
                final active = option.id == selected;
                final gradientId = gradientIdFromName(option.gradient);
                return GestureDetector(
                  onTap: () => ref
                      .read(onboardingDraftProvider.notifier)
                      .setAura(option.id),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AppGradients.linear(gradientId),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: active
                          ? Border.all(color: Colors.white, width: 2)
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      option.label,
                      style: AppTextStyles.label(color: AppColors.textOnAccent),
                    ),
                  ),
                );
              },
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Text(
              'No pudimos cargar las auras.',
              style: AppTextStyles.body(color: AppColors.coral),
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onBack,
                child: const Text('Atrás'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: GradientButton(
                label: 'Continuar',
                size: GradientButtonSize.lg,
                onPressed: onNext,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AvatarStep extends ConsumerWidget {
  const _AvatarStep({required this.onNext, required this.onBack});
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(onboardingDraftProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Elegí tu foto', style: AppTextStyles.h1()),
        const SizedBox(height: 8),
        Text(
          'Opcional — podés cambiarla cuando quieras.',
          style: AppTextStyles.body(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        Center(
          child: GestureDetector(
            onTap: () async {
              final picker = ImagePicker();
              final image = await picker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 85,
              );
              if (image != null)
                ref
                    .read(onboardingDraftProvider.notifier)
                    .setAvatarUri(image.path);
            },
            child: Stack(
              children: [
                MenzoAvatar(
                  name: draft.displayName,
                  avatarUri: draft.avatarUri,
                  gradient: gradientIdFromName(draft.aura),
                  size: 140,
                ),
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppColors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 18,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onBack,
                child: const Text('Atrás'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: GradientButton(
                label: 'Continuar',
                size: GradientButtonSize.lg,
                onPressed: onNext,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InterestsStep extends ConsumerWidget {
  const _InterestsStep({required this.onNext, required this.onBack});
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interests = ref.watch(interestsProvider);
    final selected = ref.watch(onboardingDraftProvider).interests;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('¿Qué te interesa?', style: AppTextStyles.h1()),
        const SizedBox(height: 8),
        Text(
          'Elegí hasta 5 — nos ayuda a mostrarte mejor contenido.',
          style: AppTextStyles.body(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: interests.when(
            data: (options) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map((option) {
                final active = selected.contains(option.id);
                return GestureDetector(
                  onTap: () => ref
                      .read(onboardingDraftProvider.notifier)
                      .toggleInterest(option.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.orange
                          : AppColors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      option.label,
                      style: AppTextStyles.label(
                        color: active ? Colors.black : AppColors.textPrimary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Text(
              'No pudimos cargar los intereses.',
              style: AppTextStyles.body(color: AppColors.coral),
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onBack,
                child: const Text('Atrás'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: GradientButton(
                label: 'Continuar',
                size: GradientButtonSize.lg,
                onPressed: onNext,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ConfirmStep extends ConsumerStatefulWidget {
  const _ConfirmStep({required this.onBack});
  final VoidCallback onBack;

  @override
  ConsumerState<_ConfirmStep> createState() => _ConfirmStepState();
}

class _ConfirmStepState extends ConsumerState<_ConfirmStep> {
  bool _submitting = false;

  Future<void> _submit() async {
    final draft = ref.read(onboardingDraftProvider);
    setState(() => _submitting = true);
    try {
      String? uploadedUri;
      if (draft.avatarUri != null) {
        uploadedUri = await ref
            .read(uploadsRepositoryProvider)
            .ensureUploaded(draft.avatarUri);
      }
      await ref
          .read(authProvider.notifier)
          .completeOnboarding(
            displayName: draft.displayName,
            aura: draft.aura,
            avatarUri: uploadedUri,
            avatarGradient: draft.aura,
            interests: draft.interests,
          );
    } catch (_) {
      if (mounted)
        showMenzoToast(
          context,
          'No pudimos terminar tu registro. Intenta de nuevo.',
        );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(onboardingDraftProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Todo listo, ${draft.displayName}', style: AppTextStyles.h1()),
        const SizedBox(height: 8),
        Text(
          'Revisá y confirmá tu perfil para entrar a la comunidad.',
          style: AppTextStyles.body(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        Center(
          child: MenzoAvatar(
            name: draft.displayName,
            avatarUri: draft.avatarUri,
            gradient: gradientIdFromName(draft.aura),
            size: 120,
          ),
        ),
        const SizedBox(height: 16),
        Center(child: Text(draft.displayName, style: AppTextStyles.h2())),
        Center(
          child: Text(
            '${draft.interests.length} intereses seleccionados',
            style: AppTextStyles.caption(),
          ),
        ),
        const Spacer(),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: widget.onBack,
                child: const Text('Atrás'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: GradientButton(
                label: 'Entrar a Menzo',
                size: GradientButtonSize.lg,
                loading: _submitting,
                onPressed: _submit,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
