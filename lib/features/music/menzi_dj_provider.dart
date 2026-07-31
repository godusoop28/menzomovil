import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../core/config/app_config.dart';
import '../../core/native/menzi_dj_background_channel.dart';
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
    this.videoHidden = false,
    this.localMuted = false,
    this.localVolume = _defaultVolume,
    this.playerReady = false,
    this.playerErrorCode,
    this.playerErrorVideoId,
  });

  final MusicSession? session;
  final bool loading;
  final bool expanded;

  /// El usuario ocultó la vista previa flotante del video desde el panel de Menzi DJ — el
  /// WebView sigue montado y reproduciendo audio normalmente, solo se deja de mostrar/mover el
  /// recuadro visible. Nunca se cambia desde la burbuja misma (no es tocable, ver
  /// menzi_dj_player_host.dart), solo desde controles reales del panel.
  final bool videoHidden;
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
    bool? videoHidden,
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
    videoHidden: videoHidden ?? this.videoHidden,
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
class MenziDjNotifier extends Notifier<MenziDjState>
    with WidgetsBindingObserver {
  WebViewController? _controller;
  StompChannel? _channel;
  Timer? _driftTimer;
  String? _roomId;
  String? _loadedVideoId;
  MusicSessionStatus? _lastAppliedStatus;
  void Function(double seconds)? _pendingTimeRequest;

  /// true mientras el audio lo está reproduciendo el WebView nativo en segundo plano
  /// (`MenziDjBackgroundPlayer`, Android) en vez del WebView de Flutter — ver
  /// `_handleAppBackgrounded`/`_handleAppForegrounded`.
  bool _isBackgrounded = false;

  /// Último estado (playing/paused) ya aplicado al reproductor NATIVO de fondo — igual que
  /// `_lastAppliedStatus` pero para el camino de segundo plano, así una pausa/reanudación
  /// remota (de un admin/co-host) mientras la app está minimizada se refleja también ahí, en
  /// vez de solo reenviarse el video-id (que es todo lo que se reenviaba antes de este fix).
  MusicSessionStatus? _lastBackgroundAppliedStatus;

  /// Posición calculada localmente (reloj de pared) en el instante exacto del hand-off a
  /// segundo plano, y cuándo se tomó ese cálculo — sirve de red de seguridad al volver a primer
  /// plano: si el reproductor nativo reporta una posición sospechosamente cercana a 0 (p. ej.
  /// por un fallo silencioso de `evaluateJavascript` del lado nativo), preferimos este estimado
  /// antes que confiar ciegamente en un 0 y reiniciar la canción de la nada.
  double? _backgroundHandoffPosition;
  DateTime? _backgroundHandoffAt;

  /// Se incrementa en cada transición de lifecycle — si el usuario alterna primer/segundo
  /// plano muy rápido (más rápido de lo que tarda `activate()` en resolver, que incluye un
  /// round-trip al MethodChannel), sin esto el resultado de un `_handleAppBackgrounded()` ya
  /// obsoleto podía aplicarse DESPUÉS de que `_handleAppForegrounded()` ya había vuelto a
  /// primer plano, pausando el WebView de Flutter por error mientras el usuario ya estaba
  /// mirando la app de nuevo.
  int _lifecycleGeneration = 0;

  /// Último `YT.PlayerState` reportado por el bridge (ver [YtPlayerState]). Mientras el player
  /// está en `buffering`, su posición real queda momentáneamente congelada por una razón
  /// legítima (esperando datos de red) — el chequeo de drift, que asume reproducción continua
  /// para calcular la posición esperada, no debe "corregir" eso empujándolo hacia adelante; si
  /// lo hace, el video queda saltando/reiniciando el buffer una y otra vez (se siente como que
  /// "se traba"). Se vuelve a corregir en cuanto retoma `playing`.
  int? _localPlayerState;

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
    WidgetsBinding.instance.addObserver(this);
    ref.listen<LiveState>(liveProvider, (previous, next) {
      final roomId = next.activeRoomId;
      if (roomId == _roomId) return;
      _teardownChannel();
      _roomId = roomId;
      state = const MenziDjState();
      if (roomId != null) _setup(roomId);
    });
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _teardownChannel();
    });
    return const MenziDjState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.paused ||
        lifecycleState == AppLifecycleState.hidden) {
      _handleAppBackgrounded();
    } else if (lifecycleState == AppLifecycleState.resumed) {
      _handleAppForegrounded();
    }
  }

  /// Le pasa la posta del audio al reproductor nativo en segundo plano (ya precalentado por
  /// [_setup] — ver `MenziDjBackgroundPlayer.kt`) y pausa el WebView de Flutter — si no lo
  /// pausáramos, sonarían los dos reproductores a la vez. Si no hay permiso de overlay (o
  /// cualquier otra falla), `activate` devuelve `false` y no se toca nada: el WebView de
  /// Flutter sigue como estaba, tal cual se comportaba antes de esta mejora (puede pausarse
  /// solo al minimizar del todo, según el WebView/OEM).
  Future<void> _handleAppBackgrounded() async {
    final generation = ++_lifecycleGeneration;
    final session = state.session;
    if (session == null ||
        session.currentVideoId == null ||
        session.status != MusicSessionStatus.playing) {
      return;
    }
    final snapshotAt = _sessionSnapshotAt ?? DateTime.now();
    final elapsed = DateTime.now().difference(snapshotAt).inMilliseconds / 1000;
    final expectedPosition = session.positionSeconds + elapsed;
    final handedOff = await MenziDjBackgroundChannel.activate(
      origin: AppConfig.menziDjOrigin,
      videoId: session.currentVideoId!,
      positionSeconds: expectedPosition,
      playing: true,
      muted: state.localMuted,
      volume: state.localVolume,
    );
    // Si mientras tanto ya volvimos a primer plano (u otro ciclo empezó), esta respuesta llegó
    // tarde — no pisar el estado actual pausando algo que el usuario ya está mirando.
    if (generation != _lifecycleGeneration) return;
    if (handedOff) {
      _isBackgrounded = true;
      _lastBackgroundAppliedStatus = session.status;
      _backgroundHandoffPosition = expectedPosition;
      _backgroundHandoffAt = DateTime.now();
      // Descarta cualquier respuesta de `getTime` del WebView de primer plano que estuviera en
      // vuelo — ese WebView está a punto de pausarse y no debe poder seekearse a destiempo (ver
      // el guard `_isBackgrounded` del timer de drift más abajo).
      _pendingTimeRequest = null;
      _sendCommand('pause');
    }
  }

  /// Recupera la posición real alcanzada en segundo plano y hace que el WebView de Flutter
  /// retome ahí — sin esto, al volver el video arrancaría de nuevo desde donde quedó pausado
  /// (minutos atrás), audiblemente desincronizado del resto de la sala. El reproductor de
  /// fondo NO se destruye acá (solo se pausa+mutea) — queda precalentado para la próxima vez
  /// que se minimice en esta misma sesión de LIVE/Menzi DJ.
  Future<void> _handleAppForegrounded() async {
    ++_lifecycleGeneration;
    // Descarta cualquier `getTime` del drift-timer que haya quedado pendiente de mientras
    // estábamos en segundo plano — si su respuesta llegara después del seek de acá abajo,
    // pisaría la posición correcta con una calculada sobre un `_sessionSnapshotAt` viejo (esto
    // era la causa real de "la canción se reinicia al volver": el timer de drift seguía
    // corriendo en segundo plano, ver el guard `_isBackgrounded` agregado en `_setup`).
    _pendingTimeRequest = null;
    if (!_isBackgrounded) return;
    _isBackgrounded = false;
    final reported = await MenziDjBackgroundChannel.pauseAndReportPosition();
    final position = _resolveForegroundPosition(reported);
    _backgroundHandoffPosition = null;
    _backgroundHandoffAt = null;
    _lastBackgroundAppliedStatus = null;
    _sessionSnapshotAt = DateTime.now();
    _sendCommand('seek', {'seconds': position});
    if (state.session?.status == MusicSessionStatus.playing) {
      _sendCommand('play');
      _applyLocalAudioState();
    }
    // El hand-off solo garantiza continuidad de audio — puede haber cambiado el estado real
    // (pausa remota, cambio de canción) mientras estábamos en segundo plano, así que se
    // reconcilia con un refresco normal.
    refresh();
  }

  /// Si el nativo reporta una posición sospechosamente cercana a 0 pero, según nuestro propio
  /// reloj de pared desde el hand-off, la canción ya debería llevar un buen rato sonando, algo
  /// falló en silencio del lado nativo (p. ej. `evaluateJavascript` no encontró `player`) — en
  /// ese caso preferimos el estimado local en vez de reiniciar la canción desde cero.
  double _resolveForegroundPosition(double reported) {
    final handoffPosition = _backgroundHandoffPosition;
    final handoffAt = _backgroundHandoffAt;
    if (handoffPosition == null || handoffAt == null) return reported;
    final elapsed = DateTime.now().difference(handoffAt).inMilliseconds / 1000;
    final fallback = handoffPosition + elapsed;
    if (reported < 1.0 && fallback > 2.0) return fallback;
    return reported;
  }

  void _setup(String roomId) {
    refresh();
    // Precalienta el reproductor de fondo ya mismo (con la app todavía en primer plano) —
    // montar la ventana overlay + cargar el IFrame API de YouTube implica un pedido de red que
    // NO queremos pagar recién en el instante de minimizar (ver comentario de clase en
    // MenziDjBackgroundPlayer.kt). Sin permiso de overlay esto simplemente no hace nada.
    MenziDjBackgroundChannel.warmUp(origin: AppConfig.menziDjOrigin);
    final channel = StompChannel();
    _channel = channel;
    channel.connect(
      onConnected: () {
        channel.subscribe('/topic/rooms/$roomId/music', (_) => refresh());
      },
    );
    _driftTimer = Timer.periodic(_driftCheckInterval, (_) {
      // Mientras la app está en segundo plano el WebView de Flutter está pausado de verdad (es
      // el nativo quien reproduce) — pedirle `getTime`/seekearlo en ese estado comparaba una
      // posición congelada contra un `expectedPosition` que sigue creciendo con el reloj de
      // pared, disparando un `seek` de sobra cada ~30s. Esa respuesta tardía podía además
      // pisar el seek correcto que hace `_handleAppForegrounded` justo al volver — la causa
      // real del bug de "la canción se reinicia al volver a la app".
      if (_isBackgrounded) return;
      final current = state.session;
      final snapshotAt = _sessionSnapshotAt;
      if (current == null ||
          snapshotAt == null ||
          current.status != MusicSessionStatus.playing ||
          _localPlayerState == YtPlayerState.buffering)
        return;
      final elapsed =
          DateTime.now().difference(snapshotAt).inMilliseconds / 1000;
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
    _localPlayerState = null;
    _isBackgrounded = false;
    _lastBackgroundAppliedStatus = null;
    _backgroundHandoffPosition = null;
    _backgroundHandoffAt = null;
    // Recién acá se destruye de verdad el reproductor de fondo — dejarlo precalentado durante
    // toda la sesión (ver [_setup]) solo tiene sentido mientras siga habiendo un LIVE/Menzi DJ
    // activo al que volver.
    MenziDjBackgroundChannel.teardown();
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
    } else if (type == 'stateChange' && msg['state'] is num) {
      _localPlayerState = (msg['state'] as num).toInt();
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
    if (_isBackgrounded) {
      // El WebView de Flutter está pausado (el nativo en segundo plano es quien reproduce) —
      // no tiene sentido mandarle comandos; en su lugar reenviamos al reproductor nativo
      // cualquier cambio real: de canción (nueva pista) o de estado (un admin/co-host pausó o
      // reanudó de forma remota). Antes solo se reenviaba el cambio de canción, así que una
      // pausa remota mientras la app estaba minimizada nunca llegaba a silenciar el audio de
      // fondo — lo dejaba sonando aunque el resto de la sala lo viera pausado.
      final videoId = session.currentVideoId;
      final videoChanged = videoId != null && _loadedVideoId != videoId;
      final statusChanged = _lastBackgroundAppliedStatus != session.status;
      if (videoChanged) {
        _loadedVideoId = videoId;
        _lastBackgroundAppliedStatus = session.status;
        MenziDjBackgroundChannel.updateTrack(
          videoId: videoId,
          positionSeconds: session.positionSeconds.toDouble(),
        );
      } else if (statusChanged) {
        _lastBackgroundAppliedStatus = session.status;
        MenziDjBackgroundChannel.updatePlayback(
          positionSeconds: session.positionSeconds.toDouble(),
          playing: session.status == MusicSessionStatus.playing,
        );
      }
      return;
    }
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

  /// Solo cambia si el recuadro flotante del video se muestra o no — el audio sigue igual, el
  /// WebView nunca se pausa/destruye por esto. Ver el comentario de [MenziDjState.videoHidden].
  void setVideoHidden(bool value) =>
      state = state.copyWith(videoHidden: value);

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
