import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Orbe central de DJ Menzi para la pantalla del LIVE — 1:1 en espíritu con
/// menzoweb/components/music/MenziDjBrand.tsx (el halo/ecualizador que ya existía ahí para el
/// badge chico), pero como centerpiece visible del LIVE. Nunca es el reproductor real (ese sigue
/// siendo el único WebView persistente, ver menzi_dj_player_host.dart) — es puramente decorativo,
/// tocarlo abre el panel real.
///
/// `playing` pulsa el halo de forma continua (misma idea que `.menzi-dj-breathe` en web: no hay
/// forma de leer el nivel real del audio de YouTube dentro del WebView, así que es una
/// respiración constante, no un analizador de espectro real). `voiceLevel` (0.0-1.0, el máximo de
/// `live.speakingLevels` en ese instante) le agrega un empujón extra mientras alguien está
/// hablando, así el orbe también reacciona a la voz del LIVE, no solo a la música.
class DjMenziOrb extends StatefulWidget {
  const DjMenziOrb({
    super.key,
    required this.playing,
    required this.voiceLevel,
    required this.title,
    required this.onTap,
  });

  final bool playing;
  final double voiceLevel;
  final String? title;
  final VoidCallback onTap;

  @override
  State<DjMenziOrb> createState() => _DjMenziOrbState();
}

class _DjMenziOrbState extends State<DjMenziOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final breathe = widget.playing ? _controller.value : 0.0;
              final voiceBoost = widget.voiceLevel.clamp(0.0, 1.0) * 0.18;
              final scale = 1.0 + (breathe * 0.08) + voiceBoost;
              final glow = 0.25 + (breathe * 0.25) + voiceBoost;
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.cyan, AppColors.orange],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.cyan.withValues(alpha: glow),
                        blurRadius: 22,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.graphic_eq, color: Colors.white, size: 30),
                ),
              );
            },
          ),
          if (widget.title != null) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: 96,
              child: Text(
                widget.title!,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
