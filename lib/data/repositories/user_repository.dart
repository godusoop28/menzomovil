import '../../core/network/api_client.dart';
import '../models/common.dart';
import '../models/user_models.dart';

class UserRepository {
  UserRepository(this._client);
  final ApiClient _client;

  Future<UserProfile> me() async => UserProfile.fromJson(
    await _client.get<Map<String, dynamic>>('/api/users/me'),
  );

  Future<UserProfile> completeOnboarding({
    required String displayName,
    required String aura,
    String? avatarUri,
    required String avatarGradient,
    required List<String> interests,
  }) async {
    final json = await _client.post<Map<String, dynamic>>(
      '/api/users/me/onboarding',
      body: {
        'displayName': displayName,
        'aura': aura,
        'avatarUri': avatarUri,
        'avatarGradient': avatarGradient,
        'interests': interests,
      },
    );
    return UserProfile.fromJson(json);
  }

  Future<UserProfile> updateMe(Map<String, dynamic> patch) async =>
      UserProfile.fromJson(
        await _client.patch<Map<String, dynamic>>('/api/users/me', body: patch),
      );

  Future<void> heartbeat() => _client.post<void>('/api/users/me/heartbeat');

  Future<SettingsDto> getSettings() async => SettingsDto.fromJson(
    await _client.get<Map<String, dynamic>>('/api/users/me/settings'),
  );

  Future<SettingsDto> updateSettings(Map<String, dynamic> patch) async =>
      SettingsDto.fromJson(
        await _client.patch<Map<String, dynamic>>(
          '/api/users/me/settings',
          body: patch,
        ),
      );

  Future<PageResponse<UserSummary>> search(
    String query, {
    int page = 0,
    int size = 30,
  }) async {
    final json = await _client.get<Map<String, dynamic>>(
      '/api/users/search',
      query: {'query': query, 'page': page, 'size': size},
    );
    return PageResponse.fromJson(json, UserSummary.fromJson);
  }

  Future<UserProfile> getById(String id) async => UserProfile.fromJson(
    await _client.get<Map<String, dynamic>>('/api/users/$id'),
  );

  Future<void> follow(String id) => _client.put<void>('/api/users/$id/follow');
  Future<void> unfollow(String id) =>
      _client.delete<void>('/api/users/$id/follow');

  Future<PageResponse<UserSummary>> followers(String id, {int page = 0}) async {
    final json = await _client.get<Map<String, dynamic>>(
      '/api/users/$id/followers',
      query: {'page': page},
    );
    return PageResponse.fromJson(json, UserSummary.fromJson);
  }

  Future<PageResponse<UserSummary>> following(String id, {int page = 0}) async {
    final json = await _client.get<Map<String, dynamic>>(
      '/api/users/$id/following',
      query: {'page': page},
    );
    return PageResponse.fromJson(json, UserSummary.fromJson);
  }

  Future<PageResponse<WallMessage>> wall(String userId, {int page = 0}) async {
    final json = await _client.get<Map<String, dynamic>>(
      '/api/users/$userId/wall',
      query: {'page': page},
    );
    return PageResponse.fromJson(json, WallMessage.fromJson);
  }

  Future<WallMessage> postWall(
    String userId,
    String body, {
    String? imageUri,
  }) async => WallMessage.fromJson(
    await _client.post<Map<String, dynamic>>(
      '/api/users/$userId/wall',
      body: {'body': body, 'imageUri': imageUri},
    ),
  );

  Future<PageResponse<WallComment>> wallComments(
    String messageId, {
    int page = 0,
  }) async {
    final json = await _client.get<Map<String, dynamic>>(
      '/api/wall/$messageId/comments',
      query: {'page': page},
    );
    return PageResponse.fromJson(json, WallComment.fromJson);
  }

  Future<WallComment> addWallComment(
    String messageId,
    String body, {
    String? imageUri,
  }) async => WallComment.fromJson(
    await _client.post<Map<String, dynamic>>(
      '/api/wall/$messageId/comments',
      body: {'body': body, 'imageUri': imageUri},
    ),
  );

  Future<void> deleteWallComment(String commentId) =>
      _client.delete<void>('/api/wall/comments/$commentId');
  Future<void> likeWallComment(String commentId) =>
      _client.put<void>('/api/wall/comments/$commentId/like');
  Future<void> unlikeWallComment(String commentId) =>
      _client.delete<void>('/api/wall/comments/$commentId/like');

  Future<List<AuraOption>> auras() async => ((await _client.get<List<dynamic>>(
    '/api/lookups/auras',
  ))).map((e) => AuraOption.fromJson(e as Map<String, dynamic>)).toList();

  Future<List<InterestOption>> interests() async =>
      ((await _client.get<List<dynamic>>('/api/lookups/interests')))
          .map((e) => InterestOption.fromJson(e as Map<String, dynamic>))
          .toList();
}
