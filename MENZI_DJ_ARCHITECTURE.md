# Arquitectura de Menzi DJ (menzomovil)

## Estado actual: una única instancia de reproducción por dispositivo

Hasta esta versión, Menzi DJ tenía **dos reproductores independientes** por
dispositivo:

1. El WebView de Flutter (`webview_flutter`), montado en primer plano.
2. Un WebView nativo de Android (`MenziDjBackgroundPlayer.kt`), montado en una
   ventana overlay separada y activado al minimizar la app
   (`MenziDjBackgroundChannel`).

En pruebas reales con dos dispositivos esto produjo un **split-brain**
confirmado:

- El segundo usuario no escuchaba música dentro de la app, pero sí al
  minimizarla (el reproductor nativo tomaba la posta ahí).
- Una pausa del OWNER/CO_HOST no detenía el audio del segundo dispositivo si
  estaba en segundo plano — el reproductor nativo no seguía confiablemente
  pause/resume/seek/skip/stop remotos.
- El volumen del reproductor nativo no respondía al control local del
  usuario.

**Se retiró por completo el reproductor nativo de fondo.** Archivos
eliminados: `MenziDjBackgroundPlayer.kt`,
`lib/core/native/menzi_dj_background_channel.dart`, y el `MethodChannel`
`com.sega2028.menzomovil/menzi_dj_background` en `MainActivity.kt`. Ya no
existe ningún WebView de YouTube aparte del único que vive en
`MenziDjPlayerHost` (ver `lib/features/music/menzi_dj_player_host.dart`).

## Comportamiento actual

- **Dentro de la app**: Menzi DJ se reproduce y se sincroniza normalmente vía
  STOMP + snapshots versionados (ver `menzi_dj_provider.dart`).
- **Al minimizar**: la música LOCAL se pausa (`_handleAppBackgrounded`). No se
  toca el estado global — el resto de la sala sigue escuchando normalmente.
  El LIVE de voz (Agora) y su foreground service (`BackgroundAudioService`,
  independiente de Menzi DJ) siguen funcionando en segundo plano sin cambios.
- **Al volver**: se pide el snapshot real al servidor (`refresh()`) y se
  reconcilia — video, posición, play/pause — contra lo que el WebView (que
  nunca se destruyó, solo estaba pausado) todavía tenía cargado. Nunca se usa
  la posición congelada de antes de minimizar como autoridad.

## Por qué el WebView foreground no sonaba dentro de la app

Además del split-brain, se encontró una causa concreta adicional en
`MenziDjPlayerHost`: cuando el panel de Menzi DJ no estaba expandido (el
estado normal la mayoría del tiempo — mini-bar colapsada), el WebView se
renderizaba a **1×1 píxel con `Opacity: 0`**. Un WebView de Android
(Chromium) con una superficie de renderizado prácticamente nula puede
tratarse como una vista inactiva y suspender no solo su render sino también
su reproducción — coincide con el síntoma exacto reportado ("no escucha
dentro de la app, sí al minimizar", ya que al minimizar el reproductor nativo
—ahora eliminado— sí tenía tamaño real).

Corrección: el WebView oculto ahora se posiciona **fuera del viewport**
(coordenadas negativas) pero conservando las **mismas dimensiones reales**
que el estado expandido — visible para Chromium, invisible para el usuario.
Nunca más tamaño 1×1 ni `Opacity: 0` para "mantener" audio.

## Volumen y mute — siempre locales

`localVolume`/`localMuted` (ver `MenziDjState`) nunca se envían al backend.
Cada dispositivo controla su propio volumen de Menzi DJ de forma
independiente del volumen de la llamada de Agora y de lo que hagan los demás
participantes. El control global (play/pause/seek/skip/stop/track) sigue
siendo exclusivo de OWNER/CO_HOST, vía menzoapi.

## Limitación conocida y honesta

**No hay música verdaderamente persistente en segundo plano** (tipo Discord)
en esta versión. Mientras la app está minimizada, cada dispositivo deja de
reproducir Menzi DJ — solo la voz de Agora continúa. Esto es una decisión
deliberada: la alternativa (un segundo WebView de YouTube en background) es
la arquitectura que se acaba de retirar por ser estructuralmente poco
confiable.

Para música realmente persistente en segundo plano, similar a un bot de
Discord, se necesitaría en una fase futura:

- una fuente de audio autorizada (no dos instancias de un IFrame Player de
  YouTube);
- un proceso "bot" dedicado que publique un único track de audio;
- un único publicador RTC hacia el canal de Agora (custom audio track o un
  media player autorizado del lado del servidor);
- todos los participantes reciben ese audio por el mismo canal de Agora que
  ya usan para la voz, en vez de cada dispositivo reproduciendo su propia
  copia de YouTube.

**No se debe usar la YouTube Data API ni el IFrame Player para extraer o
retransmitir audio** — eso viola los términos de servicio de YouTube. Este
documento existe para dejar constancia de la limitación, no para proponer
esa alternativa.
