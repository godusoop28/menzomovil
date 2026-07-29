package expo.modules.voiceforegroundservice

import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat
import expo.modules.kotlin.exception.Exceptions
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition

class VoiceForegroundServiceModule : Module() {
  private val context: Context
    get() = appContext.reactContext ?: throw Exceptions.ReactContextLost()

  override fun definition() = ModuleDefinition {
    Name("VoiceForegroundService")

    Function("start") { roomName: String ->
      val intent = Intent(context, VoiceForegroundService::class.java).apply {
        putExtra(VoiceForegroundService.EXTRA_ROOM_NAME, roomName)
      }
      ContextCompat.startForegroundService(context, intent)
    }

    Function("stop") {
      context.stopService(Intent(context, VoiceForegroundService::class.java))
    }
  }
}
