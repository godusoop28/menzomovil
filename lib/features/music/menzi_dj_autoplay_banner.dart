import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';
import '../live/live_provider.dart';
import 'menzi_dj_provider.dart';

/// Aviso de "el navegador/OS bloqueó el autoplay de audio" — separado del mini-reproductor
/// (ver menzi_dj_player_host.dart) porque es una alerta urgente y transversal: debe verse sin
/// importar el modo (mini/oculto/normal/cinema) ni la ruta actual, algo que ya no tiene sentido
/// mezclar con el widget que sí varía por modo/ruta.
class MenziDjAutoplayBanner extends ConsumerWidget {
  const MenziDjAutoplayBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final music = ref.watch(menziDjProvider);
    final live = ref.watch(liveProvider);

    if (!music.hasTrack || live.activeRoomId == null || !music.autoplayBlocked) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: 16,
      right: 16,
      bottom: 150,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          onTap: () => ref.read(menziDjProvider.notifier).enableAudioAfterGesture(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: AppColors.cyan),
            ),
            child: Row(
              children: [
                Icon(Icons.volume_off, color: AppColors.cyan),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Toca para activar el audio de DJ Menzi',
                    style: AppTextStyles.label(color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
