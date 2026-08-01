import 'package:flutter_test/flutter_test.dart';
import 'package:menzomovil/core/diagnostics/device_session.dart';

void main() {
  test(
    'DeviceSession.id es un string hex no vacío, estable durante la ejecución',
    () {
      expect(DeviceSession.id, isNotEmpty);
      expect(RegExp(r'^[0-9a-f]+$').hasMatch(DeviceSession.id), isTrue);
      // Mismo valor si se lee de nuevo — es un `static final`, no se regenera por lectura.
      expect(DeviceSession.id, DeviceSession.id);
    },
  );
}
