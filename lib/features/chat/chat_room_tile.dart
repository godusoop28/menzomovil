import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/chat_models.dart';
import '../shared/menzo_avatar.dart';

/// 1:1 con menzoweb/components/ChatRoomListItem.tsx.
class ChatRoomTile extends StatelessWidget {
  const ChatRoomTile({
    super.key,
    required this.room,
    this.onJoin,
    this.joining = false,
  });
  final ChatRoom room;
  final VoidCallback? onJoin;
  final bool joining;

  @override
  Widget build(BuildContext context) {
    final isDirect = room.type == ChatRoomType.direct;
    final title = isDirect
        ? (room.peer?.displayName ?? 'Conversación')
        : (room.name ?? '');
    final avatarUri = isDirect ? room.peer?.avatarUri : room.avatarUri;

    return Material(
      color: AppColors.surfaceSecondary,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => context.push('/chat/${room.id}'),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              MenzoAvatar(
                name: title,
                avatarUri: avatarUri,
                gradient: gradientIdFromName(room.gradient),
                size: 46,
                showOnline: isDirect,
                online: room.peer?.isOnline ?? false,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: AppTextStyles.label(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (room.live)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.coral,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'LIVE',
                              style: AppTextStyles.caption(color: Colors.white)
                                  .copyWith(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      room.lastMessage?.body ??
                          (isDirect ? '' : '${room.onlineCount} conectados'),
                      style: AppTextStyles.caption(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onJoin != null)
                TextButton(
                  onPressed: joining ? null : onJoin,
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    foregroundColor: Colors.black,
                  ),
                  child: Text(joining ? '…' : 'Unirse'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
