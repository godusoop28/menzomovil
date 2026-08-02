import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../core/config/app_config.dart';
import '../../core/diagnostics/app_diagnostic_logger.dart';
import '../../core/diagnostics/device_session.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/stomp_service.dart';
import '../../core/providers/repository_providers.dart';
import '../../data/models/music_models.dart';
import '../live/live_provider.dart';
import 'menzi_dj_player_html.dart';
import 'menzi_player_display_mode.dart';

const _driftCheckInterval = Duration(seconds: 15);
// Bandas de corrección (Fase 9): <1.5s no se toca nada; 1.5-4s corrección suave (playback rate
// temporal); >4s salto directo. Sin la banda intermedia, cualquier drift chico terminaba en un
// `seek` perceptible (un salto de audio) cada 15s con solo un poco de desincronización de red.
const _driftSoftBandSeconds = 1.5;
const _driftHardBandSeconds = 4.0;
// Fase de estabilización: una única instancia de reproducción por dispositivo. Antes había un
// valor nativo fijo (80/100) que se reaplicaba en cada canción nueva sin importar lo que el
// usuario hubiera elegido — 50 es un default razonable, y `state.localVolume` (no esta
// constante) es lo que se reaplica de verdad en cada track (ver `_syncPlayerToSession`).
const _defaultVolume = 50;

/// Decisión de versionado (Fase 3): un evento solo se aplica si trae una versión más nueva que
/// la que ya tenemos — sin versión (null) se aplica igual (algunos payloads no la incluyen), sin
/// sesión previa también se aplica (primera vez). Extraída como función libre de estado (no
/// depende de `this`/`state`) para poder cubrir con un test unitario simple los casos de
/// duplicado/reenvío/desorden sin tener que levantar todo el Notifier (WebView, StompChannel,
/// etc.) — ver menzi_dj_provider_test.dart.
bool shouldApplyMusicEventVersion({
  required int? incomingVersion,
  required int? currentVersion,
}) {
  if (incomingVersion == null || currentVersion == null) return true;
  return incomingVersion > currentVersion;
}

/// Bandas de corrección de drift (Fase 9) — ver comentario de las constantes arriba. Función
/// pura (sin `_sendCommand`/estado) para poder testear las bandas exactas sin un WebView real.
enum DriftAction { none, softCorrect, hardSeek }

DriftAction classifyDrift(double signedDrift) {
  final absDrift = signedDrift.abs();
  if (absDrift > _driftHardBandSeconds) return DriftAction.hardSeek;
  if (absDrift > _driftSoftBandSeconds) return DriftAction.softCorrect;
  return DriftAction.none;
}

/// BUG CONFIRMADO CON LOGS REALES (auditoría de instancias + diagnóstico en-app, dos
/// dispositivos): al cambiar de sala se descartaba TODO el estado previo con
/// `state = const MenziDjState()`, incluyendo `playerReady` — pero el WebView global (ver
/// getter `controller`) se crea y se carga UNA SOLA VEZ para toda la vida del proceso,
/// independiente de a qué sala esté atado en cada momento, y el evento `ready` de la IFrame API
/// solo se dispara UNA VEZ por documento cargado, nunca de nuevo al entrar a otra sala. Resetear
/// `playerReady` acá dejaba a `_onSnapshotReceived` (el camino que sigue todo evento recibido
/// por STOMP — el de cualquier participante que NO sea quien ejecuta la acción local de play/
/// addToQueue/etc., que en cambio pasa por `_applySession` sin ese gate) esperando para siempre
/// un `ready` que ya había pasado y que no iba a repetirse: el video de la sesión nunca se
/// cargaba (nunca se mandaba `load`), y el timer de drift terminaba mandando `seek`/`getTime`
/// sobre un YT.Player vacío cada ~15s, con YouTube devolviendo error 2 (requestedVideoId/
/// actualVideoId ambos null) una y otra vez.
MenziDjState resetStateForRoomChange(MenziDjState previous) =>
    MenziDjState(playerReady: previous.playerReady);

/// El timer de drift (Fase 9) NUNCA debe mandar `getTime`/`seek`/`setRate` si el video de la
/// sesión todavía no se pidió cargar para ESTE player — sin este chequeo, un video que llegó a
/// `state.session` pero cuyo `load` todavía no se mandó/confirmó (p. ej. justo después de un
/// error 2 recuperable, ver [isPlayerCommandBeforeLoadError]) se trataba igual que uno
/// reproduciendo normalmente, reintentando un seek sobre un player vacío cada 15s.
bool shouldRunDriftCorrection({
  required bool isBackgrounded,
  required MusicSessionStatus? sessionStatus,
  required DateTime? sessionSnapshotAt,
  required String? sessionVideoId,
  required String? loadedVideoId,
  required int? localPlayerState,
}) {
  if (isBackgrounded) return false;
  if (sessionSnapshotAt == null) return false;
  if (sessionStatus != MusicSessionStatus.playing) return false;
  if (localPlayerState == YtPlayerState.buffering) return false;
  if (sessionVideoId == null || loadedVideoId != sessionVideoId) return false;
  return true;
}

/// El error 2 ("parámetro de request inválido") de la IFrame API tiene dos causas muy distintas
/// que NUNCA deben tratarse igual: un videoId real e inválido (`requestedVideoId` viene poblado,
/// ver YtPlayerError) — o, como se confirmó con los logs de esta auditoría, un comando (`seek`,
/// típicamente del timer de drift) ejecutado sobre un player al que TODAVÍA no se le mandó
/// `loadVideoById` — en ese caso `requestedVideoId`/`actualVideoId` llegan `null` porque nunca
/// hubo ningún video pedido. Confundir el segundo caso con "este video no se puede reproducir"
/// (marcarlo restringido, saltar de canción) sería descartar una canción perfectamente válida por
/// un bug de orquestación, no del video.
bool isPlayerCommandBeforeLoadError({
  required int errorCode,
  required String? requestedVideoId,
  required String? actualVideoId,
  required String? sessionCurrentVideoId,
}) {
  return errorCode == 2 &&
      requestedVideoId == null &&
      actualVideoId == null &&
      sessionCurrentVideoId != null;
}

