import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/diagnostics/app_diagnostic_logger.dart';
import '../../core/network/api_exception.dart';
import '../../data/models/chat_models.dart';
import '../../data/models/music_models.dart';
import '../diagnostics/menzi_dj_logs_screen.dart';
import '../shared/menzi_illustration_state.dart';
import '../shared/menzo_sheet.dart';
import '../shared/menzo_toast.dart';
import '../shared/segmented_tabs.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';
import 'menzi_dj_player_html.dart';
import 'menzi_dj_provider.dart';
import 'menzi_player_display_mode.dart';

enum _Tab { search, queue, requests, history }

String _formatDuration(int? seconds) {
  if (seconds == null) return '';
  final m = seconds ~/ 60;
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// 1:1 con menzoweb/components/music/MenziDjPanel.tsx.
void showMenziDjPanel(BuildContext context, {required ChatRoom room}) {
  showMenzoSheet(
    context: context,
    title: 'DJ Menzi',
    subtitle: room.name,
    builder: (context) => _MenziDjPanelBody(room: room),
  );
}

class _MenziDjPanelBody extends ConsumerStatefulWidget {
  const _MenziDjPanelBody({required this.room});
  final ChatRoom room;

  @override
  ConsumerState<_MenziDjPanelBody> createState() => _MenziDjPanelBodyState();
}

/// Categorías relevantes al player — las que arma "Ver diagnóstico" al abrir
/// [MenziDjLogsScreen] (Fase 4 del pedido de diagnóstico sin ADB).
const _playerDiagnosticCategories = {
  DiagnosticCategory.musicSession,
  DiagnosticCategory.ytInstance,
  DiagnosticCategory.ytCommand,
  DiagnosticCategory.ytState,
  DiagnosticCategory.ytError,
  DiagnosticCategory.autoplay,
};

enum _PlayerDiagnosticStatus { playing, loading, error, notReady }

_PlayerDiagnosticStatus _playerDiagnosticStatusOf(MenziDjState music) {
  if (music.hasPlayerError) return _PlayerDiagnosticStatus.error;
  if (!music.playerReady) return _PlayerDiagnosticStatus.notReady;
  if (music.autoplayBlocked || music.loading) return _PlayerDiagnosticStatus.loading;
  if (music.session?.status == MusicSessionStatus.playing) {
    return _PlayerDiagnosticStatus.playing;
  }
  return _PlayerDiagnosticStatus.notReady;
}

Color _playerDiagnosticStatusColor(_PlayerDiagnosticStatus status) => switch (status) {
  _PlayerDiagnosticStatus.playing => Colors.greenAccent,
  _PlayerDiagnosticStatus.loading => Colors.amber,
  _PlayerDiagnosticStatus.error => AppColors.coral,
  _PlayerDiagnosticStatus.notReady => Colors.grey,
};

String _playerDiagnosticStatusLabel(_PlayerDiagnosticStatus status) => switch (status) {
  _PlayerDiagnosticStatus.playing => 'reproduciendo y audible',
  _PlayerDiagnosticStatus.loading => 'cargando/autoplay',
  _PlayerDiagnosticStatus.error => 'error',
  _PlayerDiagnosticStatus.notReady => 'player no listo',
};

class _MenziDjPanelBodyState extends ConsumerState<_MenziDjPanelBody> {
  _Tab _tab = _Tab.search;
  bool _diagnosticOverlayOpen = false;
  final _videoSlotKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref
          .read(menziDjProvider.notifier)
          .setDisplayMode(MenziPlayerDisplayMode.normal),
    );
  }

  @override
  void dispose() {
    final notifier = ref.read(menziDjProvider.notifier);
    // Nunca deja un modo "normal/cine" con nadie midiendo su hueco — sin esto, el WebView
    // quedaría posicionado en el último rect conocido (que ya no existe, el panel se cerró) en
    // vez de volver a la burbuja mini. Si estaba en fullscreen, MenziDjPlayerHost es quien
    // restaura el modo inmersivo del sistema (ver su propio `ref.listen`), no hace falta acá.
    notifier.setDisplayMode(MenziPlayerDisplayMode.mini);
    notifier.reportVideoSlotRect(null);
    super.dispose();
  }

  bool get _canModerate =>
      widget.room.role == RoomRole.owner || widget.room.role == RoomRole.coHost;

  void _setMode(MenziPlayerDisplayMode mode) =>
      ref.read(menziDjProvider.notifier).setDisplayMode(mode);

  /// El WebView del video sigue viviendo en la raíz del árbol (ver menzi_dj_player_host.dart),
  /// nunca dentro de este sheet — este placeholder solo RESERVA el espacio dentro del contenido
  /// scrolleable del panel (para que el resto de los controles nunca quede tapado) y reporta,
  /// después de cada frame, dónde está en coordenadas de pantalla, para que el WebView flotante
  /// se pueda posicionar ahí (ver [MenziDjNotifier.reportVideoSlotRect]).
  void _reportVideoSlotRect() {
    final mode = ref.read(menziDjProvider).displayMode;
    final notifier = ref.read(menziDjProvider.notifier);
    if (mode != MenziPlayerDisplayMode.normal && mode != MenziPlayerDisplayMode.cinema) {
      notifier.reportVideoSlotRect(null);
      return;
    }
    final renderObject = _videoSlotKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) return;
    final topLeft = renderObject.localToGlobal(Offset.zero);
    notifier.reportVideoSlotRect(
      Rect.fromLTWH(topLeft.dx, topLeft.dy, renderObject.size.width, renderObject.size.height),
    );
  }

  @override
  Widget build(BuildContext context) {
    final music = ref.watch(menziDjProvider);
    final session = music.session;
    final diagnosticStatus = _playerDiagnosticStatusOf(music);
    final mode = music.displayMode;
    final showsVideoSlot =
        session?.currentVideoId != null &&
        (mode == MenziPlayerDisplayMode.normal || mode == MenziPlayerDisplayMode.cinema);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reportVideoSlotRect();
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showsVideoSlot) ...[
          AspectRatio(
            key: _videoSlotKey,
            aspectRatio: 16 / 9,
            child: const DecoratedBox(
              decoration: BoxDecoration(color: Colors.black),
            ),
          ),
          const SizedBox(height: 10),
        ],
        // Fase de diagnóstico sin ADB/logcat — mientras exista, este indicador + acceso rápido
        // conviven acá. `_diagnosticOverlayOpen` inserta un bloque MÁS dentro de este mismo
        // Column (nunca un Stack/Positioned encima de los controles reales), así por
        // construcción nunca puede tapar nada — solo empuja el resto del panel hacia abajo.
        Row(
          children: [
            Tooltip(
              message: _playerDiagnosticStatusLabel(diagnosticStatus),
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _playerDiagnosticStatusColor(diagnosticStatus),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _playerDiagnosticStatusLabel(diagnosticStatus),
                style: AppTextStyles.caption(),
              ),
            ),
            IconButton(
              tooltip: _diagnosticOverlayOpen ? 'Ocultar últimas líneas' : 'Ver últimas líneas',
              iconSize: 18,
              onPressed: () => setState(() => _diagnosticOverlayOpen = !_diagnosticOverlayOpen),
              icon: Icon(_diagnosticOverlayOpen ? Icons.expand_less : Icons.expand_more),
            ),
            TextButton(
              onPressed: () => context.push(
                '/debug/menzi-dj-logs',
                extra: const MenziDjLogsScreenArgs(categories: _playerDiagnosticCategories),
              ),
              child: const Text('Ver diagnóstico'),
            ),
          ],
        ),
        if (_diagnosticOverlayOpen) _CompactDiagnosticOverlay(onClose: () => setState(() => _diagnosticOverlayOpen = false)),
        const SizedBox(height: 4),
        if (session?.currentVideoId != null)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: session!.currentThumbnailUrl != null
                      ? CachedNetworkImage(
                          imageUrl: session.currentThumbnailUrl!,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 56,
                          height: 56,
                          color: Colors.black,
                          child: const Icon(
                            Icons.music_note,
                            color: AppColors.textMuted,
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        session.currentTitle ?? '',
                        style: AppTextStyles.label(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        session.currentChannelTitle ?? '',
                        style: AppTextStyles.caption(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else if (music.loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (music.loadError)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Text(
                  'No pudimos cargar DJ Menzi. Reintentando...',
                  style: AppTextStyles.body(color: AppColors.coral),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => ref.read(menziDjProvider.notifier).refresh(),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.surfaceSecondary,
                  ),
                  child: const Text('Reintentar ahora'),
                ),
              ],
            ),
          )
        else
          const MenziIllustrationState(
            image: MenziIllustration.djHero,
            title: 'DJ Menzi',
            description: 'Busca una canción o pega un enlace para comenzar.',
            size: MenziIllustrationSize.small,
          ),
        if (session != null && music.loadError) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.sync_problem, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'No se pudo actualizar DJ Menzi — mostrando la última info conocida.',
                  style: AppTextStyles.caption(),
                ),
              ),
            ],
          ),
        ],
        if (music.hasPlayerError) ...[
          const SizedBox(height: 10),
          _PlayerErrorBanner(
            code: music.playerErrorCode!,
            canModerate: _canModerate,
          ),
        ],
        if (music.needsManualResume) ...[
          const SizedBox(height: 10),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: () =>
                  ref.read(menziDjProvider.notifier).resumeAfterUnexpectedPause(),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.cyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.cyan.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.play_circle_outline, size: 18, color: AppColors.cyan),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('DJ Menzi se pausó. Toca para continuar.'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_canModerate && session?.currentVideoId != null) ...[
              IconButton(
                onPressed: () => session!.status == MusicSessionStatus.playing
                    ? ref.read(menziDjProvider.notifier).pauseTrack()
                    : ref.read(menziDjProvider.notifier).resumeTrack(),
                icon: Icon(
                  session!.status == MusicSessionStatus.playing
                      ? Icons.pause
                      : Icons.play_arrow,
                ),
                tooltip: session!.status == MusicSessionStatus.playing
                    ? 'Pausar'
                    : 'Reproducir',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.black,
                ),
              ),
              IconButton(
                onPressed: () => ref.read(menziDjProvider.notifier).skip(),
                icon: const Icon(Icons.skip_next),
                tooltip: 'Siguiente canción',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceSecondary,
                ),
              ),
              IconButton(
                onPressed: () => ref.read(menziDjProvider.notifier).stopMusic(),
                icon: const Icon(Icons.stop),
                tooltip: 'Detener música',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.coral.withValues(alpha: 0.15),
                  foregroundColor: AppColors.coral,
                ),
              ),
            ],
            IconButton(
              onPressed: () =>
                  ref.read(menziDjProvider.notifier).toggleLocalMute(),
              icon: Icon(music.localMuted ? Icons.volume_off : Icons.volume_up),
              tooltip: music.localMuted ? 'Activar música' : 'Silenciar música',
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surfaceSecondary,
              ),
            ),
            if (session?.currentVideoId != null) ...[
              IconButton(
                onPressed: () => _setMode(
                  mode == MenziPlayerDisplayMode.hidden
                      ? MenziPlayerDisplayMode.normal
                      : MenziPlayerDisplayMode.hidden,
                ),
                icon: Icon(
                  mode == MenziPlayerDisplayMode.hidden
                      ? Icons.videocam_off
                      : Icons.videocam_outlined,
                ),
                tooltip: mode == MenziPlayerDisplayMode.hidden
                    ? 'Mostrar video'
                    : 'Ocultar video',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceSecondary,
                ),
              ),
              IconButton(
                onPressed: () => _setMode(
                  mode == MenziPlayerDisplayMode.cinema
                      ? MenziPlayerDisplayMode.normal
                      : MenziPlayerDisplayMode.cinema,
                ),
                icon: Icon(
                  mode == MenziPlayerDisplayMode.cinema
                      ? Icons.crop_landscape
                      : Icons.theaters_outlined,
                ),
                tooltip: mode == MenziPlayerDisplayMode.cinema
                    ? 'Salir de modo cine'
                    : 'Modo cine',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceSecondary,
                ),
              ),
              IconButton(
                onPressed: () => _setMode(MenziPlayerDisplayMode.fullscreen),
                icon: const Icon(Icons.fullscreen),
                tooltip: 'Pantalla completa',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceSecondary,
                ),
              ),
            ],
          ],
        ),
        // Volumen LOCAL de DJ Menzi — nunca llega al backend ni afecta a nadie más (ver
        // MenziDjNotifier.setLocalVolume): cada dispositivo elige el suyo, independiente del
        // volumen de la llamada de Agora.
        if (session?.currentVideoId != null)
          Row(
            children: [
              Icon(
                music.localMuted ? Icons.volume_off : Icons.volume_down,
                size: 18,
                color: AppColors.textMuted,
              ),
              Expanded(
                child: Slider(
                  value: music.localVolume.toDouble(),
                  min: 0,
                  max: 100,
                  // Fase 8: cada tick de `onChanged` (decenas por segundo durante un arrastre)
                  // pasa por MenziDjNotifier.setLocalVolume, que internamente decide si manda el
                  // comando ahora o lo descarta (throttle ~80ms, ver shouldSendThrottledVolume)
                  // — el valor local/UI siempre se actualiza igual, solo el comando al bridge se
                  // limita. `onChangeEnd` SIEMPRE manda el valor final, sin pasar por el
                  // throttle, para no perder el último valor si cayó justo en una ventana
                  // descartada.
                  onChanged: (value) => ref
                      .read(menziDjProvider.notifier)
                      .setLocalVolume(value.round()),
                  onChangeEnd: (value) => ref
                      .read(menziDjProvider.notifier)
                      .setLocalVolume(value.round(), bypassThrottleForFinalValue: true),
                ),
              ),
              const Icon(Icons.volume_up, size: 18, color: AppColors.textMuted),
            ],
          ),
        const SizedBox(height: 12),
        SegmentedTabs<_Tab>(
          options: _canModerate
              ? _Tab.values
              : _Tab.values.where((t) => t != _Tab.requests).toList(),
          value: _tab,
          onChanged: (t) => setState(() => _tab = t),
          labelBuilder: (t) => switch (t) {
            _Tab.search => 'Buscar',
            _Tab.queue =>
              'Cola${session != null ? ' (${session.queue.length})' : ''}',
            _Tab.requests =>
              'Solicitudes${session != null && session.pendingRequests.isNotEmpty ? ' (${session.pendingRequests.length})' : ''}',
            _Tab.history => 'Historial',
          },
        ),
        const SizedBox(height: 12),
        switch (_tab) {
          _Tab.search => _SearchTab(canModerate: _canModerate),
          _Tab.queue => _QueueTab(session: session, canModerate: _canModerate),
          _Tab.requests => _RequestsTab(session: session),
          _Tab.history => _HistoryTab(session: session),
        },
      ],
    );
  }
}

