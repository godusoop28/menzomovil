import 'package:flutter_test/flutter_test.dart';
import 'package:menzomovil/core/config/app_config.dart';

void main() {
  group('AppConfig.menziDjPlayerUrl', () {
    test('es una URL https real derivada de menziDjOrigin — nunca un origen sintético', () {
      final uri = Uri.parse(AppConfig.menziDjPlayerUrl);
      expect(uri.scheme, 'https');
      expect(uri.scheme, isNot('about'));
      expect(uri.scheme, isNot('data'));
      expect(uri.scheme, isNot('file'));
      expect(uri.origin, AppConfig.menziDjOrigin);
      expect(AppConfig.menziDjPlayerUrl, endsWith('/menzi-player.html'));
    });

    test('menziDjOrigin no tiene ruta ni slash final', () {
      final uri = Uri.parse(AppConfig.menziDjOrigin);
      expect(uri.path, isEmpty);
      expect(AppConfig.menziDjOrigin, isNot(endsWith('/')));
    });
  });

  group('buildWebSocketUrl — bug real del puerto :0', () {
    test('nunca produce :0 — https sin puerto explícito usa 443', () {
      final url = buildWebSocketUrl('https://menzoapi.onrender.com');
      expect(url, 'wss://menzoapi.onrender.com:443/ws');
      expect(url, isNot(contains(':0/')));
    });

    test('http sin puerto explícito usa 80', () {
      final url = buildWebSocketUrl('http://localhost');
      expect(url, 'ws://localhost:80/ws');
    });

    test('respeta un puerto explícito ya presente en apiBaseUrl', () {
      final url = buildWebSocketUrl('http://localhost:8080');
      expect(url, 'ws://localhost:8080/ws');
    });

    test('Uri.parse confirma el bug real que motiva este fix: wss sin puerto explícito da port=0', () {
      // No es una suposición — así es como se armaba el WebSocket antes (AppConfig.wsUrl vía
      // replaceFirst), y `Uri` de Dart no tiene un puerto por defecto para ws/wss (solo para
      // http/https), a diferencia de lo que uno esperaría.
      expect(Uri.parse('wss://menzoapi.onrender.com/ws').port, 0);
    });
  });
}
