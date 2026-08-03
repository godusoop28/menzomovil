import '../../core/network/api_client.dart';
import '../models/common.dart';
import '../models/communities_models.dart';

/// Plural a propósito — separado de CommunityRepository (singular, ya existente:
/// `/api/community/*`, la config/eventos de Menzo como plataforma única). Este repo le pega a
/// `/api/communities/*` (el nuevo dominio multi-comunidad).
class CommunitiesRepository {
  CommunitiesRepository(this._client);
  final ApiClient _client;

  Future<CommunitySummaryPage> list({int page = 0, int size = 20}) async =>
      PageResponse.fromJson(
        await _client.get<Map<String, dynamic>>(
          '/api/communities',
          query: {'page': page, 'size': size},
        ),
        CommunitySummary.fromJson,
      );

  Future<CommunitySummaryPage> discover({String? query, int page = 0, int size = 20}) async =>
      PageResponse.fromJson(
        await _client.get<Map<String, dynamic>>(
          '/api/communities/discover',
          query: {if (query != null && query.isNotEmpty) 'query': query, 'page': page, 'size': size},
        ),
        CommunitySummary.fromJson,
      );

  Future<List<MyCommunity>> my() async => (await _client.get<List<dynamic>>(
    '/api/communities/my',
  )).map((e) => MyCommunity.fromJson(e as Map<String, dynamic>)).toList();

  Future<CommunityDetail> getBySlug(String slug) async => CommunityDetail.fromJson(
    await _client.get<Map<String, dynamic>>('/api/communities/$slug'),
  );

  Future<CommunityMembership> join(String communityId) async => CommunityMembership.fromJson(
    await _client.post<Map<String, dynamic>>('/api/communities/$communityId/join'),
  );

  Future<void> leave(String communityId) =>
      _client.post<void>('/api/communities/$communityId/leave');

  // COMMUNITY_ADMIN+ de esa comunidad, o cuenta global LEADER+ — ver CommunitiesController en
  // menzoapi. body: iconUrl/logoUrl/coverUrl/backgroundUrl/bannerUrl/primaryColor/
  // secondaryColor/accentColor — "" limpia el campo, ausente lo deja sin cambios.
  Future<CommunityDetail> updateAppearance(String communityId, Map<String, dynamic> body) async =>
      CommunityDetail.fromJson(
        await _client.patch<Map<String, dynamic>>('/api/communities/$communityId/appearance', body: body),
      );

  // Reemplazo completo de themeConfig (fondos adicionales de feed/chat, estilo de encabezado/
  // tarjetas, decoraciones) — mismos permisos que updateAppearance.
  Future<CommunityDetail> updateTheme(String communityId, Map<String, dynamic> themeConfig) async =>
      CommunityDetail.fromJson(
        await _client.patch<Map<String, dynamic>>(
          '/api/communities/$communityId/theme',
          body: {'themeConfig': themeConfig},
        ),
      );

  // Reemplazo completo de navigationConfig (secciones visibles, orden, etiquetas).
  Future<CommunityDetail> updateNavigation(String communityId, Map<String, dynamic> navigationConfig) async =>
      CommunityDetail.fromJson(
        await _client.patch<Map<String, dynamic>>(
          '/api/communities/$communityId/navigation',
          body: {'navigationConfig': navigationConfig},
        ),
      );
}
