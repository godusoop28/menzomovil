import 'common.dart';

class UserSummary {
  const UserSummary({
    required this.id,
    required this.displayName,
    required this.username,
    required this.avatarUri,
    required this.avatarGradient,
    required this.isOnline,
  });

  final String id;
  final String displayName;
  final String username;
  final String? avatarUri;
  final String? avatarGradient;
  final bool isOnline;

  factory UserSummary.fromJson(Map<String, dynamic> json) => UserSummary(
    id: json['id'] as String,
    displayName: json['displayName'] as String,
    username: json['username'] as String,
    avatarUri: json['avatarUri'] as String?,
    avatarGradient: json['avatarGradient'] as String?,
    isOnline: json['isOnline'] as bool? ?? false,
  );
}

enum RelationshipStatus { self, none, following, followsYou, friends }

RelationshipStatus _relationshipFromJson(String value) {
  switch (value) {
    case 'SELF':
      return RelationshipStatus.self;
    case 'FOLLOWING':
      return RelationshipStatus.following;
    case 'FOLLOWS_YOU':
      return RelationshipStatus.followsYou;
    case 'FRIENDS':
      return RelationshipStatus.friends;
    default:
      return RelationshipStatus.none;
  }
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.username,
    required this.avatarUri,
    required this.avatarGradient,
    required this.coverUri,
    required this.backgroundUri,
    required this.backgroundColor,
    required this.aura,
    required this.bio,
    required this.statusText,
    required this.interests,
    required this.joinedAt,
    required this.level,
    required this.xp,
    required this.reputation,
    required this.followers,
    required this.following,
    required this.visitors,
    required this.isOnline,
    required this.badges,
    required this.followedByMe,
    required this.followsMe,
    required this.areFriends,
    required this.relationshipStatus,
  });

  final String id;
  final String displayName;
  final String username;
  final String? avatarUri;
  final String? avatarGradient;
  final String? coverUri;
  final String? backgroundUri;
  final String? backgroundColor;
  final String aura;
  final String? bio;
  final String? statusText;
  final List<String> interests;
  final DateTime joinedAt;
  final int level;
  final int xp;
  final int reputation;
  final int followers;
  final int following;
  final int visitors;
  final bool isOnline;
  final List<String> badges;
  final bool followedByMe;
  final bool followsMe;
  final bool areFriends;
  final RelationshipStatus relationshipStatus;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    displayName: json['displayName'] as String,
    username: json['username'] as String,
    avatarUri: json['avatarUri'] as String?,
    avatarGradient: json['avatarGradient'] as String?,
    coverUri: json['coverUri'] as String?,
    backgroundUri: json['backgroundUri'] as String?,
    backgroundColor: json['backgroundColor'] as String?,
    aura: json['aura'] as String? ?? 'fuego',
    bio: json['bio'] as String?,
    statusText: json['statusText'] as String?,
    interests: (json['interests'] as List?)?.cast<String>() ?? const [],
    joinedAt: parseInstant(json['joinedAt'] as String),
    level: json['level'] as int? ?? 1,
    xp: json['xp'] as int? ?? 0,
    reputation: json['reputation'] as int? ?? 0,
    followers: json['followers'] as int? ?? 0,
    following: json['following'] as int? ?? 0,
    visitors: json['visitors'] as int? ?? 0,
    isOnline: json['isOnline'] as bool? ?? false,
    badges: (json['badges'] as List?)?.cast<String>() ?? const [],
    followedByMe: json['followedByMe'] as bool? ?? false,
    followsMe: json['followsMe'] as bool? ?? false,
    areFriends: json['areFriends'] as bool? ?? false,
    relationshipStatus: _relationshipFromJson(
      json['relationshipStatus'] as String? ?? 'NONE',
    ),
  );

  UserSummary toSummary() => UserSummary(
    id: id,
    displayName: displayName,
    username: username,
    avatarUri: avatarUri,
    avatarGradient: avatarGradient,
    isOnline: isOnline,
  );
}

class SettingsDto {
  const SettingsDto({
    required this.notificationsEnabled,
    required this.showOnlineStatus,
    required this.allowProfileVisits,
    required this.showInterests,
  });

  final bool notificationsEnabled;
  final bool showOnlineStatus;
  final bool allowProfileVisits;
  final bool showInterests;

  factory SettingsDto.fromJson(Map<String, dynamic> json) => SettingsDto(
    notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
    showOnlineStatus: json['showOnlineStatus'] as bool? ?? true,
    allowProfileVisits: json['allowProfileVisits'] as bool? ?? true,
    showInterests: json['showInterests'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'notificationsEnabled': notificationsEnabled,
    'showOnlineStatus': showOnlineStatus,
    'allowProfileVisits': allowProfileVisits,
    'showInterests': showInterests,
  };

  SettingsDto copyWith({
    bool? notificationsEnabled,
    bool? showOnlineStatus,
    bool? allowProfileVisits,
    bool? showInterests,
  }) => SettingsDto(
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    showOnlineStatus: showOnlineStatus ?? this.showOnlineStatus,
    allowProfileVisits: allowProfileVisits ?? this.allowProfileVisits,
    showInterests: showInterests ?? this.showInterests,
  );
}

class AuraOption {
  const AuraOption({
    required this.id,
    required this.label,
    required this.gradient,
  });
  final String id;
  final String label;
  final String gradient;

  factory AuraOption.fromJson(Map<String, dynamic> json) => AuraOption(
    id: json['id'] as String,
    label: json['label'] as String,
    gradient: json['gradient'] as String? ?? 'fire',
  );
}

class InterestOption {
  const InterestOption({
    required this.id,
    required this.label,
    required this.icon,
  });
  final String id;
  final String label;
  final String? icon;

  factory InterestOption.fromJson(Map<String, dynamic> json) => InterestOption(
    id: json['id'] as String,
    label: json['label'] as String,
    icon: json['icon'] as String?,
  );
}

class WallMessage {
  const WallMessage({
    required this.id,
    required this.profileId,
    required this.author,
    required this.body,
    required this.imageUri,
    required this.createdAt,
    required this.commentCount,
  });

  final String id;
  final String profileId;
  final UserSummary author;
  final String body;
  final String? imageUri;
  final DateTime createdAt;
  final int commentCount;

  factory WallMessage.fromJson(Map<String, dynamic> json) => WallMessage(
    id: json['id'] as String,
    profileId: json['profileId'] as String,
    author: UserSummary.fromJson(json['author'] as Map<String, dynamic>),
    body: json['body'] as String,
    imageUri: json['imageUri'] as String?,
    createdAt: parseInstant(json['createdAt'] as String),
    commentCount: json['commentCount'] as int? ?? 0,
  );
}

class WallComment {
  const WallComment({
    required this.id,
    required this.wallMessageId,
    required this.author,
    required this.body,
    required this.imageUri,
    required this.createdAt,
    required this.likeCount,
    required this.likedByMe,
  });

  final String id;
  final String wallMessageId;
  final UserSummary author;
  final String body;
  final String? imageUri;
  final DateTime createdAt;
  final int likeCount;
  final bool likedByMe;

  factory WallComment.fromJson(Map<String, dynamic> json) => WallComment(
    id: json['id'] as String,
    wallMessageId: json['wallMessageId'] as String,
    author: UserSummary.fromJson(json['author'] as Map<String, dynamic>),
    body: json['body'] as String,
    imageUri: json['imageUri'] as String?,
    createdAt: parseInstant(json['createdAt'] as String),
    likeCount: json['likeCount'] as int? ?? 0,
    likedByMe: json['likedByMe'] as bool? ?? false,
  );
}
