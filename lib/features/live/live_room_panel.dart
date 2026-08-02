import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/native/bubble_preference.dart';
import '../../core/native/live_bubble_channel.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/providers/auth_provider.dart';
import '../../data/models/chat_models.dart';
import '../../data/models/live_models.dart';
import '../../data/models/music_models.dart';
import '../music/dj_menzi_orb.dart';
import '../music/menzi_dj_panel.dart';
import '../music/menzi_dj_provider.dart';
import '../shared/confirm_dialog.dart';
import '../shared/menzi_illustration_state.dart';
import '../shared/menzo_avatar.dart';
import '../shared/menzo_sheet.dart';
import '../shared/menzo_toast.dart';
import 'live_provider.dart';

const _stageRoles = {
  LiveParticipantRole.host,
  LiveParticipantRole.coHost,
  LiveParticipantRole.speaker,
};

/// 1:1 con menzoweb/components/live/LiveRoomPanel.tsx — panel de pantalla completa del LIVE:
/// escenario de hablantes, anuncio, temporizador, audiencia, moderación y entrada a DJ Menzi.
class LiveRoomPanel extends ConsumerStatefulWidget {
  const LiveRoomPanel({
    super.key,
    required this.room,
    required this.onMinimize,
  });

  final ChatRoom room;
  final VoidCallback onMinimize;

  @override
  ConsumerState<LiveRoomPanel> createState() => _LiveRoomPanelState();
}

class _LiveRoomPanelState extends ConsumerState<LiveRoomPanel> {
  @override
  void initState() {
    super.initState();
    // Mientras este panel está montado, los overlays persistentes (mini-bar de voz, mini-bar
    // de DJ Menzi) deben quedar ocultos — si no, sus controles fijos (posicionados a un número
    // de píxeles del borde inferior de TODA la pantalla) pueden terminar superpuestos a los
    // propios controles del panel (mic/salir), que también viven abajo de todo. Se marca acá en
    // vez de inferirlo de la ruta actual porque un `Navigator.push` común (como este) no cambia
    // la ubicación que ve go_router.
    Future.microtask(
      () => ref.read(isLiveRoomPanelOpenProvider.notifier).state = true,
    );
  }

  @override
  void dispose() {
    ref.read(isLiveRoomPanelOpenProvider.notifier).state = false;
    super.dispose();
  }

  ChatRoom get room => widget.room;
  VoidCallback get onMinimize => widget.onMinimize;

  @override
  Widget build(BuildContext context) {
    final live = ref.watch(liveProvider);
    final music = ref.watch(menziDjProvider);
    final myId = ref.watch(authProvider).profile?.id;
    final isConnectedHere = live.activeRoomId == room.id;
    final stage = isConnectedHere
        ? live.participants.where((p) => _stageRoles.contains(p.role)).toList()
        : <LiveParticipant>[];
    final audience = isConnectedHere
        ? live.participants.where((p) => !_stageRoles.contains(p.role)).toList()
        : <LiveParticipant>[];
    final announcement = isConnectedHere ? live.session?.announcement : null;

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
            if (isConnectedHere && live.session?.startedAt != null)
              _LiveTimer(startedAt: live.session!.startedAt!),
          ],
        ),
        actions: [
          if (isConnectedHere && live.canModerate)
            IconButton(
              icon: Badge(
                isLabelVisible: live.speakingRequests.isNotEmpty,
                label: Text('${live.speakingRequests.length}'),
                child: const Icon(Icons.settings_outlined),
              ),
              onPressed: () => _showModerationSheet(context, ref, room),
            ),
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
                // Antes, si `join()` fallaba (problema de red, Agora, lo que sea), el error
                // quedaba guardado en `live.lastMicrophoneError` pero nunca se mostraba acá — el
                // usuario solo veía el mismo cartel genérico de siempre, tocaba "Escuchar" de
                // nuevo, y sin ninguna pista de qué había fallado parecía que "no pasaba nada".
                description: live.connecting
                    ? 'Conectando…'
                    : (live.lastMicrophoneError ??
                          'Conéctate para escuchar este LIVE.'),
                actionLabel: live.connecting ? null : 'Escuchar',
                onAction: live.connecting
                    ? null
                    : () => ref.read(liveProvider.notifier).join(room.id),
              ),
            )
          : Column(
              children: [
                const _BubbleOptInPrompt(),
                if (live.reconnecting)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.cyan.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Reconectando el audio del LIVE…',
                          style: AppTextStyles.caption(color: AppColors.cyan),
                        ),
                      ],
                    ),
                  ),
                if (announcement != null && announcement.trim().isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.orange.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: AppColors.orange.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.campaign_outlined,
                          size: 18,
                          color: AppColors.orange,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            announcement,
                            style: AppTextStyles.body(),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (music.hasTrack)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: DjMenziOrb(
                      playing: music.session?.status == MusicSessionStatus.playing,
                      voiceLevel: live.speakingLevels.values.isEmpty
                          ? 0
                          : live.speakingLevels.values.reduce((a, b) => a > b ? a : b),
                      title: music.session?.currentTitle,
                      onTap: () => showMenziDjPanel(context, room: room),
                    ),
                  ),
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
                    itemBuilder: (context, i) {
                      final isMe = stage[i].user?.id == myId;
                      return _StageSlot(
                        participant: stage[i],
                        level: live.speakingLevels[stage[i].user?.id] ?? 0,
                        // El propio mic-off nunca debe depender de la lista de participantes
                        // (server-side, solo se refresca con eventos STOMP de otros) — si
                        // estás solo en la sala esa lista jamás se refresca sola y el ícono
                        // queda pegado. Para uno mismo se usa la verdad local de Agora.
                        micOffOverride: isMe
                            ? (live.muted || !live.localAudioPublished)
                            : null,
                      );
                    },
                  ),
                ),
                if (audience.isNotEmpty) _AudienceSection(audience: audience),
                _LiveControls(room: room),
              ],
            ),
    );
  }
}

