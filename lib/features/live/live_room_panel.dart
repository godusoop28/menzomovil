import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/chat_models.dart';
import '../../data/models/live_models.dart';
import '../music/menzi_dj_panel.dart';
import '../shared/menzi_illustration_state.dart';
import '../shared/menzo_avatar.dart';
import '../shared/menzo_toast.dart';
import 'live_provider.dart';

const _stageRoles = {
  LiveParticipantRole.host,
  LiveParticipantRole.coHost,
  LiveParticipantRole.speaker,
};

/// 1:1 con menzoweb/components/live/LiveRoomPanel.tsx — panel de pantalla completa del LIVE:
/// escenario de hablantes, controles de mic/mano, audiencia, y entrada a Menzi DJ.
class LiveRoomPanel extends ConsumerWidget {
  const LiveRoomPanel({
    super.key,
    required this.room,
    required this.onMinimize,
  });

  final ChatRoom room;
  final VoidCallback onMinimize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(liveProvider);
    final isConnectedHere = live.activeRoomId == room.id;
    final stage = isConnectedHere
        ? live.participants.where((p) => _stageRoles.contains(p.role)).toList()
        : <LiveParticipant>[];
    final audience = isConnectedHere
        ? live.participants.where((p) => !_stageRoles.contains(p.role)).toList()
        : <LiveParticipant>[];
    final canModerate =
        room.role == RoomRole.owner || room.role == RoomRole.coHost;

    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: onMinimize,
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.coral,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'LIVE',
                style: AppTextStyles.caption(
                  color: Colors.white,
                ).copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                room.liveSummary?.title ?? room.name ?? '',
                style: AppTextStyles.label(),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.music_note_outlined),
            onPressed: () => showMenziDjPanel(context, room: room),
          ),
        ],
      ),
      body: !isConnectedHere
          ? Center(
              child: MenziIllustrationState(
                image: MenziIllustration.liveVoice,
                description: live.connecting
                    ? 'Conectando…'
                    : 'Conéctate para escuchar este LIVE.',
                actionLabel: live.connecting ? null : 'Escuchar',
                onAction: live.connecting
                    ? null
                    : () => ref.read(liveProvider.notifier).join(room.id),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 8,
                          childAspectRatio: 0.8,
                        ),
                    itemCount: stage.length,
                    itemBuilder: (context, i) => _StageSlot(
                      participant: stage[i],
                      level: live.speakingLevels[stage[i].user?.id] ?? 0,
                    ),
                  ),
                ),
                if (audience.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Escuchando (${audience.length})',
                        style: AppTextStyles.caption(),
                      ),
                    ),
                  ),
                _LiveControls(room: room, canModerate: canModerate),
              ],
            ),
    );
  }
}

class _StageSlot extends StatelessWidget {
  const _StageSlot({required this.participant, required this.level});
  final LiveParticipant participant;
  final double level;

  @override
  Widget build(BuildContext context) {
    final user = participant.user;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.orange.withValues(alpha: 0.4 + level * 0.6),
              width: 2 + level * 2,
            ),
          ),
          padding: const EdgeInsets.all(3),
          child: MenzoAvatar(
            name: user?.displayName ?? '?',
            avatarUri: user?.avatarUri,
            size: 56,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          user?.displayName ?? '',
          style: AppTextStyles.caption(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (!participant.microphoneEnabled)
          const Icon(Icons.mic_off, size: 14, color: AppColors.coral),
      ],
    );
  }
}

class _LiveControls extends ConsumerWidget {
  const _LiveControls({required this.room, required this.canModerate});
  final ChatRoom room;
  final bool canModerate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(liveProvider);
    final micLooksOff = live.muted || !live.localAudioPublished;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (live.canSpeak)
            IconButton(
              iconSize: 26,
              onPressed: live.microphoneChanging
                  ? null
                  : () => ref.read(liveProvider.notifier).toggleMute(),
              icon: Icon(
                micLooksOff ? Icons.mic_off : Icons.mic,
                color: micLooksOff ? AppColors.coral : AppColors.textPrimary,
              ),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surfaceSecondary,
                padding: const EdgeInsets.all(14),
              ),
            )
          else if (live.myRole == LiveParticipantRole.audience)
            TextButton.icon(
              onPressed: () async {
                try {
                  await ref.read(liveProvider.notifier).requestToSpeak(room.id);
                  if (context.mounted)
                    showMenzoToast(context, 'Solicitud enviada.');
                } catch (_) {
                  if (context.mounted)
                    showMenzoToast(context, 'No pudimos enviar tu solicitud.');
                }
              },
              icon: const Icon(Icons.back_hand_outlined, size: 16),
              label: const Text('Solicitar hablar'),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.surfaceSecondary,
                foregroundColor: AppColors.textPrimary,
              ),
            )
          else if (live.myRole == LiveParticipantRole.requested)
            TextButton(
              onPressed: () =>
                  ref.read(liveProvider.notifier).cancelSpeakRequest(room.id),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.surfaceSecondary,
                foregroundColor: AppColors.textPrimary,
              ),
              child: const Text('Solicitud enviada · Cancelar'),
            ),
          const SizedBox(width: 12),
          IconButton(
            iconSize: 26,
            onPressed: () => ref.read(liveProvider.notifier).leave(),
            icon: const Icon(Icons.call_end, color: AppColors.coral),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.coral.withValues(alpha: 0.15),
              padding: const EdgeInsets.all(14),
            ),
          ),
        ],
      ),
    );
  }
}
