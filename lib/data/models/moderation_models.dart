import 'common.dart';
import 'user_models.dart';

enum ModerationActionType {
  suspendUser,
  unsuspendUser,
  deleteAccount,
  deletePost,
  hidePost,
  unhidePost,
  deleteMessage,
  kickFromLive,
  promoteRole,
  demoteRole,
  deleteStickerPack,
}

ModerationActionType _actionTypeFromJson(String value) {
  switch (value) {
    case 'SUSPEND_USER':
      return ModerationActionType.suspendUser;
    case 'UNSUSPEND_USER':
      return ModerationActionType.unsuspendUser;
    case 'DELETE_ACCOUNT':
      return ModerationActionType.deleteAccount;
    case 'DELETE_POST':
      return ModerationActionType.deletePost;
    case 'HIDE_POST':
      return ModerationActionType.hidePost;
    case 'UNHIDE_POST':
      return ModerationActionType.unhidePost;
    case 'DELETE_MESSAGE':
      return ModerationActionType.deleteMessage;
    case 'KICK_FROM_LIVE':
      return ModerationActionType.kickFromLive;
    case 'PROMOTE_ROLE':
      return ModerationActionType.promoteRole;
    case 'DEMOTE_ROLE':
      return ModerationActionType.demoteRole;
    default:
      return ModerationActionType.deleteStickerPack;
  }
}

class ModerationAction {
  const ModerationAction({
    required this.id,
    required this.actor,
    required this.actionType,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.createdAt,
  });

  final String id;
  final UserSummary actor;
  final ModerationActionType actionType;
  final String targetType;
  final String targetId;
  final String reason;
  final DateTime createdAt;

  factory ModerationAction.fromJson(Map<String, dynamic> json) => ModerationAction(
    id: json['id'] as String,
    actor: UserSummary.fromJson(json['actor'] as Map<String, dynamic>),
    actionType: _actionTypeFromJson(json['actionType'] as String),
    targetType: json['targetType'] as String,
    targetId: json['targetId'] as String,
    reason: json['reason'] as String,
    createdAt: parseInstant(json['createdAt'] as String),
  );
}

typedef ModerationActionPage = PageResponse<ModerationAction>;
