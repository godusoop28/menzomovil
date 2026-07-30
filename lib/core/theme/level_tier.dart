import 'package:flutter/widgets.dart';

import 'app_colors.dart';
import 'app_gradients.dart';

/// 1:1 con menzoweb/lib/theme.ts levelTier() — el color/gradiente/halo del anillo de nivel
/// alrededor de un avatar.
class LevelTier {
  const LevelTier({required this.color, this.gradient, this.glow = false});

  final Color color;
  final GradientId? gradient;
  final bool glow;
}

LevelTier levelTier(int level) {
  if (level >= 30)
    return const LevelTier(
      color: AppColors.yellow,
      gradient: GradientId.fire,
      glow: true,
    );
  if (level >= 20)
    return const LevelTier(color: AppColors.orange, gradient: GradientId.fire);
  if (level >= 10)
    return const LevelTier(
      color: AppColors.purple,
      gradient: GradientId.midnight,
    );
  if (level >= 5) return const LevelTier(color: AppColors.cyan);
  return const LevelTier(color: AppColors.borderStrong);
}
