import 'common.dart';

/// Dominio nuevo (multi-comunidad: Naruto, Anime, etc.) — NO confundir con `community_models.dart`
/// (singular, ya existente: CommunityConfig/CommunityEvent, la configuración de Menzo como
/// plataforma única). Ver CommunitiesController en menzoapi para el porqué de la separación.
enum CommunityVisibility { public_, private_, unlisted }

CommunityVisibility _visibilityFromJson(String value) {
  switch (value) {
    case 'PRIVATE':
      return CommunityVisibility.private_;
    case 'UNLISTED':
      return CommunityVisibility.unlisted;
    default:
      return CommunityVisibility.public_;
  }
}

enum CommunityAccessType { open_, request_, inviteOnly }

CommunityAccessType _accessTypeFromJson(String value) {
  switch (value) {
    case 'REQUEST':
      return CommunityAccessType.request_;
    case 'INVITE_ONLY':
      return CommunityAccessType.inviteOnly;
    default:
      return CommunityAccessType.open_;
  }
}

enum CommunityRole { member, curator, moderator, admin, owner }

CommunityRole _communityRoleFromJson(String value) {
  switch (value) {
    case 'COMMUNITY_CURATOR':
      return CommunityRole.curator;
    case 'COMMUNITY_MODERATOR':
      return CommunityRole.moderator;
    case 'COMMUNITY_ADMIN':
      return CommunityRole.admin;
    case 'COMMUNITY_OWNER':
      return CommunityRole.owner;
    default:
      return CommunityRole.member;
  }
}

enum CommunityMembershipStatus { active, pending, invited, left, removed, banned }

CommunityMembershipStatus _membershipStatusFromJson(String value) {
  switch (value) {
    case 'PENDING':
      return CommunityMembershipStatus.pending;
    case 'INVITED':
      return CommunityMembershipStatus.invited;
    case 'LEFT':
      return CommunityMembershipStatus.left;
    case 'REMOVED':
      return CommunityMembershipStatus.removed;
    case 'BANNED':
      return CommunityMembershipStatus.banned;
    default:
      return CommunityMembershipStatus.active;
  }
}

class CommunitySummary {
  const CommunitySummary({
    required this.id,
    required this.slug,
    required this.name,
    required this.shortDescription,
    required this.category,
    required this.tags,
    required this.iconUrl,
    required this.logoUrl,
    required this.coverUrl,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.memberCount,
    required this.featured,
    required this.official,
    required this.visibility,
    required this.accessType,
    required this.joined,
  });

  final String id;
  final String slug;
  final String name;
  final String? shortDescription;
  final String? category;
  final List<String> tags;
  final String? iconUrl;
  final String? logoUrl;
  final String? coverUrl;
  final String? primaryColor;
  final String? secondaryColor;
  final String? accentColor;
  final int memberCount;
  final bool featured;
  final bool official;
  final CommunityVisibility visibility;
  final CommunityAccessType accessType;
  final bool joined;

  factory CommunitySummary.fromJson(Map<String, dynamic> json) => CommunitySummary(
    id: json['id'] as String,
    slug: json['slug'] as String,
    name: json['name'] as String,
    shortDescription: json['shortDescription'] as String?,
    category: json['category'] as String?,
    tags: (json['tags'] as List?)?.cast<String>() ?? const [],
    iconUrl: json['iconUrl'] as String?,
    logoUrl: json['logoUrl'] as String?,
    coverUrl: json['coverUrl'] as String?,
    primaryColor: json['primaryColor'] as String?,
    secondaryColor: json['secondaryColor'] as String?,
    accentColor: json['accentColor'] as String?,
    memberCount: json['memberCount'] as int? ?? 0,
    featured: json['featured'] as bool? ?? false,
    official: json['official'] as bool? ?? false,
    visibility: _visibilityFromJson(json['visibility'] as String? ?? 'PUBLIC'),
    accessType: _accessTypeFromJson(json['accessType'] as String? ?? 'OPEN'),
    joined: json['joined'] as bool? ?? false,
  );
}

class CommunityMembership {
  const CommunityMembership({
    required this.communityRole,
    required this.membershipStatus,
    required this.joinedAt,
    required this.lastVisitedAt,
    required this.favorite,
    required this.muted,
    required this.communityNickname,
    required this.communityBio,
    required this.contributionCount,
    required this.customTitle,
  });

  final CommunityRole communityRole;
  final CommunityMembershipStatus membershipStatus;
  final DateTime joinedAt;
  final DateTime? lastVisitedAt;
  final bool favorite;
  final bool muted;
  final String? communityNickname;
  final String? communityBio;
  final int contributionCount;
  final String? customTitle;

