import 'package:flutter_test/flutter_test.dart';
import 'package:menzomovil/data/models/music_models.dart';
import 'package:menzomovil/features/music/menzi_dj_player_html.dart';
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

    test(
      'salto de versión: v21 PAUSED se aplica sobre v20 PLAYING, y una v20 desordenada después no la pisa',
      () {
        // Mismo ejemplo del pedido de estabilización: si llegan v20 PLAYING y v21 PAUSED (en
        // cualquier orden relativo mientras el player no estaba listo), lo que debe quedar
        // aplicado es siempre la versión más alta — nunca reproducir la v20 después de haber
        // visto la v21.
        const currentAfterV20 = 20;
        expect(
          shouldApplyMusicEventVersion(
            incomingVersion: 21,
            currentVersion: currentAfterV20,
          ),
          isTrue,
          reason: 'v21 es más nueva que v20 — debe aplicarse',
        );
        const currentAfterV21 = 21;
        expect(
          shouldApplyMusicEventVersion(
            incomingVersion: 20,
            currentVersion: currentAfterV21,
          ),
          isFalse,
          reason: 'v20 es más vieja que la v21 ya aplicada — nunca debe pisarla',
        );
      },
    );
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

  group('shouldAcceptBridgeMessage (auditoría de instancias)', () {
    test('acepta un mensaje sin instanceId (página abierta suelta en un browser)', () {
      expect(
        shouldAcceptBridgeMessage(
          messageInstanceId: null,
          activeInstanceId: 'global-1-1000',
        ),
        isTrue,
      );
    });

    test('acepta un mensaje de la instancia activa', () {
      expect(
        shouldAcceptBridgeMessage(
          messageInstanceId: 'global-1-1000',
          activeInstanceId: 'global-1-1000',
        ),
        isTrue,
      );
    });

    test('ignora un mensaje de una instancia distinta a la activa', () {
      expect(
        shouldAcceptBridgeMessage(
          messageInstanceId: 'global-2-2000',
          activeInstanceId: 'global-1-1000',
        ),
        isFalse,
      );
    });
  });

  group('generatePlayerInstanceId', () {
    test('nunca repite id entre llamadas, incluso con el mismo tag', () {
      final a = generatePlayerInstanceId('global');
      final b = generatePlayerInstanceId('global');
      expect(a, isNot(equals(b)));
    });

    test('conserva el tag como prefijo legible', () {
      expect(generatePlayerInstanceId('diagnostic'), startsWith('diagnostic-'));
    });
  });

  group('resetStateForRoomChange — bug confirmado con logs reales (joiner sin load)', () {
    test('preserva playerReady=true al cambiar de sala', () {
      const previous = MenziDjState(playerReady: true, expanded: true, localVolume: 30);
      final next = resetStateForRoomChange(previous);
      expect(next.playerReady, isTrue);
    });

    test('preserva playerReady=false tal cual (no lo fuerza a true)', () {
      const previous = MenziDjState(playerReady: false);
      expect(resetStateForRoomChange(previous).playerReady, isFalse);
    });

    test('descarta el resto del estado de la sala anterior (sesión, error de player, etc.)', () {
      const previous = MenziDjState(
        playerReady: true,
        playerErrorCode: 2,
        expanded: true,
        autoplayBlocked: true,
      );
      final next = resetStateForRoomChange(previous);
      expect(next.session, isNull);
      expect(next.playerErrorCode, isNull);
      expect(next.expanded, isFalse);
      expect(next.autoplayBlocked, isFalse);
    });
  });

  group('shouldRunDriftCorrection', () {
    test('no corre si el video de la sesión todavía no se cargó en el player', () {
      expect(
        shouldRunDriftCorrection(
          isBackgrounded: false,
          sessionStatus: MusicSessionStatus.playing,
          sessionSnapshotAt: DateTime.now(),
          sessionVideoId: 'wm7wx2Y6shA',
          loadedVideoId: null,
          localPlayerState: null,
        ),
        isFalse,
      );
    });

    test('no corre si loadedVideoId es de OTRO video que el de la sesión actual', () {
      expect(
        shouldRunDriftCorrection(
          isBackgrounded: false,
          sessionStatus: MusicSessionStatus.playing,
          sessionSnapshotAt: DateTime.now(),
          sessionVideoId: 'wm7wx2Y6shA',
          loadedVideoId: 'otroVideoId',
          localPlayerState: YtPlayerState.playing,
        ),
        isFalse,
      );
    });

    test('corre cuando el video coincide, está reproduciendo y no en background', () {
      expect(
        shouldRunDriftCorrection(
          isBackgrounded: false,
          sessionStatus: MusicSessionStatus.playing,
          sessionSnapshotAt: DateTime.now(),
          sessionVideoId: 'wm7wx2Y6shA',
          loadedVideoId: 'wm7wx2Y6shA',
          localPlayerState: YtPlayerState.playing,
        ),
        isTrue,
      );
    });

    test('no corre en background, ni pausado, ni buffering, ni sin sessionSnapshotAt', () {
      const base = (
        sessionStatus: MusicSessionStatus.playing,
        sessionVideoId: 'v1',
        loadedVideoId: 'v1',
      );
      expect(
        shouldRunDriftCorrection(
          isBackgrounded: true,
          sessionStatus: base.sessionStatus,
          sessionSnapshotAt: DateTime.now(),
          sessionVideoId: base.sessionVideoId,
          loadedVideoId: base.loadedVideoId,
          localPlayerState: YtPlayerState.playing,
        ),
        isFalse,
      );
      expect(
        shouldRunDriftCorrection(
          isBackgrounded: false,
          sessionStatus: MusicSessionStatus.paused,
          sessionSnapshotAt: DateTime.now(),
          sessionVideoId: base.sessionVideoId,
          loadedVideoId: base.loadedVideoId,
          localPlayerState: YtPlayerState.playing,
        ),
        isFalse,
      );
      expect(
        shouldRunDriftCorrection(
          isBackgrounded: false,
          sessionStatus: base.sessionStatus,
          sessionSnapshotAt: null,
          sessionVideoId: base.sessionVideoId,
          loadedVideoId: base.loadedVideoId,
          localPlayerState: YtPlayerState.playing,
        ),
        isFalse,
      );
      expect(
        shouldRunDriftCorrection(
          isBackgrounded: false,
          sessionStatus: base.sessionStatus,
          sessionSnapshotAt: DateTime.now(),
          sessionVideoId: base.sessionVideoId,
          loadedVideoId: base.loadedVideoId,
          localPlayerState: YtPlayerState.buffering,
        ),
        isFalse,
      );
    });
  });

  group('isPlayerCommandBeforeLoadError — error 2 recuperable, no un video inválido', () {
    test('clasifica error 2 con requestedVideoId/actualVideoId null y sesión con video como recuperable', () {
      expect(
        isPlayerCommandBeforeLoadError(
          errorCode: 2,
          requestedVideoId: null,
          actualVideoId: null,
          sessionCurrentVideoId: 'wm7wx2Y6shA',
        ),
        isTrue,
      );
    });

    test('NO lo clasifica como recuperable si requestedVideoId viene poblado (video real e inválido)', () {
      expect(
        isPlayerCommandBeforeLoadError(
          errorCode: 2,
          requestedVideoId: 'algunVideoId',
          actualVideoId: null,
          sessionCurrentVideoId: 'algunVideoId',
        ),
        isFalse,
      );
    });

    test('NO lo clasifica como recuperable para otros códigos de error', () {
      expect(
        isPlayerCommandBeforeLoadError(
          errorCode: 101,
          requestedVideoId: null,
          actualVideoId: null,
          sessionCurrentVideoId: 'wm7wx2Y6shA',
        ),
        isFalse,
      );
    });

    test('NO lo clasifica como recuperable si no hay ninguna sesión con video actual', () {
      expect(
        isPlayerCommandBeforeLoadError(
          errorCode: 2,
          requestedVideoId: null,
          actualVideoId: null,
          sessionCurrentVideoId: null,
        ),
        isFalse,
      );
    });
  });
}
