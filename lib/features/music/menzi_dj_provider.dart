import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Color;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/stomp_service.dart';
import '../../core/providers/repository_providers.dart';
import '../../data/models/music_models.dart';
import '../live/live_provider.dart';
import 'menzi_dj_player_html.dart';

const _driftCheckInterval = Duration(seconds: 15);
const _driftThresholdSeconds = 2;
const _defaultVolume = 80;

class MenziDjState {
  const MenziDjState({
    this.session,
    this.loading = false,
    this.expanded = false,
    this.localMuted = false,
    this.localVolume = _defaultVolume,
    this.playerReady = false,
    this.playerErrorCode,
    this.playerErrorVideoId,
  });

  final MusicSession? session;
  final bool loading;
  final bool expanded;
  final bool localMuted;
  final int localVolume;
  final bool playerReady;

  /// Código `onError` del IFrame Player (ver [YtPlayerError]) para el video actual — no
  /// confundir con la página de error "153" que servía YouTube por el bug de origen nulo, ya
  /// corregido; esto son los errores reales y documentados de la API.
  final int? playerErrorCode;
  final String? playerErrorVideoId;

  bool get hasTrack => session?.currentVideoId != null;
  bool get hasPlayerError =>
      playerErrorCode != null && playerErrorVideoId == session?.currentVideoId;

  MenziDjState copyWith({
    MusicSession? session,
    bool clearSession = false,
    bool? loading,
    bool? expanded,
    bool? localMuted,
    int? localVolume,
    bool? playerReady,
    int? playerErrorCode,
    bool clearPlayerError = false,
    String? playerErrorVideoId,
  }) => MenziDjState(
    session: clearSession ? null : (session ?? this.session),
    loading: loading ?? this.loading,
    expanded: expanded ?? this.expanded,
    localMuted: localMuted ?? this.localMuted,
    localVolume: localVolume ?? this.localVolume,
    playerReady: playerReady ?? this.playerReady,
    playerErrorCode: clearPlayerError
        ? null
        : (playerErrorCode ?? this.playerErrorCode),
    playerErrorVideoId: clearPlayerError
        ? null
        : (playerErrorVideoId ?? this.playerErrorVideoId),
  );
}

/// Menzi DJ — equivalente Flutter de menzoweb/lib/music/MenziDjContext.tsx y su versión
/// React Native (WebView). El WebView del reproductor oficial de YouTube vive montado una sola
/// vez (ver [MenziDjMiniBar]/[MenziDjPanel]) y sobrevive a cualquier navegación. Atado al ciclo
/// de vida de [liveProvider].activeRoomId — no tiene sentido escuchar música de un LIVE al que
/// no estás conectado.
class MenziDjNotifier extends Notifier<MenziDjState> {
  WebViewController? _controller;
  StompChannel? _channel;
  Timer? _driftTimer;
  String? _roomId;
  String? _loadedVideoId;
  MusicSessionStatus? _lastAppliedStatus;
  void Function(double seconds)? _pendingTimeRequest;

  /// Reloj local del momento en que llegó el `session` actual — `positionSeconds` viene
  /// calculado por el backend en ESE instante, no se actualiza solo con el correr del tiempo.
  /// Comparar `positionSeconds` tal cual, varios segundos después, contra
  /// `player.getCurrentTime()` (que sí avanza en tiempo real) hacía que el chequeo de drift
  /// pensara que el video se desincronizó cada vez más y lo reiniciara a la posición vieja cada
  /// ~15s — exactamente el bug de "se reinicia solo". Mismo enfoque que
  /// menzoweb/lib/music/MenziDjContext.tsx (`sessionSnapshotAtRef`).
  DateTime? _sessionSnapshotAt;

