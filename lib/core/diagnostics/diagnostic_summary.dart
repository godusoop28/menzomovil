import 'app_diagnostic_logger.dart';

/// Última "foto" conocida del estado real de Menzi DJ, reconstruida escaneando los logs en orden
/// — no se guarda aparte en ningún provider: los logs SON la única fuente de verdad, tal como
/// pide la Fase 6 del diagnóstico ("=== RESUMEN ===" al final del TXT exportado).
class DiagnosticSummary {
  const DiagnosticSummary({
    this.activePlayerCount,
    this.activeInstanceId,
    this.roomId,
    this.role,
    this.currentVideoId,
    this.lastVersion,
    this.lastEventId,
    this.pageLoaded = false,
    this.iframeReady = false,
    this.lastCommand,
    this.lastPlayerState,
    this.lastErrorCode,
    this.muted,
    this.volume,
    this.currentTime,
    this.autoplayBlocked = false,
  });

  final int? activePlayerCount;
  final String? activeInstanceId;
  final String? roomId;
  final String? role;
  final String? currentVideoId;
  final int? lastVersion;
  final String? lastEventId;
  final bool pageLoaded;
  final bool iframeReady;
  final String? lastCommand;
  final int? lastPlayerState;
  final int? lastErrorCode;
  final bool? muted;
  final double? volume;
  final double? currentTime;
  final bool autoplayBlocked;

  String toBlock() {
    String s(Object? v) => v?.toString() ?? '-';
    return [
      '=== RESUMEN ===',
      'activePlayerCount: ${s(activePlayerCount)}',
      'activeInstanceId: ${s(activeInstanceId)}',
      'roomId: ${s(roomId)}',
      'role: ${s(role)}',
      'currentVideoId: ${s(currentVideoId)}',
      'lastVersion: ${s(lastVersion)}',
      'lastEventId: ${s(lastEventId)}',
      'pageLoaded: $pageLoaded',
      'iframeReady: $iframeReady',
      'lastCommand: ${s(lastCommand)}',
      'lastPlayerState: ${s(lastPlayerState)}',
      'lastErrorCode: ${s(lastErrorCode)}',
      'muted: ${s(muted)}',
      'volume: ${s(volume)}',
      'currentTime: ${s(currentTime)}',
      'autoplayBlocked: $autoplayBlocked',
    ].join('\n');
  }
}

/// Reconstruye [DiagnosticSummary] recorriendo [entries] EN ORDEN (más viejo primero) — cada
/// campo queda con el último valor visto para esa clave, tal como pide la Fase 6. Función pura:
/// no depende de [AppDiagnosticLogger.instance], se prueba pasándole una lista armada a mano.
DiagnosticSummary buildDiagnosticSummary(List<DiagnosticLogEntry> entries) {
  int? activePlayerCount;
  String? activeInstanceId;
  String? roomId;
  String? role;
  String? currentVideoId;
  int? lastVersion;
  String? lastEventId;
  bool pageLoaded = false;
  bool iframeReady = false;
  String? lastCommand;
  int? lastPlayerState;
  int? lastErrorCode;
  bool? muted;
  double? volume;
  double? currentTime;
  bool autoplayBlocked = false;

  num? asNum(Object? v) => v is num ? v : null;

  for (final e in entries) {
    final data = e.data;
    switch (e.category) {
      case DiagnosticCategory.live:
        roomId = (data?['roomId'] as String?) ?? roomId;
        role = (data?['role'] as String?) ?? role;
      case DiagnosticCategory.musicSession:
        currentVideoId = (data?['videoId'] as String?) ?? currentVideoId;
        lastVersion = asNum(data?['version'])?.toInt() ?? lastVersion;
        lastEventId = (data?['eventId'] as String?) ?? lastEventId;
      case DiagnosticCategory.ytInstance:
        if (e.message == 'page loaded') pageLoaded = true;
        if (e.message == 'iframe ready' || e.message == 'player ready') {
          iframeReady = true;
        }
        activeInstanceId = (data?['instanceId'] as String?) ?? activeInstanceId;
        activePlayerCount = asNum(data?['activePlayerCount'])?.toInt() ?? activePlayerCount;
      case DiagnosticCategory.ytCommand:
        lastCommand = (data?['cmd'] as String?) ?? lastCommand;
      case DiagnosticCategory.ytState:
        lastPlayerState = asNum(data?['state'])?.toInt() ?? lastPlayerState;
        if (data?['muted'] is bool) muted = data!['muted'] as bool;
        volume = asNum(data?['volume'])?.toDouble() ?? volume;
        currentTime = asNum(data?['currentTime'])?.toDouble() ?? currentTime;
      case DiagnosticCategory.ytError:
        lastErrorCode = asNum(data?['errorCode'])?.toInt() ?? lastErrorCode;
      case DiagnosticCategory.autoplay:
        if (e.message.contains('blocked')) autoplayBlocked = true;
        if (e.message.contains('granted') || e.message.contains('unblocked')) {
          autoplayBlocked = false;
        }
      case DiagnosticCategory.build:
      case DiagnosticCategory.stomp:
      case DiagnosticCategory.ytBridge:
      case DiagnosticCategory.lifecycle:
        break;
    }
  }

  return DiagnosticSummary(
    activePlayerCount: activePlayerCount,
    activeInstanceId: activeInstanceId,
    roomId: roomId,
    role: role,
    currentVideoId: currentVideoId,
    lastVersion: lastVersion,
    lastEventId: lastEventId,
    pageLoaded: pageLoaded,
    iframeReady: iframeReady,
    lastCommand: lastCommand,
    lastPlayerState: lastPlayerState,
    lastErrorCode: lastErrorCode,
    muted: muted,
    volume: volume,
    currentTime: currentTime,
    autoplayBlocked: autoplayBlocked,
  );
}

