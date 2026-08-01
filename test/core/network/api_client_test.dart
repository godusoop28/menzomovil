import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:menzomovil/core/network/api_client.dart';

/// `isJwtCloseToExpiry` es lo que decide, antes de cada connect/reconnect de STOMP, si hace
/// falta refrescar el access token (ver ApiClient.ensureFreshAccessToken) — a diferencia de REST,
/// un CONNECT con un JWT vencido no tiene un 401 al que reaccionar después. Estos tests
/// construyen JWTs falsos (mismo formato header.payload.signature en base64url, firma no
/// verificada) con un `exp` controlado, sin necesitar el backend real ni SecureStorage.
String _fakeJwt(Map<String, dynamic> payload) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode({
    'alg': 'HS256',
  })}.${encode(payload)}.fake-signature';
}

void main() {
  group('isJwtCloseToExpiry', () {
    test('token con exp bien en el futuro no está cerca de vencer', () {
      final now = DateTime.utc(2026, 1, 1, 12, 0, 0);
      final exp = now.add(const Duration(minutes: 15)).millisecondsSinceEpoch ~/ 1000;
      final jwt = _fakeJwt({'exp': exp});

      expect(isJwtCloseToExpiry(jwt, now: now), isFalse);
    });

    test('token que ya venció está cerca de vencer', () {
      final now = DateTime.utc(2026, 1, 1, 12, 0, 0);
      final exp = now.subtract(const Duration(minutes: 1)).millisecondsSinceEpoch ~/ 1000;
      final jwt = _fakeJwt({'exp': exp});

      expect(isJwtCloseToExpiry(jwt, now: now), isTrue);
    });

    test('token a punto de vencer (dentro del margen) cuenta como cerca', () {
      final now = DateTime.utc(2026, 1, 1, 12, 0, 0);
      final exp = now.add(const Duration(seconds: 10)).millisecondsSinceEpoch ~/ 1000;
      final jwt = _fakeJwt({'exp': exp});

      expect(
        isJwtCloseToExpiry(jwt, now: now, skew: const Duration(seconds: 30)),
        isTrue,
      );
    });

    test('token malformado (no tiene 3 partes) no bloquea la conexión', () {
      expect(isJwtCloseToExpiry('no-es-un-jwt'), isFalse);
    });

    test('payload sin exp no bloquea la conexión', () {
      final jwt = _fakeJwt({'sub': 'user-1'});
      expect(isJwtCloseToExpiry(jwt), isFalse);
    });

    test('respeta un margen (skew) custom', () {
      final now = DateTime.utc(2026, 1, 1, 12, 0, 0);
      final exp = now.add(const Duration(minutes: 2)).millisecondsSinceEpoch ~/ 1000;
      final jwt = _fakeJwt({'exp': exp});

      expect(
        isJwtCloseToExpiry(jwt, now: now, skew: const Duration(minutes: 1)),
        isFalse,
      );
      expect(
        isJwtCloseToExpiry(jwt, now: now, skew: const Duration(minutes: 5)),
        isTrue,
      );
    });
  });
}
