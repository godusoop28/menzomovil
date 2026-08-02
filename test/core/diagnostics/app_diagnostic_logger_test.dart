import 'package:flutter_test/flutter_test.dart';
import 'package:menzomovil/core/diagnostics/app_diagnostic_logger.dart';

void main() {
  group('AppDiagnosticLogger — límite de 500 entradas', () {
    test('nunca guarda más de 500, descartando la más vieja primero', () {
      final logger = AppDiagnosticLogger();
      for (var i = 0; i < 510; i++) {
        logger.log(DiagnosticCategory.ytCommand, MenziLogLevel.info, 'entry $i');
      }
      expect(logger.entries.length, AppDiagnosticLogger.maxEntries);
      expect(logger.entries.first.message, 'entry 10');
      expect(logger.entries.last.message, 'entry 509');
    });

    test('clear() vacía todo', () {
      final logger = AppDiagnosticLogger();
      logger.log(DiagnosticCategory.live, MenziLogLevel.info, 'x');
      logger.clear();
      expect(logger.entries, isEmpty);
    });
  });

  group('redactSensitiveData — secretos nunca guardados', () {
    test('redacta claves con nombres sensibles, sin importar mayúsculas/guiones bajos', () {
      final result = redactSensitiveData({
        'accessToken': 'abc.def.ghi',
        'refresh_token': 'xyz',
        'Authorization': 'Bearer abc',
        'agoraToken': 'zzz',
        'password': '123456',
        'apiKey': 'k-123',
        'videoId': 'dQw4w9WgXcQ',
      });
      expect(result!['accessToken'], redactedPlaceholder);
      expect(result['refresh_token'], redactedPlaceholder);
      expect(result['Authorization'], redactedPlaceholder);
      expect(result['agoraToken'], redactedPlaceholder);
      expect(result['password'], redactedPlaceholder);
      expect(result['apiKey'], redactedPlaceholder);
      expect(result['videoId'], 'dQw4w9WgXcQ');
    });

    test('redacta un valor con forma de JWT aunque la clave sea inocente', () {
      final result = redactSensitiveData({
        'someField': 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dQw4w9WgXcQdQw4w9WgXcQ',
      });
      expect(result!['someField'], redactedPlaceholder);
    });

    test('redacta recursivamente mapas anidados', () {
      final result = redactSensitiveData({
        'nested': {'jwt': 'secreto'},
      });
      expect((result!['nested'] as Map)['jwt'], redactedPlaceholder);
    });

    test('log() nunca persiste un secreto en las entradas guardadas', () {
      final logger = AppDiagnosticLogger();
      logger.log(
        DiagnosticCategory.stomp,
        MenziLogLevel.info,
        'connected',
        data: {'token': 'super-secreto'},
      );
      expect(logger.entries.single.toLine(), isNot(contains('super-secreto')));
      expect(logger.entries.single.toLine(), contains(redactedPlaceholder));
    });

    test('valores no sensibles pasan intactos', () {
      final result = redactSensitiveData({'videoId': 'abc', 'volume': 80});
      expect(result, {'videoId': 'abc', 'volume': 80});
    });
  });

  group('filtered', () {
    test('onlyErrors filtra por nivel', () {
      final logger = AppDiagnosticLogger();
      logger.log(DiagnosticCategory.ytError, MenziLogLevel.error, 'boom');
      logger.log(DiagnosticCategory.ytState, MenziLogLevel.info, 'ok');
      final result = logger.filtered(onlyErrors: true);
      expect(result, hasLength(1));
      expect(result.single.message, 'boom');
    });

    test('categories filtra por categoría', () {
      final logger = AppDiagnosticLogger();
      logger.log(DiagnosticCategory.stomp, MenziLogLevel.info, 'a');
      logger.log(DiagnosticCategory.live, MenziLogLevel.info, 'b');
      final result = logger.filtered(categories: {DiagnosticCategory.live});
      expect(result, hasLength(1));
      expect(result.single.category, DiagnosticCategory.live);
    });
  });
}