/// Playback rate a aplicar para una corrección suave: atrasado (drift negativo) → acelerar;
/// adelantado (drift positivo) → frenar.
double softCorrectionRateFor(double signedDrift) =>
    signedDrift < 0 ? 1.25 : 0.75;

class MenziDjState {
  const MenziDjState({
    this.session,
    this.loading = false,
    this.loadError = false,
    this.displayMode = MenziPlayerDisplayMode.mini,
    this.localMuted = false,
    this.localVolume = _defaultVolume,
    this.playerReady = false,
    this.playerErrorCode,
    this.playerErrorVideoId,
    this.autoplayBlocked = false,
    this.needsManualResume = false,
    this.unexpectedPauseCount = 0,
    this.lastPauseReason,
    this.videoSlotRect,
  });

  final MusicSession? session;
  final bool loading;

  /// true cuando el último `refresh()` falló Y todavía no hay ningún `session` previo para
  /// mostrar en su lugar — antes cualquier fallo (un hipo de red, una respuesta lenta del
  /// backend, etc.) borraba `session` directo a null sin distinción, y el panel mostraba
  /// exactamente el mismo placeholder de "Busca una canción para comenzar" que el estado
  /// genuinamente vacío — parecía que Menzi DJ "no cargaba nada" sin ninguna pista de que en
  /// realidad había fallado una petición. Ver [MenziDjNotifier.refresh].
  final bool loadError;

  /// Modo visual del ÚNICO WebView persistente — ver [MenziPlayerDisplayMode]. Cambiar esto
  /// NUNCA crea, destruye ni intercambia el `WebViewWidget`/controller (ver
  /// menzi_dj_player_host.dart); solo cambia tamaño/posición/capas encima.
  final MenziPlayerDisplayMode displayMode;
  final bool localMuted;
  final int localVolume;
  final bool playerReady;

  /// Código `onError` del IFrame Player (ver [YtPlayerError]) para el video actual — no
  /// confundir con la página de error "153" que servía YouTube por el bug de origen nulo, ya
  /// corregido; esto son los errores reales y documentados de la API.
  final int? playerErrorCode;
  final String? playerErrorVideoId;

  /// El WebView/OEM aceptó el comando play/unmute pero el player nunca llegó a reproducir de
  /// verdad (ver `scheduleBlockCheck` en menzi_dj_player_html.dart) — mientras esto sea true, la
  /// UI no puede mostrar "reproduciendo": tiene que ofrecer un botón real para que el usuario
  /// habilite el audio con un toque genuino.
  final bool autoplayBlocked;

  /// true cuando la recuperación automática de una pausa inesperada (ver
  /// [MenziDjNotifier._attemptUnexpectedPauseRecovery]) agotó sus reintentos sin éxito — la UI
  /// debe ofrecer "Menzi DJ se pausó. Toca para continuar" en vez de seguir reintentando sola.
  final bool needsManualResume;

  /// Contador de diagnóstico (Fase 19) — cuántas veces se detectó un `state=2` sin ninguna razón
  /// válida en esta sesión de LIVE. Nunca se resetea salvo al cambiar de sala.
  final int unexpectedPauseCount;
  final MenziPauseReason? lastPauseReason;

  /// Rectángulo (coordenadas de pantalla) donde el panel de Menzi DJ (menzi_dj_panel.dart)
  /// reservó espacio para el video en modo `normal`/`cinema` — lo mide y reporta el panel mismo
  /// (ver [MenziDjNotifier.reportVideoSlotRect]) después de cada frame, así el WebView flotante
  /// (que sigue viviendo en la raíz del árbol, nunca dentro del sheet) se puede posicionar para
  /// que VISUALMENTE coincida con el hueco reservado, sin taparle controles al panel. Puramente
  /// local — nunca se persiste ni se manda a ningún lado.
  final Rect? videoSlotRect;

  bool get hasTrack => session?.currentVideoId != null;
  bool get hasPlayerError =>
      playerErrorCode != null && playerErrorVideoId == session?.currentVideoId;

