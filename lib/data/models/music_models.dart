import 'user_models.dart';

enum QueueItemStatus {
  pending,
  queued,
  playing,
  played,
  skipped,
  rejected,
  removed,
}

QueueItemStatus queueItemStatusFromJson(String value) =>
    QueueItemStatus.values.firstWhere(
      (e) => e.name.toUpperCase() == value,
      orElse: () => QueueItemStatus.pending,
    );

class QueueItem {
  const QueueItem({
    required this.id,
    required this.videoId,
    required this.title,
    required this.channelTitle,
    required this.thumbnailUrl,
    required this.durationSeconds,
    required this.requestedBy,
    required this.approvedBy,
    required this.position,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String videoId;
  final String title;
  final String channelTitle;
  final String? thumbnailUrl;
  final int? durationSeconds;
  final UserSummary? requestedBy;
  final UserSummary? approvedBy;
  final int? position;
  final QueueItemStatus status;
  final DateTime createdAt;

  factory QueueItem.fromJson(Map<String, dynamic> json) => QueueItem(
    id: json['id'] as String,
    videoId: json['videoId'] as String,
    title: json['title'] as String,
    channelTitle: json['channelTitle'] as String,
    thumbnailUrl: json['thumbnailUrl'] as String?,
    durationSeconds: json['durationSeconds'] as int?,
    requestedBy: json['requestedBy'] != null
        ? UserSummary.fromJson(json['requestedBy'] as Map<String, dynamic>)
        : null,
    approvedBy: json['approvedBy'] != null
        ? UserSummary.fromJson(json['approvedBy'] as Map<String, dynamic>)
        : null,
    position: json['position'] as int?,
    status: queueItemStatusFromJson(json['status'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
  );
}

enum MusicSessionStatus { idle, playing, paused, stopped, error }

MusicSessionStatus musicStatusFromJson(String value) =>
    MusicSessionStatus.values.firstWhere(
      (e) => e.name.toUpperCase() == value,
      orElse: () => MusicSessionStatus.idle,
    );

class MusicSession {
  const MusicSession({
    required this.musicSessionId,
    required this.roomId,
    required this.liveSessionId,
    required this.status,
    required this.currentQueueItemId,
    required this.currentVideoId,
    required this.currentTitle,
    required this.currentChannelTitle,
    required this.currentThumbnailUrl,
    required this.durationSeconds,
    required this.positionSeconds,
    required this.allowRequests,
    required this.version,
    required this.queue,
    required this.pendingRequests,
    required this.history,
  });

  final String musicSessionId;
  final String roomId;
  final String liveSessionId;
  final MusicSessionStatus status;
  final String? currentQueueItemId;
  final String? currentVideoId;
  final String? currentTitle;
  final String? currentChannelTitle;
  final String? currentThumbnailUrl;
  final int? durationSeconds;
  final int positionSeconds;
  final bool allowRequests;
  final int version;
  final List<QueueItem> queue;
  final List<QueueItem> pendingRequests;
  final List<QueueItem> history;

  factory MusicSession.fromJson(Map<String, dynamic> json) => MusicSession(
    musicSessionId: json['musicSessionId'] as String,
    roomId: json['roomId'] as String,
    liveSessionId: json['liveSessionId'] as String,
    status: musicStatusFromJson(json['status'] as String),
    currentQueueItemId: json['currentQueueItemId'] as String?,
    currentVideoId: json['currentVideoId'] as String?,
    currentTitle: json['currentTitle'] as String?,
    currentChannelTitle: json['currentChannelTitle'] as String?,
    currentThumbnailUrl: json['currentThumbnailUrl'] as String?,
    durationSeconds: json['durationSeconds'] as int?,
    positionSeconds: json['positionSeconds'] as int? ?? 0,
    allowRequests: json['allowRequests'] as bool? ?? true,
    version: json['version'] as int? ?? 0,
    queue: (json['queue'] as List? ?? const [])
        .map((e) => QueueItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    pendingRequests: (json['pendingRequests'] as List? ?? const [])
        .map((e) => QueueItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    history: (json['history'] as List? ?? const [])
        .map((e) => QueueItem.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class YoutubeSearchResult {
  const YoutubeSearchResult({
    required this.videoId,
    required this.title,
    required this.channelTitle,
    required this.thumbnailUrl,
    required this.durationSeconds,
    required this.embeddable,
    required this.live,
  });

  final String videoId;
  final String title;
  final String channelTitle;
  final String? thumbnailUrl;
  final int? durationSeconds;
  final bool embeddable;
  final bool live;

  factory YoutubeSearchResult.fromJson(Map<String, dynamic> json) =>
      YoutubeSearchResult(
        videoId: json['videoId'] as String,
        title: json['title'] as String,
        channelTitle: json['channelTitle'] as String,
        thumbnailUrl: json['thumbnailUrl'] as String?,
        durationSeconds: json['durationSeconds'] as int?,
        embeddable: json['embeddable'] as bool? ?? true,
        live: json['live'] as bool? ?? false,
      );
}
