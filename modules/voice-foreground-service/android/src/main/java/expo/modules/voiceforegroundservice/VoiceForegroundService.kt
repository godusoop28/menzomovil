package expo.modules.voiceforegroundservice

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
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat

/**
 * Mantiene viva la conexión de audio de una sala de voz cuando la app pasa a segundo plano o la
 * pantalla se bloquea. Android mata el proceso (y con él, la conexión de Agora) si no hay un
 * foreground service activo con `foregroundServiceType="microphone"` — la notificación persistente
 * es un requisito del sistema para eso, no una decisión de producto.
 */
class VoiceForegroundService : Service() {

  override fun onBind(intent: Intent?): IBinder? = null

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    val roomName = intent?.getStringExtra(EXTRA_ROOM_NAME)?.takeIf { it.isNotBlank() } ?: "Sala de voz"
    createChannelIfNeeded()
    ServiceCompat.startForeground(
      this,
      NOTIFICATION_ID,
      buildNotification(roomName),
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE else 0
    )
    return START_NOT_STICKY
  }

  override fun onDestroy() {
    stopForeground(STOP_FOREGROUND_REMOVE)
    super.onDestroy()
  }

  private fun createChannelIfNeeded() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
    val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    if (manager.getNotificationChannel(CHANNEL_ID) != null) return
    val channel = NotificationChannel(CHANNEL_ID, "Salas de voz", NotificationManager.IMPORTANCE_LOW).apply {
      description = "Se muestra mientras estás conectado a una sala de voz de Menzo."
      setShowBadge(false)
    }
    manager.createNotificationChannel(channel)
  }

  private fun buildNotification(roomName: String): Notification {
    // El módulo es una librería aparte (namespace expo.modules.voiceforegroundservice), así que no
    // tiene acceso en tiempo de compilación al R del host — el ícono del launcher se busca por
    // nombre en tiempo de ejecución, con un ícono del sistema como último recurso.
    val iconRes = resources.getIdentifier("ic_launcher", "mipmap", packageName)
      .takeIf { it != 0 } ?: android.R.drawable.ic_dialog_info

    val contentIntent = packageManager.getLaunchIntentForPackage(packageName)?.let {
      PendingIntent.getActivity(this, 0, it, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
    }

    return NotificationCompat.Builder(this, CHANNEL_ID)
      .setContentTitle("En vivo: $roomName")
      .setContentText("Menzo sigue conectado a la sala de voz.")
      .setSmallIcon(iconRes)
      .setOngoing(true)
      .setOnlyAlertOnce(true)
      .setPriority(NotificationCompat.PRIORITY_LOW)
      .setContentIntent(contentIntent)
      .build()
  }

  companion object {
    const val EXTRA_ROOM_NAME = "roomName"
    private const val CHANNEL_ID = "menzo_voice_room"
    private const val NOTIFICATION_ID = 4821
  }
}