/// Prompt contextual (una sola vez, nunca en el primer inicio de la app) para pedir permiso de
/// overlay y activar la burbuja flotante — se monta al entrar a un LIVE, que es exactamente el
/// momento en que tiene sentido explicarlo. Si el usuario dice que no, o el sistema rechaza el
/// permiso, no pasa nada: sigue disponible la mini-barra dentro de la app y puede activarla
/// después desde Configuración (ver `settings_screen.dart`).
class _BubbleOptInPrompt extends StatefulWidget {
  const _BubbleOptInPrompt();

  @override
  State<_BubbleOptInPrompt> createState() => _BubbleOptInPromptState();
}

class _BubbleOptInPromptState extends State<_BubbleOptInPrompt> {
  /// Solo en memoria (no persistido) — se resetea al reiniciar la app. Antes se guardaba en
  /// disco que "ya se preguntó" apenas se MOSTRABA el diálogo (sin importar la respuesta), así
  /// que un solo "Ahora no" tocado una vez, alguna vez, dejaba el permiso sin volver a pedirse
  /// NUNCA MÁS. Ahora se vuelve a preguntar en cada LIVE nuevo (una vez por sesión de la app)
  /// mientras el permiso siga sin concederse de verdad — este permiso de overlay es solo para
  /// la burbuja del LIVE; DJ Menzi ya no depende de él (el reproductor nativo de fondo que sí
  /// lo necesitaba se retiró, ver MENZI_DJ_ARCHITECTURE.md).
  static bool _declinedThisSession = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePrompt());
  }

  Future<void> _maybePrompt() async {
    // Nunca confiar en un flag propio de "ya se concedió" — siempre se vuelve a comprobar el
    // estado real (pudo revocarse desde Ajustes, o el diálogo anterior pudo haberse aceptado
    // sin que el usuario llegara a tocar el switch en la pantalla de Ajustes de Android).
    if (await LiveBubbleChannel.checkPermission()) {
      await BubblePreference.setEnabled(true);
      return;
    }
    if (_declinedThisSession) return;
    if (!mounted) return;
    final accepted = await showConfirmDialog(
      context,
      title: 'Mantené el LIVE activo al minimizar',
      description:
          'Menzo necesita este permiso para que tu voz y DJ Menzi sigan sonando cuando minimizás la app o usás otra — además vas a ver una burbuja para volver rápido a la llamada. Sin esto, el audio se corta al salir de Menzo.',
      confirmLabel: 'Permitir',
      cancelLabel: 'Ahora no',
    );
    if (!accepted) {
      _declinedThisSession = true;
      return;
    }
    await BubblePreference.setEnabled(true);
    await LiveBubbleChannel.requestPermission();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _LiveTimer extends StatefulWidget {
  const _LiveTimer({required this.startedAt});
  final DateTime startedAt;

  @override
  State<_LiveTimer> createState() => _LiveTimerState();
}

class _LiveTimerState extends State<_LiveTimer> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.startedAt);
    final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = elapsed.inHours;
    final label = hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
    return Text(
      label,
      style: AppTextStyles.caption(color: AppColors.textMuted),
    );
  }
}

