import 'package:flutter_test/flutter_test.dart';
import 'package:menzomovil/data/models/live_models.dart';

void main() {
  group('LiveSession.fromJson', () {
    test('parsea myRole y banderas propias', () {
      final json = {
        'id': 'live-1',
        'roomId': 'room-1',
        'status': 'ACTIVE',
        'title': 'Charla',
        'description': null,
        'announcement': null,
        'startedAt': '2026-07-31T12:00:00Z',
        'participantCount': 3,
        'speakerCount': 2,
        'myRole': 'CO_HOST',
        'myMicrophoneEnabled': false,
        'hasPendingSpeakRequest': false,
      };

      final session = LiveSession.fromJson(json);

      expect(session.status, 'ACTIVE');
      expect(session.myRole, LiveParticipantRole.coHost);
      expect(session.myMicrophoneEnabled, isFalse);
      expect(session.participantCount, 3);
    });

    test('myRole null cuando el viewer no está en el LIVE', () {
      final json = {
        'id': 'live-1',
        'roomId': 'room-1',
        'status': 'ACTIVE',
        'title': null,
        'description': null,
        'announcement': null,
        'startedAt': null,
        'myRole': null,
      };
      final session = LiveSession.fromJson(json);
      expect(session.myRole, isNull);
      expect(session.participantCount, 0);
    });
  });

  group('canSpeakRole', () {
    test('host/coHost/speaker pueden hablar, audience/requested no', () {
      expect(canSpeakRole(LiveParticipantRole.host), isTrue);
      expect(canSpeakRole(LiveParticipantRole.coHost), isTrue);
      expect(canSpeakRole(LiveParticipantRole.speaker), isTrue);
      expect(canSpeakRole(LiveParticipantRole.audience), isFalse);
      expect(canSpeakRole(LiveParticipantRole.requested), isFalse);
      expect(canSpeakRole(null), isFalse);
    });
  });

  group('LiveParticipant.fromJson', () {
    test('parsea el usuario embebido y el rol', () {
      final json = {
        'user': {
          'id': 'user-1',
          'displayName': 'Ana',
          'username': 'ana',
          'avatarUri': null,
          'avatarGradient': null,
          'isOnline': true,
        },
        'role': 'SPEAKER',
        'microphoneEnabled': true,
        'requestedToSpeakAt': null,
        'joinedAt': '2026-07-31T12:00:00Z',
      };

      final participant = LiveParticipant.fromJson(json);

      expect(participant.user?.displayName, 'Ana');
      expect(participant.role, LiveParticipantRole.speaker);
      expect(participant.microphoneEnabled, isTrue);
      expect(participant.speakingLevel, 0);
    });
  });

  group('LiveEvent.fromJson', () {
    test('conserva el payload crudo para que el llamador lo interprete', () {
      final json = {
        'type': 'CHAT_LIVE_MICROPHONE_CHANGED',
        'roomId': 'room-1',
        'payload': {
          'user': {'id': 'user-1'},
          'microphoneEnabled': false,
        },
      };
      final event = LiveEvent.fromJson(json);
      expect(event.type, 'CHAT_LIVE_MICROPHONE_CHANGED');
      expect(event.payload?['microphoneEnabled'], isFalse);
    });
  });
}
