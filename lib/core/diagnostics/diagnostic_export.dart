import 'app_diagnostic_logger.dart';
import 'device_info_snapshot.dart';
import 'diagnostic_summary.dart';

/// `menzo-dj-diagnostic-2026-08-01-183000.txt` — nombre determinista a partir de [now], para que
/// dos exportaciones seguidas no se pisen si el usuario genera varias en la misma sesión.
String diagnosticFileName(DateTime now) {
  String two(int n) => n.toString().padLeft(2, '0');
  final date = '${now.year}-${two(now.month)}-${two(now.day)}';
  final time = '${two(now.hour)}${two(now.minute)}${two(now.second)}';
  return 'menzo-dj-diagnostic-$date-$time.txt';
}

/// Arma el contenido completo del archivo a compartir (Fase 5/6 del pedido): info de build/
/// dispositivo, todos los registros en orden y el resumen + hallazgos automáticos al final.
/// Función pura — recibe los datos ya capturados, no depende de plugins ni del logger global,
/// así se puede probar con una lista de entradas armada a mano.
String buildDiagnosticReportText({
  required DeviceInfoSnapshot device,
  required List<DiagnosticLogEntry> entries,
}) {
  final buffer = StringBuffer();
  buffer.writeln('=== MENZO — DIAGNÓSTICO DE MENZI DJ ===');
  buffer.writeln('generado: ${DateTime.now().toIso8601String()}');
  buffer.writeln();
  buffer.writeln('=== BUILD / DISPOSITIVO ===');
  buffer.writeln(device.toBlock());
  buffer.writeln();
  buffer.writeln('=== REGISTROS (${entries.length}) ===');
  for (final entry in entries) {
    buffer.writeln(entry.toLine());
  }
  buffer.writeln();
  buffer.writeln(buildDiagnosticSummary(entries).toBlock());
  buffer.writeln();
  buffer.writeln('=== DETECCIÓN AUTOMÁTICA ===');
  for (final finding in detectAnomalies(entries)) {
    buffer.writeln(finding.toLine());
  }
  return buffer.toString();
}
