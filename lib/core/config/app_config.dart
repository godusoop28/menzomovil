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

  /// Origen HTTPS real donde vive la página del reproductor de Menzi DJ (ver
  /// menziDjPlayerUrl) — el WebView carga esa página de verdad vía `loadRequest`, ya NO con
  /// `loadHtmlString`/`baseUrl` (un documento generado in-process con un origen sintético no
  /// garantiza que Android WebView mande un HTTP Referer válido en los pedidos internos que hace
  /// el iframe de YouTube, y ESO es lo que produce el error 153 — "missing Referer/API client
  /// identity" — que es un código real y documentado de la YouTube IFrame Player API, no una
  /// invención). Debe coincidir exactamente con el origen real que sirve esa página.
  static const String menziDjOrigin = String.fromEnvironment(
    'MENZI_DJ_ORIGIN',
    defaultValue: 'https://menzoweb.vercel.app',
  );

  /// URL completa de la página estática del reproductor — ver
  /// menzoweb/public/menzi-player.html.
  static String get menziDjPlayerUrl => '$menziDjOrigin/menzi-player.html';
}
