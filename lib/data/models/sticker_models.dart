import 'common.dart';
import 'user_models.dart';

class Sticker {
  const Sticker({required this.id, required this.imageUrl, required this.sortOrder});

  final String id;
  final String imageUrl;
  final int sortOrder;

  factory Sticker.fromJson(Map<String, dynamic> json) => Sticker(
    id: json['id'] as String,
    imageUrl: json['imageUrl'] as String,
    sortOrder: json['sortOrder'] as int? ?? 0,
  );
}

class StickerPackSummary {
  const StickerPackSummary({
    required this.id,
    required this.name,
    required this.creator,
    required this.coverImageUrl,
    required this.stickerCount,
    required this.createdAt,
  });

  final String id;
  final String name;
  final UserSummary creator;
  final String? coverImageUrl;
  final int stickerCount;
  final DateTime createdAt;

  factory StickerPackSummary.fromJson(Map<String, dynamic> json) => StickerPackSummary(
    id: json['id'] as String,
    name: json['name'] as String,
    creator: UserSummary.fromJson(json['creator'] as Map<String, dynamic>),
    coverImageUrl: json['coverImageUrl'] as String?,
    stickerCount: json['stickerCount'] as int? ?? 0,
    createdAt: parseInstant(json['createdAt'] as String),
  );
}

class StickerPackDetail {
  const StickerPackDetail({
    required this.id,
    required this.name,
    required this.creator,
    required this.stickers,
    required this.createdAt,
  });

  final String id;
  final String name;
  final UserSummary creator;
  final List<Sticker> stickers;
  final DateTime createdAt;

  factory StickerPackDetail.fromJson(Map<String, dynamic> json) => StickerPackDetail(
    id: json['id'] as String,
    name: json['name'] as String,
    creator: UserSummary.fromJson(json['creator'] as Map<String, dynamic>),
    stickers: (json['stickers'] as List? ?? const [])
        .map((e) => Sticker.fromJson(e as Map<String, dynamic>))
        .toList(),
    createdAt: parseInstant(json['createdAt'] as String),
  );
}

typedef StickerPackSummaryPage = PageResponse<StickerPackSummary>;
