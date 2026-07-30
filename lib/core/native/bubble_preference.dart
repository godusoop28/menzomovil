import 'package:shared_preferences/shared_preferences.dart';

/// Preferencia local (no vive en menzoapi, es puramente de este dispositivo) de si el usuario
/// aceptó la burbuja flotante del LIVE — se pide una sola vez, contextualmente, nunca en el
/// primer inicio de la app (ver `LiveBubbleController`/`live_room_panel.dart`).
class BubblePreference {
  BubblePreference._();

  static const _keyEnabled = 'live_bubble_enabled';
  static const _keyPrompted = 'live_bubble_prompted';

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyEnabled) ?? false;
  }

  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, value);
  }

  static Future<bool> hasBeenPrompted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyPrompted) ?? false;
  }

  static Future<void> markPrompted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPrompted, true);
  }
}
