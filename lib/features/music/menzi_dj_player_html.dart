/// Página mínima que carga el reproductor OFICIAL de YouTube (IFrame Player API) dentro de un
/// WebView — no hay SDK nativo de YouTube para Flutter, y este es el mismo patrón ya usado en
/// la versión React Native de esta app (WebView + IFrame API oficial), portado acá con
/// `MenziBridge` (JavaScriptChannel de webview_flutter) en vez de `ReactNativeWebView.postMessage`.
///
/// Nunca se extrae audio del reproductor ni se oculta permanentemente — el iframe de YouTube
/// sigue siendo el que reproduce, esto solo lo controla por comandos en vez de botones visibles.
///
/// [origin] debe coincidir exactamente con el `baseUrl` que se le pasa a
/// `WebViewController.loadHtmlString` (ver `AppConfig.menziDjOrigin`) — cargar esta página sin
/// un origen HTTP(S) real (p. ej. `loadHtmlString` sin `baseUrl`, que deja la página con un
/// origen opaco tipo `about:blank`) es la causa exacta de "Error 153 — Error de configuración
/// del reproductor de video" de YouTube: el iframe embed rechaza pedidos sin un origen válido,
/// incluso para videos perfectamente reproducibles en youtube.com.
String menziDjPlayerHtml(String origin) =>
    '''<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no" />
  <style>
    html, body { margin: 0; padding: 0; background: #000; width: 100%; height: 100%; overflow: hidden; }
    #player { width: 100%; height: 100%; }
  </style>
</head>
<body>
  <div id="player"></div>
  <script src="https://www.youtube.com/iframe_api"></script>
  <script>
    var player = null;
    var ready = false;
    var pendingVideoId = null;
    var currentVideoId = null;
    var blockCheckTimer = null;

    function post(message) {
      if (window.MenziBridge) {
        window.MenziBridge.postMessage(JSON.stringify(message));
      }
    }

    // No basta con llamar playVideo()/unMute() y asumir que ya suena — un WebView/OEM que
    // ignore la configuración de "no requiere gesto del usuario" (ver
    // AndroidWebViewController.setMediaPlaybackRequiresUserGesture(false) y
    // WebKitWebViewControllerCreationParams.mediaTypesRequiringUserAction en el lado Dart)
    // puede aceptar el comando en silencio sin que el audio realmente arranque. Este margen le
    // da tiempo al player de pasar por BUFFERING legítimo antes de considerar que quedó
    // bloqueado — si a los 2.5s no está ni reproduciendo ni bufferizando, se avisa a Dart en vez
    // de seguir mostrando "reproduciendo" sobre un player que en los hechos está mudo/parado.
    function scheduleBlockCheck() {
      if (blockCheckTimer) clearTimeout(blockCheckTimer);
      blockCheckTimer = setTimeout(function () {
        blockCheckTimer = null;
        if (!player) return;
        var s = player.getPlayerState();
        if (s !== 1 && s !== 3) {
          post({ type: 'autoplayBlocked' });
        }
      }, 2500);
    }

    function cancelBlockCheck() {
      if (blockCheckTimer) {
        clearTimeout(blockCheckTimer);
        blockCheckTimer = null;
      }
    }

    function onYouTubeIframeAPIReady() {
      player = new YT.Player('player', {
        width: '100%',
        height: '100%',
        playerVars: {
          autoplay: 1,
          mute: 1,
          playsinline: 1,
          controls: 0,
          modestbranding: 1,
          rel: 0,
          origin: '$origin',
          enablejsapi: 1
        },
        events: {
          onReady: function () {
            ready = true;
            post({ type: 'ready' });
            if (pendingVideoId) {
              currentVideoId = pendingVideoId;
              player.loadVideoById(pendingVideoId);
              pendingVideoId = null;
            }
          },
          onStateChange: function (event) {
            if (event.data === 1) cancelBlockCheck();
            post({ type: 'stateChange', state: event.data });
          },
          onError: function (event) {
            post({ type: 'error', code: event.data, videoId: currentVideoId });
          }
        }
      });
    }

    window.handleMenziCommand = function (raw) {
      var msg;
      try { msg = JSON.parse(raw); } catch (e) { return; }
      if (!ready || !player) {
        if (msg.cmd === 'load') pendingVideoId = msg.videoId;
        return;
      }
      switch (msg.cmd) {
        case 'load':
          currentVideoId = msg.videoId;
          // Con posición inicial en el mismo loadVideoById (en vez de cargar y mandar un seek
          // aparte inmediatamente después) evita una carrera entre dos llamadas JS separadas —
          // relevante sobre todo para quien entra tarde a una canción ya empezada (ver Fase 11):
          // el video arranca directo cerca de la posición real, no desde 0 con un salto detrás.
          if (typeof msg.startSeconds === 'number') {
            player.loadVideoById({ videoId: msg.videoId, startSeconds: msg.startSeconds });
          } else {
            player.loadVideoById(msg.videoId);
          }
          break;
        case 'play':
          player.playVideo();
          scheduleBlockCheck();
          break;
        case 'pause':
          cancelBlockCheck();
          player.pauseVideo();
          break;
        case 'seek':
          player.seekTo(msg.seconds, true);
          break;
        case 'mute':
          player.mute();
          break;
        case 'unmute':
          player.unMute();
          if (typeof msg.volume === 'number') player.setVolume(msg.volume);
          scheduleBlockCheck();
          break;
        case 'volume':
          player.setVolume(msg.volume);
          break;
        case 'getTime':
          post({ type: 'time', seconds: player.getCurrentTime(), state: player.getPlayerState() });
          break;
        case 'setRate':
          // Corrección suave de drift (Fase 9): un empujón de velocidad temporal en vez de un
          // seek audible para desincronizaciones chicas. setPlaybackRate ajusta al valor
          // soportado más cercano solo; no hace falta round-trip a getAvailablePlaybackRates()
          // para este uso (nunca se pide algo lejos de 1.0).
          player.setPlaybackRate(msg.rate);
          break;
      }
    };
  </script>
</body>
</html>''';

