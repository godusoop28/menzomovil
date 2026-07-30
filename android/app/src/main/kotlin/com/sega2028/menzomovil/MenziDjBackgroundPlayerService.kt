package com.sega2028.menzomovil

import android.annotation.SuppressLint
import android.app.Service
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.util.Log
import android.view.WindowManager
import android.webkit.JavascriptInterface
import android.webkit.ValueCallback
import android.webkit.WebView
import org.json.JSONObject

/**
 * Reproductor de YouTube (audio) que sigue vivo aunque `MainActivity` esté detenida —
 * el WebView de Flutter (`webview_flutter`, usado en primer plano) está atado al ciclo de vida
 * de esa Activity/FlutterView; en cuanto el usuario minimiza Menzo del todo, Chromium puede
 * congelar sus timers/reproducción. Este es un `android.webkit.WebView` NATIVO aparte, montado
 * en una ventana overlay de 1×1 (mismo permiso `SYSTEM_ALERT_WINDOW` que ya usa la burbuja del
 * LIVE) — su ventana sigue "visible" para Android aunque la Activity esté parada, así que
 * Chromium no lo trata como una pestaña en segundo plano.
 *
 * No es un servicio en primer plano propio: el proceso ya se mantiene vivo por
 * [BackgroundAudioService] (que sí lo es) mientras haya un LIVE o música activos — este servicio
 * solo necesita sobrevivir mientras el proceso viva, no correr independiente de él.
 *
 * Nunca reemplaza al WebView de Flutter — son dos instancias del MISMO reproductor oficial de
 * YouTube (misma página, mismo bridge de comandos): cuando la app pasa a segundo plano, Dart le
 * pide a este servicio [ACTION_ENTER] con el video/posición actuales y pausa su propio WebView
 * (para no reproducir doble audio); al volver a primer plano, Dart pide [ACTION_EXIT], que
 * devuelve la posición real alcanzada acá para que el WebView de Flutter retome ahí sin salto
 * audible, y este servicio se apaga.
 */
class MenziDjBackgroundPlayerService : Service() {
    companion object {
        const val ACTION_ENTER = "enter"
        const val ACTION_UPDATE_TRACK = "update_track"
        const val ACTION_UPDATE_AUDIO = "update_audio"
        const val ACTION_EXIT = "exit"
        const val EXTRA_VIDEO_ID = "videoId"
        const val EXTRA_ORIGIN = "origin"
        const val EXTRA_POSITION = "positionSeconds"
        const val EXTRA_PLAYING = "playing"
        const val EXTRA_MUTED = "muted"
        const val EXTRA_VOLUME = "volume"
        private const val TAG = "MenziDjBackgroundPlayer"

        /** Único punto que otras clases (MainActivity) usan para pedir la posición actual antes
         * de apagar el servicio — no hace falta un binder de verdad para esto. */
        var instance: MenziDjBackgroundPlayerService? = null
            private set
    }

