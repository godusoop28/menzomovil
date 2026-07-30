import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';

/// Primitivo único de modal/bottom-sheet para toda la app — 1:1 con
/// menzoweb/components/ui/Sheet.tsx (ahí es centrado en desktop / hoja en mobile; acá, al ser
/// solo móvil, siempre es una hoja que sube desde abajo).
Future<T?> showMenzoSheet<T>({
  required BuildContext context,
  required String title,
  String? subtitle,
  required WidgetBuilder builder,
  Widget? footer,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    builder: (context) => _MenzoSheetShell(
      title: title,
      subtitle: subtitle,
      footer: footer,
      child: Builder(builder: builder),
    ),
  );
}

class _MenzoSheetShell extends StatelessWidget {
  const _MenzoSheetShell({
    required this.title,
    this.subtitle,
    required this.child,
    this.footer,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.92;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl),
            ),
            border: Border.fromBorderSide(
              BorderSide(color: AppColors.borderSoft),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: AppTextStyles.h3(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle!,
                              style: AppTextStyles.caption(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(
                        Icons.close,
                        color: AppColors.textPrimary,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surfaceSecondary,
                        shape: const CircleBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.borderSoft),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: child,
                ),
              ),
              if (footer != null) ...[
                const Divider(height: 1, color: AppColors.borderSoft),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: footer!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
