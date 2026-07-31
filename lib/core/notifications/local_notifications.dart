import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notificaciones nativas de Android disparadas por la propia app mientras sigue corriendo
/// (foreground o en segundo plano con el proceso vivo, igual que ya sostenemos el audio de
/// Menzi DJ/LIVE) — no es push real vía FCM: si la app está completamente cerrada o el
/// teléfono se reinició, no llega nada hasta que se vuelva a abrir. Ver
/// `NotificationStreamController`, que es quien decide CUÁNDO mostrar una.
class LocalNotifications {
  LocalNotifications._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _channelId = 'menzo_notifications';

  /// [onTap] recibe el `payload` tal cual se pasó a [show] — se usa para navegar a la sala/post/
  /// perfil relacionado cuando el usuario toca la notificación.
  static Future<void> init({required void Function(String? payload) onTap}) async {
    if (_initialized) return;
    _initialized = true;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings),
      onDidReceiveNotificationResponse: (response) => onTap(response.payload),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            'Menzo',
            description: 'Mensajes, seguidores, LIVEs y novedades de Menzo.',
            importance: Importance.high,
          ),
        );
  }

  static Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) return;
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Menzo',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: payload,
    );
  }
}
