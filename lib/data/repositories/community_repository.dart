import '../../core/network/api_client.dart';
import '../models/common.dart';
import '../models/community_models.dart';

class CommunityRepository {
  CommunityRepository(this._client);
  final ApiClient _client;

  Future<CommunityConfig> config() async => CommunityConfig.fromJson(
    await _client.get<Map<String, dynamic>>(
      '/api/community/config',
      skipAuth: true,
    ),
  );

  Future<EventPage> events({int page = 0}) async {
    final json = await _client.get<Map<String, dynamic>>(
      '/api/community/events',
      query: {'page': page},
      skipAuth: true,
    );
    return PageResponse.fromJson(json, CommunityEvent.fromJson);
  }

  Future<CommunityEvent> getEvent(String id) async => CommunityEvent.fromJson(
    await _client.get<Map<String, dynamic>>(
      '/api/community/events/$id',
      skipAuth: true,
    ),
  );

  Future<CommunityEvent> createEvent(Map<String, dynamic> body) async =>
      CommunityEvent.fromJson(
        await _client.post<Map<String, dynamic>>(
          '/api/community/events',
          body: body,
        ),
      );

  Future<void> attend(String id) =>
      _client.put<void>('/api/community/events/$id/attend');
  Future<void> unattend(String id) =>
      _client.delete<void>('/api/community/events/$id/attend');
}

class NotificationsRepository {
  NotificationsRepository(this._client);
  final ApiClient _client;

  Future<NotificationPage> list({int page = 0}) async {
    final json = await _client.get<Map<String, dynamic>>(
      '/api/notifications',
      query: {'page': page},
    );
    return PageResponse.fromJson(json, AppNotification.fromJson);
  }

  Future<void> markRead(String id) =>
      _client.post<void>('/api/notifications/$id/read');
  Future<void> markAllRead() =>
      _client.post<void>('/api/notifications/read-all');
}

class ActivityRepository {
  ActivityRepository(this._client);
  final ApiClient _client;

  Future<List<String>> recentSearches() async =>
      (await _client.get<List<dynamic>>(
        '/api/activity/recent-searches',
      )).cast<String>();
  Future<void> addRecentSearch(String query) => _client.post<void>(
    '/api/activity/recent-searches',
    body: {'query': query},
  );
  Future<void> clearRecentSearches() =>
      _client.delete<void>('/api/activity/recent-searches');
}
