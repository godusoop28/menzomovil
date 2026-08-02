import '../../core/network/api_client.dart';
import '../models/common.dart';
import '../models/moderation_models.dart';
import '../models/post_models.dart';
import '../models/user_models.dart';

/// Panel de staff global (CURATOR/LEADER/MASTER) — ver AdminController en menzoapi. Nunca hay un
/// método acá para navegar mensajes/salas: eso queda estructuralmente excluido (ver el plan,
/// decisión sobre chats DIRECT).
class AdminRepository {
  AdminRepository(this._client);
  final ApiClient _client;

  Future<PageResponse<UserProfile>> searchUsers(
    String query, {
    int page = 0,
    int size = 20,
  }) async => PageResponse.fromJson(
    await _client.get<Map<String, dynamic>>(
      '/api/admin/users',
      query: {'query': query, 'page': page, 'size': size},
    ),
    UserProfile.fromJson,
  );

  Future<void> suspendUser(String userId, String reason) => _client.post<void>(
    '/api/admin/users/$userId/suspend',
    body: {'reason': reason},
  );

  Future<void> unsuspendUser(String userId, String reason) => _client.post<void>(
    '/api/admin/users/$userId/unsuspend',
    body: {'reason': reason},
  );

  Future<void> deleteAccount(String userId, String reason) => _client.delete<void>(
    '/api/admin/users/$userId',
    body: {'reason': reason},
  );

  Future<void> changeRole(String userId, GlobalRole role, String reason) => _client.post<void>(
    '/api/admin/users/$userId/role',
    body: {'role': globalRoleToJson(role), 'reason': reason},
  );

  Future<PageResponse<Post>> searchPosts(
    String query, {
    int page = 0,
    int size = 20,
  }) async => PageResponse.fromJson(
    await _client.get<Map<String, dynamic>>(
      '/api/admin/posts',
      query: {'query': query, 'page': page, 'size': size},
    ),
    Post.fromJson,
  );

  Future<void> hidePost(String postId, String reason) => _client.post<void>(
    '/api/admin/posts/$postId/hide',
    body: {'reason': reason},
  );

  Future<void> unhidePost(String postId, String reason) => _client.post<void>(
    '/api/admin/posts/$postId/unhide',
    body: {'reason': reason},
  );

  Future<ModerationActionPage> moderationLog({int page = 0, int size = 30}) async =>
      PageResponse.fromJson(
        await _client.get<Map<String, dynamic>>(
          '/api/admin/moderation-log',
          query: {'page': page, 'size': size},
        ),
        ModerationAction.fromJson,
      );
}
