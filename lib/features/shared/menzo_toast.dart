import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';

/// Equivalente a menzoweb/components/Toast.tsx (mensaje flotante transitorio, 3.2s) — usa el
/// SnackBar nativo de Flutter (mecanismo estándar, sin overlay a mano) con la misma estética
/// oscura del resto de la app.
void showMenzoToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(message, style: AppTextStyles.body(size: 14)),
        backgroundColor: AppColors.surfaceElevated,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 3200),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
}
