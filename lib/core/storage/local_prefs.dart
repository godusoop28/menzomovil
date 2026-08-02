import 'dart:ui' show Offset;

import 'package:shared_preferences/shared_preferences.dart';

/// Cache liviana no sensible (a diferencia de [SessionStorage], que guarda los tokens cifrados).
/// Se usa solo para pintar algo instantáneo antes de que responda `usersApi.me()` — igual que
/// el `localStorage.getItem("menzo.profile")` de la web.
class LocalPrefs {
  LocalPrefs._();
  static final LocalPrefs instance = LocalPrefs._();

  SharedPreferences? _prefs;

  Future<SharedPreferences> _ensure() async =>
      _prefs ??= await SharedPreferences.getInstance();

  static const _keyCachedProfileJson = 'menzo.cachedProfileJson';
  static const _keyOnboardingCompleted = 'menzo.onboardingCompleted';
  static const _keyVoiceBubbleHidden = 'menzo.voiceBubbleHidden';
  static const _keyVoiceBubbleFractionX = 'menzo.voiceBubbleFractionX';
  static const _keyVoiceBubbleFractionY = 'menzo.voiceBubbleFractionY';

  Future<String?> get cachedProfileJson async =>
      (await _ensure()).getString(_keyCachedProfileJson);
  Future<void> setCachedProfileJson(String json) async =>
      (await _ensure()).setString(_keyCachedProfileJson, json);

  Future<bool> get onboardingCompleted async =>
      (await _ensure()).getBool(_keyOnboardingCompleted) ?? false;
  Future<void> setOnboardingCompleted(bool value) async =>
      (await _ensure()).setBool(_keyOnboardingCompleted, value);

  /// Preferencias puramente visuales de la burbuja flotante del LIVE (ver
  /// features/live/persistent_voice_bubble.dart) — nunca permisos/roles/sanciones, esos vienen
  /// siempre del backend.
  Future<bool> get voiceBubbleHidden async =>
      (await _ensure()).getBool(_keyVoiceBubbleHidden) ?? false;
  Future<void> setVoiceBubbleHidden(bool value) async =>
      (await _ensure()).setBool(_keyVoiceBubbleHidden, value);

  /// Posición guardada como fracción (0.0-1.0) del área de arrastre disponible, no en píxeles
  /// crudos — así sigue siendo válida si el usuario rota la pantalla o cambia de dispositivo.
  Future<Offset?> get voiceBubblePositionFraction async {
    final prefs = await _ensure();
    final dx = prefs.getDouble(_keyVoiceBubbleFractionX);
    final dy = prefs.getDouble(_keyVoiceBubbleFractionY);
    if (dx == null || dy == null) return null;
    return Offset(dx, dy);
  }

  Future<void> setVoiceBubblePositionFraction(Offset value) async {
    final prefs = await _ensure();
    await prefs.setDouble(_keyVoiceBubbleFractionX, value.dx);
    await prefs.setDouble(_keyVoiceBubbleFractionY, value.dy);
  }

  Future<void> clear() async => (await _ensure()).clear();
}
