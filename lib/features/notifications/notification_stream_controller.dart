import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/stomp_service.dart';
import '../../core/notifications/local_notifications.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/router/app_router.dart';
import '../../data/models/community_models.dart';
import '../chat/chat_list_screen.dart';
import 'notifications_screen.dart';

/// Empuje en tiempo real de notificaciones (mensajes directos, seguidores, comentarios/likes,
/// LIVE iniciado) — se suscribe a `/topic/users/{miId}/notifications` (mismo patrón de tópico
/// por entidad que ya usan sala/LIVE/música, ver menzoapi NotificationService) y muestra una
/// notificación nativa de Android por cada evento mientras la app sigue con vida (foreground o
/// segundo plano con el proceso activo). Esto NO es push real vía FCM — si la app está
/// completamente cerrada no llega nada hasta reabrirla; ver la conversación sobre por qué (no
/// hay proyecto de Firebase configurado todavía).
class NotificationStreamController {
  NotificationStreamController(this.ref) {
    LocalNotifications.init(onTap: _handleTap);
    ref.listen<AuthState>(authProvider, (previous, next) {
      final userId = next.profile?.id;
      if (userId == previous?.profile?.id) return;
      _teardown();
      if (userId != null) _setup(userId);
    }, fireImmediately: true);
  }

  final Ref ref;
  StompChannel? _channel;

  void _setup(String userId) {
    final channel = StompChannel();
    _channel = channel;
    channel.connect(
      onConnected: () {
        channel.subscribe('/topic/users/$userId/notifications', _handleEvent);
      },
    );
  }

  void _teardown() {
    _channel?.dispose();
    _channel = null;
  }

  void _handleEvent(Map<String, dynamic> payload) {
    AppNotification notification;
    try {
      notification = AppNotification.fromJson(payload);
    } catch (_) {
      return;
    }
    // El badge/lista de la pantalla de notificaciones vive de un FutureProvider con fetch
    // manual — sin invalidarlo acá, un mensaje/seguidor nuevo no aparecería ahí hasta que el
    // usuario refresque la pantalla a mano.
    ref.invalidate(notificationsListProvider);
    if (notification.category == NotificationCategory.mensajes) {
      // La bandeja de chats (myRoomsProvider) también vive de un fetch manual — sin esto, un
      // mensaje nuevo en OTRO chat no reordenaba la bandeja (el chat no subía al primer lugar)
      // hasta que el usuario la reabriera a mano. El backend ya devuelve la lista ordenada por
      // actividad más reciente (ver ChatService.INBOX_ORDER), así que un refetch simple alcanza
      // — no hace falta reordenar la lista localmente a mano.
      ref.invalidate(myRoomsProvider);
    }
    LocalNotifications.show(
      id: notification.id.hashCode & 0x7fffffff,
      title: notification.title,
      body: notification.body,
      payload: jsonEncode({
        'relatedPostId': notification.relatedPostId,
        'relatedRoomId': notification.relatedRoomId,
        'relatedUserId': notification.relatedUserId,
        'relatedEventId': notification.relatedEventId,
      }),
    );
  }

  void _handleTap(String? payload) {
    if (payload == null) return;
    Map<String, dynamic> data;
    try {
      data = jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final router = ref.read(appRouterProvider);
    if (data['relatedPostId'] != null) {
      router.push('/post/${data['relatedPostId']}');
    } else if (data['relatedRoomId'] != null) {
      router.push('/chat/${data['relatedRoomId']}');
    } else if (data['relatedUserId'] != null) {
      router.push('/member/${data['relatedUserId']}');
    } else if (data['relatedEventId'] != null) {
      router.push('/events/${data['relatedEventId']}');
    }
  }

  void dispose() => _teardown();
}

final notificationStreamControllerProvider =
    Provider<NotificationStreamController>((ref) {
      final controller = NotificationStreamController(ref);
      ref.onDispose(controller.dispose);
      return controller;
    });
