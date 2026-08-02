import 'package:flutter_test/flutter_test.dart';
import 'package:menzomovil/core/diagnostics/app_diagnostic_logger.dart';
import 'package:menzomovil/core/diagnostics/device_info_snapshot.dart';
import 'package:menzomovil/core/diagnostics/diagnostic_export.dart';

void main() {
  test('diagnosticFileName sigue el formato menzo-dj-diagnostic-YYYY-MM-DD-HHmmss.txt', () {
    final name = diagnosticFileName(DateTime(2026, 8, 1, 18, 30, 0));
    expect(name, 'menzo-dj-diagnostic-2026-08-01-183000.txt');
  });

  test('buildDiagnosticReportText incluye build/dispositivo, registros y resumen', () {
    const device = DeviceInfoSnapshot(
      appVersion: '1.0.0',
      buildNumber: '1',
      commit: 'abc1234',
      deviceModel: 'Samsung Galaxy A10',
      androidVersion: 'Android 11 (SDK 30)',
      webViewVersion: 'no disponible vía API pública en este dispositivo',
      deviceId: 'device-1',
    );
    final logger = AppDiagnosticLogger();
    logger.log(DiagnosticCategory.live, MenziLogLevel.info, 'connected', data: {'roomId': 'room-1'});
    logger.log(DiagnosticCategory.ytError, MenziLogLevel.error, 'onError', data: {'errorCode': 153});

    final text = buildDiagnosticReportText(device: device, entries: logger.entries);

    expect(text, contains('=== MENZO — DIAGNÓSTICO DE MENZI DJ ==='));
    expect(text, contains('appVersion: 1.0.0'));
    expect(text, contains('deviceModel: Samsung Galaxy A10'));
    expect(text, contains('=== REGISTROS (2) ==='));
    expect(text, contains('connected'));
    expect(text, contains('=== RESUMEN ==='));
    expect(text, contains('lastErrorCode: 153'));
    expect(text, contains('=== DETECCIÓN AUTOMÁTICA ==='));
  });

  test('el reporte nunca contiene un secreto aunque se haya logueado uno', () {
    const device = DeviceInfoSnapshot(
      appVersion: '1.0.0',
      buildNumber: '1',
      commit: 'abc1234',
      deviceModel: null,
      androidVersion: null,
      webViewVersion: null,
      deviceId: 'device-1',
    );
    final logger = AppDiagnosticLogger();
    logger.log(DiagnosticCategory.stomp, MenziLogLevel.info, 'connected', data: {'jwt': 'super-secreto-123'});

    final text = buildDiagnosticReportText(device: device, entries: logger.entries);
    expect(text, isNot(contains('super-secreto-123')));
  });
}
