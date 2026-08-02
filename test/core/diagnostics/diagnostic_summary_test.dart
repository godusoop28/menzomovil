import 'package:flutter_test/flutter_test.dart';
import 'package:menzomovil/core/diagnostics/app_diagnostic_logger.dart';
import 'package:menzomovil/core/diagnostics/diagnostic_summary.dart';

DiagnosticLogEntry _entry(
  DiagnosticCategory category,
  String message, {
  Map<String, dynamic>? data,
  MenziLogLevel level = MenziLogLevel.info,
}) {
  return DiagnosticLogEntry(
    timestamp: DateTime(2026, 8, 1),
    deviceId: 'device-1',
    category: category,
    level: level,
    message: message,
    data: data,
  );
}

void main() {
  group('buildDiagnosticSummary', () {
    test('reconstruye el último valor visto de cada campo', () {
      final entries = [
        _entry(DiagnosticCategory.live, 'connected', data: {'roomId': 'room-1', 'role': 'host'}),
        _entry(DiagnosticCategory.ytInstance, 'controller created', data: {'instanceId': 'global-1-1'}),
        _entry(DiagnosticCategory.ytInstance, 'page loaded', data: {'instanceId': 'global-1-1'}),
        _entry(DiagnosticCategory.ytInstance, 'iframe ready', data: {'instanceId': 'global-1-1', 'activePlayerCount': 1}),
        _entry(DiagnosticCategory.musicSession, 'snapshot received', data: {
          'videoId': 'xvVLWSsKjkI',
          'version': 5,
          'eventId': 'evt-5',
        }),
        _entry(DiagnosticCategory.ytCommand, 'command sent', data: {'cmd': 'play'}),
        _entry(DiagnosticCategory.ytState, 'stateChange', data: {'state': 1, 'muted': false, 'volume': 80, 'currentTime': 3.2}),
        _entry(DiagnosticCategory.ytError, 'onError', data: {'errorCode': 153}),
      ];

      final summary = buildDiagnosticSummary(entries);
      expect(summary.roomId, 'room-1');
      expect(summary.role, 'host');
      expect(summary.activeInstanceId, 'global-1-1');
      expect(summary.pageLoaded, isTrue);
      expect(summary.iframeReady, isTrue);
      expect(summary.activePlayerCount, 1);
      expect(summary.currentVideoId, 'xvVLWSsKjkI');
      expect(summary.lastVersion, 5);
      expect(summary.lastEventId, 'evt-5');
      expect(summary.lastCommand, 'play');
      expect(summary.lastPlayerState, 1);
      expect(summary.muted, isFalse);
      expect(summary.volume, 80);
      expect(summary.currentTime, 3.2);
      expect(summary.lastErrorCode, 153);
    });

    test('campos sin ningún dato quedan en null/default, no tiran', () {
      final summary = buildDiagnosticSummary(const []);
      expect(summary.roomId, isNull);
      expect(summary.pageLoaded, isFalse);
      expect(summary.autoplayBlocked, isFalse);
    });
  });

  group('detectCommandBeforeReady', () {
    test('detecta load antes de iframeReady', () {
      final entries = [
        _entry(DiagnosticCategory.ytCommand, 'command sent', data: {'instanceId': 'i1', 'cmd': 'load'}),
        _entry(DiagnosticCategory.ytInstance, 'iframe ready', data: {'instanceId': 'i1'}),
      ];
      final findings = detectCommandBeforeReady(entries);
      expect(findings.any((f) => f.level == MenziLogLevel.warning && f.message.contains('load enviado antes')), isTrue);
    });

    test('detecta unmute antes de state=1', () {
      final entries = [
        _entry(DiagnosticCategory.ytInstance, 'iframe ready', data: {'instanceId': 'i1'}),
        _entry(DiagnosticCategory.ytCommand, 'command sent', data: {'instanceId': 'i1', 'cmd': 'load'}),
        _entry(DiagnosticCategory.ytCommand, 'command sent', data: {'instanceId': 'i1', 'cmd': 'unmute'}),
      ];
      final findings = detectCommandBeforeReady(entries);
      expect(findings.any((f) => f.level == MenziLogLevel.warning && f.message.contains('unmute enviado antes')), isTrue);
    });

    test('orden correcto no produce warnings, solo un OK', () {
      final entries = [
        _entry(DiagnosticCategory.ytInstance, 'iframe ready', data: {'instanceId': 'i1'}),
        _entry(DiagnosticCategory.ytCommand, 'command sent', data: {'instanceId': 'i1', 'cmd': 'load'}),
        _entry(DiagnosticCategory.ytCommand, 'command sent', data: {'instanceId': 'i1', 'cmd': 'seek'}),
        _entry(DiagnosticCategory.ytCommand, 'command sent', data: {'instanceId': 'i1', 'cmd': 'play'}),
        _entry(DiagnosticCategory.ytState, 'stateChange', data: {'instanceId': 'i1', 'state': 1}),
        _entry(DiagnosticCategory.ytCommand, 'command sent', data: {'instanceId': 'i1', 'cmd': 'unmute'}),
      ];
      final findings = detectCommandBeforeReady(entries);
      expect(findings.every((f) => f.level == MenziLogLevel.info), isTrue);
      expect(findings, isNotEmpty);
    });
  });

  test('detectForeignInstanceMessages detecta mensajes de instancia ajena', () {
    final entries = [
      _entry(DiagnosticCategory.ytInstance, 'message from foreign instance ignored', level: MenziLogLevel.warning),
    ];
    final findings = detectForeignInstanceMessages(entries);
    expect(findings, isNotEmpty);
    expect(findings.single.level, MenziLogLevel.error);
  });

  test('detectMultipleGlobalInstances detecta más de una instancia global', () {
    final entries = [
      _entry(DiagnosticCategory.ytInstance, 'iframe ready', data: {'instanceId': 'global-1-100'}),
      _entry(DiagnosticCategory.ytInstance, 'iframe ready', data: {'instanceId': 'global-2-200'}),
    ];
    final findings = detectMultipleGlobalInstances(entries);
    expect(findings.single.level, MenziLogLevel.error);
  });

  test('detectStalledCurrentTime detecta currentTime congelado con state=1', () {
    final entries = [
      _entry(DiagnosticCategory.ytState, 'stateChange', data: {'state': 1, 'currentTime': 10.0}),
      _entry(DiagnosticCategory.ytState, 'stateChange', data: {'state': 1, 'currentTime': 10.0}),
      _entry(DiagnosticCategory.ytState, 'stateChange', data: {'state': 1, 'currentTime': 10.0}),
    ];
    final findings = detectStalledCurrentTime(entries);
    expect(findings, isNotEmpty);
    expect(findings.single.level, MenziLogLevel.error);
  });

  test('detectStalledCurrentTime no dispara si currentTime avanza normalmente', () {
    final entries = [
      _entry(DiagnosticCategory.ytState, 'stateChange', data: {'state': 1, 'currentTime': 10.0}),
      _entry(DiagnosticCategory.ytState, 'stateChange', data: {'state': 1, 'currentTime': 11.0}),
      _entry(DiagnosticCategory.ytState, 'stateChange', data: {'state': 1, 'currentTime': 12.0}),
    ];
    expect(detectStalledCurrentTime(entries), isEmpty);
  });

  test('detectVideoIdMismatch detecta requestedVideoId distinto al actual', () {
    final entries = [
      _entry(DiagnosticCategory.ytError, 'onError', data: {
        'requestedVideoId': 'aaa',
        'actualVideoId': 'bbb',
      }),
    ];
    expect(detectVideoIdMismatch(entries), isNotEmpty);
  });

  test('detectOldEventApplied detecta un evento con version menor aplicado después', () {
    final entries = [
      _entry(DiagnosticCategory.musicSession, 'event applied', data: {'version': 21}),
      _entry(DiagnosticCategory.musicSession, 'event applied', data: {'version': 20}),
    ];
    final findings = detectOldEventApplied(entries);
    expect(findings, isNotEmpty);
    expect(findings.single.level, MenziLogLevel.error);
  });

  test('detectRealPlayerError reporta el último onError real', () {
    final entries = [
      _entry(DiagnosticCategory.ytError, 'onError', data: {'errorCode': 153, 'instanceId': 'i1'}),
    ];
    final findings = detectRealPlayerError(entries);
    expect(findings.single.message, contains('153'));
  });

  test('detectRealPlayerError informa OK cuando no hay ningún error', () {
    final findings = detectRealPlayerError(const []);
    expect(findings.single.level, MenziLogLevel.info);
  });
}