  MenziDjState copyWith({
    MusicSession? session,
    bool clearSession = false,
    bool? loading,
    bool? loadError,
    MenziPlayerDisplayMode? displayMode,
    bool? localMuted,
    int? localVolume,
    bool? playerReady,
    int? playerErrorCode,
    bool clearPlayerError = false,
    String? playerErrorVideoId,
    bool? autoplayBlocked,
    bool? needsManualResume,
    int? unexpectedPauseCount,
    MenziPauseReason? lastPauseReason,
    Rect? videoSlotRect,
    bool clearVideoSlotRect = false,
  }) => MenziDjState(
    session: clearSession ? null : (session ?? this.session),
    loading: loading ?? this.loading,
    loadError: loadError ?? this.loadError,
    displayMode: displayMode ?? this.displayMode,
    localMuted: localMuted ?? this.localMuted,
    localVolume: localVolume ?? this.localVolume,
    playerReady: playerReady ?? this.playerReady,
    playerErrorCode: clearPlayerError
        ? null
        : (playerErrorCode ?? this.playerErrorCode),
    playerErrorVideoId: clearPlayerError
        ? null
        : (playerErrorVideoId ?? this.playerErrorVideoId),
    autoplayBlocked: autoplayBlocked ?? this.autoplayBlocked,
    needsManualResume: needsManualResume ?? this.needsManualResume,
    unexpectedPauseCount: unexpectedPauseCount ?? this.unexpectedPauseCount,
    lastPauseReason: lastPauseReason ?? this.lastPauseReason,
    videoSlotRect: clearVideoSlotRect ? null : (videoSlotRect ?? this.videoSlotRect),
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

  /// Id de la ÚNICA instancia global de Menzi DJ que este dispositivo debería tener corriendo —
  /// generado una sola vez, cuando se crea el controller (ver getter `controller`). Viaja como
  /// query param al cargar menzi-player.html y viene de vuelta en todo mensaje del bridge; si algún
  /// día algo creara una segunda instancia por error, sus mensajes llegarían con OTRO instanceId y
  /// `shouldAcceptBridgeMessage` los descartaría en vez de mezclar su estado con el real.
  String? _instanceId;
  String get instanceId => _instanceId ??= generatePlayerInstanceId('global');

  StompChannel? _channel;
  Timer? _driftTimer;
  Timer? _reconciliationTimer;
  String? _roomId;
  String? _loadedVideoId;
  MusicSessionStatus? _lastAppliedStatus;
  void Function(double seconds)? _pendingTimeRequest;

  /// true una vez que el usuario ya tocó el botón de "Habilitar audio" en esta sesión de
  /// LIVE/Menzi DJ — a partir de acá, un `autoplayBlocked` de una canción siguiente no vuelve a
  /// mostrar el aviso (se reintenta play/unmute solo, en silencio); pedirlo de nuevo en cada
  /// canción sería exactamente el tipo de fricción que el pedido original marcó como prohibida.
  bool _audioGestureGranted = false;

  /// true mientras el WebView de Flutter está pausado localmente por tener la app en segundo
  /// plano. Ya NO existe un reproductor nativo alternativo que tome la posta (ver
  /// MENZI_DJ_ARCHITECTURE.md): la sesión musical global sigue viva en el servidor sin importar
  /// esto, este dispositivo simplemente deja de reproducirla mientras está minimizado y la
  /// retoma sincronizada (`refresh()`) al volver — ver `_handleAppBackgrounded`/
  /// `_handleAppForegrounded`. Antes este mismo flag significaba "el nativo de fondo está
  /// sonando en mi lugar"; ese reproductor se retiró por completo porque terminaba
  /// desincronizado del estado global (split-brain: dos instancias de YouTube, cada una con su
  /// propia posición/volumen, ninguna obedeciendo confiablemente pause/resume/seek remotos).
  bool _isBackgrounded = false;

  /// Debounce del lifecycle (Fase 6) — `AppLifecycleState.inactive` puede dispararse por cosas
  /// completamente ajenas a "el usuario minimizó la app" (un diálogo del sistema, un selector de
  /// permisos, una notificación, una llamada entrante) y NUNCA debe pausar por sí solo. Solo
  /// `paused`/`hidden`/`detached` sostenidos por más de [_backgroundDebounce] cuentan como
  /// background real — un `inactive` seguido rápido de `resumed` (el caso típico de esos
  /// diálogos) se cancela acá sin llegar a pausar nada.
  Timer? _backgroundDebounceTimer;
  static const _backgroundDebounce = Duration(milliseconds: 400);

  /// Última razón por la que ESTE dispositivo mandó `pause` — ver [MenziPauseReason] y
  /// [_sendPauseCommand]. Sirve para que, cuando llega la confirmación (`state=2`) de ese mismo
  /// comando, no se la confunda con una pausa inexplicada (ver [classifyLocalPause]).
  MenziPauseReason? _lastCommandedPauseReason;
  DateTime? _lastCommandedPauseAt;

  /// Bookkeeping de la recuperación automática de pausas inesperadas (Fase 7) — máximo 2
  /// reintentos por ventana de 10s, nunca en bucle infinito.
  int _unexpectedPauseRecoveryAttempts = 0;
  DateTime? _unexpectedPauseWindowStart;

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
    final id = instanceId;
    _log(DiagnosticCategory.ytInstance, MenziLogLevel.info, 'controller created', data: {'instanceId': id});
    // El getter solo lo llama MenziDjPlayerHost.build() al armar su WebViewWidget — por
    // construcción, si esto corre es porque un WebViewWidget está por montarse con este mismo
    // controller (ver menzi_dj_player_host.dart).
    _log(DiagnosticCategory.ytInstance, MenziLogLevel.info, 'WebView mounted', data: {'instanceId': id});
    final controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000))
      ..addJavaScriptChannel(
        'MenziBridge',
        onMessageReceived: _handleBridgeMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            _log(DiagnosticCategory.ytInstance, MenziLogLevel.info, 'page loaded', data: {
              'instanceId': id,
              'url': url,
            });
          },
        ),
      );
    final platform = controller.platform;
    if (platform is AndroidWebViewController) {
      platform.setMediaPlaybackRequiresUserGesture(false);
    }
    // `loadRequest` a una página HTTP(S) real — NO `loadHtmlString`/`baseUrl`. Un documento
    // generado in-process con un origen sintético no garantiza que Android WebView mande un
    // HTTP Referer válido en los pedidos internos que hace el iframe de YouTube; eso es lo que
    // produce el error 153 ("missing Referer/API client identity" — código real y documentado
    // de la YouTube IFrame Player API, ver YtPlayerError.missingClientIdentity). La página vive
    // en menzoweb/public/menzi-player.html, servida de verdad desde AppConfig.menziDjOrigin.
    // `instanceId` en la query — ver comentario del campo `instanceId` arriba.
    final uri = Uri.parse(
      AppConfig.menziDjPlayerUrl,
    ).replace(queryParameters: {'instanceId': id});
    debugPrint('[MenziDJPlayer][${DeviceSession.id}] loading $uri');
    controller.loadRequest(uri);
    return _controller = controller;
  }

  void _log(
    DiagnosticCategory category,
    MenziLogLevel level,
    String message, {
    Map<String, dynamic>? data,
  }) {
    AppDiagnosticLogger.instance.log(category, level, message, data: data);
  }

  @override
  MenziDjState build() {
    WidgetsBinding.instance.addObserver(this);
    ref.listen<LiveState>(liveProvider, (previous, next) {
      final roomId = next.activeRoomId;
      if (roomId == _roomId) return;
      _teardownChannel();
      _roomId = roomId;
      // Ver resetStateForRoomChange — `playerReady` NUNCA se resetea acá, es una propiedad del
      // WebView global (una sola vez por proceso), no de la sala.
      state = resetStateForRoomChange(state);
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
        lifecycleState == AppLifecycleState.hidden ||
        lifecycleState == AppLifecycleState.detached) {
      // Ver [_backgroundDebounceTimer] — no se pausa de inmediato ni siquiera acá: un
      // `inactive` fugaz seguido de `paused`/`hidden` genuino (o al revés, un `paused`
      // reportado justo antes de volver a `resumed`, que también pasa en algunos OEM durante
      // transiciones cortas) no debe alcanzar a pausar nada si todo se resuelve dentro de la
      // ventana de debounce.
      _backgroundDebounceTimer?.cancel();
      _backgroundDebounceTimer = Timer(_backgroundDebounce, _handleAppBackgrounded);
    } else if (lifecycleState == AppLifecycleState.resumed) {
      _backgroundDebounceTimer?.cancel();
      _backgroundDebounceTimer = null;
      _handleAppForegrounded();
    } else if (lifecycleState == AppLifecycleState.inactive) {
      // `inactive` NUNCA pausa por sí solo (Fase 6) — puede ser un menú del sistema, un diálogo
      // de permisos, una llamada entrante, un selector, una notificación. Si de verdad se está
      // yendo a background, `paused`/`hidden` llega después y arranca el debounce de arriba.
      _log(DiagnosticCategory.lifecycle, MenziLogLevel.info, 'inactive ignored');
    }
  }

  /// Al minimizar: SOLO pausa el WebView local. No toca el estado global (nadie más se ve
  /// afectado), no llama ningún endpoint de pausa, y — a diferencia de la versión anterior — no
  /// arranca ningún reproductor alternativo. La sesión musical sigue viva en menzoapi;
  /// `_handleAppForegrounded` es quien reconcilia contra el servidor al volver.
  void _handleAppBackgrounded() {
    if (_isBackgrounded) return;
    _isBackgrounded = true;
    _log(DiagnosticCategory.lifecycle, MenziLogLevel.info, 'background confirmed');
    // Descarta cualquier `getTime` del drift-timer que estuviera en vuelo — el WebView está a
    // punto de pausarse y no debe poder seekearse a destiempo (ver el guard `_isBackgrounded`
    // del timer de drift en `_setup`).
    _pendingTimeRequest = null;
    debugPrint('[MenziDJ][${DeviceSession.id}] lifecycle paused — local playback suspended');
    _sendPauseCommand(MenziPauseReason.appBackgrounded);
  }

  /// Al volver a primer plano: nunca confía en la posición congelada de antes de minimizar como
  /// autoridad — pide el snapshot real al servidor y deja que `_syncPlayerToSession` (vía
  /// `refresh()`) decida si hay que cambiar de video, seekear o cambiar play/pause, comparando
  /// contra el estado que el WebView (pausado, no destruido) todavía tiene cargado.
  void _handleAppForegrounded() {
    _pendingTimeRequest = null;
    if (!_isBackgrounded) return;
    _isBackgrounded = false;
    debugPrint('[MenziDJ][${DeviceSession.id}] lifecycle resumed — reconciling with server snapshot');
    _log(DiagnosticCategory.lifecycle, MenziLogLevel.info, 'foreground resumed');
    refresh().then((_) {
      _log(DiagnosticCategory.lifecycle, MenziLogLevel.info, 'snapshot reconciled');
      _log(DiagnosticCategory.lifecycle, MenziLogLevel.info, 'local playback restored');
    });
  }

  void _setup(String roomId) {
    _log(DiagnosticCategory.live, MenziLogLevel.info, 'Menzi DJ attached to room', data: {'roomId': roomId});
    final channel = StompChannel();
    _channel = channel;
    // Orden crítico: la suscripción se registra ANTES de conectar. `StompChannel.connect` manda
    // el frame SUBSCRIBE real (dentro de su propio `onConnect`) antes de invocar este
    // `onConnected`, así que para cuando `refresh()` corre acá abajo la suscripción ya está
    // activa — una canción que arranque justo en el medio no puede colarse por el hueco que
    // había antes (refresh() disparado ANTES de conectar/suscribirse, corriendo en paralelo con
    // el handshake STOMP). `onConnected` se llama en la primera conexión Y en cada reconexión
    // (ver StompChannel), así que este mismo snapshot de reconciliación se repite solo cada vez.
    channel.subscribe('/topic/rooms/$roomId/music', _handleMusicEvent);
    channel.connect(onConnected: refresh);
    _driftTimer = Timer.periodic(_driftCheckInterval, (_) {
      // Mientras la app está en segundo plano el WebView está pausado de verdad — pedirle
      // `getTime`/seekearlo en ese estado comparaba una posición congelada contra un
      // `expectedPosition` que sigue creciendo con el reloj de pared, disparando un `seek` de
      // sobra cada ~30s. Esa respuesta tardía podía además pisar el seek correcto que hace
      // `_handleAppForegrounded` justo al volver.
      final current = state.session;
      if (!shouldRunDriftCorrection(
        isBackgrounded: _isBackgrounded,
        sessionStatus: current?.status,
        sessionSnapshotAt: _sessionSnapshotAt,
        sessionVideoId: current?.currentVideoId,
        loadedVideoId: _loadedVideoId,
        localPlayerState: _localPlayerState,
      )) {
        if (current != null &&
            current.currentVideoId != null &&
            _loadedVideoId != current.currentVideoId) {
          _log(DiagnosticCategory.ytCommand, MenziLogLevel.warning, 'drift skipped: video not loaded', data: {
            'desiredVideoId': current.currentVideoId,
            'loadedVideoId': _loadedVideoId,
            'localPlayerState': _localPlayerState,
          });
        }
        return;
      }
      final snapshotAt = _sessionSnapshotAt!;
      final elapsed =
          DateTime.now().difference(snapshotAt).inMilliseconds / 1000;
      final expectedPosition = current!.positionSeconds + elapsed;
      _pendingTimeRequest = (seconds) {
        // Con signo: negativo = el player va atrás del esperado, positivo = va adelante.
        final drift = seconds - expectedPosition;
        final action = classifyDrift(drift);
        if (action != DriftAction.none) {
          debugPrint(
            '[MenziDJ][${DeviceSession.id}] drift=${drift.toStringAsFixed(2)}s expected=${expectedPosition.toStringAsFixed(2)} actual=${seconds.toStringAsFixed(2)} action=$action',
          );
        }
        if (action == DriftAction.hardSeek) {
          _sendCommand('seek', {'seconds': expectedPosition});
          _sendCommand('setRate', {'rate': 1.0});
        } else if (action == DriftAction.softCorrect) {
          // Corrección suave: un empujón de velocidad temporal en vez de un seek audible, y
          // volver a 1.0x solo.
          _sendCommand('setRate', {'rate': softCorrectionRateFor(drift)});
          Future.delayed(const Duration(seconds: 3), () {
            if (!_isBackgrounded) _sendCommand('setRate', {'rate': 1.0});
          });
        }
      };
      _sendCommand('getTime');
    });
    // Reconciliación defensiva (Fase 10): aunque STOMP funcione, un mensaje puntual se puede
    // perder sin que nada lo note (un blip de red exactamente durante el heartbeat, un bug de
    // otro cliente, etc.) — un GET del snapshot real cada ~25s mientras hay LIVE activo en
    // primer plano corrige eso solo, sin recrear el reproductor ni el WebView (refresh() ya
    // aplica el snapshot solo si de verdad cambió algo, vía _onSnapshotReceived/_applySession).
    _reconciliationTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (!_isBackgrounded) refresh();
    });
  }

  void _teardownChannel() {
    _channel?.dispose();
    _channel = null;
    _driftTimer?.cancel();
    _driftTimer = null;
    _reconciliationTimer?.cancel();
    _reconciliationTimer = null;
    _loadedVideoId = null;
    _lastAppliedStatus = null;
    _sessionSnapshotAt = null;
    _localPlayerState = null;
    _isBackgrounded = false;
    _audioGestureGranted = false;
    _recentEventIds.clear();
  }

  void _sendCommand(String cmd, [Map<String, dynamic>? args]) {
    _log(DiagnosticCategory.ytCommand, MenziLogLevel.info, 'command sent', data: {
      'instanceId': instanceId,
      'cmd': cmd,
      ...?args,
    });
    _controller?.runJavaScript(
      'window.handleMenziCommand(${jsonEncode(jsonEncode({'cmd': cmd, ...?args}))})',
    );
  }

  /// Único punto que manda `pause` — SIEMPRE con una razón (Fase 5). Registra cuándo/por qué fue
  /// este dispositivo el que pausó, así cuando llegue la confirmación `state=2` correspondiente
  /// [classifyLocalPause] puede reconocerla como "esperada" en vez de marcarla como pausa
  /// inexplicada.
  void _sendPauseCommand(MenziPauseReason reason) {
    _lastCommandedPauseReason = reason;
    _lastCommandedPauseAt = DateTime.now();
    _log(DiagnosticCategory.ytCommand, MenziLogLevel.info, 'pause', data: {
      'instanceId': instanceId,
      'reason': reason.name,
    });
    _sendCommand('pause');
  }

  void _applyLocalAudioState() {
    if (state.localMuted) {
      _sendCommand('mute');
    } else {
      _sendCommand('unmute', {'volume': state.localVolume});
    }
  }

  /// Se llama en TODO `state=2` que reporte el bridge — la mayoría son perfectamente normales
  /// (pausa global real, background, un `pause` que este mismo dispositivo acaba de mandar). Solo
  /// actúa cuando [classifyLocalPause] concluye que no hay ninguna razón válida — exactamente el
  /// bug confirmado con logs reales (abrir opciones/mover el WebView pausaba sin que existiera
  /// ningún evento global ni comando local que lo explicara).
  void _handlePossibleUnexpectedPause() {
    final reason = classifyLocalPause(
      sessionStatus: state.session?.status,
      lastCommandedReason: _lastCommandedPauseReason,
      lastCommandedAt: _lastCommandedPauseAt,
      isBackgrounded: _isBackgrounded,
      now: DateTime.now(),
    );
    state = state.copyWith(lastPauseReason: reason);
    if (reason != MenziPauseReason.unexpectedPlatformPause) return;
    _log(DiagnosticCategory.ytState, MenziLogLevel.warning, 'unexpected local pause', data: {
      'instanceId': instanceId,
      'sessionStatus': state.session?.status.name,
    });
    state = state.copyWith(unexpectedPauseCount: state.unexpectedPauseCount + 1);
    _attemptUnexpectedPauseRecovery();
  }

  /// Máximo 2 reintentos por ventana de 10s, con un pequeño delay antes de cada uno para darle
  /// margen al player de recuperarse solo (Fase 7) — nunca un bucle infinito, y nunca reintenta
  /// si mientras tanto la sesión pasó a pausa global real o el dispositivo se fue a background
  /// (ambas son razones válidas para seguir pausado).
  void _attemptUnexpectedPauseRecovery() {
    final now = DateTime.now();
    if (_unexpectedPauseWindowStart == null ||
        now.difference(_unexpectedPauseWindowStart!) > const Duration(seconds: 10)) {
      _unexpectedPauseWindowStart = now;
      _unexpectedPauseRecoveryAttempts = 0;
    }
    if (_unexpectedPauseRecoveryAttempts >= 2) {
      _log(DiagnosticCategory.ytState, MenziLogLevel.error, 'unexpected pause recovery exhausted', data: {
        'instanceId': instanceId,
      });
      state = state.copyWith(needsManualResume: true);
      return;
    }
    _unexpectedPauseRecoveryAttempts++;
    final attempt = _unexpectedPauseRecoveryAttempts;
    Future.delayed(Duration(milliseconds: 250 * attempt), () {
      if (_localPlayerState != YtPlayerState.paused) return;
      if (_isBackgrounded) return;
      if (state.session?.status != MusicSessionStatus.playing) return;
      _log(DiagnosticCategory.ytState, MenziLogLevel.info, 'recovering from unexpected pause', data: {
        'instanceId': instanceId,
        'attempt': attempt,
      });
      _sendCommand('play');
      _applyLocalAudioState();
    });
  }

  /// Botón "Menzi DJ se pausó. Toca para continuar." (Fase 7) — solo aparece cuando la
  /// recuperación automática ya agotó sus reintentos.
  void resumeAfterUnexpectedPause() {
    state = state.copyWith(needsManualResume: false);
    _unexpectedPauseRecoveryAttempts = 0;
    _unexpectedPauseWindowStart = null;
    _sendCommand('play');
    _applyLocalAudioState();
  }

  void _handleBridgeMessage(JavaScriptMessage message) {
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(message.message) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final messageInstanceId = msg['instanceId'] as String?;
    if (!shouldAcceptBridgeMessage(
      messageInstanceId: messageInstanceId,
      activeInstanceId: instanceId,
    )) {
      // Ver shouldAcceptBridgeMessage — un mensaje con un instanceId distinto al activo viene de
      // un WebView/documento que ya no es este, y aplicar su estado pisaría el real con datos
      // ajenos. Si esto se loguea alguna vez en producción, es la prueba de una duplicación real
      // (no la que se confirmó en la auditoría — dos WIDGETS distintos, cada uno con su propio
      // instanceId propio y consistente, nunca mezclado entre sí).
      debugPrint(
        '[YT-INSTANCE][${DeviceSession.id}] message from foreign instance ignored '
        'expected=$instanceId got=$messageInstanceId type=${msg['type']}',
      );
      _log(DiagnosticCategory.ytInstance, MenziLogLevel.warning, 'message from foreign instance ignored', data: {
        'expected': instanceId,
        'got': messageInstanceId,
        'type': msg['type'],
      });
      return;
    }
    final type = msg['type'] as String?;
    if (type == 'ready') {
      // Única instancia de reproducción por dispositivo — ya no existe un segundo reproductor
      // nativo de fondo que pueda quedar sonando por su cuenta (ver MENZI_DJ_ARCHITECTURE.md).
      debugPrint(
        '[MenziDJ][${DeviceSession.id}] player ready id=$instanceId — activePlayerCount=1',
      );
      _log(DiagnosticCategory.ytInstance, MenziLogLevel.info, 'iframe ready', data: {
        'instanceId': instanceId,
        'activePlayerCount': 1,
      });
      state = state.copyWith(playerReady: true);
      _syncPlayerToSession(state.session);
    } else if (type == 'time' && msg['seconds'] is num) {
      _pendingTimeRequest?.call((msg['seconds'] as num).toDouble());
      _pendingTimeRequest = null;
    } else if (type == 'error' && msg['errorCode'] is num) {
      debugPrint(
        '[YT-INSTANCE][${DeviceSession.id}] onError id=$instanceId errorCode=${msg['errorCode']} '
        'requestedVideoId=${msg['requestedVideoId'] ?? _loadedVideoId} actualVideoId=${msg['actualVideoId']} '
        'documentOrigin=${msg['documentOrigin']} playerState=${msg['playerState']} muted=${msg['muted']} volume=${msg['volume']}',
      );
      _log(DiagnosticCategory.ytError, MenziLogLevel.error, 'onError', data: {
        'instanceId': instanceId,
        'errorCode': msg['errorCode'],
        'requestedVideoId': msg['requestedVideoId'] ?? _loadedVideoId,
        'actualVideoId': msg['actualVideoId'],
        'documentOrigin': msg['documentOrigin'],
        'documentReferrer': msg['documentReferrer'],
        'userAgent': msg['userAgent'],
        'playerState': msg['playerState'],
        'muted': msg['muted'],
        'volume': msg['volume'],
        'currentTime': msg['currentTime'],
      });
      final errorCode = (msg['errorCode'] as num).toInt();
      final rawRequestedVideoId = msg['requestedVideoId'] as String?;
      final rawActualVideoId = msg['actualVideoId'] as String?;
      if (isPlayerCommandBeforeLoadError(
        errorCode: errorCode,
        requestedVideoId: rawRequestedVideoId,
        actualVideoId: rawActualVideoId,
        sessionCurrentVideoId: state.session?.currentVideoId,
      )) {
        // Ver isPlayerCommandBeforeLoadError — este NO es un video inválido/restringido, es un
        // comando (típicamente el timer de drift, ya blindado por shouldRunDriftCorrection, pero
        // esto cubre cualquier otro camino que quede) ejecutado sobre un player al que nunca se
        // le mandó `load`. Nunca marcar el video como restringido ni saltar de canción acá —
        // reintentar: limpiar `_loadedVideoId`/`_lastAppliedStatus` fuerza a
        // `_syncPlayerToSession` a mandar `load` de nuevo en vez de asumir que ya estaba cargado.
        _log(DiagnosticCategory.ytError, MenziLogLevel.warning, 'PLAYER_COMMAND_BEFORE_LOAD — retrying load', data: {
          'instanceId': instanceId,
          'sessionCurrentVideoId': state.session?.currentVideoId,
        });
        _loadedVideoId = null;
        _lastAppliedStatus = null;
        _syncPlayerToSession(state.session);
        return;
      }
      state = state.copyWith(
        playerErrorCode: errorCode,
        playerErrorVideoId: rawRequestedVideoId ?? _loadedVideoId,
      );
    } else if (type == 'duplicatePlayerPrevented') {
      debugPrint(
        '[YT-INSTANCE][${DeviceSession.id}] duplicatePlayerPrevented id=$instanceId — '
        'onYouTubeIframeAPIReady se disparó dos veces en el mismo documento',
      );
      _log(DiagnosticCategory.ytInstance, MenziLogLevel.error, 'duplicatePlayerPrevented', data: {
        'instanceId': instanceId,
      });
    } else if (type == 'stateChange' && msg['state'] is num) {
      _log(DiagnosticCategory.ytState, MenziLogLevel.info, 'stateChange', data: {
        'instanceId': instanceId,
        'state': msg['state'],
        'requestedVideoId': msg['requestedVideoId'],
        'currentTime': msg['currentTime'],
        'muted': msg['muted'],
        'volume': msg['volume'],
      });
      debugPrint(
        '[YT-INSTANCE][${DeviceSession.id}] stateChange id=$instanceId state=${msg['state']}',
      );
      _localPlayerState = (msg['state'] as num).toInt();
      if (_localPlayerState == YtPlayerState.playing) {
        if (state.autoplayBlocked) state = state.copyWith(autoplayBlocked: false);
        // Confirmó que sí está reproduciendo — cierra cualquier ventana de recuperación
        // abierta (Fase 7); el siguiente state=2 inesperado, si lo hay, empieza una nueva.
        _unexpectedPauseRecoveryAttempts = 0;
        _unexpectedPauseWindowStart = null;
        if (state.needsManualResume) {
          state = state.copyWith(needsManualResume: false);
        }
      } else if (_localPlayerState == YtPlayerState.paused) {
        _handlePossibleUnexpectedPause();
      }
    } else if (type == 'autoplayBlocked') {
      debugPrint(
        '[MenziDJ][${DeviceSession.id}] autoplayBlocked (gestureGranted=$_audioGestureGranted)',
      );
      _log(DiagnosticCategory.autoplay, MenziLogLevel.warning, 'blocked', data: {
        'instanceId': instanceId,
        'gestureGranted': _audioGestureGranted,
        'playerState': msg['playerState'],
        'muted': msg['muted'],
        'volume': msg['volume'],
      });
      if (_audioGestureGranted) {
        // Ya nos autorizaron una vez en este LIVE — no volver a mostrar el aviso, solo
        // reintentar en silencio (puede ser un hipo puntual de buffering lento, no un bloqueo
        // real del navegador).
        _sendCommand('play');
        _applyLocalAudioState();
      } else {
        _log(DiagnosticCategory.autoplay, MenziLogLevel.warning, 'audio gesture requested', data: {
          'instanceId': instanceId,
        });
        state = state.copyWith(autoplayBlocked: true);
      }
    }
  }

  /// Llamado desde un toque real del usuario sobre "Toca para activar el audio de Menzi DJ" —
  /// a diferencia de los comandos que manda el propio provider (play/unmute automáticos al
  /// sincronizar sesión), este SÍ nace de un gesto genuino, que es justo lo que le puede faltar
  /// al WebView/OEM para dejar sonar el audio. Se recuerda para el resto de la sesión del LIVE
  /// (ver `_audioGestureGranted`): no tiene sentido volver a pedirlo en cada canción nueva.
  void enableAudioAfterGesture() {
    _audioGestureGranted = true;
    _log(DiagnosticCategory.autoplay, MenziLogLevel.info, 'audio gesture granted', data: {
      'instanceId': instanceId,
    });
    state = state.copyWith(autoplayBlocked: false);
    _sendCommand('play');
    _applyLocalAudioState();
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
      _sendCommand('load', {
        'videoId': session.currentVideoId,
        'startSeconds': session.positionSeconds,
      });
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
      _sendPauseCommand(MenziPauseReason.global);
    }
  }

  /// Body real de `/topic/rooms/{roomId}/music` (ver MusicEvent.java en menzoapi): trae siempre
  /// `type` y `version`, y en la mayoría de los tipos (STARTED/PAUSED/RESUMED/SEEKED/SKIPPED/
  /// STOPPED/SETTINGS_UPDATED/TRACK_CHANGED/SESSION_CREATED) un `payload` que ya es el snapshot
  /// completo (mismo shape que GET .../music) — se aplica directo, sin otro round-trip. Antes
  /// esto ignoraba el body entero (`subscribe(topic, (_) => refresh())`), así que cada evento
  /// costaba un GET completo y no había forma de distinguir un evento viejo/duplicado de uno
  /// nuevo (dos controles casi simultáneos podían aplicarse fuera de orden).
  ///
  /// TRACK_ADDED/QUEUE_UPDATED/REQUEST_* mandan un QueueItem (o nada) como payload, no un
  /// snapshot — no alcanza para reconstruir `MusicSession` acá, así que esos siguen
  /// reconciliándose con un GET real.
  /// Últimos `eventId` ya procesados (Fase 3: idempotencia) — acotado, no hace falta recordar
  /// más que un puñado: un reenvío real (reconexión que reentrega algo que ya se aplicó) llega
  /// cerca en el tiempo, no minutos después.
  final List<String> _recentEventIds = [];
  static const _recentEventIdsLimit = 20;

  void _handleMusicEvent(Map<String, dynamic> event) {
    final type = event['type'];
    final version = event['version'] as int?;
    final eventId = event['eventId'] as String?;
    final payload = event['payload'];
    debugPrint(
      '[MenziDJ][${DeviceSession.id}] event received: type=$type version=$version eventId=$eventId',
    );
    if (eventId != null) {
      if (_recentEventIds.contains(eventId)) {
        debugPrint(
          '[MenziDJ][${DeviceSession.id}] event ignored: duplicate eventId=$eventId',
        );
        _log(DiagnosticCategory.musicSession, MenziLogLevel.warning, 'event ignored: duplicate eventId', data: {
          'eventId': eventId,
          'type': type,
        });
        return;
      }
      _recentEventIds.add(eventId);
      if (_recentEventIds.length > _recentEventIdsLimit) {
        _recentEventIds.removeAt(0);
      }
    }
    if (payload is! Map<String, dynamic> ||
        !payload.containsKey('musicSessionId')) {
      refresh();
      return;
    }
    final currentVersion = state.session?.version;
    if (!shouldApplyMusicEventVersion(
      incomingVersion: version,
      currentVersion: currentVersion,
    )) {
      // Ya aplicado (reenvío/reconexión) o llegó desordenado respecto a algo más nuevo que ya
      // tenemos — ignorarlo evita pisar el estado actual con uno viejo.
      debugPrint(
        '[MenziDJ][${DeviceSession.id}] event ignored: type=$type version=$version currentVersion=$currentVersion',
      );
      return;
    }
    // Salto de versión (p. ej. actual=10, llega 13): algo se perdió en el medio — se aplica
    // este snapshot igual (es el más nuevo que tenemos, mejor que dejar la música colgada) pero
    // se dispara una reconciliación real por GET para no quedarse con un estado a medio camino.
    if (version != null &&
        currentVersion != null &&
        version - currentVersion > 1) {
      debugPrint(
        '[MenziDJ][${DeviceSession.id}] version gap detected: currentVersion=$currentVersion incomingVersion=$version — reconciling',
      );
      refresh();
    }
    debugPrint(
      '[MenziDJ][${DeviceSession.id}] event applied: type=$type version=$version',
    );
    _log(DiagnosticCategory.musicSession, MenziLogLevel.info, 'event applied', data: {
      'type': type,
      'version': version,
      'eventId': eventId,
      'videoId': payload['currentVideoId'],
      'status': payload['status'],
      'positionSeconds': payload['positionSeconds'],
    });
    _onSnapshotReceived(MusicSession.fromJson(payload));
  }

  /// Único lugar que decide cómo aplicar un snapshot recién obtenido (por REST o por STOMP):
  /// si el player todavía no está listo, el video no puede cargarse todavía — se guarda el
  /// `session` en el estado igual (para que el panel ya muestre algo) y se aplica de verdad al
  /// player recién en el callback `ready` (ver `_handleBridgeMessage`); si ya está listo, se
  /// aplica ahora mismo.
  void _onSnapshotReceived(MusicSession session) {
    if (state.playerReady) {
      _applySession(session);
    } else {
      _sessionSnapshotAt = DateTime.now();
      state = state.copyWith(session: session);
    }
  }

  /// Punto único que reemplaza el `session` del estado — siempre re-estampa
  /// `_sessionSnapshotAt` (el backend acaba de calcular `positionSeconds` fresco para este
  /// instante, sea cual sea el motivo del refresco) y solo entonces sincroniza el player.
  void _applySession(MusicSession session) {
    _sessionSnapshotAt = DateTime.now();
    state = state.copyWith(session: session);
    if (_isBackgrounded) {
      // El WebView está pausado por estar la app en segundo plano — no tiene sentido mandarle
      // comandos a un player que no se está reproduciendo. `state.session` ya quedó actualizado
      // con lo más nuevo; `_loadedVideoId`/`_lastAppliedStatus` (usados por
      // `_syncPlayerToSession`) deliberadamente NO se tocan acá, así que cuando
      // `_handleAppForegrounded` dispare un `refresh()` real al volver, la comparación contra
      // esos valores (todavía los de antes de minimizar) detecta el cambio real y lo aplica.
      return;
    }
    _syncPlayerToSession(session);
  }

  /// Se incrementa en cada llamada a [refresh] — si un reintento automático (ver más abajo)
  /// llega a resolver DESPUÉS de que ya hubo un refresh más nuevo (exitoso o no), su resultado
  /// se descarta en vez de pisar el estado actual con una respuesta obsoleta.
  int _refreshRequestSeq = 0;

  Future<void> refresh() async {
    final roomId = _roomId;
    if (roomId == null) return;
    final seq = ++_refreshRequestSeq;
    state = state.copyWith(loading: true);
    try {
      final session = await ref.read(musicRepositoryProvider).snapshot(roomId);
      if (seq != _refreshRequestSeq) return;
      _log(DiagnosticCategory.musicSession, MenziLogLevel.info, 'snapshot received', data: {
        'videoId': session.currentVideoId,
        'status': session.status.name,
        'positionSeconds': session.positionSeconds,
        'version': session.version,
      });
      state = state.copyWith(loading: false, loadError: false);
      _onSnapshotReceived(session);
    } catch (_) {
      if (seq != _refreshRequestSeq) return;
      // Antes cualquier fallo (un hipo de red, el backend tardando en responder, etc.) borraba
      // `session` a null sin distinción — la canción/cola que YA se estaban mostrando
      // desaparecían de la pantalla como si nunca hubiera habido nada, sin ningún aviso. Ahora,
      // si ya había una sesión cargada, se mantiene visible (sigue siendo la última info real
      // que tenemos) y solo se marca `loadError` para que el panel pueda avisar; recién se
      // limpia a "no hay sesión" si el fallo ocurre en la carga inicial, sin nada previo que
      // mostrar. Un reintento automático a los 3s cubre el caso común de que haya sido un hipo
      // pasajero (por ejemplo, el LIVE recién se creó y la primera lectura llegó un instante
      // antes de que el backend terminara de confirmarlo).
      state = state.copyWith(
        loading: false,
        loadError: true,
        clearSession: state.session == null,
      );
      Future.delayed(const Duration(seconds: 3), () {
        if (seq == _refreshRequestSeq) refresh();
      });
    }
  }

  /// Único punto que cambia el modo visual del player — ver [MenziPlayerDisplayMode]. Jamás
  /// toca `controller`/`instanceId`/página/iframe (Fase 1-2): el WebView persistente
  /// (menzi_dj_player_host.dart) solo lee este valor para decidir tamaño/posición/capas, nunca
  /// para decidir si crear o destruir nada.
  void setDisplayMode(MenziPlayerDisplayMode mode) {
    if (state.displayMode == mode) return;
    _log(DiagnosticCategory.ytInstance, MenziLogLevel.info, 'layout mode changed', data: {
      'instanceId': instanceId,
      'from': state.displayMode.name,
      'to': mode.name,
    });
    state = state.copyWith(displayMode: mode);
  }

  /// El panel mide el hueco que reservó para el video (modo `normal`/`cinema`) y lo reporta acá
  /// después de cada frame — ver comentario de [MenziDjState.videoSlotRect]. `null` significa
  /// "no estoy midiendo nada ahora" (panel cerrado, u otro modo), no "escondelo".
  void reportVideoSlotRect(Rect? rect) {
    if (rect == state.videoSlotRect) return;
    state = state.copyWith(videoSlotRect: rect, clearVideoSlotRect: rect == null);
  }

  void toggleLocalMute() {
    final next = !state.localMuted;
    state = state.copyWith(localMuted: next);
    if (next) {
      _sendCommand('mute');
    } else {
      _sendCommand('unmute', {'volume': state.localVolume});
    }
  }

  DateTime? _lastVolumeCommandAt;

  /// Fase 8: el bridge distingue `unmute` (desmutea Y aplica volumen, dispara
  /// `scheduleBlockCheck` — ver menzi-player.html) de `volume` (SOLO cambia el número, sin
  /// reevaluar nada más). Antes esto mandaba `unmute` en cada tick del slider — decenas de
  /// comandos por segundo durante un solo arrastre, cada uno reevaluando autoplay de nuevo. Ahora
  /// solo se manda `unmute` en la transición real mute→unmute; cualquier otro cambio de valor usa
  /// `volume`. El throttle real (que el slider no llame esto en cada pixel) vive en la UI
  /// (menzi_dj_panel.dart) via [shouldSendThrottledVolume] — acá solo se garantiza que, llame
  /// quien llame, el comando de bridge correcto es el mínimo necesario.
  void setLocalVolume(int value, {bool bypassThrottleForFinalValue = false}) {
    final clamped = value.clamp(0, 100);
    final wasMuted = state.localMuted;
    // Mover el slider mientras está muteado desmutea — mismo comportamiento esperado que
    // cualquier reproductor: no tiene sentido que el número suba y el audio siga en silencio
    // sin ninguna señal de por qué.
    state = state.copyWith(localVolume: clamped, localMuted: false);
    if (wasMuted) {
      _lastVolumeCommandAt = DateTime.now();
      _sendCommand('unmute', {'volume': clamped});
      return;
    }
    final now = DateTime.now();
    if (!bypassThrottleForFinalValue &&
        !shouldSendThrottledVolume(lastSentAt: _lastVolumeCommandAt, now: now)) {
      return;
    }
    _lastVolumeCommandAt = now;
    _sendCommand('volume', {'volume': clamped});
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
