import '../../core/network/api_client.dart';
import '../models/common.dart';
import '../models/post_models.dart';

class PostRepository {
  PostRepository(this._client);
  final ApiClient _client;

  // communityId opcional (ver PostController en menzoapi): sin él no filtra nada. Los clientes
  // actualizados siempre mandan la comunidad activa para no mezclar publicaciones entre comunidades.
  Future<PostPage> list({String? communityId, int page = 0, int size = 20}) async =>
      PageResponse.fromJson(
        await _client.get<Map<String, dynamic>>(
          '/api/posts',
          query: {if (communityId != null) 'communityId': communityId, 'page': page, 'size': size},
        ),
        Post.fromJson,
      );

  Future<PostPage> featured({String? communityId, int page = 0}) async => PageResponse.fromJson(
    await _client.get<Map<String, dynamic>>(
      '/api/posts/featured',
      query: {if (communityId != null) 'communityId': communityId, 'page': page},
    ),
    Post.fromJson,
  );

  Future<PostPage> bookmarked({int page = 0}) async => PageResponse.fromJson(
    await _client.get<Map<String, dynamic>>(
      '/api/posts/bookmarked',
      query: {'page': page},
    ),
    Post.fromJson,
  );

  Future<PostPage> search(String query, {String? communityId, int page = 0}) async =>
      PageResponse.fromJson(
        await _client.get<Map<String, dynamic>>(
          '/api/posts/search',
          query: {'query': query, if (communityId != null) 'communityId': communityId, 'page': page},
        ),
        Post.fromJson,
      );

  Future<PostPage> byAuthor(String userId, {int page = 0}) async =>
      PageResponse.fromJson(
        await _client.get<Map<String, dynamic>>(
          '/api/users/$userId/posts',
          query: {'page': page},
        ),
        Post.fromJson,
      );

  Future<Post> getById(String id) async =>
      Post.fromJson(await _client.get<Map<String, dynamic>>('/api/posts/$id'));

  Future<Post> create(Map<String, dynamic> body) async => Post.fromJson(
    await _client.post<Map<String, dynamic>>('/api/posts', body: body),
  );

  // body solo hace falta cuando quien borra no es el autor (staff LEADER+, motivo obligatorio) —
  // ver PostController.deletePost/PostService.deletePost en menzoapi.
  Future<void> remove(String id, {String? reason}) => _client.delete<void>(
    '/api/posts/$id',
    body: reason != null ? {'reason': reason} : null,
  );
  Future<void> like(String id) => _client.put<void>('/api/posts/$id/like');
  Future<void> unlike(String id) => _client.delete<void>('/api/posts/$id/like');
  Future<void> bookmark(String id) =>
      _client.put<void>('/api/posts/$id/bookmark');
  Future<void> unbookmark(String id) =>
      _client.delete<void>('/api/posts/$id/bookmark');

  Future<Post> vote(String postId, String optionId) async => Post.fromJson(
    await _client.post<Map<String, dynamic>>(
      '/api/posts/$postId/vote',
      body: {'optionId': optionId},
    ),
  );

  Future<PageResponse<PostComment>> comments(
    String postId, {
    int page = 0,
  }) async {
    final json = await _client.get<Map<String, dynamic>>(
      '/api/posts/$postId/comments',
      query: {'page': page},
    );
    return PageResponse.fromJson(json, PostComment.fromJson);
  }

  Future<PostComment> addComment(String postId, String body) async =>
      PostComment.fromJson(
        await _client.post<Map<String, dynamic>>(
          '/api/posts/$postId/comments',
          body: {'body': body},
        ),
      );
}
