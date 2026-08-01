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
}
