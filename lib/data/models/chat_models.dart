import 'common.dart';
import 'user_models.dart';

enum RoomRole { owner, coHost, member }

RoomRole roomRoleFromJson(String value) {
  switch (value) {
    case 'OWNER':
      return RoomRole.owner;
    case 'CO_HOST':
      return RoomRole.coHost;
    default:
      return RoomRole.member;
  }
}

String roomRoleToJson(RoomRole role) => switch (role) {
  RoomRole.owner => 'OWNER',
  RoomRole.coHost => 'CO_HOST',
  RoomRole.member => 'MEMBER',
};

enum ChatRoomType { public, direct }

class ChatRoomLiveSummary {
  const ChatRoomLiveSummary({
    required this.liveSessionId,
    required this.title,
    required this.announcement,
    required this.participantCount,
    required this.speakerCount,
    required this.host,
  });

  final String liveSessionId;
  final String? title;
  final String? announcement;
  final int participantCount;
  final int speakerCount;
  final UserSummary? host;

  factory ChatRoomLiveSummary.fromJson(Map<String, dynamic> json) =>
      ChatRoomLiveSummary(
        liveSessionId: json['liveSessionId'] as String,
        title: json['title'] as String?,
        announcement: json['announcement'] as String?,
        participantCount: json['participantCount'] as int? ?? 0,
        speakerCount: json['speakerCount'] as int? ?? 0,
        host: json['host'] != null
            ? UserSummary.fromJson(json['host'] as Map<String, dynamic>)
            : null,
      );
}

class ChatRoomLastMessage {
  const ChatRoomLastMessage({
    required this.body,
    required this.hasImage,
    required this.senderId,
    required this.createdAt,
  });
  final String body;
  final bool hasImage;
  final String senderId;
  final DateTime createdAt;

  factory ChatRoomLastMessage.fromJson(Map<String, dynamic> json) =>
      ChatRoomLastMessage(
        body: json['body'] as String,
        hasImage: json['hasImage'] as bool? ?? false,
        senderId: json['senderId'] as String,
        createdAt: parseInstant(json['createdAt'] as String),
      );
}

class ChatRoom {
  const ChatRoom({
    required this.id,
    required this.name,
    required this.description,
    required this.topic,
    required this.gradient,
    required this.icon,
    required this.type,
    required this.avatarUri,
    required this.coverUri,
    required this.backgroundUri,
    required this.category,
    required this.peer,
    required this.memberCount,
    required this.onlineCount,
    required this.favorite,
    required this.joined,
    required this.role,
    required this.live,
    required this.liveSummary,
    required this.createdAt,
    required this.lastMessage,
  });

  final String id;
  final String? name;
  final String? description;
  final String? topic;
  final String? gradient;
  final String? icon;
  final ChatRoomType type;
  final String? avatarUri;
  final String? coverUri;
  final String? backgroundUri;
  final String? category;
  final UserSummary? peer;
  final int memberCount;
  final int onlineCount;
  final bool favorite;
  final bool joined;
  final RoomRole? role;
  final bool live;
  final ChatRoomLiveSummary? liveSummary;
  final DateTime createdAt;
  final ChatRoomLastMessage? lastMessage;

  factory ChatRoom.fromJson(Map<String, dynamic> json) => ChatRoom(
    id: json['id'] as String,
    name: json['name'] as String?,
    description: json['description'] as String?,
    topic: json['topic'] as String?,
    gradient: json['gradient'] as String?,
    icon: json['icon'] as String?,
    type: json['type'] == 'DIRECT' ? ChatRoomType.direct : ChatRoomType.public,
    avatarUri: json['avatarUri'] as String?,
    coverUri: json['coverUri'] as String?,
    backgroundUri: json['backgroundUri'] as String?,
    category: json['category'] as String?,
    peer: json['peer'] != null
        ? UserSummary.fromJson(json['peer'] as Map<String, dynamic>)
        : null,
    memberCount: json['memberCount'] as int? ?? 0,
    onlineCount: json['onlineCount'] as int? ?? 0,
    favorite: json['favorite'] as bool? ?? false,
    joined: json['joined'] as bool? ?? false,
    role: json['role'] != null
        ? roomRoleFromJson(json['role'] as String)
        : null,
    live: json['live'] as bool? ?? false,
    liveSummary: json['liveSummary'] != null
        ? ChatRoomLiveSummary.fromJson(
            json['liveSummary'] as Map<String, dynamic>,
          )
        : null,
    createdAt: parseInstant(json['createdAt'] as String),
    lastMessage: json['lastMessage'] != null
        ? ChatRoomLastMessage.fromJson(
            json['lastMessage'] as Map<String, dynamic>,
          )
        : null,
  );
}

