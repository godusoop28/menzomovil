import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
import '../shared/menzo_sheet.dart';
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
  bool _autoJoinAttempted = false;
  final List<_PendingMessage> _pending = [];
  int _localIdSeq = 0;
  final Map<String, String> _typingUsers = {};
  final Map<String, Timer> _typingExpiry = {};
  DateTime _lastTypingPublish = DateTime.fromMillisecondsSinceEpoch(0);
  MessageReplyPreview? _pendingReplyTo;

  @override
  void initState() {
    super.initState();
    _channel = StompChannel()
      ..connect(
        onConnected: () {
          _channel!.subscribe('/topic/rooms/${widget.roomId}/messages', (
            payload,
          ) {
            if (!mounted) return;
            setState(() => _liveMessages.add(ChatMessage.fromJson(payload)));
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _scrollToBottom(),
            );
          });
          _channel!.subscribe('/topic/rooms/${widget.roomId}/typing', (
            payload,
          ) {
            final userId = payload['userId'] as String?;
            final myId = ref.read(authProvider).profile?.id;
            if (userId == null || userId == myId) return;
            _typingExpiry[userId]?.cancel();
            if (payload['typing'] != true) {
              _typingExpiry.remove(userId);
              if (mounted) setState(() => _typingUsers.remove(userId));
              return;
            }
            if (mounted) {
              setState(
                () => _typingUsers[userId] =
                    payload['displayName'] as String? ?? '',
              );
            }
            _typingExpiry[userId] = Timer(const Duration(seconds: 3), () {
              _typingExpiry.remove(userId);
              if (mounted) setState(() => _typingUsers.remove(userId));
            });
          });
        },
        onReconnected: () {
          // STOMP no reentrega mensajes publicados mientras el socket estuvo caído — sin este
          // refetch, un mensaje de otra persona (o el eco del propio, si se perdió la
          // reconexión) podía tardar minutos en aparecer, hasta el próximo refresh manual de
          // la pantalla. `_liveMessages` no se limpia: el merge en `_mergeMessages` deduplica
          // por id, así que no importa si algo queda repetido entre el fetch fresco y lo ya
          // acumulado por WebSocket.
          if (mounted) ref.invalidate(roomMessagesProvider(widget.roomId));
        },
      );
    Future.microtask(
      () => ref.read(liveProvider.notifier).watchRoom(widget.roomId),
    );
  }

  @override
  void dispose() {
    _channel?.dispose();
    for (final timer in _typingExpiry.values) {
      timer.cancel();
    }
    ref.read(liveProvider.notifier).unwatchRoom(widget.roomId);
    _draftController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Historial (REST) + mensajes recibidos por WebSocket, dedupeados por id — así no importa
  /// si un refetch tras reconectar (ver `onReconnected` arriba) trae de nuevo algo que ya
  /// habíamos agregado por STOMP, ni el orden en que lleguen ambas fuentes.
  List<ChatMessage> _mergeMessages(List<ChatMessage> pageItems) {
    final byId = <String, ChatMessage>{};
    for (final m in pageItems) {
      byId[m.id] = m;
    }
    for (final m in _liveMessages) {
      byId[m.id] = m;
    }
    final merged = byId.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return merged;
  }

  void _notifyTyping() {
    final now = DateTime.now();
    if (now.difference(_lastTypingPublish) < const Duration(seconds: 2)) return;
    _lastTypingPublish = now;
    _channel?.send('/app/rooms/${widget.roomId}/typing', {'typing': true});
  }

  /// Arma la lista mensajes+separadores de fecha, agrupando burbujas consecutivas del mismo
  /// autor (estilo Amino/Discord) para no repetir avatar/nombre en cada línea.
  List<Widget> _buildTimeline(List<ChatMessage> messages, String? myId) {
    final widgets = <Widget>[];
    DateTime? lastDay;
    for (var i = 0; i < messages.length; i++) {
      final message = messages[i];
      final day = DateTime(
        message.createdAt.year,
        message.createdAt.month,
        message.createdAt.day,
      );
      if (lastDay == null || day != lastDay) {
        widgets.add(_DateSeparator(date: day));
        lastDay = day;
      }
      final previous = i > 0 ? messages[i - 1] : null;
      final showHeader =
          previous == null ||
          previous.author?.id != message.author?.id ||
          message.createdAt.difference(previous.createdAt) >
              const Duration(minutes: 5) ||
          DateTime(
                previous.createdAt.year,
                previous.createdAt.month,
                previous.createdAt.day,
              ) !=
              day;
      widgets.add(
        _MessageBubble(
          message: message,
          isMe: message.author?.id == myId,
          showHeader: showHeader,
          onReply: message.type == MessageType.system ? null : _setPendingReply,
        ),
      );
    }
    return widgets;
  }

  void _setPendingReply(ChatMessage message) {
    setState(
      () => _pendingReplyTo = MessageReplyPreview(
        id: message.id,
        authorName: message.author?.displayName ?? 'Miembro',
        bodyPreview: message.imageUri != null && message.body.isEmpty
            ? 'Imagen'
            : message.body,
        deleted: false,
      ),
    );
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  /// Modelo de envío optimista: el mensaje aparece de inmediato como "enviando…" (nunca queda
  /// invisible mientras el POST está en vuelo), se reconcilia con el mensaje real que devuelve
  /// el backend (nunca se espera al eco de WebSocket para mostrarlo — si el socket está caído o
  /// reconectando, eso es justo lo que antes hacía que un mensaje ya guardado pareciera
  /// "perdido" varios minutos), y si falla queda marcado para reintentar sin perder el texto.
  Future<void> _send() async {
    final text = _draftController.text.trim();
    if (text.isEmpty) return;
    _draftController.clear();
    final localId = 'local-${_localIdSeq++}';
    final replyToMessageId = _pendingReplyTo?.id;
    setState(() {
      _pending.add(
        _PendingMessage(
          localId: localId,
          body: text,
          status: _SendStatus.sending,
          replyToMessageId: replyToMessageId,
        ),
      );
      _pendingReplyTo = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    await _attemptSend(localId, text, replyToMessageId);
  }

  Future<void> _attemptSend(
    String localId,
    String text,
    String? replyToMessageId,
  ) async {
    try {
      final sent = await ref
          .read(chatRepositoryProvider)
          .sendMessage(
            widget.roomId,
            text,
            replyToMessageId: replyToMessageId,
          );
      if (!mounted) return;
      setState(() {
        _pending.removeWhere((p) => p.localId == localId);
        // El eco por WebSocket de este mismo mensaje va a llegar también — `_mergeMessages`
        // lo dedupea por id, así que agregarlo ya mismo (en vez de esperar el socket) es lo
        // que hace que se vea "enviado" al instante en vez de recién cuando llegue el eco.
        _liveMessages.add(sent);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final idx = _pending.indexWhere((p) => p.localId == localId);
        if (idx != -1) {
          _pending[idx] = _pending[idx].copyWith(status: _SendStatus.failed);
        }
      });
    }
  }

  void _retry(String localId) {
    final idx = _pending.indexWhere((p) => p.localId == localId);
    if (idx == -1) return;
    final text = _pending[idx].body;
    final replyToMessageId = _pending[idx].replyToMessageId;
    setState(
      () => _pending[idx] = _pending[idx].copyWith(status: _SendStatus.sending),
    );
    _attemptSend(localId, text, replyToMessageId);
  }

  void _discardFailed(String localId) {
    setState(() => _pending.removeWhere((p) => p.localId == localId));
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
      _autoJoinAttempted = true;
      await ref.read(liveProvider.notifier).join(room.id);
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

    // Auto-unirse como audiencia al entrar a una sala con LIVE activo — 1:1 con el efecto de
    // menzoweb/app/(app)/chat/[id]/page.tsx que evita que el usuario tenga que tocar "Escuchar"
    // manualmente cada vez que entra a un chat que ya tiene un LIVE en curso. Se prioriza
    // `live.viewingState` (actualizado en tiempo real por `watchRoom`, ver live_provider.dart)
    // por sobre `room.live` (solo el snapshot REST del momento en que se abrió la pantalla) —
    // si alguien inicia un LIVE mientras esta pantalla ya está abierta, `room.live` se queda
    // congelado en `false` para siempre y este efecto nunca se disparaba.
    final isThisRoomLive = live.watchedRoomId == widget.roomId
        ? live.viewingState?.status == 'ACTIVE'
        : roomAsync.maybeWhen(data: (room) => room.live, orElse: () => false);
    if (isThisRoomLive &&
        !_autoJoinAttempted &&
        !live.connecting &&
        live.activeRoomId != widget.roomId) {
      _autoJoinAttempted = true;
      Future.microtask(
        () => ref.read(liveProvider.notifier).join(widget.roomId),
      );
    }

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
              if (isThisRoomLive) {
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
      body: Stack(
        children: [
          if (roomAsync.value?.backgroundUri != null &&
              roomAsync.value!.backgroundUri!.isNotEmpty) ...[
            Positioned.fill(
              child: Image.network(
                roomAsync.value!.backgroundUri!,
                fit: BoxFit.cover,
              ),
            ),
            const Positioned.fill(child: ColoredBox(color: Color(0x9E07090D))),
          ],
          Column(
            children: [
              Expanded(
                child: messagesAsync.when(
                  data: (page) {
                    final all = _mergeMessages(page.items);
                    if (all.isEmpty && _pending.isEmpty) {
                      return const Center(
                        child: MenziIllustrationState(
                          image: MenziIllustration.chat,
                          title: 'Aún no hay mensajes aquí',
                          description: 'Sé el primero en escribir algo.',
                          size: MenziIllustrationSize.small,
                        ),
                      );
                    }
                    final timeline = _buildTimeline(all, myId)
                      ..addAll(
                        _pending.map(
                          (p) => _PendingMessageBubble(
                            pending: p,
                            onRetry: () => _retry(p.localId),
                            onDiscard: () => _discardFailed(p.localId),
                          ),
                        ),
                      );
                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: timeline.length,
                      itemBuilder: (context, i) => timeline[i],
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: GestureDetector(
                    onTap: () => roomAsync.maybeWhen(
                      data: _openLivePanel,
                      orElse: () {},
                    ),
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
              if (_typingUsers.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _typingUsers.length == 1
                          ? '${_typingUsers.values.first} está escribiendo…'
                          : '${_typingUsers.length} personas están escribiendo…',
                      style: AppTextStyles.caption(color: AppColors.textMuted),
                    ),
                  ),
                ),
              if (_pendingReplyTo != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: const Border(
                        left: BorderSide(color: AppColors.cyan, width: 2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Respondiendo a ${_pendingReplyTo!.authorName}',
                                style: AppTextStyles.caption(
                                  color: AppColors.cyan,
                                ).copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                _pendingReplyTo!.bodyPreview ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.caption(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              setState(() => _pendingReplyTo = null),
                          icon: const Icon(Icons.close, size: 16),
                          tooltip: 'Cancelar respuesta',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
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
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (_) => _notifyTyping(),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _send,
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
        ],
      ),
    );
  }
}

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final isToday =
        date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    final yesterday = today.subtract(const Duration(days: 1));
    final isYesterday =
        date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
    final label = isToday
        ? 'Hoy'
        : isYesterday
        ? 'Ayer'
        : DateFormat('d MMMM', 'es_MX').format(date);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceSecondary,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(label, style: AppTextStyles.caption()),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.showHeader,
    this.onReply,
  });
  final ChatMessage message;
  final bool isMe;
  final bool showHeader;
  /// Ausente para mensajes de sistema — ahí no tiene sentido responder.
  final ValueChanged<ChatMessage>? onReply;

  void _showReplySheet(BuildContext context) {
    showMenzoSheet<void>(
      context: context,
      title: 'Mensaje',
      builder: (context) => ListTile(
        leading: const Icon(Icons.reply_outlined, color: AppColors.textPrimary),
        title: const Text('Responder'),
        onTap: () {
          Navigator.of(context).maybePop();
          onReply?.call(message);
        },
      ),
    );
  }

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
    final hasImage = message.imageUri != null && message.imageUri!.isNotEmpty;
    final replyTo = message.replyTo;
    final bubbleContent = Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: hasImage
          ? const EdgeInsets.all(4)
          : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.72,
      ),
      decoration: BoxDecoration(
        color: isMe ? AppColors.orange : AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isMe && showHeader)
            Padding(
              padding: const EdgeInsets.only(bottom: 2, left: 2),
              child: Text(
                message.author?.displayName ?? '',
                style: AppTextStyles.caption(color: AppColors.cyan),
              ),
            ),
          if (replyTo != null)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border(
                  left: BorderSide(
                    color: isMe ? Colors.black45 : AppColors.cyan,
                    width: 2,
                  ),
                ),
              ),
              child: replyTo.deleted
                  ? Text(
                      'Mensaje eliminado',
                      style: AppTextStyles.caption(
                        color: isMe
                            ? Colors.black.withValues(alpha: 0.6)
                            : AppColors.textMuted,
                      ).copyWith(fontStyle: FontStyle.italic),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          replyTo.authorName ?? '',
                          style: AppTextStyles.caption(
                            color: isMe ? Colors.black87 : AppColors.cyan,
                          ).copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          replyTo.bodyPreview ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption(
                            color: isMe
                                ? Colors.black.withValues(alpha: 0.7)
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
            ),
          if (hasImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: CachedNetworkImage(
                imageUrl: message.imageUri!,
                fit: BoxFit.cover,
                width: 220,
                placeholder: (context, url) => const SizedBox(
                  width: 220,
                  height: 160,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
          if (message.body.isNotEmpty)
            Padding(
              padding: hasImage
                  ? const EdgeInsets.fromLTRB(8, 6, 8, 4)
                  : EdgeInsets.zero,
              child: Text(
                message.body,
                style: AppTextStyles.body(
                  color: isMe ? Colors.black : AppColors.textPrimary,
                ),
              ),
            ),
        ],
      ),
    );
    final bubble = GestureDetector(
      onLongPress: onReply == null ? null : () => _showReplySheet(context),
      child: bubbleContent,
    );

    if (isMe) {
      return Align(alignment: Alignment.centerRight, child: bubble);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: 32,
            child: showHeader
                ? MenzoAvatar(
                    name: message.author?.displayName ?? '?',
                    avatarUri: message.author?.avatarUri,
                    gradient: gradientIdFromName(
                      message.author?.avatarGradient,
                    ),
                    size: 28,
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Flexible(child: bubble),
        ],
      ),
    );
  }
}

enum _SendStatus { sending, failed }

class _PendingMessage {
  const _PendingMessage({
    required this.localId,
    required this.body,
    required this.status,
    this.replyToMessageId,
  });
  final String localId;
  final String body;
  final _SendStatus status;
  final String? replyToMessageId;

  _PendingMessage copyWith({_SendStatus? status}) => _PendingMessage(
    localId: localId,
    body: body,
    status: status ?? this.status,
    replyToMessageId: replyToMessageId,
  );
}

/// Burbuja de un mensaje todavía no confirmado por el backend — "enviando…" con spinner, o
/// "no se pudo enviar" con reintentar/descartar si falló. Nunca queda un mensaje invisible
/// mientras el POST está en vuelo, y nunca se envía silenciosamente minutos después sin mostrar
/// su estado (ver `_send`/`_attemptSend` más arriba).
class _PendingMessageBubble extends StatelessWidget {
  const _PendingMessageBubble({
    required this.pending,
    required this.onRetry,
    required this.onDiscard,
  });
  final _PendingMessage pending;
  final VoidCallback onRetry;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final failed = pending.status == _SendStatus.failed;
    return Align(
      alignment: Alignment.centerRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            decoration: BoxDecoration(
              color: failed
                  ? AppColors.coral.withValues(alpha: 0.25)
                  : AppColors.orange.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Text(
              pending.body,
              style: AppTextStyles.body(
                color: failed ? AppColors.textPrimary : Colors.black,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: failed
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 12,
                        color: AppColors.coral,
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: onRetry,
                        child: Text(
                          'No se pudo enviar · Reintentar',
                          style: AppTextStyles.caption(color: AppColors.coral),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: onDiscard,
                        child: Icon(
                          Icons.close,
                          size: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      ),
                      const SizedBox(width: 6),
                      Text('Enviando…', style: AppTextStyles.caption()),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
