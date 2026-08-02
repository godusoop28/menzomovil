/// `Uri.parse('wss://host/path').port` (y lo mismo para `ws://`) devuelve `0` cuando la URL no
/// trae un puerto explícito — a diferencia de `http`/`https`, el esquema `ws`/`wss` NO tiene un
/// puerto por defecto en la tabla que usa `package:core`'s `Uri`. Ese `0` "calculado" quedaba
/// después horneado como puerto EXPLÍCITO en la URL real que arma `dart:io`'s `WebSocket.connect`
/// para el handshake HTTP de upgrade (a diferencia de un puerto ausente en el string original,
/// uno fijado a mano vía `Uri(..., port: 0, ...)` SÍ se serializa como `:0`) — de ahí el
/// `https://menzoapi.onrender.com:0/ws#` real visto en los logs, y los `WebSocketException`/
/// `HTTP status code: 500` que le siguen (nada escucha en el puerto 0). Construir la URL acá con
/// el puerto SIEMPRE explícito (443 para wss, 80 para ws, o el que ya traiga `apiBaseUrl`) evita
/// que ese `0` implícito llegue a existir en ningún punto de la cadena.
String buildWebSocketUrl(String apiBaseUrl, {String path = '/ws'}) {
  final apiUri = Uri.parse(apiBaseUrl);
  final isSecure = apiUri.scheme == 'https';
  final port = apiUri.hasPort ? apiUri.port : (isSecure ? 443 : 80);
  return Uri(
    scheme: isSecure ? 'wss' : 'ws',
    host: apiUri.host,
    port: port,
    path: path,
  ).toString();
}

/// Config del entorno — reemplaza el `EXPO_PUBLIC_API_URL` de `.env` del proyecto RN.
/// Se puede sobrescribir en build/run con `--dart-define=API_BASE_URL=https://...`
/// sin tener que tocar código ni empaquetar un `.env` como asset.
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://menzoapi.onrender.com',
  );

  static String get wsUrl => buildWebSocketUrl(apiBaseUrl);

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

  /// Commit corto de este build — se pasa al compilar con
  /// `--dart-define=GIT_COMMIT=$(git rev-parse --short HEAD)` (ver device_info_snapshot.dart).
  /// Sin ese define queda "unknown" en vez de inventar un valor — el log [BUILD]/el TXT
  /// exportado nunca deben sugerir que se confirmó un commit que en realidad no se pasó.
  static const String gitCommit = String.fromEnvironment(
    'GIT_COMMIT',
    defaultValue: 'unknown',
  );
}
