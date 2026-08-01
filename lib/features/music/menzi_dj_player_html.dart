/// Espejo de YT.PlayerState del IFrame API oficial — el reproductor real vive en
/// `menzoweb/public/menzi-player.html` (servido de verdad vía HTTPS y cargado con
/// `WebViewController.loadRequest`, ver `AppConfig.menziDjPlayerUrl` y
/// `MenziDjNotifier.controller`). Esta clase y [YtPlayerError] solo son el espejo Dart de los
/// valores que ese HTML manda por el bridge — ya no generamos el documento del player in-process
/// acá: un documento HTML creado con `loadHtmlString`/`baseUrl` no garantiza que Android WebView
/// mande un HTTP Referer válido en los pedidos internos que hace el iframe de YouTube, y eso es
/// justo lo que produce el error 153 (ver [YtPlayerError.missingClientIdentity]).
class YtPlayerState {
  YtPlayerState._();
  static const unstarted = -1;
  static const ended = 0;
  static const playing = 1;
  static const paused = 2;
  static const buffering = 3;
  static const cued = 5;
}

/// Códigos documentados de `onError` del IFrame Player API oficial
/// (https://developers.google.com/youtube/iframe_api_reference#onError).
class YtPlayerError {
  YtPlayerError._();

  /// Parámetro de request inválido — normalmente un `videoId` malformado.
  static const invalidParam = 2;

  /// El reproductor HTML5 tiró un error interno.
  static const html5Error = 5;

  /// Video no encontrado, privado o eliminado.
  static const notFound = 100;

  /// El dueño del video no permite reproducción embebida (dos códigos distintos, mismo motivo).
  static const embedNotAllowed = 101;
  static const embedNotAllowed2 = 150;

  /// 153 — código REAL y documentado de la YouTube IFrame Player API (no una invención ni un
  /// código inventado por Menzo): el pedido del embed llegó sin poder identificar el origen/
  /// Referer del cliente ante YouTube. No tiene nada que ver con el video en sí — el mismo video
  /// puede reproducirse perfectamente en youtube.com o en menzoweb. Nunca debe tratarse como
  /// "este video no es embebible" (eso son 101/150): no hay que marcarlo como restringido, no
  /// saltar de canción automáticamente, no levantar un segundo reproductor — hay que corregir el
  /// origen/Referer de la página que sirve el iframe (ver menzoDjPlayerHtml.md /
  /// menzoweb/public/menzi-player.html) y permitir reintentar.
  static const missingClientIdentity = 153;

  static bool isEmbedRestricted(int code) =>
      code == embedNotAllowed || code == embedNotAllowed2;

  static String describe(int code) => switch (code) {
    invalidParam => 'Parámetro de video inválido.',
    html5Error => 'Error interno del reproductor.',
    notFound => 'Este video no está disponible (eliminado o privado).',
    embedNotAllowed || embedNotAllowed2 =>
      'El propietario de este video no permite reproducirlo embebido.',
    missingClientIdentity =>
      'El reproductor móvil no pudo identificarse correctamente ante YouTube.',
    _ => 'No pudimos reproducir este video (código $code).',
  };
}