class RoomMember {
  const RoomMember({
    required this.user,
    required this.role,
    required this.joinedAt,
  });
  final UserSummary user;
  final RoomRole role;
  final DateTime joinedAt;

  factory RoomMember.fromJson(Map<String, dynamic> json) => RoomMember(
    user: UserSummary.fromJson(json['user'] as Map<String, dynamic>),
    role: roomRoleFromJson(json['role'] as String),
    joinedAt: parseInstant(json['joinedAt'] as String),
  );
}

class RoomBan {
  const RoomBan({
    required this.user,
    required this.reason,
    required this.createdAt,
    required this.bannedBy,
  });
  final UserSummary user;
  final String? reason;
  final DateTime createdAt;
  final UserSummary? bannedBy;

  factory RoomBan.fromJson(Map<String, dynamic> json) => RoomBan(
    user: UserSummary.fromJson(json['user'] as Map<String, dynamic>),
    reason: json['reason'] as String?,
    createdAt: parseInstant(json['createdAt'] as String),
    bannedBy: json['bannedBy'] != null
        ? UserSummary.fromJson(json['bannedBy'] as Map<String, dynamic>)
        : null,
  );
}

enum MessageType { text, system }

class MessageReplyPreview {
  const MessageReplyPreview({
    required this.id,
    required this.authorName,
    required this.bodyPreview,
    required this.deleted,
  });

  final String id;
  final String? authorName;
  final String? bodyPreview;
  final bool deleted;

  factory MessageReplyPreview.fromJson(Map<String, dynamic> json) =>
      MessageReplyPreview(
        id: json['id'] as String,
        authorName: json['authorName'] as String?,
        bodyPreview: json['bodyPreview'] as String?,
        deleted: json['deleted'] as bool? ?? false,
      );
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.roomId,
    required this.author,
    required this.body,
    required this.imageUri,
    required this.type,
    required this.createdAt,
    required this.replyTo,
  });

  final String id;
  final String roomId;
  final UserSummary? author;
  final String body;
  final String? imageUri;
  final MessageType type;
  final DateTime createdAt;
  final MessageReplyPreview? replyTo;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    roomId: json['roomId'] as String,
    author: json['author'] != null
        ? UserSummary.fromJson(json['author'] as Map<String, dynamic>)
        : null,
    body: json['body'] as String,
    imageUri: json['imageUri'] as String?,
    type: json['type'] == 'system' ? MessageType.system : MessageType.text,
    createdAt: parseInstant(json['createdAt'] as String),
    replyTo: json['replyTo'] != null
        ? MessageReplyPreview.fromJson(json['replyTo'] as Map<String, dynamic>)
        : null,
  );
}

class TypingEvent {
  const TypingEvent({
    required this.userId,
    required this.displayName,
    required this.typing,
  });
  final String userId;
  final String displayName;
  final bool typing;

  factory TypingEvent.fromJson(Map<String, dynamic> json) => TypingEvent(
    userId: json['userId'] as String,
    displayName: json['displayName'] as String,
    typing: json['typing'] as bool? ?? false,
  );
}

class RoomModerationEvent {
  const RoomModerationEvent({
    required this.type,
    required this.roomId,
    required this.targetUserId,
    required this.targetDisplayName,
  });
  final String type;
  final String roomId;
  final String targetUserId;
  final String targetDisplayName;

  factory RoomModerationEvent.fromJson(Map<String, dynamic> json) =>
      RoomModerationEvent(
        type: json['type'] as String,
        roomId: json['roomId'] as String,
        targetUserId: json['targetUserId'] as String,
        targetDisplayName: json['targetDisplayName'] as String,
      );
}

typedef ChatRoomPage = PageResponse<ChatRoom>;
typedef ChatMessagePage = PageResponse<ChatMessage>;
