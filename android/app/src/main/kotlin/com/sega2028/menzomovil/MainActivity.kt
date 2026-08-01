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
