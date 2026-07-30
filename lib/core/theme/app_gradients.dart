import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'app_colors.dart';

/// 1:1 con menzoweb/lib/theme.ts — mismos IDs y mismos colores, en el mismo orden.
enum GradientId { fire, connection, midnight, creative, community }

class AppGradients {
  AppGradients._();

  static const Map<GradientId, List<Color>> _stops = {
    GradientId.fire: [AppColors.yellow, AppColors.orange, AppColors.coral],
    GradientId.connection: [AppColors.blue, AppColors.cyan],
    GradientId.midnight: [AppColors.purple, AppColors.blue, AppColors.cyan],
    GradientId.creative: [AppColors.coral, AppColors.violet, AppColors.blue],
    GradientId.community: [AppColors.green, AppColors.cyan, AppColors.blue],
  };

  static List<Color> colors(GradientId id) => _stops[id]!;

  /// `angle` en grados, igual que `gradientCss` en la web (default 135°: de arriba-izquierda a
  /// abajo-derecha).
  static LinearGradient linear(GradientId id, {double angle = 135}) {
    final radians = angle * math.pi / 180;
    final dx = math.cos(radians);
    final dy = math.sin(radians);
    return LinearGradient(
      begin: Alignment(-dx, -dy),
      end: Alignment(dx, dy),
      colors: colors(id),
    );
  }
}

/// Resuelve un [GradientId] a partir del string que manda el backend (mismo valor que se
/// guarda como "gradient" en ChatRoomDto/UserProfileDto/PostDto) — con "fire" de respaldo,
/// igual que el fallback silencioso que ya hacía la web/RN.
GradientId gradientIdFromName(String? name) {
  return GradientId.values.firstWhere(
    (g) => g.name == name,
    orElse: () => GradientId.fire,
  );
}
