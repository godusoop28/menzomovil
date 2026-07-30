import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/stomp_service.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/chat_models.dart';
import '../live/live_provider.dart';
import '../live/live_room_panel.dart';
import '../shared/confirm_dialog.dart';
import '../shared/menzi_illustration_state.dart';
import '../shared/menzo_avatar.dart';
import '../shared/menzo_toast.dart';
import 'room_settings_screen.dart';

final roomProvider = FutureProvider.family.autoDispose(
  (ref, String roomId) => ref.watch(chatRepositoryProvider).getRoom(roomId),
);
final roomMessagesProvider = FutureProvider.family.autoDispose(
  (ref, String roomId) => ref.watch(chatRepositoryProvider).messages(roomId),
);

/// 1:1 con menzoweb/app/(app)/chat/[id]/page.tsx — mensajes + composer + entrada al LIVE.
class ChatRoomScreen extends ConsumerStatefulWidget {
  const ChatRoomScreen({super.key, required this.roomId});
  final String roomId;

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final _draftController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _liveMessages = [];
  StompChannel? _channel;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _channel = StompChannel()
      ..connect(
        onConnected: () {
          _channel!.subscribe('/topic/rooms/${widget.roomId}/messages', (
            payload,
          ) {
            setState(() => _liveMessages.add(ChatMessage.fromJson(payload)));
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _scrollToBottom(),
            );
          });
        },
      );
    Future.microtask(
      () => ref.read(liveProvider.notifier).watchRoom(widget.roomId),
    );
  }

  @override
  void dispose() {
    _channel?.dispose();
    ref.read(liveProvider.notifier).unwatchRoom(widget.roomId);
    _draftController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  Future<void> _send() async {
    final text = _draftController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _draftController.clear();
    try {
      await ref.read(chatRepositoryProvider).sendMessage(widget.roomId, text);
    } catch (_) {
      if (mounted) {
        showMenzoToast(context, 'No pudimos enviar tu mensaje.');
        _draftController.text = text;
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _startLive(ChatRoom room) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Iniciar LIVE',
      description:
          'Vas a encender una llamada en vivo en esta sala. Los miembros van a poder escuchar y pedir para hablar.',
      confirmLabel: 'Iniciar',
      image: MenziIllustration.liveVoice,
    );
    if (!confirmed) return;
    try {
      await ref.read(liveRepositoryProvider).start(room.id);
      ref.invalidate(roomProvider(widget.roomId));
      if (mounted) _openLivePanel(room);
    } catch (_) {
      if (mounted) showMenzoToast(context, 'No pudimos iniciar el LIVE.');
    }
  }

  void _openLivePanel(ChatRoom room) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LiveRoomPanel(
          room: room,
          onMinimize: () => Navigator.of(context).pop(),
        ),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(roomProvider(widget.roomId));
    final messagesAsync = ref.watch(roomMessagesProvider(widget.roomId));
    final myId = ref.watch(authProvider).profile?.id;
    final live = ref.watch(liveProvider);

    return Scaffold(
      appBar: AppBar(
        title: roomAsync.maybeWhen(
          data: (room) => Row(
            children: [
              MenzoAvatar(
                name: room.type == ChatRoomType.direct
                    ? (room.peer?.displayName ?? '')
                    : (room.name ?? ''),
                avatarUri: room.type == ChatRoomType.direct
                    ? room.peer?.avatarUri
                    : room.avatarUri,
                gradient: gradientIdFromName(room.gradient),
                size: 32,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  room.type == ChatRoomType.direct
                      ? (room.peer?.displayName ?? '')
                      : (room.name ?? ''),
                  style: AppTextStyles.label(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          orElse: () => const SizedBox.shrink(),
        ),
        actions: [
          roomAsync.maybeWhen(
            data: (room) {
              final canModerate =
                  room.role == RoomRole.owner || room.role == RoomRole.coHost;
              if (room.live) {
                return TextButton.icon(
                  onPressed: () => _openLivePanel(room),
                  icon: const Icon(
                    Icons.podcasts,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'LIVE',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: TextButton.styleFrom(backgroundColor: AppColors.coral),
                );
              }
              if (canModerate && room.type == ChatRoomType.public) {
                return TextButton(
                  onPressed: () => _startLive(room),
                  child: const Text('Iniciar LIVE'),
                );
              }
              return const SizedBox.shrink();
            },
            orElse: () => const SizedBox.shrink(),
          ),
          IconButton(
            icon: const Icon(Icons.people_outline),
            onPressed: () => context.push('/chat/${widget.roomId}/members'),
          ),
          roomAsync.maybeWhen(
            data: (room) =>
                (room.role == RoomRole.owner || room.role == RoomRole.coHost)
                ? IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => RoomSettingsScreen(room: room),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (page) {
                final all = [...page.items, ..._liveMessages];
                if (all.isEmpty) {
                  return const Center(
                    child: MenziIllustrationState(
                      image: MenziIllustration.chat,
                      title: 'Aún no hay mensajes aquí',
                      description: 'Sé el primero en escribir algo.',
                      size: MenziIllustrationSize.small,
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: all.length,
                  itemBuilder: (context, i) => _MessageBubble(
                    message: all[i],
                    isMe: all[i].author?.id == myId,
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(
                child: Text(
                  'No pudimos cargar los mensajes.',
                  style: AppTextStyles.body(color: AppColors.coral),
                ),
              ),
            ),
          ),
          if (live.connected && live.activeRoomId == widget.roomId)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: GestureDetector(
                onTap: () =>
                    roomAsync.maybeWhen(data: _openLivePanel, orElse: () {}),
                child: Row(
                  children: [
                    const Icon(
                      Icons.podcasts,
                      size: 14,
                      color: AppColors.coral,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Estás en el LIVE de esta sala · Toca para volver',
                      style: AppTextStyles.caption(color: AppColors.coral),
                    ),
                  ],
                ),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _draftController,
                      style: AppTextStyles.body(),
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Escribe un mensaje…',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.orange,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMe});
  final ChatMessage message;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    if (message.type == MessageType.system) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(message.body, style: AppTextStyles.caption()),
        ),
      );
    }
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe ? AppColors.orange : AppColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isMe)
              Text(
                message.author?.displayName ?? '',
                style: AppTextStyles.caption(color: AppColors.cyan),
              ),
            Text(
              message.body,
              style: AppTextStyles.body(
                color: isMe ? Colors.black : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