/// Se muestra cuando el IFrame Player reporta un error real para el video actual (ver
/// [YtPlayerError]) — nunca dejamos solamente el recuadro genérico del WebView; siempre hay una
/// salida: ver en YouTube, elegir otra canción, o saltar (moderadores).
class _PlayerErrorBanner extends ConsumerWidget {
  const _PlayerErrorBanner({required this.code, required this.canModerate});
  final int code;
  final bool canModerate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.coral.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.coral.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, size: 18, color: AppColors.coral),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  YtPlayerError.describe(code),
                  style: AppTextStyles.body(color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final url = ref
                      .read(menziDjProvider.notifier)
                      .currentYoutubeUrl;
                  if (url == null) return;
                  await launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  );
                },
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Ver en YouTube'),
              ),
              if (canModerate)
                OutlinedButton.icon(
                  onPressed: () => ref.read(menziDjProvider.notifier).skip(),
                  icon: const Icon(Icons.skip_next, size: 16),
                  label: const Text('Saltar'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SearchTab extends ConsumerStatefulWidget {
  const _SearchTab({required this.canModerate});
  final bool canModerate;

  @override
  ConsumerState<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends ConsumerState<_SearchTab> {
  final _controller = TextEditingController();
  List<YoutubeSearchResult>? _results;
  String? _error;
  bool _searching = false;
  String? _busyVideoId;

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.length < 3) {
      showMenzoToast(context, 'Escribe al menos 3 caracteres para buscar.');
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final found = await ref.read(menziDjProvider.notifier).searchSongs(query);
      setState(() => _results = found);
    } catch (e) {
      setState(
        () => _error = e is ApiException
            ? e.message
            : 'No pudimos buscar música en este momento.',
      );
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _addToQueue(String videoId, bool playNow) async {
    setState(() => _busyVideoId = videoId);
    try {
      await ref
          .read(menziDjProvider.notifier)
          .addToQueue(videoId, playNow: playNow);
      if (mounted)
        showMenzoToast(
          context,
          playNow ? 'Reproduciendo ahora.' : 'Se agregó a la cola.',
        );
    } catch (_) {
      if (mounted) showMenzoToast(context, 'No pudimos agregar esa canción.');
    } finally {
      if (mounted) setState(() => _busyVideoId = null);
    }
  }

  Future<void> _request(String videoId) async {
    setState(() => _busyVideoId = videoId);
    try {
      await ref.read(menziDjProvider.notifier).requestSong(videoId);
      if (mounted) showMenzoToast(context, 'Solicitud enviada.');
    } catch (_) {
      if (mounted) showMenzoToast(context, 'No pudimos enviar tu solicitud.');
    } finally {
      if (mounted) setState(() => _busyVideoId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                onSubmitted: (_) => _search(),
                decoration: const InputDecoration(
                  hintText: 'Busca una canción o pega un enlace',
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _searching ? null : _search,
              icon: const Icon(Icons.search),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_searching)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          ),
        if (!_searching && _error != null)
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _error!,
                  style: AppTextStyles.body(color: AppColors.coral),
                  textAlign: TextAlign.center,
                ),
              ),
              TextButton(
                onPressed: _search,
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.surfaceSecondary,
                ),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        if (!_searching &&
            _error == null &&
            _results != null &&
            _results!.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No encontramos canciones con esa búsqueda.',
              style: AppTextStyles.body(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ),
        if (_error == null)
          ...?_results?.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: r.thumbnailUrl != null
                          ? CachedNetworkImage(
                              imageUrl: r.thumbnailUrl!,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: 44,
                              height: 44,
                              color: Colors.black,
                            ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            r.title,
                            style: AppTextStyles.label(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${r.channelTitle} · ${_formatDuration(r.durationSeconds)}',
                            style: AppTextStyles.caption(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (widget.canModerate) ...[
                      IconButton(
                        onPressed: _busyVideoId == r.videoId
                            ? null
                            : () => _addToQueue(r.videoId, true),
                        icon: const Icon(Icons.play_arrow, size: 18),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.orange,
                          foregroundColor: Colors.black,
                          minimumSize: const Size(34, 34),
                        ),
                      ),
                      IconButton(
                        onPressed: _busyVideoId == r.videoId
                            ? null
                            : () => _addToQueue(r.videoId, false),
                        icon: const Icon(Icons.add, size: 18),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.surfaceElevated,
                          minimumSize: const Size(34, 34),
                        ),
                      ),
                    ] else
                      TextButton(
                        onPressed: _busyVideoId == r.videoId
                            ? null
                            : () => _request(r.videoId),
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.cyan,
                          foregroundColor: Colors.black,
                        ),
                        child: const Text('Solicitar'),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _QueueTab extends ConsumerWidget {
  const _QueueTab({required this.session, required this.canModerate});
  final MusicSession? session;
  final bool canModerate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (session == null || session!.queue.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'La cola está vacía.',
          style: AppTextStyles.body(color: AppColors.textMuted),
          textAlign: TextAlign.center,
        ),
      );
    }
    return Column(
      children: session!.queue.asMap().entries.map((entry) {
        final item = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: Text(
                    '${entry.key + 1}',
                    style: AppTextStyles.caption(),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.title,
                        style: AppTextStyles.label(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        item.channelTitle,
                        style: AppTextStyles.caption(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (canModerate)
                  IconButton(
                    onPressed: () => ref
                        .read(menziDjProvider.notifier)
                        .removeQueueItem(item.id),
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: AppColors.coral,
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _RequestsTab extends ConsumerWidget {
  const _RequestsTab({required this.session});
  final MusicSession? session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (session == null || session!.pendingRequests.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'No hay solicitudes pendientes.',
          style: AppTextStyles.body(color: AppColors.textMuted),
          textAlign: TextAlign.center,
        ),
      );
    }
    return Column(
      children: session!.pendingRequests.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.title,
                        style: AppTextStyles.label(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${item.requestedBy?.displayName ?? "Alguien"} solicitó esta canción',
                        style: AppTextStyles.caption(),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => ref
                      .read(menziDjProvider.notifier)
                      .approveRequest(item.id),
                  icon: const Icon(Icons.check),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: Colors.black,
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      ref.read(menziDjProvider.notifier).rejectRequest(item.id),
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surfaceElevated,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.session});
  final MusicSession? session;

  @override
  Widget build(BuildContext context) {
    if (session == null || session!.history.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'Todavía no sonó ninguna canción.',
          style: AppTextStyles.body(color: AppColors.textMuted),
          textAlign: TextAlign.center,
        ),
      );
    }
    return Column(
      children: session!.history.map((item) {
        return Opacity(
          opacity: 0.8,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.title,
                          style: AppTextStyles.label(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${item.channelTitle} · ${item.status == QueueItemStatus.skipped ? "saltada" : "reproducida"}',
                          style: AppTextStyles.caption(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Panel compacto opcional (Fase 8 del pedido de diagnóstico sin ADB) — últimas 8 líneas
/// relevantes al player, siempre dentro del flujo normal del Column (nunca un overlay flotante
/// sobre controles), cerrable con el botón X. Se re-renderiza solo mientras está abierto (ver
/// `revision` de AppDiagnosticLogger), así que no tiene costo si el usuario no lo usa.
class _CompactDiagnosticOverlay extends StatelessWidget {
  const _CompactDiagnosticOverlay({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AppDiagnosticLogger.instance.revision,
      builder: (context, revision, child) {
        final lines = AppDiagnosticLogger.instance
            .filtered(categories: _playerDiagnosticCategories)
            .reversed
            .take(8)
            .toList()
            .reversed
            .toList();
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Últimas líneas (diagnóstico)',
                    style: AppTextStyles.caption(color: Colors.white70),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: onClose,
                    child: const Icon(Icons.close, size: 14, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (lines.isEmpty)
                Text('Sin registros todavía', style: AppTextStyles.caption(color: Colors.white54))
              else
                for (final line in lines)
                  Text(
                    line.toLine(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 9,
                      color: Colors.white70,
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}
