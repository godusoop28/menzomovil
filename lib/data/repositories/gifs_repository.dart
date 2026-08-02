import '../../core/network/api_client.dart';
import '../models/gif_models.dart';

/// Búsqueda de GIFs — le pega solo al proxy propio (`/api/gifs/*`, ver TenorController en
/// menzoapi), nunca directo a Tenor: la API key es solo del servidor.
class GifsRepository {
  GifsRepository(this._client);
  final ApiClient _client;

  Future<GifSearchResult> search(String query, {String? pos}) async =>
      GifSearchResult.fromJson(
        await _client.get<Map<String, dynamic>>(
          '/api/gifs/search',
          query: {'q': query, if (pos != null) 'pos': pos},
        ),
      );

  Future<GifSearchResult> trending({String? pos}) async =>
      GifSearchResult.fromJson(
        await _client.get<Map<String, dynamic>>(
          '/api/gifs/trending',
          query: {if (pos != null) 'pos': pos},
        ),
      );
}
