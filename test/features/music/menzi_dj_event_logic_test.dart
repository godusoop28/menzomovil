import 'package:flutter_test/flutter_test.dart';
import 'package:menzomovil/features/music/menzi_dj_provider.dart';

/// Cubre las decisiones puras que MenziDjNotifier usa para versionado (Fase 3) y corrección de
/// drift (Fase 9) — extraídas como funciones libres de estado precisamente para poder probarlas
/// sin levantar un WebView/StompChannel real (ver comentarios junto a cada función en
/// menzi_dj_provider.dart).
void main() {
  group('shouldApplyMusicEventVersion', () {
    test('aplica una versión mayor', () {
      expect(
        shouldApplyMusicEventVersion(incomingVersion: 5, currentVersion: 4),
        isTrue,
      );
    });

    test('ignora la misma versión (reenvío/eco)', () {
      expect(
        shouldApplyMusicEventVersion(incomingVersion: 4, currentVersion: 4),
        isFalse,
      );
    });

    test('ignora una versión anterior (evento desordenado)', () {
      expect(
        shouldApplyMusicEventVersion(incomingVersion: 3, currentVersion: 4),
        isFalse,
      );
    });

    test('aplica si no hay sesión previa (primera vez)', () {
      expect(
        shouldApplyMusicEventVersion(incomingVersion: 1, currentVersion: null),
        isTrue,
      );
    });

    test('aplica si el evento no trae versión', () {
      expect(
        shouldApplyMusicEventVersion(incomingVersion: null, currentVersion: 10),
        isTrue,
      );
    });
  });

  group('classifyDrift', () {
    test('menor a 1.5s no corrige nada', () {
      expect(classifyDrift(1.0), DriftAction.none);
      expect(classifyDrift(-1.4), DriftAction.none);
    });

    test('entre 1.5s y 4s corrige suave', () {
      expect(classifyDrift(2.0), DriftAction.softCorrect);
      expect(classifyDrift(-3.9), DriftAction.softCorrect);
    });

    test('mayor a 4s hace seek directo', () {
      expect(classifyDrift(4.1), DriftAction.hardSeek);
      expect(classifyDrift(-10), DriftAction.hardSeek);
    });

    test('los límites exactos de banda no corrigen (estrictamente mayor)', () {
      expect(classifyDrift(1.5), DriftAction.none);
      expect(classifyDrift(4.0), DriftAction.softCorrect);
    });
  });

  group('softCorrectionRateFor', () {
    test('atrasado (negativo) acelera', () {
      expect(softCorrectionRateFor(-2.0), 1.25);
    });

    test('adelantado (positivo) frena', () {
      expect(softCorrectionRateFor(2.0), 0.75);
    });
  });
}
