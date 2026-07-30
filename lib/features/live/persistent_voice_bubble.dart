import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/app_router.dart';
import '../../core/router/current_location.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';
import 'live_provider.dart';

/// 1:1 con menzoweb/components/PersistentVoiceBubble.tsx — "chat head" flotante que se ve en
/// cualquier pantalla mientras haya un LIVE activo, salvo en la propia pantalla de esa sala.
class PersistentVoiceBubble extends ConsumerWidget {
  const PersistentVoiceBubble({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(liveProvider);
    final location = ref.watch(currentLocationProvider);
    final hiddenHere = location == '/chat/${live.activeRoomId}';

    if (!live.connected || live.activeRoomId == null || hiddenHere)
      return const SizedBox.shrink();

    final micLooksOff = live.muted || !live.localAudioPublished;

    return Positioned(
      left: 16,
      right: 16,
      bottom: 90,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          onTap: () =>
              ref.read(appRouterProvider).push('/chat/${live.activeRoomId}'),
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
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: AppColors.orange,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mic,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.coral,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.surfaceElevated,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'EN VIVO',
                        style: AppTextStyles.caption(color: AppColors.coral),
                      ),
                      Text(
                        'Toca para volver',
                        style: AppTextStyles.label(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (live.canSpeak)
                  IconButton(
                    onPressed: live.microphoneChanging
                        ? null
                        : () => ref.read(liveProvider.notifier).toggleMute(),
                    icon: Icon(
                      micLooksOff ? Icons.mic_off : Icons.mic,
                      color: micLooksOff
                          ? AppColors.coral
                          : AppColors.textPrimary,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surfaceSoft,
                    ),
                  ),
                IconButton(
                  onPressed: () => ref.read(liveProvider.notifier).leave(),
                  icon: const Icon(Icons.close, color: AppColors.textPrimary),
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
