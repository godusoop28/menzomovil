import 'package:flutter/material.dart';

const _overlayTint = Color(0xFF07090D);

/// 1:1 con menzoweb/components/ScreenBackground.tsx — imagen (o color liso) de fondo con velo
/// oscuro + degradado hacia abajo, usado en login/registro/onboarding, el hero de home, el
/// perfil propio/ajeno y el directorio de miembros para que la app se sienta con la misma
/// identidad visual "comunidad" que la web en vez de fondos planos.
class MenzoImageBackground extends StatelessWidget {
  const MenzoImageBackground({
    super.key,
    this.imagePath,
    this.color,
    this.overlay = 0.72,
    required this.child,
  });

  final String? imagePath;
  final Color? color;
  final double overlay;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (imagePath != null)
          Image.asset(imagePath!, fit: BoxFit.cover)
        else
          ColoredBox(color: color ?? _overlayTint),
        ColoredBox(color: _overlayTint.withValues(alpha: overlay)),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x2607090D), Color(0x5907090D), Color(0xE607090D)],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
        ),
        child,
      ],
    );
  }
}