/// Espejo de YT.PlayerState del IFrame API oficial.
class YtPlayerState {
  YtPlayerState._();
  static const unstarted = -1;
  static const ended = 0;
  static const playing = 1;
  static const paused = 2;
  static const buffering = 3;
  static const cued = 5;
}

/// Espejo de los códigos documentados de `onError` del IFrame API oficial
/// (https://developers.google.com/youtube/iframe_api_reference#onError) — "153" no es un código
/// real de la API (es una página de error estática que sirve YouTube cuando el pedido del iframe
/// no trae un origen válido, ver [menziDjPlayerHtml]); si el origen está bien configurado y de
/// todos modos aparece un error, va a ser uno de estos.
class YtPlayerError {
  YtPlayerError._();

  /// Parámetro de request inválido — normalmente un `videoId` malformado.
  static const invalidParam = 2;

  /// El reproductor HTML5 tiró un error interno.
  static const html5Error = 5;

  /// Video no encontrado, privado o eliminado.
  static const notFound = 100;

  /// El dueño del video no permite reproducción embebida (dos códigos distintos, mismo motivo).
  static const embedNotAllowed = 101;
  static const embedNotAllowed2 = 150;

  static bool isEmbedRestricted(int code) =>
      code == embedNotAllowed || code == embedNotAllowed2;

  static String describe(int code) => switch (code) {
    invalidParam => 'Parámetro de video inválido.',
    html5Error => 'Error interno del reproductor.',
    notFound => 'Este video no está disponible (eliminado o privado).',
    embedNotAllowed || embedNotAllowed2 =>
      'El propietario de este video no permite reproducirlo embebido.',
    _ => 'No pudimos reproducir este video (código $code).',
  };
}
