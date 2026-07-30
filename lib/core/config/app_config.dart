/// Config del entorno — reemplaza el `EXPO_PUBLIC_API_URL` de `.env` del proyecto RN.
/// Se puede sobrescribir en build/run con `--dart-define=API_BASE_URL=https://...`
/// sin tener que tocar código ni empaquetar un `.env` como asset.
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://menzoapi.onrender.com',
  );

  static String get wsUrl =>
      apiBaseUrl.replaceFirst(RegExp(r'^http'), 'ws') + '/ws';
}
