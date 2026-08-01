import 'package:flutter_test/flutter_test.dart';
import 'package:menzomovil/data/models/music_models.dart';

/// Cubre el parseo del contrato real que manda menzoapi (ver MusicSessionResponse.java) — mismo
/// shape que viaja tanto en el GET de snapshot como en el `payload` de los eventos STOMP que sí
/// traen sesión completa (ver MenziDjNotifier._handleMusicEvent). Si alguno de los dos lados
/// cambia un nombre de campo sin que el otro se entere, este test es el que lo nota antes que un
/// dispositivo real.
void main() {
  group('MusicSession.fromJson', () {
    test('parsea un snapshot completo con cola, pendientes e historial', () {
      final json = {
        'musicSessionId': 'session-1',
        'roomId': 'room-1',
        'liveSessionId': 'live-1',
        'status': 'PLAYING',
        'currentQueueItemId': 'item-1',
        'currentVideoId': 'dQw4w9WgXcQ',
        'currentTitle': 'Never Gonna Give You Up',
        'currentChannelTitle': 'Rick Astley',
        'currentThumbnailUrl': 'https://example.com/thumb.jpg',
        'durationSeconds': 213,
        'positionSeconds': 42,
        'allowRequests': true,
        'version': 7,
        'queue': [
          {
            'id': 'item-2',
            'videoId': 'abc123',
            'title': 'Next track',
            'channelTitle': 'Some channel',
            'thumbnailUrl': null,
            'durationSeconds': 180,
            'requestedBy': null,
            'approvedBy': null,
            'position': 0,
            'status': 'QUEUED',
            'createdAt': '2026-07-31T12:00:00Z',
          },
        ],
        'pendingRequests': <Map<String, dynamic>>[],
        'history': <Map<String, dynamic>>[],
      };

      final session = MusicSession.fromJson(json);

      expect(session.musicSessionId, 'session-1');
      expect(session.roomId, 'room-1');
      expect(session.liveSessionId, 'live-1');
      expect(session.status, MusicSessionStatus.playing);
      expect(session.currentVideoId, 'dQw4w9WgXcQ');
      expect(session.durationSeconds, 213);
      expect(session.positionSeconds, 42);
      expect(session.allowRequests, isTrue);
      expect(session.version, 7);
      expect(session.queue, hasLength(1));
      expect(session.queue.first.videoId, 'abc123');
      expect(session.queue.first.status, QueueItemStatus.queued);
      expect(session.pendingRequests, isEmpty);
      expect(session.history, isEmpty);
    });

    test('status desconocido cae a idle en vez de tirar', () {
      expect(
        musicStatusFromJson('ALGO_QUE_NO_EXISTE'),
        MusicSessionStatus.idle,
      );
    });

    test('campos opcionales ausentes usan sus defaults', () {
      final json = {
        'musicSessionId': 'session-1',
        'roomId': 'room-1',
        'liveSessionId': 'live-1',
        'status': 'IDLE',
        'currentQueueItemId': null,
        'currentVideoId': null,
        'currentTitle': null,
        'currentChannelTitle': null,
        'currentThumbnailUrl': null,
        'durationSeconds': null,
        'status2': null,
      };
      final session = MusicSession.fromJson(json);
      expect(session.positionSeconds, 0);
      expect(session.allowRequests, isTrue);
      expect(session.version, 0);
      expect(session.queue, isEmpty);
    });
  });

  group('QueueItem.fromJson', () {
    test('parsea requestedBy/approvedBy cuando vienen presentes', () {
      final json = {
        'id': 'item-1',
        'videoId': 'xyz',
        'title': 'Title',
        'channelTitle': 'Channel',
        'thumbnailUrl': null,
        'durationSeconds': 100,
        'requestedBy': {
          'id': 'user-1',
          'displayName': 'Ana',
          'username': 'ana',
          'avatarUri': null,
          'avatarGradient': null,
          'isOnline': true,
        },
        'approvedBy': null,
        'position': null,
        'status': 'PENDING',
        'createdAt': '2026-07-31T12:00:00Z',
      };

      final item = QueueItem.fromJson(json);

      expect(item.requestedBy?.displayName, 'Ana');
      expect(item.approvedBy, isNull);
      expect(item.status, QueueItemStatus.pending);
    });
  });
}
