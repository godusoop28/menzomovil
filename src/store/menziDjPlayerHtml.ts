/** Página mínima que carga el reproductor OFICIAL de YouTube (IFrame Player API) dentro de un
 * WebView — no hay SDK nativo de YouTube para Expo/React Native, y este es el patrón recomendado
 * (WebView + IFrame API oficial) en vez de un módulo nativo custom, tal como pide la sección 22
 * del pedido ("evitar código nativo innecesario si WebView funciona").
 *
 * Puente con React Native:
 * - RN → WebView: `webviewRef.current.postMessage(JSON.stringify({ cmd, ...args }))`, recibido acá
 *   como evento 'message' (document en Android, window en iOS — se escuchan los dos).
 * - WebView → RN: `window.ReactNativeWebView.postMessage(JSON.stringify({ type, ...data }))`.
 *
 * Nunca se extrae audio del reproductor ni se oculta permanentemente — el iframe de YouTube
 * sigue siendo el que reproduce, esto solo lo controla por comandos en vez de botones visibles.
 */
export const MENZI_DJ_PLAYER_HTML = `<!DOCTYPE html>
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

    function post(message) {
      if (window.ReactNativeWebView) {
        window.ReactNativeWebView.postMessage(JSON.stringify(message));
      }
    }

    function onYouTubeIframeAPIReady() {
      player = new YT.Player('player', {
        width: '100%',
        height: '100%',
        playerVars: { autoplay: 1, mute: 1, playsinline: 1, controls: 0, modestbranding: 1, rel: 0 },
        events: {
          onReady: function () {
            ready = true;
            post({ type: 'ready' });
            if (pendingVideoId) {
              player.loadVideoById(pendingVideoId);
              pendingVideoId = null;
            }
          },
          onStateChange: function (event) {
            post({ type: 'stateChange', state: event.data });
          },
          onError: function (event) {
            post({ type: 'error', code: event.data });
          }
        }
      });
    }

    function handleCommand(raw) {
      var msg;
      try { msg = JSON.parse(raw); } catch (e) { return; }
      if (!ready || !player) {
        if (msg.cmd === 'load') pendingVideoId = msg.videoId;
        return;
      }
      switch (msg.cmd) {
        case 'load':
          player.loadVideoById(msg.videoId);
          break;
        case 'play':
          player.playVideo();
          break;
        case 'pause':
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
          break;
        case 'volume':
          player.setVolume(msg.volume);
          break;
        case 'getTime':
          post({ type: 'time', seconds: player.getCurrentTime(), state: player.getPlayerState() });
          break;
      }
    }

    document.addEventListener('message', function (e) { handleCommand(e.data); });
    window.addEventListener('message', function (e) { handleCommand(e.data); });
  </script>
</body>
</html>`;

/** Espejo de YT.PlayerState del IFrame API oficial. */
export const YT_PLAYER_STATE = {
  UNSTARTED: -1,
  ENDED: 0,
  PLAYING: 1,
  PAUSED: 2,
  BUFFERING: 3,
  CUED: 5,
} as const;
