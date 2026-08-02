import '../../core/network/api_client.dart';
import '../models/chat_models.dart';
import '../models/common.dart';

class ChatRepository {
  ChatRepository(this._client);
  final ApiClient _client;

  Future<List<ChatRoom>> myRooms() async => (await _client.get<List<dynamic>>(
    '/api/chat/rooms',
  )).map((e) => ChatRoom.fromJson(e as Map<String, dynamic>)).toList();

  Future<List<ChatRoom>> discover({String sort = 'recent'}) async =>
      (await _client.get<List<dynamic>>(
        '/api/chat/rooms/discover',
        query: {'sort': sort},
      )).map((e) => ChatRoom.fromJson(e as Map<String, dynamic>)).toList();

  Future<List<ChatRoom>> liveRooms() async => (await _client.get<List<dynamic>>(
    '/api/chat/rooms/live',
  )).map((e) => ChatRoom.fromJson(e as Map<String, dynamic>)).toList();

  Future<ChatRoom> getRoom(String id) async => ChatRoom.fromJson(
    await _client.get<Map<String, dynamic>>('/api/chat/rooms/$id'),
  );

  Future<ChatRoom> createRoom(Map<String, dynamic> body) async =>
      ChatRoom.fromJson(
        await _client.post<Map<String, dynamic>>('/api/chat/rooms', body: body),
      );

  Future<ChatRoom> updateRoom(String id, Map<String, dynamic> patch) async =>
      ChatRoom.fromJson(
        await _client.patch<Map<String, dynamic>>(
          '/api/chat/rooms/$id',
          body: patch,
        ),
      );

  Future<ChatRoom> openDirect(String userId) async => ChatRoom.fromJson(
    await _client.post<Map<String, dynamic>>('/api/chat/rooms/dm/$userId'),
  );

  Future<void> join(String id) =>
      _client.post<void>('/api/chat/rooms/$id/join');
  Future<void> leave(String id) =>
      _client.post<void>('/api/chat/rooms/$id/leave');
  Future<void> favorite(String id) =>
      _client.put<void>('/api/chat/rooms/$id/favorite');
  Future<void> unfavorite(String id) =>
      _client.delete<void>('/api/chat/rooms/$id/favorite');
  Future<void> deleteRoom(String id) =>
      _client.delete<void>('/api/chat/rooms/$id');

  Future<ChatMessagePage> messages(
    String roomId, {
    int page = 0,
    int size = 50,
  }) async {
    final json = await _client.get<Map<String, dynamic>>(
      '/api/chat/rooms/$roomId/messages',
      query: {'page': page, 'size': size},
    );
    return PageResponse.fromJson(json, ChatMessage.fromJson);
  }

  Future<ChatMessage> sendMessage(
    String roomId,
    String body, {
    String? imageUri,
    String? replyToMessageId,
  }) async => ChatMessage.fromJson(
    await _client.post<Map<String, dynamic>>(
      '/api/chat/rooms/$roomId/messages',
      body: {
        'body': body,
        'imageUri': imageUri,
        'replyToMessageId': replyToMessageId,
      },
    ),
  );

  Future<List<RoomMember>> members(String roomId) async =>
      (await _client.get<List<dynamic>>(
        '/api/chat/rooms/$roomId/members',
      )).map((e) => RoomMember.fromJson(e as Map<String, dynamic>)).toList();

  Future<void> promote(String roomId, String userId) =>
      _client.post<void>('/api/chat/rooms/$roomId/members/$userId/promote');
  Future<void> demote(String roomId, String userId) =>
      _client.post<void>('/api/chat/rooms/$roomId/members/$userId/demote');
  Future<void> kick(String roomId, String userId) =>
      _client.delete<void>('/api/chat/rooms/$roomId/members/$userId');
  Future<void> ban(String roomId, String userId, {String? reason}) =>
      _client.post<void>(
        '/api/chat/rooms/$roomId/members/$userId/ban',
        body: reason != null ? {'reason': reason} : null,
      );
  Future<void> unban(String roomId, String userId) =>
      _client.delete<void>('/api/chat/rooms/$roomId/bans/$userId');

  Future<List<RoomBan>> bans(String roomId) async =>
      (await _client.get<List<dynamic>>(
        '/api/chat/rooms/$roomId/bans',
      )).map((e) => RoomBan.fromJson(e as Map<String, dynamic>)).toList();

  Future<void> invite(String roomId, String userId) =>
      _client.post<void>('/api/chat/rooms/$roomId/members/$userId/invite');
  Future<void> transferOwnership(String roomId, String userId) =>
      _client.post<void>('/api/chat/rooms/$roomId/transfer-ownership/$userId');
}