class _AudienceSection extends StatefulWidget {
  const _AudienceSection({required this.audience});
  final List<LiveParticipant> audience;

  @override
  State<_AudienceSection> createState() => _AudienceSectionState();
}

class _AudienceSectionState extends State<_AudienceSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Text(
                  'Escuchando (${widget.audience.length})',
                  style: AppTextStyles.caption(),
                ),
                const SizedBox(width: 4),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                children: widget.audience
                    .map(
                      (p) => SizedBox(
                        width: 56,
                        child: Column(
                          children: [
                            MenzoAvatar(
                              name: p.user?.displayName ?? '?',
                              avatarUri: p.user?.avatarUri,
                              size: 40,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              p.user?.displayName ?? '',
                              style: AppTextStyles.caption(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _StageSlot extends StatelessWidget {
  const _StageSlot({
    required this.participant,
    required this.level,
    this.micOffOverride,
  });
  final LiveParticipant participant;
  final double level;

  /// Cuando no es `null`, reemplaza a `!participant.microphoneEnabled` — se usa para el propio
  /// tile del usuario local, cuya verdad de mic vive en [LiveState] (Agora), no en la lista de
  /// participantes que llega del backend (ver comentario en el `itemBuilder` que instancia esto).
  final bool? micOffOverride;

  @override
  Widget build(BuildContext context) {
    final user = participant.user;
    final micOff = micOffOverride ?? !participant.microphoneEnabled;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
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
            if (participant.role == LiveParticipantRole.host ||
                participant.role == LiveParticipantRole.coHost)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceElevated,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    participant.role == LiveParticipantRole.host
                        ? Icons.star
                        : Icons.shield,
                    size: 12,
                    color: AppColors.orange,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          user?.displayName ?? '',
          style: AppTextStyles.caption(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (micOff) const Icon(Icons.mic_off, size: 14, color: AppColors.coral),
      ],
    );
  }
}

class _LiveControls extends ConsumerWidget {
  const _LiveControls({required this.room});
  final ChatRoom room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(liveProvider);
    final micLooksOff = live.muted || !live.localAudioPublished;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (live.canSpeak && live.microphonePermissionDenied)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const Icon(Icons.mic_off, size: 16, color: AppColors.coral),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sin permiso de micrófono — estás en el LIVE pero no podés hablar.',
                      style: AppTextStyles.caption(color: AppColors.coral),
                    ),
                  ),
                  TextButton(
                    onPressed: openAppSettings,
                    child: const Text('Ajustes'),
                  ),
                ],
              ),
            ),
          Row(
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
                    color: micLooksOff
                        ? AppColors.coral
                        : AppColors.textPrimary,
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
                      await ref
                          .read(liveProvider.notifier)
                          .requestToSpeak(room.id);
                      if (context.mounted)
                        showMenzoToast(context, 'Solicitud enviada.');
                    } catch (_) {
                      if (context.mounted)
                        showMenzoToast(
                          context,
                          'No pudimos enviar tu solicitud.',
                        );
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
                  onPressed: () => ref
                      .read(liveProvider.notifier)
                      .cancelSpeakRequest(room.id),
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
        ],
      ),
    );
  }
}

void _showModerationSheet(BuildContext context, WidgetRef ref, ChatRoom room) {
  showMenzoSheet(
    context: context,
    title: 'Moderar LIVE',
    subtitle: 'Solicitudes, participantes y anuncio',
    builder: (context) => _ModerationSheetBody(room: room),
  );
}

class _ModerationSheetBody extends ConsumerStatefulWidget {
  const _ModerationSheetBody({required this.room});
  final ChatRoom room;

  @override
  ConsumerState<_ModerationSheetBody> createState() =>
      _ModerationSheetBodyState();
}

class _ModerationSheetBodyState extends ConsumerState<_ModerationSheetBody> {
  late final TextEditingController _announcementController;

  @override
  void initState() {
    super.initState();
    final live = ref.read(liveProvider);
    _announcementController = TextEditingController(
      text: live.session?.announcement ?? '',
    );
  }

  @override
  void dispose() {
    _announcementController.dispose();
    super.dispose();
  }

  Future<void> _saveAnnouncement() async {
    try {
      await ref
          .read(liveProvider.notifier)
          .updateAnnouncement(
            widget.room.id,
            _announcementController.text.trim(),
          );
      if (mounted) showMenzoToast(context, 'Anuncio actualizado.');
    } catch (_) {
      if (mounted) showMenzoToast(context, 'No pudimos actualizar el anuncio.');
    }
  }

