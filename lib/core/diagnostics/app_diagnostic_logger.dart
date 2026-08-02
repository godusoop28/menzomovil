import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'device_session.dart';

/// Categorías fijas del pedido de diagnóstico en-app (sin ADB/logcat) — cada entrada de
/// [AppDiagnosticLogger] pertenece a exactamente una. `label` es el texto EXACTO que se muestra
/// en la pantalla de logs y en el TXT exportado.
enum DiagnosticCategory {
  build('BUILD'),
  live('LIVE'),
  stomp('STOMP'),
  musicSession('MUSIC_SESSION'),
  ytInstance('YT_INSTANCE'),
  ytBridge('YT_BRIDGE'),
  ytCommand('YT_COMMAND'),
  ytState('YT_STATE'),
  ytError('YT_ERROR'),
  autoplay('AUTOPLAY'),
  lifecycle('LIFECYCLE'),
  agora('AGORA');

  const DiagnosticCategory(this.label);
  final String label;
}

enum MenziLogLevel {
  info('OK'),
  warning('WARNING'),
  error('ERROR');

  const MenziLogLevel(this.label);
  final String label;
}

/// Nombres de campo que NUNCA deben quedar en un log, sin importar la categoría — comparación
/// case-insensitive y por substring, porque un campo real puede llamarse `accessToken`,
/// `refresh_token`, `agoraToken`, `Authorization`, etc. Ver Fase 1 del pedido de diagnóstico.
const _secretKeyFragments = [
  'token',
  'jwt',
  'password',
  'contrasena',
  'apikey',
  'api_key',
  'secret',
  'authorization',
  'certificate',
  'credential',
];

/// Un valor de texto que *parece* un JWT (tres tramos base64url separados por puntos) se redacta
/// aunque venga en un campo con un nombre inocente — defensa en profundidad, no solo por nombre
/// de clave (ver [_secretKeyFragments]).
final _jwtLikePattern = RegExp(r'^[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}$');

const redactedPlaceholder = '[REDACTADO]';

/// Copia [data] reemplazando cualquier valor sensible por [redactedPlaceholder] — nunca muta el
/// mapa original (los llamadores suelen pasar el mismo mapa que después siguen usando). Pública y
/// pura a propósito: es lo primero que corre dentro de [AppDiagnosticLogger.log], y se prueba
/// directo en menzi_dj_diagnostic_logger_test.dart sin necesidad de pasar por el logger.
Map<String, dynamic>? redactSensitiveData(Map<String, dynamic>? data) {
  if (data == null) return null;
  final result = <String, dynamic>{};
  for (final entry in data.entries) {
    final keyLower = entry.key.toLowerCase();
    final isSecretKey = _secretKeyFragments.any(keyLower.contains);
    final value = entry.value;
    if (isSecretKey) {
      result[entry.key] = redactedPlaceholder;
    } else if (value is String && _jwtLikePattern.hasMatch(value)) {
      result[entry.key] = redactedPlaceholder;
    } else if (value is Map) {
      result[entry.key] = redactSensitiveData(Map<String, dynamic>.from(value));
    } else {
      result[entry.key] = value;
    }
  }
  return result;
}

class DiagnosticLogEntry {
  DiagnosticLogEntry({
    required this.timestamp,
    required this.deviceId,
    required this.category,
    required this.level,
    required this.message,
    this.data,
  });

  final DateTime timestamp;
  final String deviceId;
  final DiagnosticCategory category;
  final MenziLogLevel level;
  final String message;
  final Map<String, dynamic>? data;

  String get timeLabel {
    final t = timestamp;
    String two(int n) => n.toString().padLeft(2, '0');
    String three(int n) => n.toString().padLeft(3, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}.${three(t.millisecond)}';
  }

  /// Línea de texto plano — misma que se usa en pantalla y en el TXT exportado (Fase 3/5 del
  /// pedido), así lo que el usuario ve en el celular es exactamente lo que termina compartiendo.
  String toLine() {
    final buffer = StringBuffer(
      '[$timeLabel][$deviceId][${category.label}][${level.label}] $message',
    );
    if (data != null && data!.isNotEmpty) {
      buffer.write(' ${jsonEncode(data)}');
    }
    return buffer.toString();
  }
}

/// Registro interno en memoria de DJ Menzi/LIVE — pensado para diagnosticar en dispositivos donde
/// no se puede activar depuración USB (ver Fase de diagnóstico sin ADB). Guarda como máximo
/// [maxEntries] líneas (ring buffer: la más vieja se descarta al llegar al límite) y nunca
/// persiste a disco por sí solo — solo vive en memoria del proceso, se exporta a pedido (ver
/// menzi_dj_logs_screen.dart).
///
/// No es un singleton "cerrado" (constructor público) a propósito: `instance` es la que usa la
/// app real, pero los tests instancian la clase directo para no compartir estado entre casos.
class AppDiagnosticLogger {
  AppDiagnosticLogger();

  static final AppDiagnosticLogger instance = AppDiagnosticLogger();

  static const maxEntries = 500;

  final List<DiagnosticLogEntry> _entries = [];
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  List<DiagnosticLogEntry> get entries => List.unmodifiable(_entries);

  void log(
    DiagnosticCategory category,
    MenziLogLevel level,
    String message, {
    Map<String, dynamic>? data,
  }) {
    final entry = DiagnosticLogEntry(
      timestamp: DateTime.now(),
      deviceId: DeviceSession.id,
      category: category,
      level: level,
      message: message,
      data: redactSensitiveData(data),
    );
    _entries.add(entry);
    if (_entries.length > maxEntries) {
      _entries.removeAt(0);
    }
    revision.value++;
    // Espejo a debugPrint — sin costo si no hay debugger/USB conectado, y sigue siendo útil
    // cuando sí lo hay. La fuente de verdad para el usuario sin ADB es `_entries`, no esto.
    debugPrint(entry.toLine());
  }

  void clear() {
    _entries.clear();
    revision.value++;
  }

  List<DiagnosticLogEntry> filtered({
    Set<DiagnosticCategory>? categories,
    bool onlyErrors = false,
  }) {
    return _entries.where((e) {
      if (onlyErrors && e.level != MenziLogLevel.error) return false;
      if (categories != null &&
          categories.isNotEmpty &&
          !categories.contains(e.category)) {
        return false;
      }
      return true;
    }).toList();
  }
}
