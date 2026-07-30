/// Envelope genérico de paginación — 1:1 con `PageResponse<T>` en menzoapi.
class PageResponse<T> {
  const PageResponse({
    required this.items,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.hasNext,
  });

  final List<T> items;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool hasNext;

  static PageResponse<T> fromJson<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemParser,
  ) {
    return PageResponse<T>(
      items: (json['items'] as List)
          .map((e) => itemParser(e as Map<String, dynamic>))
          .toList(),
      page: json['page'] as int,
      size: json['size'] as int,
      totalElements: json['totalElements'] as int,
      totalPages: json['totalPages'] as int,
      hasNext: json['hasNext'] as bool,
    );
  }
}

DateTime parseInstant(String value) => DateTime.parse(value).toLocal();
DateTime? parseInstantOrNull(String? value) =>
    value == null ? null : DateTime.parse(value).toLocal();
