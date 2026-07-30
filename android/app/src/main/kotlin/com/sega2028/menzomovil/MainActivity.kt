package com.sega2028.menzomovil

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.sega2028.menzomovil/background_audio"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val intent = Intent(this, BackgroundAudioService::class.java)
                    intent.putExtra(BackgroundAudioService.EXTRA_TITLE, call.argument<String>("title") ?: "MENZO")
                    intent.putExtra(BackgroundAudioService.EXTRA_TEXT, call.argument<String>("text") ?: "Conectado a un LIVE")
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(null)
                }
                "stop" -> {
                    stopService(Intent(this, BackgroundAudioService::class.java))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
