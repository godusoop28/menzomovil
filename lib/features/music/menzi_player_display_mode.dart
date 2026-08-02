import '../../data/models/music_models.dart';

/// Modo visual del ÚNICO WebView persistente de Menzi DJ — nunca implica crear, destruir ni
/// intercambiar el `WebViewWidget`/`WebViewController` (ver menzi_dj_player_host.dart): solo
/// cambia tamaño, posición y qué capa/controles se pintan encima. Reemplaza los booleanos
/// sueltos `expanded`/`videoHidden` de antes — con dos booleanos independientes existían 4
/// combinaciones posibles pero solo 2 ramas de UI reales, lo cual ya era una fuente de
/// ambigüedad; el enum hace explícitos los 5 estados que de verdad importan.
enum MenziPlayerDisplayMode {
  /// Video oculto a pedido del usuario — la música sigue sonando, el WebView sigue montado con
  /// tamaño real (nunca 1×1/Offstage/Opacity 0, ver comentario histórico en
  /// menzi_dj_player_host.dart), solo se cubre con una capa visual propia.
  hidden,

  /// Burbuja flotante pequeña, arrastrable, siempre visible mientras haya una canción y el panel
  /// completo no esté abierto.
  mini,

  /// Panel de Menzi DJ abierto — el video se ancla cerca de la parte superior de ese panel.
  normal,

  /// Igual que `normal` pero a ancho completo / más alto, para una experiencia más inmersiva
  /// dentro del panel.
  cinema,

  /// El video ocupa toda la pantalla (modo inmersivo del sistema).
  fullscreen,
}

/// Razón de una pausa LOCAL del player — nunca se manda al backend, es puramente para poder
/// diagnosticar y decidir si hay que recuperarse solo o no (ver Fase 5/7 del pedido de
/// estabilización). `global` es la única que refleja el estado real de la sesión en menzoapi;
/// todas las demás son honestas sobre POR QUÉ el player de este dispositivo dejó de sonar sin
/// que el resto de la sala se haya visto afectado.
enum MenziPauseReason {
  global,
  appBackgrounded,
  userLocal,
  playerEnded,
  autoplayBlocked,
  unexpectedPlatformPause,
  unknown,
}

/// Decide con qué [MenziPauseReason] explicar un `state=2` (paused) que acaba de reportar el
/// bridge — pura y testeable sin WebView/Timer real (ver menzi_dj_event_logic_test.dart).
///
/// Orden de las reglas, de la más a la menos autoritativa:
/// 1. Si la sesión GLOBAL no está en `playing`, el pause es exactamente lo esperado — `global`.
/// 2. Si el dispositivo está en background, es la pausa local deliberada de esta app — ver
///    `_handleAppBackgrounded`.
/// 3. Si hace poco (`< recentWindow`) este mismo dispositivo mandó un `pause` con una razón
///    conocida, ese state=2 es simplemente la confirmación de ese comando — se reporta esa misma
///    razón, no `unexpectedPlatformPause`.
/// 4. Si nada de lo anterior explica el pause, es exactamente el bug que reportaron los logs
///    reales (abrir opciones, mover el WebView, etc.) — `unexpectedPlatformPause`.
MenziPauseReason classifyLocalPause({
  required MusicSessionStatus? sessionStatus,
  required MenziPauseReason? lastCommandedReason,
  required DateTime? lastCommandedAt,
  required bool isBackgrounded,
  required DateTime now,
  Duration recentWindow = const Duration(seconds: 3),
}) {
  if (sessionStatus != MusicSessionStatus.playing) return MenziPauseReason.global;
  if (isBackgrounded) return MenziPauseReason.appBackgrounded;
  if (lastCommandedReason != null &&
      lastCommandedAt != null &&
      now.difference(lastCommandedAt) < recentWindow) {
    return lastCommandedReason;
  }
  return MenziPauseReason.unexpectedPlatformPause;
}

/// Throttle del slider de volumen local (Fase 8) — decide si corresponde mandar el comando AHORA
/// o esperar al próximo tick/al final del drag. Pura: no depende de un `Timer` real, así se
/// prueba con instantes de tiempo fabricados a mano. El llamador SIEMPRE debe mandar el valor
/// final en `onChangeEnd` sin pasar por este chequeo — el throttle nunca debe poder perder el
/// valor final, solo los intermedios durante el arrastre.
bool shouldSendThrottledVolume({
  required DateTime? lastSentAt,
  required DateTime now,
  Duration minInterval = const Duration(milliseconds: 80),
}) {
  if (lastSentAt == null) return true;
  return now.difference(lastSentAt) >= minInterval;
}
