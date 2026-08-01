import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/native/live_bubble_channel.dart';
import '../../core/network/api_exception.dart';
import '../../data/models/chat_models.dart';
import '../../data/models/music_models.dart';
import '../shared/menzi_illustration_state.dart';
import '../shared/menzo_sheet.dart';
import '../shared/menzo_toast.dart';
import '../shared/segmented_tabs.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';
import 'menzi_dj_player_html.dart';
import 'menzi_dj_provider.dart';

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
    title: 'Menzi DJ',
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

class _MenziDjPanelBodyState extends ConsumerState<_MenziDjPanelBody>
    with WidgetsBindingObserver {
  _Tab _tab = _Tab.search;

  /// null = todavía sin comprobar. El hand-off nativo que mantiene la música sonando al
  /// minimizar (`MenziDjBackgroundPlayer`) necesita el mismo permiso de overlay que la burbuja
  /// del LIVE — si nunca se concedió (o se revocó), ese hand-off falla en silencio cada vez, lo
  /// que se sentía como "la música se corta/reinicia al salir de la app" sin ninguna pista de
  /// por qué. Este banner lo deja visible y accionable en vez de un fallo silencioso.
  bool? _overlayGranted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(
      () => ref.read(menziDjProvider.notifier).setExpanded(true),
    );
    _checkOverlayPermission();
  }

  Future<void> _checkOverlayPermission() async {
    final granted = await LiveBubbleChannel.checkPermission();
    if (mounted) setState(() => _overlayGranted = granted);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Vuelve a comprobar al volver de Ajustes (Android no devuelve un resultado confiable de
    // esa pantalla) — así el banner desaparece solo apenas el permiso quede concedido de
    // verdad, sin que el usuario tenga que cerrar y reabrir el panel.
    if (state == AppLifecycleState.resumed) _checkOverlayPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ref.read(menziDjProvider.notifier).setExpanded(false);
    super.dispose();
  }

  bool get _canModerate =>
      widget.room.role == RoomRole.owner || widget.room.role == RoomRole.coHost;

  @override
  Widget build(BuildContext context) {
    final music = ref.watch(menziDjProvider);
    final session = music.session;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_overlayGranted == false) ...[
          _OverlayPermissionBanner(onGranted: _checkOverlayPermission),
          const SizedBox(height: 12),
        ],
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
                  'No pudimos cargar Menzi DJ. Reintentando...',
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
            title: 'Menzi DJ',
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
                  'No se pudo actualizar Menzi DJ — mostrando la última info conocida.',
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
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.black,
                ),
              ),
              IconButton(
                onPressed: () => ref.read(menziDjProvider.notifier).skip(),
                icon: const Icon(Icons.skip_next),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceSecondary,
                ),
              ),
              IconButton(
                onPressed: () => ref.read(menziDjProvider.notifier).stopMusic(),
                icon: const Icon(Icons.stop),
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
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surfaceSecondary,
              ),
            ),
            if (session?.currentVideoId != null)
              IconButton(
                onPressed: () => ref
                    .read(menziDjProvider.notifier)
                    .setVideoHidden(!music.videoHidden),
                icon: Icon(
                  music.videoHidden
                      ? Icons.videocam_off
                      : Icons.videocam_outlined,
                ),
                tooltip: music.videoHidden
                    ? 'Mostrar video flotante'
                    : 'Ocultar video flotante',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceSecondary,
                ),
              ),
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

/// Sin el permiso "Mostrar sobre otras apps" el reproductor nativo de fondo
/// (`MenziDjBackgroundPlayer`) no puede montarse — la música puede cortarse o reiniciarse al
/// minimizar sin ningún aviso. Este banner deja esa dependencia visible y accionable en vez de
/// un fallo silencioso.
class _OverlayPermissionBanner extends StatelessWidget {
  const _OverlayPermissionBanner({required this.onGranted});
  final VoidCallback onGranted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: AppColors.orange,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Activá "Mostrar sobre otras apps" para que la música no se corte al minimizar.',
              style: AppTextStyles.caption(),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () async {
              await LiveBubbleChannel.requestPermission();
              onGranted();
            },
            child: const Text('Activar'),
          ),
        ],
      ),
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