  Future<void> _endLive() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Finalizar LIVE',
      description: 'Se cerrará para todos los participantes.',
      confirmLabel: 'Finalizar',
      danger: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(liveProvider.notifier).endLiveForAll(widget.room.id);
      if (mounted) Navigator.of(context).maybePop();
    } catch (_) {
      if (mounted) showMenzoToast(context, 'No pudimos finalizar el LIVE.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final live = ref.watch(liveProvider);
    final myId = ref.watch(authProvider).profile?.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Anuncio', style: AppTextStyles.label()),
        const SizedBox(height: 8),
        TextField(
          controller: _announcementController,
          style: AppTextStyles.body(),
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: 'Ej: Haciendo un 24hs, no me eliminen ni cancelen la…',
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _saveAnnouncement,
            child: const Text('Guardar anuncio'),
          ),
        ),
        const Divider(height: 28, color: AppColors.borderSoft),
        Text(
          'Solicitudes para hablar (${live.speakingRequests.length})',
          style: AppTextStyles.label(),
        ),
        const SizedBox(height: 8),
        if (live.speakingRequests.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Nadie pidió el micrófono todavía.',
              style: AppTextStyles.body(color: AppColors.textMuted),
            ),
          )
        else
          ...live.speakingRequests.map(
            (p) => _RequestTile(
              participant: p,
              onApprove: () => ref
                  .read(liveProvider.notifier)
                  .approveSpeaking(widget.room.id, p.user!.id),
              onReject: () => ref
                  .read(liveProvider.notifier)
                  .rejectSpeaking(widget.room.id, p.user!.id),
            ),
          ),
        const Divider(height: 28, color: AppColors.borderSoft),
        Text('Participantes', style: AppTextStyles.label()),
        const SizedBox(height: 8),
        ...live.participants
            .where((p) => p.user != null && p.user!.id != myId)
            .map(
              (p) => _ParticipantModTile(
                participant: p,
                onMute: p.microphoneEnabled
                    ? () => ref
                          .read(liveProvider.notifier)
                          .muteParticipant(widget.room.id, p.user!.id)
                    : null,
                onDemote:
                    _stageRoles.contains(p.role) &&
                        p.role != LiveParticipantRole.host
                    ? () => ref
                          .read(liveProvider.notifier)
                          .demoteParticipant(widget.room.id, p.user!.id)
                    : null,
                onRemove: () => ref
                    .read(liveProvider.notifier)
                    .removeParticipant(widget.room.id, p.user!.id),
              ),
            ),
        const Divider(height: 28, color: AppColors.borderSoft),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _endLive,
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('Finalizar LIVE para todos'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.coral,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({
    required this.participant,
    required this.onApprove,
    required this.onReject,
  });
  final LiveParticipant participant;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final user = participant.user;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          MenzoAvatar(
            name: user?.displayName ?? '?',
            avatarUri: user?.avatarUri,
            size: 36,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(user?.displayName ?? '', style: AppTextStyles.body()),
          ),
          IconButton(
            onPressed: onReject,
            icon: const Icon(Icons.close, color: AppColors.coral),
          ),
          IconButton(
            onPressed: onApprove,
            icon: const Icon(Icons.check, color: AppColors.orange),
          ),
        ],
      ),
    );
  }
}

class _ParticipantModTile extends StatelessWidget {
  const _ParticipantModTile({
    required this.participant,
    this.onMute,
    this.onDemote,
    required this.onRemove,
  });
  final LiveParticipant participant;
  final VoidCallback? onMute;
  final VoidCallback? onDemote;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final user = participant.user;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          MenzoAvatar(
            name: user?.displayName ?? '?',
            avatarUri: user?.avatarUri,
            size: 36,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(user?.displayName ?? '', style: AppTextStyles.body()),
          ),
          if (onMute != null)
            IconButton(
              tooltip: 'Silenciar',
              onPressed: onMute,
              icon: const Icon(Icons.mic_off, size: 18),
            ),
          if (onDemote != null)
            IconButton(
              tooltip: 'Bajar del escenario',
              onPressed: onDemote,
              icon: const Icon(Icons.arrow_downward, size: 18),
            ),
          IconButton(
            tooltip: 'Expulsar',
            onPressed: onRemove,
            icon: const Icon(
              Icons.person_remove_outlined,
              size: 18,
              color: AppColors.coral,
            ),
          ),
        ],
      ),
    );
  }
}
