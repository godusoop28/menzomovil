import '../../core/network/api_client.dart';
import '../models/live_models.dart';

class LiveRepository {
  LiveRepository(this._client);
  final ApiClient _client;

  /// 204 (sin body) cuando no hay un LIVE activo — ApiClient ya lo traduce a null, no hace
  /// falta capturar una excepción para ese caso.
  Future<LiveSession?> state(String roomId) async {
    final json = await _client.get<Map<String, dynamic>?>(
      '/api/chat/rooms/$roomId/live',
    );
    return json == null ? null : LiveSession.fromJson(json);
  }

  Future<LiveSession> start(
    String roomId, {
    String? title,
    String? description,
    String? announcement,
  }) async {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (description != null) body['description'] = description;
    if (announcement != null) body['announcement'] = announcement;
    return LiveSession.fromJson(
      await _client.post<Map<String, dynamic>>(
        '/api/chat/rooms/$roomId/live/start',
        body: body,
      ),
    );
  }

  Future<void> end(String roomId) =>
      _client.post<void>('/api/chat/rooms/$roomId/live/end');

  Future<LiveSession> update(String roomId, Map<String, dynamic> patch) async =>
      LiveSession.fromJson(
        await _client.patch<Map<String, dynamic>>(
          '/api/chat/rooms/$roomId/live',
          body: patch,
        ),
      );

  Future<LiveSession> join(String roomId) async => LiveSession.fromJson(
    await _client.post<Map<String, dynamic>>(
      '/api/chat/rooms/$roomId/live/join',
    ),
  );

  Future<void> leave(String roomId) =>
      _client.post<void>('/api/chat/rooms/$roomId/live/leave');

  /// Sin llamar esto periódicamente, el backend da por terminada la sesión sola pasados 30-45s
  /// sin actividad de join/leave — ver el comentario de clase en LiveService.heartbeat.
  Future<void> heartbeat(String roomId) =>
      _client.post<void>('/api/chat/rooms/$roomId/live/heartbeat');

  Future<LiveToken> token(String roomId) async => LiveToken.fromJson(
    await _client.get<Map<String, dynamic>>(
      '/api/chat/rooms/$roomId/live/token',
    ),
  );

  Future<List<LiveParticipant>> participants(String roomId) async =>
      (await _client.get<List<dynamic>>(
            '/api/chat/rooms/$roomId/live/participants',
          ))
          .map((e) => LiveParticipant.fromJson(e as Map<String, dynamic>))
          .toList();

  Future<void> setMicrophone(String roomId, bool enabled) => _client.post<void>(
    '/api/chat/rooms/$roomId/live/microphone',
    body: {'enabled': enabled},
  );

  Future<void> setScreenSharing(String roomId, bool enabled) =>
      _client.post<void>(
        '/api/chat/rooms/$roomId/live/screen-share',
        body: {'enabled': enabled},
      );

  Future<void> requestToSpeak(String roomId) =>
      _client.post<void>('/api/chat/rooms/$roomId/live/speaking-requests');
  Future<void> cancelSpeakRequest(String roomId) => _client.post<void>(
    '/api/chat/rooms/$roomId/live/speaking-requests/cancel',
  );

  Future<List<LiveParticipant>> speakingRequests(String roomId) async =>
      (await _client.get<List<dynamic>>(
            '/api/chat/rooms/$roomId/live/speaking-requests',
          ))
          .map((e) => LiveParticipant.fromJson(e as Map<String, dynamic>))
          .toList();

  Future<void> approveSpeaking(String roomId, String userId) =>
      _client.post<void>(
        '/api/chat/rooms/$roomId/live/speaking-requests/$userId/approve',
      );
  Future<void> rejectSpeaking(String roomId, String userId) =>
      _client.post<void>(
        '/api/chat/rooms/$roomId/live/speaking-requests/$userId/reject',
      );
  Future<void> demoteParticipant(String roomId, String userId) => _client
      .post<void>('/api/chat/rooms/$roomId/live/participants/$userId/demote');
  Future<void> muteParticipant(String roomId, String userId) => _client
      .post<void>('/api/chat/rooms/$roomId/live/participants/$userId/mute');
  Future<void> removeParticipant(String roomId, String userId) =>
      _client.delete<void>('/api/chat/rooms/$roomId/live/participants/$userId');
}