/// Un hallazgo automático de la Fase 6 — WARNING/ERROR cuando el orden real no coincide con el
/// esperado, OK para confirmar explícitamente que una regla puntual SÍ se cumplió (para no dejar
/// la duda de si no se detectó nada porque está todo bien o porque no se llegó a evaluar).
class DiagnosticFinding {
  const DiagnosticFinding(this.level, this.message);
  final MenziLogLevel level;
  final String message;

  String toLine() => '${level.label}: $message';
}

/// Corre las 10 detecciones automáticas de la Fase 6 sobre [entries] (orden cronológico, más
/// viejo primero) — cada una es una función libre más abajo para poder probarla suelta.
List<DiagnosticFinding> detectAnomalies(List<DiagnosticLogEntry> entries) {
  return [
    ...detectCommandBeforeReady(entries),
    ...detectForeignInstanceMessages(entries),
    ...detectMultipleGlobalInstances(entries),
    ...detectStalledCurrentTime(entries),
    ...detectVideoIdMismatch(entries),
    ...detectOldEventApplied(entries),
    ...detectRealPlayerError(entries),
  ];
}

String? _instanceIdOf(DiagnosticLogEntry e) => e.data?['instanceId'] as String?;

/// Cubre "load antes de iframeReady", "seek antes de video cargado", "play antes de ready" y
/// "unmute antes de state=1" — las cuatro son el mismo patrón (un YT_COMMAND que llegó antes de
/// la precondición que debía cumplirse primero), por instancia.
List<DiagnosticFinding> detectCommandBeforeReady(List<DiagnosticLogEntry> entries) {
  final findings = <DiagnosticFinding>[];
  final readyInstances = <String>{};
  final loadedInstances = <String>{};
  final playingState1Instances = <String>{};
  var anyChecked = false;

  for (final e in entries) {
    final instanceId = _instanceIdOf(e);
    if (e.category == DiagnosticCategory.ytInstance &&
        (e.message == 'iframe ready' || e.message == 'player ready') &&
        instanceId != null) {
      readyInstances.add(instanceId);
    }
    if (e.category == DiagnosticCategory.ytCommand && instanceId != null) {
      anyChecked = true;
      final cmd = e.data?['cmd'] as String?;
      if (cmd == 'load') {
        if (!readyInstances.contains(instanceId)) {
          findings.add(DiagnosticFinding(
            MenziLogLevel.warning,
            'load enviado antes de iframeReady (instance=$instanceId)',
          ));
        }
        loadedInstances.add(instanceId);
      } else if (cmd == 'seek') {
        if (!loadedInstances.contains(instanceId)) {
          findings.add(DiagnosticFinding(
            MenziLogLevel.warning,
            'seek enviado antes de cargar el video (instance=$instanceId)',
          ));
        }
      } else if (cmd == 'play') {
        if (!readyInstances.contains(instanceId)) {
          findings.add(DiagnosticFinding(
            MenziLogLevel.warning,
            'play enviado antes de que el player estuviera ready (instance=$instanceId)',
          ));
        }
      } else if (cmd == 'unmute') {
        if (!playingState1Instances.contains(instanceId)) {
          findings.add(DiagnosticFinding(
            MenziLogLevel.warning,
            'unmute enviado antes de state=1/playing (instance=$instanceId)',
          ));
        }
      }
    }
    if (e.category == DiagnosticCategory.ytState && instanceId != null) {
      final state = e.data?['state'];
      if (state == 1) playingState1Instances.add(instanceId);
    }
  }

  if (anyChecked && findings.isEmpty) {
    findings.add(const DiagnosticFinding(
      MenziLogLevel.info,
      'orden de comandos (load/seek/play/unmute) respetó las precondiciones esperadas',
    ));
  }
  return findings;
}

/// "comandos enviados a instancia incorrecta" — ya detectado y logueado en el momento por
/// `shouldAcceptBridgeMessage` (ver menzi_dj_provider.dart); acá solo se resume para el reporte.
List<DiagnosticFinding> detectForeignInstanceMessages(List<DiagnosticLogEntry> entries) {
  final foreign = entries.where(
    (e) => e.category == DiagnosticCategory.ytInstance && e.message.contains('foreign instance'),
  );
  if (foreign.isEmpty) return const [];
  return [
    DiagnosticFinding(
      MenziLogLevel.error,
      '${foreign.length} mensaje(s) de una instancia distinta a la activa fueron ignorados',
    ),
  ];
}

