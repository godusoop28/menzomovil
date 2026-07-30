package com.sega2028.menzomovil

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Mantiene viva la sesión de audio (mic del LIVE y/o música de Menzi DJ) cuando la app pasa a
 * segundo plano. Sin un foreground service real, Android 8+ suspende el acceso al micrófono y
 * puede pausar el WebView/Agora poco después de minimizar la app — los permisos declarados en
 * el manifest (FOREGROUND_SERVICE_MICROPHONE, etc.) no alcanzan por sí solos, hace falta un
 * servicio en primer plano corriendo de verdad con una notificación persistente.
 *
 * IMPORTANTE (causa del crash `SecurityException: Starting FGS with type microphone`): en
 * targetSdk 34+ Android exige que `RECORD_AUDIO` esté REALMENTE concedido en el momento exacto
 * de `startForeground()` para poder declarar el tipo `microphone` — no alcanza con que el
 * permiso esté en el manifest. Este servicio nunca decide por su cuenta si corresponde pedir
 * ese tipo: recibe el modo ya resuelto desde Dart (`EXTRA_MODE`), que es quien ya comprobó el
 * permiso con `permission_handler` antes de invocar el MethodChannel (ver
 * `lib/features/live/live_provider.dart`). Acá solo queda una red de seguridad: si aun así
 * `startForeground` con tipo `microphone` es rechazado (permiso revocado en el ínterin, OEM
 * raro, condición de carrera), se degrada a solo `mediaPlayback` en vez de dejar que la
 * excepción tumbe toda la app.
 */
class BackgroundAudioService : Service() {
    companion object {
        const val CHANNEL_ID = "menzo_live_audio"
        const val NOTIFICATION_ID = 4201
        const val EXTRA_TITLE = "title"
        const val EXTRA_TEXT = "text"
        const val EXTRA_MODE = "mode"
        const val MODE_LISTEN = "listen"
        const val MODE_SPEAK = "speak"
        private const val TAG = "BackgroundAudioService"
    }

    private var currentMode: String = MODE_LISTEN
    private var wakeLock: PowerManager.WakeLock? = null

    /**
     * Un `PARTIAL_WAKE_LOCK` deja la pantalla apagarse pero mantiene la CPU corriendo — sin
     * esto, Doze/App Standby puede congelar los timers del WebView (JS de Menzi DJ) y el hilo
     * de audio de Agora poco después de apagar la pantalla con la app en segundo plano, aunque
     * el foreground service siga técnicamente "vivo". Se toma/suelta junto con el ciclo de vida
     * del servicio, nunca fuera de él.
     */
    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        val lock = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "menzomovil:live_audio",
        )
        lock.setReferenceCounted(false)
        lock.acquire(4 * 60 * 60 * 1000L) // tope de 4h de seguridad, no debería durar tanto
        wakeLock = lock
    }

    private fun releaseWakeLock() {
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) {
            // Android puede volver a entregar un Intent nulo con START_STICKY tras matar el
            // proceso (p. ej. por memoria baja). El estado real del LIVE vive en el proceso de
            // Dart, que también se perdió — no hay nada válido que retomar acá, así que no
            // arriesgamos un startForeground con datos inventados.
            stopSelf()
            return START_NOT_STICKY
        }

        val title = intent.getStringExtra(EXTRA_TITLE) ?: "MENZO"
        val text = intent.getStringExtra(EXTRA_TEXT) ?: "Conectado a un LIVE"
        val mode = intent.getStringExtra(EXTRA_MODE) ?: MODE_LISTEN
        currentMode = mode

        try {
            startForeground(NOTIFICATION_ID, buildNotification(title, text), foregroundType(mode))
            acquireWakeLock()
        } catch (e: SecurityException) {
            Log.w(TAG, "startForeground con modo '$mode' rechazado, degradando a listen", e)
            currentMode = MODE_LISTEN
            try {
                startForeground(
                    NOTIFICATION_ID,
                    buildNotification(title, text),
                    foregroundType(MODE_LISTEN),
                )
                acquireWakeLock()
            } catch (e2: SecurityException) {
                Log.e(TAG, "startForeground falló incluso en modo listen, deteniendo servicio", e2)
                stopSelf()
            }
        }
        return START_STICKY
    }

    private fun foregroundType(mode: String): Int {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return 0
        return if (mode == MODE_SPEAK) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE or
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
        } else {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
        }
    }

    private fun buildNotification(title: String, text: String): Notification {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val existing = manager.getNotificationChannel(CHANNEL_ID)
            if (existing == null) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "Audio en vivo",
                    NotificationManager.IMPORTANCE_LOW,
                )
                channel.description = "Micrófono y música de Menzi DJ activos"
                channel.setShowBadge(false)
                manager.createNotificationChannel(channel)
            }
        }

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val contentIntent = if (launchIntent != null) {
            PendingIntent.getActivity(
                this,
                0,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        } else null

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(applicationInfo.icon)
            .setOngoing(true)
            .setContentIntent(contentIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    override fun onDestroy() {
        releaseWakeLock()
        super.onDestroy()
        currentMode = MODE_LISTEN
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
