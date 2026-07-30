package com.sega2028.menzomovil

import io.flutter.plugin.common.EventChannel

/**
 * Puente en memoria (mismo proceso, sin IPC real) entre [LiveBubbleService] y el
 * `EventChannel` que Dart escucha para reaccionar a toques en la burbuja — volver a Menzo,
 * mutear/desmutear, o abandonar el LIVE. La burbuja NUNCA toca Agora ni el foreground service
 * de audio directamente: solo emite la intención, y quien decide/ejecuta sigue siendo
 * `live_provider.dart` (única fuente de verdad del estado del LIVE).
 */
object LiveBubbleBridge {
    private var sink: EventChannel.EventSink? = null

    fun attach(sink: EventChannel.EventSink) {
        this.sink = sink
    }

    fun detach() {
        this.sink = null
    }

    fun emit(action: String) {
        sink?.success(mapOf("action" to action))
    }
}
