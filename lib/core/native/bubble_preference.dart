import 'package:shared_preferences/shared_preferences.dart';

/// Preferencia local (no vive en menzoapi, es puramente de este dispositivo) de si el usuario
/// aceptó la burbuja flotante del LIVE — se pide contextualmente al entrar a un LIVE, nunca en
/// el primer inicio de la app (ver `LiveBubbleController`/`live_room_panel.dart`).
class BubblePreference {
  BubblePreference._();

  static const _keyEnabled = 'live_bubble_enabled';

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyEnabled) ?? false;
  }

  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, value);
  }
}
