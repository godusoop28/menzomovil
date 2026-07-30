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

  Future<String?> get cachedProfileJson async =>
      (await _ensure()).getString(_keyCachedProfileJson);
  Future<void> setCachedProfileJson(String json) async =>
      (await _ensure()).setString(_keyCachedProfileJson, json);

  Future<bool> get onboardingCompleted async =>
      (await _ensure()).getBool(_keyOnboardingCompleted) ?? false;
  Future<void> setOnboardingCompleted(bool value) async =>
      (await _ensure()).setBool(_keyOnboardingCompleted, value);

  Future<void> clear() async => (await _ensure()).clear();
}
