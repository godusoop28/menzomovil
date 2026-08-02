import '../../core/network/api_client.dart';
import '../models/common.dart';
import '../models/sticker_models.dart';

/// Público desde el instante en que se crea — no hay endpoint de "agregar a mi bandeja" (ver
/// StickerService en menzoapi). Cualquier usuario logueado puede crear un pack y cualquier otro
/// puede usarlo de inmediato.
class StickerRepository {
  StickerRepository(this._client);
  final ApiClient _client;

  Future<StickerPackDetail> createPack(String name, List<String> imageUrls) async =>
      StickerPackDetail.fromJson(
        await _client.post<Map<String, dynamic>>(
          '/api/stickers/packs',
          body: {'name': name, 'imageUrls': imageUrls},
        ),
      );

  Future<StickerPackSummaryPage> listPacks({String? query, int page = 0, int size = 24}) async =>
      PageResponse.fromJson(
        await _client.get<Map<String, dynamic>>(
          '/api/stickers/packs',
          query: {if (query != null && query.isNotEmpty) 'query': query, 'page': page, 'size': size},
        ),
        StickerPackSummary.fromJson,
      );

  Future<StickerPackDetail> getPack(String id) async =>
      StickerPackDetail.fromJson(await _client.get<Map<String, dynamic>>('/api/stickers/packs/$id'));

  Future<void> deletePack(String id, {String? reason}) => _client.delete<void>(
    '/api/stickers/packs/$id',
    body: reason != null ? {'reason': reason} : null,
  );
}
