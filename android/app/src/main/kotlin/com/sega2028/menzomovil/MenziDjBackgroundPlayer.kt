package com.sega2028.menzomovil

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.PixelFormat
import android.os.Build
import android.util.Log
import android.view.WindowManager
import android.webkit.JavascriptInterface
import android.webkit.WebView
import org.json.JSONObject

/**
 * Reproductor de YouTube (audio) que sigue vivo aunque `MainActivity` esté detenida —
 * el WebView de Flutter (`webview_flutter`, usado en primer plano) está atado al ciclo de vida
 * de esa Activity/FlutterView; en cuanto el usuario minimiza Menzo del todo, Chromium puede
 * congelar sus timers/reproducción. Este es un `android.webkit.WebView` NATIVO aparte, montado
 * en una ventana overlay de 1×1 (mismo permiso `SYSTEM_ALERT_WINDOW` que ya usa la burbuja del
 * LIVE) — su ventana sigue "visible" para Android aunque la Activity esté parada.
 *
 * Es un objeto Kotlin plano (no un `Service` de Android) — el proceso ya se mantiene vivo por
 * `BackgroundAudioService` (que sí es un foreground service real) mientras haya un LIVE o
 * música activos, así que no hace falta un segundo Service compitiendo por lo mismo. La ventaja
 * concreta de NO ser un Service: las llamadas corren de forma síncrona en el mismo hilo que
 * llama desde `MainActivity`, así que el resultado que se le devuelve a Dart es el resultado
 * REAL de intentar montar la ventana — antes, con `startService(Intent)` + `result.success(true)`
 * inmediato, Dart podía creer que el hand-off funcionó (y pausar su propio WebView) aunque
 * `addView` fallara en el service de fondo, dejando a la música directamente muda.
 *
 * PRECALENTADO: montar la ventana + cargar el IFrame API de YouTube implica un pedido de red
 * (`<script src="https://www.youtube.com/iframe_api">`) que puede tardar unos segundos — hacer
 * todo eso recién en el instante exacto de minimizar la app dejaba un hueco audible de silencio
 * real antes de que el reproductor de fondo llegara a arrancar (el de primer plano ya se había
 * pausado). Por eso [warmUp] se llama apenas Menzi DJ tiene una canción activa (con la app
 * todavía en primer plano) y el WebView de fondo queda montado, muteado y en pausa durante TODA
 * la sesión — [activate]/[pause] solo alternan play/pause+mute sobre una instancia que ya está
 * lista, sin ningún pedido de red de por medio. Recién se destruye con [teardown], al salir del
 * LIVE/de Menzi DJ.
 */
object MenziDjBackgroundPlayer {
    private const val TAG = "MenziDjBackgroundPlayer"

    private var webView: WebView? = null
    private var windowManager: WindowManager? = null
    private var ready = false
    private var applyOnReady: (() -> Unit)? = null

    /** Deja lista la ventana/reproductor de fondo (muteado y sin reproducir nada todavía) para
     * que, llegado el momento real de pasar a segundo plano, [activate] sea instantáneo — no
     * hay pedido de red pendiente en ese momento. Seguro de llamar varias veces (no-op si ya
     * está montado). */
    @SuppressLint("SetJavaScriptEnabled")
    fun warmUp(context: Context, origin: String): Boolean {
        if (webView != null) return true
        return tryAttach(context, origin)
    }

    /** true si el WebView de fondo está montado de verdad — Dart solo debe pausar su propio
     * WebView cuando esto (o el resultado de `activate`) es true; si es false, no hay quién
     * reproduzca nada. */
    val isActive: Boolean
        get() = webView != null

    /** Pasa a primer plano el audio en el reproductor de fondo (ya precalentado por [warmUp] —
     * si por algún motivo no lo estaba, lo intenta acá mismo como red de seguridad). */
    fun activate(
        context: Context,
        origin: String,
        videoId: String,
        positionSeconds: Double,
        playing: Boolean,
        muted: Boolean,
        volume: Int,
    ): Boolean {
        if (webView == null) {
            val attached = tryAttach(context, origin)
            if (!attached) return false
        }
        applyOnReady = {
            sendCommand("load", mapOf("videoId" to videoId))
            sendCommand("seek", mapOf("seconds" to positionSeconds))
            if (playing) sendCommand("play", null) else sendCommand("pause", null)
            if (muted) sendCommand("mute", null) else sendCommand("unmute", mapOf("volume" to volume))
        }
        if (ready) applyOnReady?.invoke()
        return true
    }

    fun updateTrack(videoId: String, positionSeconds: Double) {
        if (webView == null) return
        sendCommand("load", mapOf("videoId" to videoId))
        sendCommand("seek", mapOf("seconds" to positionSeconds))
        sendCommand("play", null)
    }

    fun updateAudioState(muted: Boolean, volume: Int) {
        if (webView == null) return
        if (muted) sendCommand("mute", null) else sendCommand("unmute", mapOf("volume" to volume))
    }

    /** Pide la posición real alcanzada y PAUSA+MUTEA el reproductor de fondo — pero no lo
     * destruye, queda precalentado para la próxima vez que se minimice la app en esta misma
     * sesión de LIVE/Menzi DJ. */
    fun pauseAndReportPosition(callback: (Double) -> Unit) {
        val view = webView
        if (view == null) {
            callback(0.0)
            return
        }
        view.evaluateJavascript(
            "(function(){ try { return player ? player.getCurrentTime() : 0; } catch(e) { return 0; } })()",
        ) { result ->
            val value = result?.toDoubleOrNull() ?: 0.0
            sendCommand("pause", null)
            sendCommand("mute", null)
            callback(value)
        }
    }

    /** Destruye de verdad la ventana/WebView de fondo — solo al salir del LIVE o terminar la
     * sesión de Menzi DJ, no en cada ida y vuelta de primer/segundo plano. */
    fun teardown() {
        val view = webView
        if (view != null) {
            try {
                windowManager?.removeView(view)
            } catch (_: Exception) {}
            view.destroy()
        }
        webView = null
        windowManager = null
        ready = false
        applyOnReady = null
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun tryAttach(context: Context, origin: String): Boolean {
        return try {
            val appContext = context.applicationContext
            val wm = appContext.getSystemService(Context.WINDOW_SERVICE) as WindowManager

            val view = WebView(appContext)
            view.settings.javaScriptEnabled = true
            view.settings.domStorageEnabled = true
            view.settings.mediaPlaybackRequiresUserGesture = false
            view.setBackgroundColor(android.graphics.Color.BLACK)
            view.addJavascriptInterface(
                object {
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
                },
                "MenziBackgroundBridge",
            )
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
            wm.addView(view, params)
            windowManager = wm
            webView = view
            true
        } catch (e: Exception) {
            // Sin permiso de overlay concedido de verdad (o cualquier otro fallo del
            // WindowManager) — se reporta `false` y Dart NUNCA pausa su propio WebView, así
            // que la música sigue sonando por el camino de siempre (el que había antes de esta
            // mejora) en vez de quedar muda por las dos vías a la vez.
            Log.w(TAG, "no se pudo montar el WebView de fondo", e)
            webView = null
            windowManager = null
            false
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
