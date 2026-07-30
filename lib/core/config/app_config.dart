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

  /// Origen HTTPS que se le da al WebView de Menzi DJ (como `baseUrl` de `loadHtmlString` y como
  /// `origin` en los `playerVars` del IFrame Player). Sin esto el WebView carga la página con un
  /// origen nulo/opaco (`about:blank`-like) y el embed de YouTube la rechaza con "Error 153 —
  /// Error de configuración del reproductor de video", aunque el video sea perfectamente
  /// reproducible en youtube.com. No hace falta que este dominio esté registrado en ningún lado
  /// para este propósito puntual — el iframe API solo necesita un origen HTTP(S) bien formado
  /// que coincida entre `baseUrl` y `origin`; alcanza con un dominio real controlado por Menzo.
  static const String menziDjOrigin = String.fromEnvironment(
    'MENZI_DJ_ORIGIN',
    defaultValue: 'https://menzoweb.vercel.app',
  );
}
