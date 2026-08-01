package com.sega2028.menzomovil

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val audioChannelName = "com.sega2028.menzomovil/background_audio"
    private val bubbleChannelName = "com.sega2028.menzomovil/live_bubble"
    private val bubbleEventsName = "com.sega2028.menzomovil/live_bubble_events"
    private val menziDjBackgroundChannelName = "com.sega2028.menzomovil/menzi_dj_background"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, audioChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val intent = Intent(this, BackgroundAudioService::class.java)
                    intent.putExtra(BackgroundAudioService.EXTRA_TITLE, call.argument<String>("title") ?: "MENZO")
                    intent.putExtra(BackgroundAudioService.EXTRA_TEXT, call.argument<String>("text") ?: "Conectado a un LIVE")
                    intent.putExtra(
                        BackgroundAudioService.EXTRA_MODE,
                        call.argument<String>("mode") ?: BackgroundAudioService.MODE_LISTEN,
                    )
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(null)
                    } catch (e: Exception) {
                        // No debe tumbar la app: el LIVE de voz sigue funcionando vía Agora aunque
                        // el foreground service no arranque (solo se pierde la persistencia en
                        // segundo plano), así que reportamos el error a Dart en vez de dejar
                        // propagar la excepción.
                        result.error("BACKGROUND_AUDIO_START_FAILED", e.message, null)
                    }
                }
                "stop" -> {
                    stopService(Intent(this, BackgroundAudioService::class.java))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, bubbleChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkPermission" -> {
                    result.success(canDrawOverlays())
                }
                "requestPermission" -> {
                    if (canDrawOverlays()) {
                        result.success(true)
                    } else {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName"),
                        )
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        // Android no devuelve un resultado confiable de esta pantalla de ajustes —
                        // Dart debe volver a llamar a `checkPermission` al reanudar (didChangeAppLifecycleState),
                        // nunca asumir que quedó concedido solo porque el usuario volvió.
                        result.success(false)
                    }
                }
                "show" -> {
                    if (!canDrawOverlays()) {
                        result.success(false)
                    } else {
                        val intent = Intent(this, LiveBubbleService::class.java)
                        intent.action = LiveBubbleService.ACTION_SHOW
                        intent.putExtra(LiveBubbleService.EXTRA_CAN_SPEAK, call.argument<Boolean>("canSpeak") ?: false)
                        intent.putExtra(LiveBubbleService.EXTRA_MUTED, call.argument<Boolean>("muted") ?: true)
                        startService(intent)
                        result.success(true)
                    }
                }
                "updateState" -> {
                    val intent = Intent(this, LiveBubbleService::class.java)
                    intent.action = LiveBubbleService.ACTION_UPDATE
                    intent.putExtra(LiveBubbleService.EXTRA_CAN_SPEAK, call.argument<Boolean>("canSpeak") ?: false)
                    intent.putExtra(LiveBubbleService.EXTRA_MUTED, call.argument<Boolean>("muted") ?: true)
                    startService(intent)
                    result.success(null)
                }
                "hide" -> {
                    val intent = Intent(this, LiveBubbleService::class.java)
                    intent.action = LiveBubbleService.ACTION_HIDE
                    startService(intent)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, menziDjBackgroundChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "warmUp" -> {
                    // Se llama apenas hay una canción activa, con la app en primer plano —
                    // deja lista la ventana/reproductor de fondo (montaje + carga del IFrame
                    // API de YouTube, que implica un pedido de red) ANTES de que haga falta,
                    // para que activate() sea instantáneo al minimizar de verdad.
                    if (!canDrawOverlays()) {
                        result.success(false)
                    } else {
                        result.success(
                            MenziDjBackgroundPlayer.warmUp(
                                context = applicationContext,
                                origin = call.argument<String>("origin") ?: "https://menzoweb.vercel.app",
                            ),
                        )
                    }
                }
                "activate" -> {
                    if (!canDrawOverlays()) {
                        // Sin overlay no hay dónde montar el WebView nativo — Dart no debe
                        // pausar su propio WebView, la música sigue por el camino de siempre.
                        result.success(false)
                    } else {
                        // Llamada síncrona (no Intent/Service) — el resultado que le llega a
                        // Dart es el resultado REAL de intentar montar/activar la ventana
                        // overlay, no una suposición optimista. Ver el comentario de clase en
                        // MenziDjBackgroundPlayer.kt sobre por qué esto importa.
                        val activated = MenziDjBackgroundPlayer.activate(
                            context = applicationContext,
                            origin = call.argument<String>("origin") ?: "https://menzoweb.vercel.app",
                            videoId = call.argument<String>("videoId") ?: "",
                            positionSeconds = call.argument<Double>("positionSeconds") ?: 0.0,
                            playing = call.argument<Boolean>("playing") ?: true,
                            muted = call.argument<Boolean>("muted") ?: false,
                            volume = call.argument<Int>("volume") ?: 80,
                        )
                        result.success(activated)
                    }
                }
                "updateTrack" -> {
                    MenziDjBackgroundPlayer.updateTrack(
                        videoId = call.argument<String>("videoId") ?: "",
                        positionSeconds = call.argument<Double>("positionSeconds") ?: 0.0,
                    )
                    result.success(null)
                }
                "updateAudioState" -> {
                    MenziDjBackgroundPlayer.updateAudioState(
                        muted = call.argument<Boolean>("muted") ?: false,
                        volume = call.argument<Int>("volume") ?: 80,
                    )
                    result.success(null)
                }
                "updatePlayback" -> {
                    MenziDjBackgroundPlayer.updatePlayback(
                        positionSeconds = call.argument<Double>("positionSeconds") ?: 0.0,
                        playing = call.argument<Boolean>("playing") ?: true,
                    )
                    result.success(null)
                }
                "playbackState" -> {
                    result.success(MenziDjBackgroundPlayer.playbackState())
                }
                "pauseAndReportPosition" -> {
                    MenziDjBackgroundPlayer.pauseAndReportPosition { position ->
                        result.success(mapOf("positionSeconds" to position))
                    }
                }
                "teardown" -> {
                    MenziDjBackgroundPlayer.teardown()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, bubbleEventsName).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    LiveBubbleBridge.attach(events)
                }

                override fun onCancel(arguments: Any?) {
                    LiveBubbleBridge.detach()
                }
            },
        )
    }

    private fun canDrawOverlays(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }
}
