import 'common.dart';
import 'user_models.dart';

class CommunityConfig {
  const CommunityConfig({
    required this.name,
    required this.subtitle,
    required this.tags,
    required this.memberCount,
    required this.onlineCount,
  });
  final String name;
  final String? subtitle;
  final List<String> tags;
  final int memberCount;
  final int onlineCount;

  factory CommunityConfig.fromJson(Map<String, dynamic> json) =>
      CommunityConfig(
        name: json['name'] as String? ?? 'Menzo',
        subtitle: json['subtitle'] as String?,
        tags: (json['tags'] as List?)?.cast<String>() ?? const [],
        memberCount: json['memberCount'] as int? ?? 0,
        onlineCount: json['onlineCount'] as int? ?? 0,
      );
}

class CommunityEvent {
  const CommunityEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.coverUri,
    required this.startsAt,
    required this.endsAt,
    required this.attendeeCount,
    required this.attendingByMe,
    required this.host,
  });

  final String id;
  final String title;
  final String? description;
  final String? coverUri;
  final DateTime startsAt;
  final DateTime? endsAt;
  final int attendeeCount;
  final bool attendingByMe;
  final UserSummary? host;

  factory CommunityEvent.fromJson(Map<String, dynamic> json) => CommunityEvent(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String?,
    coverUri: json['coverUri'] as String?,
    startsAt: parseInstant(json['startsAt'] as String),
    endsAt: parseInstantOrNull(json['endsAt'] as String?),
    attendeeCount: json['attendeeCount'] as int? ?? 0,
    attendingByMe: json['attendingByMe'] as bool? ?? false,
    host: json['host'] != null
        ? UserSummary.fromJson(json['host'] as Map<String, dynamic>)
        : null,
  );
}

/// Minúscula en español — ver hallazgos del contrato (NotificationCategory).
enum NotificationCategory {
  comentarios,
  likes,
  mensajes,
  eventos,
  seguimientos,
}

NotificationCategory notificationCategoryFromJson(String value) =>
    NotificationCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => NotificationCategory.mensajes,
    );

class AppNotification {
  const AppNotification({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
    required this.relatedPostId,
    required this.relatedRoomId,
    required this.relatedUserId,
    required this.relatedEventId,
  });

  final String id;
  final NotificationCategory category;
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt;
  final String? relatedPostId;
  final String? relatedRoomId;
  final String? relatedUserId;
  final String? relatedEventId;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        category: notificationCategoryFromJson(json['category'] as String),
        title: json['title'] as String,
        body: json['body'] as String,
        read: json['read'] as bool? ?? false,
        createdAt: parseInstant(json['createdAt'] as String),
        relatedPostId: json['relatedPostId'] as String?,
        relatedRoomId: json['relatedRoomId'] as String?,
        relatedUserId: json['relatedUserId'] as String?,
        relatedEventId: json['relatedEventId'] as String?,
      );
}

typedef EventPage = PageResponse<CommunityEvent>;
typedef NotificationPage = PageResponse<AppNotification>;
