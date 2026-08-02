import 'common.dart';
import 'user_models.dart';

/// Minúsculas — a diferencia de la mayoría de los enums del backend (ver hallazgos del
/// contrato: PostType/MessageType/NotificationCategory serializan en minúscula).
enum PostType { text, image, poll, question, event }

PostType postTypeFromJson(String value) => PostType.values.firstWhere(
  (e) => e.name == value,
  orElse: () => PostType.text,
);

class PollOption {
  const PollOption({
    required this.id,
    required this.label,
    required this.voteCount,
    required this.votedByMe,
  });
  final String id;
  final String label;
  final int voteCount;
  final bool votedByMe;

  factory PollOption.fromJson(Map<String, dynamic> json) => PollOption(
    id: json['id'] as String,
    label: json['label'] as String,
    voteCount: json['voteCount'] as int? ?? 0,
    votedByMe: json['votedByMe'] as bool? ?? false,
  );
}

class AbstractVisual {
  const AbstractVisual({required this.preset, required this.caption});
  final String preset;
  final String? caption;

  factory AbstractVisual.fromJson(Map<String, dynamic> json) => AbstractVisual(
    preset: json['preset'] as String,
    caption: json['caption'] as String?,
  );
}

/// Espejo de PostBlock.java (backend) — `type` decide qué otros campos importan: paragraph/
/// heading usan `text`; image/gif usan `url` (siempre https, nunca un path local) y opcionalmente
/// `alt`; divider no usa ninguno. `id` es generado por el cliente, solo para keys de
/// ReorderableListView al reordenar — el backend nunca le da significado propio.
enum PostBlockType { paragraph, heading, image, gif, divider }

PostBlockType postBlockTypeFromJson(String value) => PostBlockType.values.firstWhere(
  (e) => e.name == value,
  orElse: () => PostBlockType.paragraph,
);

class PostBlock {
  const PostBlock({
    required this.id,
    required this.type,
    this.text,
    this.url,
    this.alt,
  });

  final String id;
  final PostBlockType type;
  final String? text;
  final String? url;
  final String? alt;

  factory PostBlock.fromJson(Map<String, dynamic> json) => PostBlock(
    id: json['id'] as String,
    type: postBlockTypeFromJson(json['type'] as String),
    text: json['text'] as String?,
    url: json['url'] as String?,
    alt: json['alt'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'text': text,
    'url': url,
    'alt': alt,
  };

  PostBlock copyWith({String? text}) =>
      PostBlock(id: id, type: type, text: text ?? this.text, url: url, alt: alt);
}

class Post {
  const Post({
    required this.id,
    required this.author,
    required this.type,
    required this.title,
    required this.body,
    required this.imageUri,
    required this.abstractVisual,
    required this.gradient,
    required this.tags,
    required this.pollOptions,
    required this.eventId,
    required this.likeCount,
    required this.likedByMe,
    required this.bookmarkedByMe,
    required this.commentCount,
    required this.featured,
    required this.createdAt,
    required this.blocks,
    required this.hidden,
  });

  final String id;
  final UserSummary author;
  final PostType type;
  final String? title;
  final String body;
  final String? imageUri;
  final AbstractVisual? abstractVisual;
  final String? gradient;
  final List<String> tags;
  final List<PollOption> pollOptions;
  final String? eventId;
  final int likeCount;
  final bool likedByMe;
  final bool bookmarkedByMe;
  final int commentCount;
  final bool featured;
  final DateTime createdAt;
  final List<PostBlock> blocks;
  final bool hidden;

  factory Post.fromJson(Map<String, dynamic> json) => Post(
    id: json['id'] as String,
    author: UserSummary.fromJson(json['author'] as Map<String, dynamic>),
    type: postTypeFromJson(json['type'] as String),
    title: json['title'] as String?,
    body: json['body'] as String,
    imageUri: json['imageUri'] as String?,
    abstractVisual: json['abstractVisual'] != null
        ? AbstractVisual.fromJson(
            json['abstractVisual'] as Map<String, dynamic>,
          )
        : null,
    gradient: json['gradient'] as String?,
    tags: (json['tags'] as List?)?.cast<String>() ?? const [],
    pollOptions: (json['pollOptions'] as List? ?? const [])
        .map((e) => PollOption.fromJson(e as Map<String, dynamic>))
        .toList(),
    eventId: json['eventId'] as String?,
    likeCount: json['likeCount'] as int? ?? 0,
    likedByMe: json['likedByMe'] as bool? ?? false,
    bookmarkedByMe: json['bookmarkedByMe'] as bool? ?? false,
    commentCount: json['commentCount'] as int? ?? 0,
    featured: json['featured'] as bool? ?? false,
    createdAt: parseInstant(json['createdAt'] as String),
    blocks: (json['blocks'] as List? ?? const [])
        .map((e) => PostBlock.fromJson(e as Map<String, dynamic>))
        .toList(),
    hidden: json['hidden'] as bool? ?? false,
  );

  Post copyWith({
    int? likeCount,
    bool? likedByMe,
    bool? bookmarkedByMe,
    int? commentCount,
    List<PollOption>? pollOptions,
    bool? hidden,
  }) => Post(
    id: id,
    author: author,
    type: type,
    title: title,
    body: body,
    imageUri: imageUri,
    abstractVisual: abstractVisual,
    gradient: gradient,
    tags: tags,
    pollOptions: pollOptions ?? this.pollOptions,
    eventId: eventId,
    likeCount: likeCount ?? this.likeCount,
    likedByMe: likedByMe ?? this.likedByMe,
    bookmarkedByMe: bookmarkedByMe ?? this.bookmarkedByMe,
    commentCount: commentCount ?? this.commentCount,
    featured: featured,
    createdAt: createdAt,
    blocks: blocks,
    hidden: hidden ?? this.hidden,
  );
}

class PostComment {
  const PostComment({
    required this.id,
    required this.postId,
    required this.author,
    required this.body,
    required this.createdAt,
  });
  final String id;
  final String postId;
  final UserSummary author;
  final String body;
  final DateTime createdAt;

  factory PostComment.fromJson(Map<String, dynamic> json) => PostComment(
    id: json['id'] as String,
    postId: json['postId'] as String,
    author: UserSummary.fromJson(json['author'] as Map<String, dynamic>),
    body: json['body'] as String,
    createdAt: parseInstant(json['createdAt'] as String),
  );
}

typedef PostPage = PageResponse<Post>;
