import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// 1:1 con menzoweb/components/illustrations/MenziIllustrationState.tsx — ilustración de marca
/// para estados vacíos, nunca para reemplazar íconos funcionales (ver sección 5 del pedido de
/// diseño original). Las imágenes vienen de assets/illustrations/menzi/ (copiadas de menzoweb).
class MenziIllustration {
  MenziIllustration._();
  static const chat = 'assets/illustrations/menzi/menzi-chat.webp';
  static const djHero = 'assets/illustrations/menzi/menzi-dj-hero.webp';
  static const djIdle = 'assets/illustrations/menzi/menzi-dj-idle.webp';
  static const friends = 'assets/illustrations/menzi/menzi-friends.webp';
  static const liveVoice = 'assets/illustrations/menzi/menzi-live-voice.webp';
  static const notifications =
      'assets/illustrations/menzi/menzi-notifications.webp';
  static const settings = 'assets/illustrations/menzi/menzi-settings.webp';
}

enum MenziIllustrationSize { small, medium, large }

class MenziIllustrationState extends StatelessWidget {
  const MenziIllustrationState({
    super.key,
    required this.image,
    this.title,
    this.description,
    this.actionLabel,
    this.onAction,
    this.size = MenziIllustrationSize.medium,
    this.compact = false,
  });

  final String image;
  final String? title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final MenziIllustrationSize size;
  final bool compact;

  double get _dimension => switch (size) {
    MenziIllustrationSize.small => 72,
    MenziIllustrationSize.medium => 140,
    MenziIllustrationSize.large => 200,
  };

  @override
  Widget build(BuildContext context) {
    final picture = Image.asset(
      image,
      width: _dimension,
      height: _dimension,
      fit: BoxFit.contain,
    );

    if (compact) {
      return Row(
        children: [
          picture,
          const SizedBox(width: 12),
          if (title != null || description != null)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null) Text(title!, style: AppTextStyles.h3()),
                  if (description != null)
                    Text(description!, style: AppTextStyles.caption()),
                ],
              ),
            ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          picture,
          const SizedBox(height: 12),
          if (title != null)
            Text(
              title!,
              style: AppTextStyles.h3(),
              textAlign: TextAlign.center,
            ),
          if (description != null) ...[
            const SizedBox(height: 4),
            Text(
              description!,
              style: AppTextStyles.caption(),
              textAlign: TextAlign.center,
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                backgroundColor: AppColors.cyan,
                foregroundColor: Colors.black,
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
