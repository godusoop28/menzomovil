package com.sega2028.menzomovil

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * Mantiene viva la sesión de audio (mic del LIVE y/o música de Menzi DJ) cuando la app pasa a
 * segundo plano. Sin un foreground service real, Android 8+ suspende el acceso al micrófono y
 * puede pausar el WebView/Agora poco después de minimizar la app — los permisos declarados en
 * el manifest (FOREGROUND_SERVICE_MICROPHONE, etc.) no alcanzan por sí solos, hace falta un
 * servicio en primer plano corriendo de verdad con una notificación persistente.
 */
class BackgroundAudioService : Service() {
    companion object {
        const val CHANNEL_ID = "menzo_live_audio"
        const val NOTIFICATION_ID = 4201
        const val EXTRA_TITLE = "title"
        const val EXTRA_TEXT = "text"
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val title = intent?.getStringExtra(EXTRA_TITLE) ?: "MENZO"
        val text = intent?.getStringExtra(EXTRA_TEXT) ?: "Conectado a un LIVE"
        startForeground(NOTIFICATION_ID, buildNotification(title, text), foregroundType())
        return START_STICKY
    }

    private fun foregroundType(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE or
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
        } else 0
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

    override fun onBind(intent: Intent?): IBinder? = null
}
