import '../../core/network/api_client.dart';
import '../models/music_models.dart';

class MusicRepository {
  MusicRepository(this._client);
  final ApiClient _client;

  Future<MusicSession> snapshot(String roomId) async => MusicSession.fromJson(
    await _client.get<Map<String, dynamic>>(
      '/api/chat/rooms/$roomId/live/music',
    ),
  );

  Future<List<YoutubeSearchResult>> search(String roomId, String q) async =>
      (await _client.get<List<dynamic>>(
            '/api/chat/rooms/$roomId/live/music/search',
            query: {'q': q},
          ))
          .map((e) => YoutubeSearchResult.fromJson(e as Map<String, dynamic>))
          .toList();

  Future<MusicSession> addToQueue(
    String roomId, {
    required String videoId,
    int? expectedVersion,
    bool? playNow,
  }) async {
    final body = {
      'videoId': videoId,
      if (expectedVersion != null) 'expectedVersion': expectedVersion,
      if (playNow != null) 'playNow': playNow,
    };
    return MusicSession.fromJson(
      await _client.post<Map<String, dynamic>>(
        '/api/chat/rooms/$roomId/live/music/queue',
        body: body,
      ),
    );
  }

  Future<void> requestSong(String roomId, String videoId) => _client.post<void>(
    '/api/chat/rooms/$roomId/live/music/requests',
    body: {'videoId': videoId},
  );

  Future<void> approveRequest(String roomId, String requestId) =>
      _client.post<void>(
        '/api/chat/rooms/$roomId/live/music/requests/$requestId/approve',
      );
  Future<void> rejectRequest(String roomId, String requestId) =>
      _client.post<void>(
        '/api/chat/rooms/$roomId/live/music/requests/$requestId/reject',
      );

  Future<MusicSession> _control(
    String roomId,
    String action, {
    int? expectedVersion,
  }) async => MusicSession.fromJson(
    await _client.post<Map<String, dynamic>>(
      '/api/chat/rooms/$roomId/live/music/$action',
      body: expectedVersion != null
          ? {'expectedVersion': expectedVersion}
          : null,
    ),
  );

  Future<MusicSession> play(String roomId, {int? expectedVersion}) =>
      _control(roomId, 'play', expectedVersion: expectedVersion);
  Future<MusicSession> pause(String roomId, {int? expectedVersion}) =>
      _control(roomId, 'pause', expectedVersion: expectedVersion);
  Future<MusicSession> resume(String roomId, {int? expectedVersion}) =>
      _control(roomId, 'resume', expectedVersion: expectedVersion);
  Future<MusicSession> skip(String roomId, {int? expectedVersion}) =>
      _control(roomId, 'skip', expectedVersion: expectedVersion);
  Future<MusicSession> stop(String roomId, {int? expectedVersion}) =>
      _control(roomId, 'stop', expectedVersion: expectedVersion);

  Future<MusicSession> seek(
    String roomId, {
    required int positionSeconds,
    int? expectedVersion,
  }) async => MusicSession.fromJson(
    await _client.post<Map<String, dynamic>>(
      '/api/chat/rooms/$roomId/live/music/seek',
      body: {
        'positionSeconds': positionSeconds,
        if (expectedVersion != null) 'expectedVersion': expectedVersion,
      },
    ),
  );

  Future<MusicSession> updateSettings(
    String roomId, {
    bool? allowRequests,
  }) async => MusicSession.fromJson(
    await _client.patch<Map<String, dynamic>>(
      '/api/chat/rooms/$roomId/live/music/settings',
      body: {if (allowRequests != null) 'allowRequests': allowRequests},
    ),
  );

  Future<MusicSession> reorderQueue(
    String roomId,
    List<String> orderedIds, {
    int? expectedVersion,
  }) async => MusicSession.fromJson(
    await _client.patch<Map<String, dynamic>>(
      '/api/chat/rooms/$roomId/live/music/queue/reorder',
      body: {
        'orderedQueueItemIds': orderedIds,
        if (expectedVersion != null) 'expectedVersion': expectedVersion,
      },
    ),
  );

  Future<void> removeQueueItem(String roomId, String queueItemId) => _client
      .delete<void>('/api/chat/rooms/$roomId/live/music/queue/$queueItemId');
  Future<void> clearQueue(String roomId) =>
      _client.delete<void>('/api/chat/rooms/$roomId/live/music/queue');
}