  WebViewController get controller {
    if (_controller != null) return _controller!;
    // Android's WebView bloquea por defecto cualquier reproducción de audio/video que no
    // venga de un gesto real del usuario (`setMediaPlaybackRequiresUserGesture` es `true` por
    // default) — como acá el `unMute()`/`play()` los dispara Dart vía el bridge JS (no un tap
    // real sobre el WebView), Chromium los ignora en silencio: el player sigue "reproduciendo"
    // (los eventos de estado llegan bien) pero nunca se escucha nada. Mismo problema en iOS con
    // `mediaTypesRequiringUserActionForPlayback`.
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }
    final controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000))
      ..addJavaScriptChannel(
        'MenziBridge',
        onMessageReceived: _handleBridgeMessage,
      )
      // `baseUrl` es la parte que faltaba: sin un origen HTTP(S) real, YouTube rechaza el
      // embed con "Error 153" aunque el video sea perfectamente reproducible — ver
      // AppConfig.menziDjOrigin y el comentario en menzi_dj_player_html.dart.
      ..loadHtmlString(
        menziDjPlayerHtml(AppConfig.menziDjOrigin),
        baseUrl: AppConfig.menziDjOrigin,
      );
    final platform = controller.platform;
    if (platform is AndroidWebViewController) {
      platform.setMediaPlaybackRequiresUserGesture(false);
    }
    return _controller = controller;
  }

  @override
  MenziDjState build() {
    ref.listen<LiveState>(liveProvider, (previous, next) {
      final roomId = next.activeRoomId;
      if (roomId == _roomId) return;
      _teardownChannel();
      _roomId = roomId;
      state = const MenziDjState();
      if (roomId != null) _setup(roomId);
    });
    ref.onDispose(_teardownChannel);
    return const MenziDjState();
  }

  void _setup(String roomId) {
    refresh();
    final channel = StompChannel();
    _channel = channel;
    channel.connect(
      onConnected: () {
        channel.subscribe('/topic/rooms/$roomId/music', (_) => refresh());
      },
    );
    _driftTimer = Timer.periodic(_driftCheckInterval, (_) {
      final current = state.session;
      final snapshotAt = _sessionSnapshotAt;
      if (current == null ||
          snapshotAt == null ||
          current.status != MusicSessionStatus.playing)
        return;
      final elapsed = DateTime.now().difference(snapshotAt).inMilliseconds / 1000;
      final expectedPosition = current.positionSeconds + elapsed;
      _pendingTimeRequest = (seconds) {
        final drift = (seconds - expectedPosition).abs();
        if (drift > _driftThresholdSeconds) {
          _sendCommand('seek', {'seconds': expectedPosition});
        }
      };
      _sendCommand('getTime');
    });
  }

  void _teardownChannel() {
    _channel?.dispose();
    _channel = null;
    _driftTimer?.cancel();
    _driftTimer = null;
    _loadedVideoId = null;
    _lastAppliedStatus = null;
    _sessionSnapshotAt = null;
  }

  void _sendCommand(String cmd, [Map<String, dynamic>? args]) {
    _controller?.runJavaScript(
      'window.handleMenziCommand(${jsonEncode(jsonEncode({'cmd': cmd, ...?args}))})',
    );
  }

  void _applyLocalAudioState() {
    if (state.localMuted) {
      _sendCommand('mute');
    } else {
      _sendCommand('unmute', {'volume': state.localVolume});
    }
  }

  void _handleBridgeMessage(JavaScriptMessage message) {
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(message.message) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final type = msg['type'] as String?;
    if (type == 'ready') {
      state = state.copyWith(playerReady: true);
      _syncPlayerToSession(state.session);
    } else if (type == 'time' && msg['seconds'] is num) {
      _pendingTimeRequest?.call((msg['seconds'] as num).toDouble());
      _pendingTimeRequest = null;
    } else if (type == 'error' && msg['code'] is num) {
      state = state.copyWith(
        playerErrorCode: (msg['code'] as num).toInt(),
        playerErrorVideoId: msg['videoId'] as String? ?? _loadedVideoId,
      );
    }
  }

  /// Solo re-seekea/retoca play-pause cuando de verdad cambió el video o el estado
  /// (playing/paused/etc) — no en cada actualización de sesión. Antes se ejecutaba sin condición
  /// alguna en CUALQUIER refresco (incluyendo agregar una canción a la cola sin tocar la que
  /// está sonando), forzando un `seekTo`/`play` de la pista actual a cada rato; combinado con el
  /// bug de posición congelada de arriba, esto hacía que agregar canciones se sintiera como si
  /// "no dejara" — en realidad sí se agregaban, pero cada agregado sacudía/reiniciaba la que
  /// estaba sonando.
  void _syncPlayerToSession(MusicSession? session) {
    if (session == null || session.currentVideoId == null) {
      _lastAppliedStatus = null;
      return;
    }
    final videoChanged = _loadedVideoId != session.currentVideoId;
    if (videoChanged) {
      _loadedVideoId = session.currentVideoId;
      state = state.copyWith(clearPlayerError: true);
      _sendCommand('load', {'videoId': session.currentVideoId});
    }
    final statusChanged = _lastAppliedStatus != session.status;
    if (!videoChanged && !statusChanged) return;
    _lastAppliedStatus = session.status;
    if (session.status == MusicSessionStatus.playing) {
      _sendCommand('seek', {'seconds': session.positionSeconds});
      _sendCommand('play');
      _applyLocalAudioState();
    } else if (session.status == MusicSessionStatus.paused) {
      _sendCommand('seek', {'seconds': session.positionSeconds});
      _sendCommand('pause');
    }
  }

  /// Punto único que reemplaza el `session` del estado — siempre re-estampa
  /// `_sessionSnapshotAt` (el backend acaba de calcular `positionSeconds` fresco para este
  /// instante, sea cual sea el motivo del refresco) y solo entonces sincroniza el player.
  void _applySession(MusicSession session) {
    _sessionSnapshotAt = DateTime.now();
    state = state.copyWith(session: session);
    _syncPlayerToSession(session);
  }

  Future<void> refresh() async {
    final roomId = _roomId;
    if (roomId == null) return;
    state = state.copyWith(loading: true);
    try {
      final session = await ref.read(musicRepositoryProvider).snapshot(roomId);
      state = state.copyWith(loading: false);
      if (state.playerReady) {
        _applySession(session);
      } else {
        _sessionSnapshotAt = DateTime.now();
        state = state.copyWith(session: session);
      }
    } catch (_) {
      state = state.copyWith(clearSession: true, loading: false);
    }
  }

  void setExpanded(bool value) => state = state.copyWith(expanded: value);

  void toggleLocalMute() {
    final next = !state.localMuted;
    state = state.copyWith(localMuted: next);
    if (next) {
      _sendCommand('mute');
    } else {
      _sendCommand('unmute', {'volume': state.localVolume});
    }
  }

  void setLocalVolume(int value) {
    final clamped = value.clamp(0, 100);
    state = state.copyWith(localVolume: clamped);
    if (!state.localMuted) _sendCommand('volume', {'volume': clamped});
  }

  int? get _version => state.session?.version;

  Future<List<YoutubeSearchResult>> searchSongs(String query) async {
    final roomId = _roomId;
    if (roomId == null) return const [];
    return ref.read(musicRepositoryProvider).search(roomId, query);
  }

  Future<void> addToQueue(String videoId, {bool playNow = false}) async {
    final roomId = _roomId;
    if (roomId == null) return;
    final session = await ref
        .read(musicRepositoryProvider)
        .addToQueue(
          roomId,
          videoId: videoId,
          expectedVersion: _version,
          playNow: playNow,
        );
    _applySession(session);
  }

  Future<void> requestSong(String videoId) async {
    final roomId = _roomId;
    if (roomId == null) return;
    await ref.read(musicRepositoryProvider).requestSong(roomId, videoId);
    await refresh();
  }

  Future<void> approveRequest(String id) async {
    if (_roomId == null) return;
    await ref.read(musicRepositoryProvider).approveRequest(_roomId!, id);
    await refresh();
  }

  Future<void> rejectRequest(String id) async {
    if (_roomId == null) return;
    await ref.read(musicRepositoryProvider).rejectRequest(_roomId!, id);
    await refresh();
  }

  Future<void> _applyControl(
    Future<MusicSession> Function(String roomId, {int? expectedVersion}) action,
  ) async {
    final roomId = _roomId;
    if (roomId == null) return;
    final session = await action(roomId, expectedVersion: _version);
    _applySession(session);
  }

  Future<void> play() => _applyControl(ref.read(musicRepositoryProvider).play);
  Future<void> pauseTrack() =>
      _applyControl(ref.read(musicRepositoryProvider).pause);
  Future<void> resumeTrack() =>
      _applyControl(ref.read(musicRepositoryProvider).resume);
  Future<void> skip() => _applyControl(ref.read(musicRepositoryProvider).skip);
  Future<void> stopMusic() =>
      _applyControl(ref.read(musicRepositoryProvider).stop);

  Future<void> removeQueueItem(String id) async {
    if (_roomId == null) return;
    await ref.read(musicRepositoryProvider).removeQueueItem(_roomId!, id);
    await refresh();
  }

  /// URL para el fallback "Ver en YouTube" cuando el video no es embebible (error 101/150) o
  /// falla por cualquier otro motivo — nunca extraemos audio ni usamos un reproductor no
  /// oficial, solo abrimos la app/página real de YouTube.
  String? get currentYoutubeUrl {
    final videoId = state.session?.currentVideoId;
    if (videoId == null) return null;
    return 'https://www.youtube.com/watch?v=$videoId';
  }
}

final menziDjProvider = NotifierProvider<MenziDjNotifier, MenziDjState>(
  MenziDjNotifier.new,
);

/// Re-exporta ApiException para las pantallas de música (evita otro import en cada archivo).
typedef MenziApiException = ApiException;
