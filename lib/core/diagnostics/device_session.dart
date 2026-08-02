import 'dart:math';

/// Id aleatorio generado una vez por ejecución del proceso (no persiste entre reinicios de la
/// app, y no depende de ningún dato real del usuario) — sirve para correlacionar, en los logs de
/// diagnóstico de un mismo dispositivo, todos los eventos de una sesión de LIVE/DJ Menzi (ver
/// Fase 20 del pedido de estabilización: "deviceSessionId aleatorio por instalación/ejecución").
class DeviceSession {
  DeviceSession._();

  static final String id = _generate();

  static String _generate() {
    final random = Random();
    final bytes = List<int>.generate(8, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
