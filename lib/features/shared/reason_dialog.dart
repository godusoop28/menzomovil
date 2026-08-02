import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';

/// Como showConfirmDialog, pero exige escribir un motivo antes de confirmar — usado por toda
/// acción de moderación de staff global (suspender, eliminar cuenta, ocultar/borrar publicación,
/// cambiar rol, etc.), que siempre queda registrada en el log de moderación con ese motivo.
/// Devuelve el motivo (String no vacío) si se confirmó, o null si se canceló.
Future<String?> showReasonDialog(
  BuildContext context, {
  required String title,
  String? description,
  String confirmLabel = 'Confirmar',
  String cancelLabel = 'Cancelar',
}) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final canConfirm = controller.text.trim().isNotEmpty;
        return Dialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppTextStyles.h3(), textAlign: TextAlign.center),
                if (description != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: AppTextStyles.body(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  maxLines: 3,
                  maxLength: 300,
                  onChanged: (_) => setState(() {}),
                  style: AppTextStyles.body(),
                  decoration: const InputDecoration(hintText: 'Motivo (obligatorio)'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.surfaceSecondary,
                          foregroundColor: AppColors.textPrimary,
                          side: BorderSide.none,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                        ),
                        child: Text(cancelLabel),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: canConfirm
                            ? () => Navigator.of(context).pop(controller.text.trim())
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.coral,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                        ),
                        child: Text(confirmLabel),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
  controller.dispose();
  return result;
}