  factory CommunityMembership.fromJson(Map<String, dynamic> json) => CommunityMembership(
    communityRole: _communityRoleFromJson(json['communityRole'] as String? ?? 'MEMBER'),
    membershipStatus: _membershipStatusFromJson(json['membershipStatus'] as String? ?? 'ACTIVE'),
    joinedAt: parseInstant(json['joinedAt'] as String),
    lastVisitedAt: parseInstantOrNull(json['lastVisitedAt'] as String?),
    favorite: json['favorite'] as bool? ?? false,
    muted: json['muted'] as bool? ?? false,
    communityNickname: json['communityNickname'] as String?,
    communityBio: json['communityBio'] as String?,
    contributionCount: json['contributionCount'] as int? ?? 0,
    customTitle: json['customTitle'] as String?,
  );
}

class MyCommunity {
  const MyCommunity({required this.community, required this.membership});

  final CommunitySummary community;
  final CommunityMembership membership;

  factory MyCommunity.fromJson(Map<String, dynamic> json) => MyCommunity(
    community: CommunitySummary.fromJson(json['community'] as Map<String, dynamic>),
    membership: CommunityMembership.fromJson(json['membership'] as Map<String, dynamic>),
  );
}

class CommunityDetail {
  const CommunityDetail({
    required this.id,
    required this.slug,
    required this.name,
    required this.shortDescription,
    required this.fullDescription,
    required this.category,
    required this.tags,
    required this.iconUrl,
    required this.logoUrl,
    required this.coverUrl,
    required this.backgroundUrl,
    required this.bannerUrl,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.textColor,
    required this.surfaceColor,
    required this.memberCount,
    required this.featured,
    required this.official,
    required this.allowJoinRequests,
    required this.allowPublicChats,
    required this.allowBlogs,
    required this.allowVoiceRooms,
    required this.allowMemberPosts,
    required this.minimumGlobalLevelToJoin,
    required this.minimumGlobalLevelToPost,
    required this.themeConfig,
    required this.navigationConfig,
    required this.myMembership,
  });

  final String id;
  final String slug;
  final String name;
  final String? shortDescription;
  final String? fullDescription;
  final String? category;
  final List<String> tags;
  final String? iconUrl;
  final String? logoUrl;
  final String? coverUrl;
  final String? backgroundUrl;
  final String? bannerUrl;
  final String? primaryColor;
  final String? secondaryColor;
  final String? accentColor;
  final String? textColor;
  final String? surfaceColor;
  final int memberCount;
  final bool featured;
  final bool official;
  final bool allowJoinRequests;
  final bool allowPublicChats;
  final bool allowBlogs;
  final bool allowVoiceRooms;
  final bool allowMemberPosts;
  final int minimumGlobalLevelToJoin;
  final int minimumGlobalLevelToPost;
  final Map<String, dynamic> themeConfig;
  final Map<String, dynamic> navigationConfig;
  final CommunityMembership? myMembership;

  factory CommunityDetail.fromJson(Map<String, dynamic> json) => CommunityDetail(
    id: json['id'] as String,
    slug: json['slug'] as String,
    name: json['name'] as String,
    shortDescription: json['shortDescription'] as String?,
    fullDescription: json['fullDescription'] as String?,
    category: json['category'] as String?,
    tags: (json['tags'] as List?)?.cast<String>() ?? const [],
    iconUrl: json['iconUrl'] as String?,
    logoUrl: json['logoUrl'] as String?,
    coverUrl: json['coverUrl'] as String?,
    backgroundUrl: json['backgroundUrl'] as String?,
    bannerUrl: json['bannerUrl'] as String?,
    primaryColor: json['primaryColor'] as String?,
    secondaryColor: json['secondaryColor'] as String?,
    accentColor: json['accentColor'] as String?,
    textColor: json['textColor'] as String?,
    surfaceColor: json['surfaceColor'] as String?,
    memberCount: json['memberCount'] as int? ?? 0,
    featured: json['featured'] as bool? ?? false,
    official: json['official'] as bool? ?? false,
    allowJoinRequests: json['allowJoinRequests'] as bool? ?? true,
    allowPublicChats: json['allowPublicChats'] as bool? ?? true,
    allowBlogs: json['allowBlogs'] as bool? ?? true,
    allowVoiceRooms: json['allowVoiceRooms'] as bool? ?? true,
    allowMemberPosts: json['allowMemberPosts'] as bool? ?? true,
    minimumGlobalLevelToJoin: json['minimumGlobalLevelToJoin'] as int? ?? 0,
    minimumGlobalLevelToPost: json['minimumGlobalLevelToPost'] as int? ?? 0,
    themeConfig: (json['themeConfig'] as Map?)?.cast<String, dynamic>() ?? const {},
    navigationConfig: (json['navigationConfig'] as Map?)?.cast<String, dynamic>() ?? const {},
    myMembership: json['myMembership'] != null
        ? CommunityMembership.fromJson(json['myMembership'] as Map<String, dynamic>)
        : null,
  );
}

typedef CommunitySummaryPage = PageResponse<CommunitySummary>;
