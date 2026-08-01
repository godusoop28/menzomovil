import 'package:flutter_test/flutter_test.dart';
import 'package:menzomovil/features/music/menzi_dj_player_html.dart';

void main() {
  group('YtPlayerError', () {
    test('isEmbedRestricted reconoce los dos códigos documentados', () {
      expect(YtPlayerError.isEmbedRestricted(101), isTrue);
      expect(YtPlayerError.isEmbedRestricted(150), isTrue);
      expect(YtPlayerError.isEmbedRestricted(100), isFalse);
    });

    test('describe da un mensaje distinto por código conocido', () {
      expect(YtPlayerError.describe(100), contains('no está disponible'));
      expect(YtPlayerError.describe(101), contains('no permite reproducirlo'));
      expect(YtPlayerError.describe(2), contains('inválido'));
    });

    test('describe no falla ante un código no documentado', () {
      expect(YtPlayerError.describe(9999), contains('9999'));
    });
  });

  group('YtPlayerState', () {
    test('los valores espejan YT.PlayerState del IFrame API oficial', () {
      expect(YtPlayerState.unstarted, -1);
      expect(YtPlayerState.ended, 0);
      expect(YtPlayerState.playing, 1);
      expect(YtPlayerState.paused, 2);
      expect(YtPlayerState.buffering, 3);
      expect(YtPlayerState.cued, 5);
    });
  });
}