    private var webView: WebView? = null
    private var windowManager: WindowManager? = null
    private var ready = false
    private var pendingVideoId: String? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    @SuppressLint("SetJavaScriptEnabled")
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        when (action) {
            ACTION_ENTER -> {
                val videoId = intent.getStringExtra(EXTRA_VIDEO_ID) ?: return START_NOT_STICKY
                val origin = intent.getStringExtra(EXTRA_ORIGIN) ?: "https://menzoweb.vercel.app"
                val position = intent.getDoubleExtra(EXTRA_POSITION, 0.0)
                val playing = intent.getBooleanExtra(EXTRA_PLAYING, true)
                val muted = intent.getBooleanExtra(EXTRA_MUTED, false)
                val volume = intent.getIntExtra(EXTRA_VOLUME, 80)
                ensureWebView(origin)
                pendingVideoId = videoId
                applyOnReady = {
                    sendCommand("load", mapOf("videoId" to videoId))
                    sendCommand("seek", mapOf("seconds" to position))
                    if (playing) sendCommand("play", null) else sendCommand("pause", null)
                    if (muted) sendCommand("mute", null) else sendCommand("unmute", mapOf("volume" to volume))
                }
                if (ready) applyOnReady?.invoke()
            }
            ACTION_UPDATE_TRACK -> {
                val videoId = intent?.getStringExtra(EXTRA_VIDEO_ID) ?: return START_NOT_STICKY
                val position = intent.getDoubleExtra(EXTRA_POSITION, 0.0)
                sendCommand("load", mapOf("videoId" to videoId))
                sendCommand("seek", mapOf("seconds" to position))
                sendCommand("play", null)
            }
            ACTION_UPDATE_AUDIO -> {
                val muted = intent?.getBooleanExtra(EXTRA_MUTED, false) ?: false
                val volume = intent?.getIntExtra(EXTRA_VOLUME, 80) ?: 80
                if (muted) sendCommand("mute", null) else sendCommand("unmute", mapOf("volume" to volume))
            }
            ACTION_EXIT -> {
                teardown()
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    private var applyOnReady: (() -> Unit)? = null

    private fun ensureWebView(origin: String) {
        if (webView != null) return
        val wm = getSystemService(WINDOW_SERVICE) as WindowManager
        windowManager = wm

        val view = WebView(this)
        view.settings.javaScriptEnabled = true
        view.settings.domStorageEnabled = true
        view.settings.mediaPlaybackRequiresUserGesture = false
        view.setBackgroundColor(android.graphics.Color.BLACK)
        view.addJavascriptInterface(object {
            @JavascriptInterface
            fun postMessage(message: String) {
                try {
                    val json = JSONObject(message)
                    if (json.optString("type") == "ready") {
                        ready = true
                        applyOnReady?.invoke()
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "mensaje del bridge inválido", e)
                }
            }
        }, "MenziBackgroundBridge")
        view.loadDataWithBaseURL(origin, playerHtml(origin), "text/html", "utf-8", null)

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_SYSTEM_ALERT
        }
        val params = WindowManager.LayoutParams(
            1,
            1,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE,
            PixelFormat.TRANSLUCENT,
        )
        try {
            wm.addView(view, params)
            webView = view
        } catch (e: Exception) {
            // Sin permiso de overlay (el usuario nunca lo concedió, o lo revocó) — no hay forma
            // de mantener este WebView vivo en segundo plano. No es un error fatal: Dart simplemente
            // no recibirá el hand-off y el audio se pausará al minimizar, como antes de esta mejora.
            Log.w(TAG, "no se pudo agregar el WebView de fondo (¿falta permiso de overlay?)", e)
            webView = null
        }
    }

    /** Se llama desde MainActivity al recibir `exitBackground` — pide la posición actual antes
     * de que el propio caller destruya este servicio. */
    fun currentPosition(callback: (Double) -> Unit) {
        val view = webView
        if (view == null) {
            callback(0.0)
            return
        }
        view.evaluateJavascript("(function(){ try { return player ? player.getCurrentTime() : 0; } catch(e) { return 0; } })()") { result ->
            val value = result?.toDoubleOrNull() ?: 0.0
            callback(value)
        }
    }

    private fun sendCommand(cmd: String, args: Map<String, Any?>?) {
        val payload = JSONObject()
        payload.put("cmd", cmd)
        args?.forEach { (k, v) -> payload.put(k, v) }
        val json = JSONObject.quote(payload.toString())
        webView?.post {
            webView?.evaluateJavascript("window.handleMenziCommand($json)", null)
        }
    }

    private fun teardown() {
        val view = webView
        if (view != null) {
            try {
                windowManager?.removeView(view)
            } catch (_: Exception) {}
            view.destroy()
        }
        webView = null
        ready = false
        pendingVideoId = null
        applyOnReady = null
    }

    override fun onDestroy() {
        teardown()
        if (instance === this) instance = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    /** Página mínima con el IFrame Player oficial de YouTube — mismo bridge de comandos que
     * `menzi_dj_player_html.dart` (Flutter), portado a Kotlin porque acá no hay forma de
     * compartir el string de Dart directamente. Si se cambia uno, cambiar el otro. */
    private fun playerHtml(origin: String): String = """
        <!DOCTYPE html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no" />
          <style>html,body{margin:0;padding:0;background:#000;width:100%;height:100%;overflow:hidden}#player{width:100%;height:100%}</style>
        </head>
        <body>
          <div id="player"></div>
          <script src="https://www.youtube.com/iframe_api"></script>
          <script>
            var player = null; var ready = false; var pendingVideoId = null;
            function post(m){ if (window.MenziBackgroundBridge) window.MenziBackgroundBridge.postMessage(JSON.stringify(m)); }
            function onYouTubeIframeAPIReady(){
              player = new YT.Player('player', {
                width: '100%', height: '100%',
                playerVars: { autoplay: 1, mute: 1, playsinline: 1, controls: 0, modestbranding: 1, rel: 0, origin: '$origin', enablejsapi: 1 },
                events: {
                  onReady: function(){ ready = true; post({type:'ready'}); if (pendingVideoId){ player.loadVideoById(pendingVideoId); pendingVideoId = null; } }
                }
              });
            }
            window.handleMenziCommand = function(raw){
              var msg; try { msg = JSON.parse(raw); } catch(e){ return; }
              if (!ready || !player){ if (msg.cmd === 'load') pendingVideoId = msg.videoId; return; }
              switch(msg.cmd){
                case 'load': player.loadVideoById(msg.videoId); break;
                case 'play': player.playVideo(); break;
                case 'pause': player.pauseVideo(); break;
                case 'seek': player.seekTo(msg.seconds, true); break;
                case 'mute': player.mute(); break;
                case 'unmute': player.unMute(); if (typeof msg.volume === 'number') player.setVolume(msg.volume); break;
              }
            };
          </script>
        </body>
        </html>
    """.trimIndent()
}

private fun String.toDoubleOrNull(): Double? = try {
    this.toDouble()
} catch (e: NumberFormatException) {
    null
}
