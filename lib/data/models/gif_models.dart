/// Espejo de GifResult.java (backend, ver TenorController) — forma ya trimada del resultado de
/// Tenor, nunca el payload crudo del proveedor.
class GifResult {
  const GifResult({
    required this.id,
    required this.url,
    required this.previewUrl,
    this.width,
    this.height,
  });

  final String id;
  final String url;
  final String previewUrl;
  final int? width;
  final int? height;

  factory GifResult.fromJson(Map<String, dynamic> json) => GifResult(
    id: json['id'] as String,
    url: json['url'] as String,
    previewUrl: json['previewUrl'] as String,
    width: json['width'] as int?,
    height: json['height'] as int?,
  );
}

class GifSearchResult {
  const GifSearchResult({required this.results, required this.next});
  final List<GifResult> results;
  final String? next;

  factory GifSearchResult.fromJson(Map<String, dynamic> json) => GifSearchResult(
    results: (json['results'] as List? ?? const [])
        .map((e) => GifResult.fromJson(e as Map<String, dynamic>))
        .toList(),
    next: json['next'] as String?,
  );
}