/// "WebView recreado" / "dos players activos" — si el player global ("global-...") llegó a
/// reportar ready con más de un instanceId distinto durante la misma sesión de logs, hubo más de
/// una instancia real corriendo (o una recreación) en algún momento.
List<DiagnosticFinding> detectMultipleGlobalInstances(List<DiagnosticLogEntry> entries) {
  final globalReadyIds = <String>{};
  for (final e in entries) {
    if (e.category != DiagnosticCategory.ytInstance) continue;
    if (e.message != 'iframe ready' && e.message != 'player ready') continue;
    final id = _instanceIdOf(e);
    if (id != null && id.startsWith('global-')) globalReadyIds.add(id);
  }
  if (globalReadyIds.length > 1) {
    return [
      DiagnosticFinding(
        MenziLogLevel.error,
        'se detectaron ${globalReadyIds.length} instancias globales distintas activas: ${globalReadyIds.join(", ")}',
      ),
    ];
  }
  return const [
    DiagnosticFinding(MenziLogLevel.info, 'una sola instancia global de Menzi DJ detectada'),
  ];
}

/// "currentTime sin avanzar" — 3 o más muestras consecutivas de YT_STATE con state=1 (playing)
/// pero el mismo currentTime exacto sugieren que el audio quedó congelado pese a reportarse como
/// reproduciendo (a diferencia de BUFFERING legítimo, que reporta state=3, no state=1).
List<DiagnosticFinding> detectStalledCurrentTime(List<DiagnosticLogEntry> entries) {
  double? lastTime;
  var streak = 0;
  for (final e in entries) {
    if (e.category != DiagnosticCategory.ytState) continue;
    final state = e.data?['state'];
    final time = (e.data?['currentTime'] as num?)?.toDouble();
    if (state != 1 || time == null) {
      lastTime = null;
      streak = 0;
      continue;
    }
    if (lastTime != null && time == lastTime) {
      streak++;
    } else {
      streak = 1;
    }
    lastTime = time;
    if (streak >= 3) {
      return [
        DiagnosticFinding(
          MenziLogLevel.error,
          'currentTime detenido en ${time}s durante $streak muestras seguidas con state=1',
        ),
      ];
    }
  }
  return const [];
}

/// "videoId solicitado distinto al cargado" — cualquier entrada (error o stateChange) que traiga
/// a la vez `requestedVideoId` y `actualVideoId`/`loadedVideoId` con valores distintos.
List<DiagnosticFinding> detectVideoIdMismatch(List<DiagnosticLogEntry> entries) {
  for (final e in entries) {
    final requested = e.data?['requestedVideoId'] as String?;
    final actual = (e.data?['actualVideoId'] ?? e.data?['loadedVideoId']) as String?;
    if (requested != null && actual != null && requested.isNotEmpty && actual.isNotEmpty && requested != actual) {
      return [
        DiagnosticFinding(
          MenziLogLevel.error,
          'videoId solicitado ($requested) distinto al reportado por el player ($actual)',
        ),
      ];
    }
  }
  return const [];
}

/// "evento antiguo aplicado" — un MUSIC_SESSION con mensaje "event applied" cuya version es MENOR
/// a la mayor ya vista antes en la sesión de logs (ver shouldApplyMusicEventVersion — esto debería
/// ser imposible en un dispositivo sano; que aparezca acá es señal real de un bug de versionado).
List<DiagnosticFinding> detectOldEventApplied(List<DiagnosticLogEntry> entries) {
  int? maxVersionSeen;
  for (final e in entries) {
    if (e.category != DiagnosticCategory.musicSession) continue;
    if (e.message != 'event applied') continue;
    final version = (e.data?['version'] as num?)?.toInt();
    if (version == null) continue;
    if (maxVersionSeen != null && version < maxVersionSeen) {
      return [
        DiagnosticFinding(
          MenziLogLevel.error,
          'se aplicó un evento con version=$version DESPUÉS de haber visto version=$maxVersionSeen',
        ),
      ];
    }
    maxVersionSeen = maxVersionSeen == null ? version : (version > maxVersionSeen ? version : maxVersionSeen);
  }
  return const [];
}

/// "error real del IFrame" — cualquier YT_ERROR presente se resume acá con su código exacto (ver
/// YtPlayerError.describe en menzi_dj_player_html.dart para la traducción legible).
List<DiagnosticFinding> detectRealPlayerError(List<DiagnosticLogEntry> entries) {
  final errors = entries.where((e) => e.category == DiagnosticCategory.ytError).toList();
  if (errors.isEmpty) {
    return const [
      DiagnosticFinding(MenziLogLevel.info, 'no se registró ningún onError real del IFrame Player'),
    ];
  }
  final last = errors.last;
  return [
    DiagnosticFinding(
      MenziLogLevel.error,
      'onError real del IFrame Player: errorCode=${last.data?['errorCode']} requestedVideoId=${last.data?['requestedVideoId']} instance=${last.data?['instanceId']}',
    ),
  ];
}
