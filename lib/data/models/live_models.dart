import 'user_models.dart';

enum LiveParticipantRole { host, coHost, speaker, audience, requested }

LiveParticipantRole liveRoleFromJson(String value) {
  switch (value) {
    case 'HOST':
      return LiveParticipantRole.host;
    case 'CO_HOST':
      return LiveParticipantRole.coHost;
    case 'SPEAKER':
      return LiveParticipantRole.speaker;
    case 'REQUESTED':
      return LiveParticipantRole.requested;
    default:
      return LiveParticipantRole.audience;
  }
}

bool canSpeakRole(LiveParticipantRole? role) =>
    role == LiveParticipantRole.host ||
    role == LiveParticipantRole.coHost ||
    role == LiveParticipantRole.speaker;

class LiveSession {
  const LiveSession({
    required this.id,
    required this.roomId,
    required this.status,
    required this.title,
    required this.description,
    required this.announcement,
    required this.startedAt,
    required this.participantCount,
    required this.speakerCount,
    required this.myRole,
    required this.myMicrophoneEnabled,
    required this.hasPendingSpeakRequest,
  });

  final String id;
  final String roomId;
  final String status; // ACTIVE | ENDED
  final String? title;
  final String? description;
  final String? announcement;
  final DateTime? startedAt;
  final int participantCount;
  final int speakerCount;
  final LiveParticipantRole? myRole;
  final bool myMicrophoneEnabled;
  final bool hasPendingSpeakRequest;

  factory LiveSession.fromJson(Map<String, dynamic> json) => LiveSession(
    id: json['id'] as String,
    roomId: json['roomId'] as String,
    status: json['status'] as String,
    title: json['title'] as String?,
    description: json['description'] as String?,
    announcement: json['announcement'] as String?,
    startedAt: json['startedAt'] != null
        ? DateTime.parse(json['startedAt'] as String).toLocal()
        : null,
    participantCount: json['participantCount'] as int? ?? 0,
    speakerCount: json['speakerCount'] as int? ?? 0,
    myRole: json['myRole'] != null
        ? liveRoleFromJson(json['myRole'] as String)
        : null,
    myMicrophoneEnabled: json['myMicrophoneEnabled'] as bool? ?? false,
    hasPendingSpeakRequest: json['hasPendingSpeakRequest'] as bool? ?? false,
  );
}

class LiveParticipant {
  const LiveParticipant({
    required this.user,
    required this.role,
    required this.microphoneEnabled,
    required this.requestedToSpeakAt,
    required this.joinedAt,
    this.speakingLevel = 0,
  });

  final UserSummary? user;
  final LiveParticipantRole role;
  final bool microphoneEnabled;
  final DateTime? requestedToSpeakAt;
  final DateTime joinedAt;

  /// 0-1, viene de Agora (onAudioVolumeIndication) — nunca del backend.
  final double speakingLevel;

  factory LiveParticipant.fromJson(Map<String, dynamic> json) =>
      LiveParticipant(
        user: json['user'] != null
            ? UserSummary.fromJson(json['user'] as Map<String, dynamic>)
            : null,
        role: liveRoleFromJson(json['role'] as String),
        microphoneEnabled: json['microphoneEnabled'] as bool? ?? false,
        requestedToSpeakAt: json['requestedToSpeakAt'] != null
            ? DateTime.parse(json['requestedToSpeakAt'] as String).toLocal()
            : null,
        joinedAt: DateTime.parse(json['joinedAt'] as String).toLocal(),
      );

  LiveParticipant withSpeakingLevel(double level) => LiveParticipant(
    user: user,
    role: role,
    microphoneEnabled: microphoneEnabled,
    requestedToSpeakAt: requestedToSpeakAt,
    joinedAt: joinedAt,
    speakingLevel: level,
  );
}

class LiveToken {
  const LiveToken({
    required this.appId,
    required this.channelName,
    required this.token,
    required this.uid,
  });
  final String appId;
  final String channelName;
  final String token;
  final String uid;

  factory LiveToken.fromJson(Map<String, dynamic> json) => LiveToken(
    appId: json['appId'] as String,
    channelName: json['channelName'] as String,
    token: json['token'] as String,
    uid: json['uid'].toString(),
  );
}

/// Discriminador del envelope `/topic/rooms/{roomId}/live` — ver LiveEventType en menzoapi.
class LiveEvent {
  const LiveEvent({
    required this.type,
    required this.roomId,
    required this.payload,
  });
  final String type;
  final String roomId;
  final Map<String, dynamic>? payload;

  factory LiveEvent.fromJson(Map<String, dynamic> json) => LiveEvent(
    type: json['type'] as String,
    roomId: json['roomId'] as String,
    payload: json['payload'] as Map<String, dynamic>?,
  );
}
