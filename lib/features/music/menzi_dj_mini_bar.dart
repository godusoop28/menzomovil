import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/app_router.dart';
import '../../core/router/current_location.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/live_models.dart';
import '../live/live_provider.dart';
import '../shared/menzi_illustration_state.dart';
import 'menzi_dj_provider.dart';

/// Barra flotante minimizada de Menzi DJ — 1:1 con la parte de "mini reproductor" de
/// menzoweb/components/music/MenziDjPlayerHost.tsx. Tocarla vuelve a la sala del LIVE; el
/// panel completo de buscar/cola se abre desde el botón de música del header de esa sala.
class MenziDjMiniBar extends ConsumerWidget {
  const MenziDjMiniBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final music = ref.watch(menziDjProvider);
    final live = ref.watch(liveProvider);
    final location = ref.watch(currentLocationProvider);
    final hiddenHere = location == '/chat/${live.activeRoomId}';

    if (!music.hasTrack ||
        music.expanded ||
        live.activeRoomId == null ||
        hiddenHere) {
      return const SizedBox.shrink();
    }

    final isPlaying = music.session?.status.name == 'playing';
    final canModerate =
        live.myRole == LiveParticipantRole.host ||
        live.myRole == LiveParticipantRole.coHost;

    return Positioned(
      left: 16,
      right: 16,
      bottom: 150,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          onTap: () {
            ref.read(appRouterProvider).push('/chat/${live.activeRoomId}');
            ref.read(menziDjProvider.notifier).setExpanded(true);
          },
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: AppColors.borderStrong),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: music.session?.currentThumbnailUrl != null
                      ? CachedNetworkImage(
                          imageUrl: music.session!.currentThumbnailUrl!,
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                        )
                      : Image.asset(
                          MenziIllustration.djIdle,
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                        ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'MENZI DJ',
                        style: AppTextStyles.caption(color: AppColors.cyan),
                      ),
                      Text(
                        music.session?.currentTitle ?? 'Reproduciendo…',
                        style: AppTextStyles.label(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (canModerate)
                  IconButton(
                    onPressed: () => isPlaying
                        ? ref.read(menziDjProvider.notifier).pauseTrack()
                        : ref.read(menziDjProvider.notifier).resumeTrack(),
                    icon: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: AppColors.textPrimary,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surfaceSoft,
                    ),
                  ),
                IconButton(
                  onPressed: () =>
                      ref.read(menziDjProvider.notifier).toggleLocalMute(),
                  icon: Icon(
                    music.localMuted ? Icons.volume_off : Icons.volume_up,
                    color: AppColors.textPrimary,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surfaceSoft,
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
