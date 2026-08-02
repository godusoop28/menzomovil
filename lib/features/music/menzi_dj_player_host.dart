import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemChrome, SystemUiMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/router/app_router.dart';
import '../../core/router/current_location.dart';
import '../../core/storage/local_prefs.dart';
import '../../data/models/live_models.dart';
import '../live/live_provider.dart';
import 'menzi_dj_provider.dart';
import 'menzi_player_display_mode.dart';

/// Ruta de [YouTubeMobileDiagnosticScreen] (ver core/router/app_router.dart) — esa pantalla
/// monta su PROPIO WebViewController/YT.Player aislado a propósito (sin LIVE/STOMP/Agora), pero
/// `_RootOverlays` (app.dart) sigue envolviendo esa ruta igual que cualquier otra, así que sin
/// este chequeo el player global de acá abajo también queda visible encima — dos reproductores
/// de YouTube superpuestos en pantalla al mismo tiempo (uno real, uno de diagnóstico), que es
/// exactamente la duplicación reportada. No es un bug de instancias duplicadas del MISMO player:
/// son dos widgets distintos, cada uno con su propio WebView, montados a la vez sin querer.
const _diagnosticRoute = '/debug/youtube-player';

/// Tamaños del modo mini/oculto — dos presets discretos, no resize libre: redimensionar en vivo
/// una superficie respaldada por `PlatformView` (el WebView nativo) a mitad de gesto arriesga
/// glitches de composición en Android/iOS, y ningún otro elemento arrastrable de esta app soporta
/// resize tampoco (ver MenzoFloatingBubble, solo posición). Se persiste en LocalPrefs.
enum _MiniSizePreset {
  compact(88, 88),
  expanded(200, 122);

  const _MiniSizePreset(this.width, this.height);
  final double width;
  final double height;

  _MiniSizePreset get toggled =>
      this == _MiniSizePreset.compact ? _MiniSizePreset.expanded : _MiniSizePreset.compact;

  static _MiniSizePreset fromName(String? name) => switch (name) {
    'expanded' => _MiniSizePreset.expanded,
    _ => _MiniSizePreset.compact,
  };
}

/// Único WebView del reproductor oficial de YouTube para toda la app — vive montado siempre (ver
/// AppShell) y NUNCA se destruye ni se vuelve a crear al navegar, minimizar o cambiar de modo
/// visual (ver [MenziPlayerDisplayMode]). 1:1 con menzoweb/components/music/MenziDjPlayerHost.tsx.
///
/// CAUSA RAÍZ CONFIRMADA (auditoría de widget tree, logs reales): la versión anterior tenía TRES
/// ramas `return` distintas (oculto/mini/expandido), cada una construyendo su PROPIO
/// `WebViewWidget(controller: controller)` en una posición estructuralmente distinta del árbol.
/// Aunque las tres pasaban el MISMO `controller`, Flutter reconcilia por TIPO en la misma
/// posición del árbol — al cambiar de rama el framework desmontaba el `WebViewWidget` viejo y
/// montaba uno nuevo, forzando a Android a destruir/recrear el `PlatformView` (la superficie
/// nativa real del WebView) — y ESO hacía que YouTube reportara `state=2` sin que existiera
/// ningún pause real: no era una pausa, era el WebView completo reapareciendo de cero.
///
/// La corrección: un ÚNICO árbol de widgets, con la MISMA forma estructural en todos los modos
/// (`Positioned > GestureDetector > ClipRRect > Stack > [Positioned.fill(WebViewWidget), extra?]`)
/// — el modo solo cambia propiedades (tamaño/posición/radio/si el GestureDetector reacciona a
/// arrastre/si hay una capa extra encima), nunca el TIPO ni la profundidad de los widgets. El
/// WebView siempre es el PRIMER hijo del Stack; todo lo demás (controles, drag-hint, tapa de
/// oculto) se agrega DESPUÉS, así que nunca perturba al WebView.
///
/// Fase de estabilización (mini-player bloqueaba pantalla / no se podía mover ni minimizar):
/// antes existían DOS widgets flotantes independientes — este WebView arrastrable-pero-diminuto
/// y, aparte, `MenziDjMiniBar` (una píldora NO arrastrable, sin botón de minimizar, cuyo rect por
/// defecto se superponía con el de este WebView). Se unificaron acá: el WebView sigue siendo la
/// única superficie de video, y sus controles (silenciar, play/pause, minimizar, cambiar tamaño)
/// ahora viven como una capa superpuesta sobre el mismo widget, nunca como un segundo elemento
/// flotante aparte. El aviso de "autoplay bloqueado" quedó en su propio widget chico
/// (menzi_dj_autoplay_banner.dart) porque es una alerta transversal que debe verse sin importar
/// modo/ruta, algo que ya no tenía sentido mezclar acá.
class MenziDjPlayerHost extends ConsumerStatefulWidget {
  const MenziDjPlayerHost({super.key});

  @override
  ConsumerState<MenziDjPlayerHost> createState() => _MenziDjPlayerHostState();
}

class _MenziDjPlayerHostState extends ConsumerState<MenziDjPlayerHost> {
  Offset? _miniPosition;
  _MiniSizePreset _preset = _MiniSizePreset.compact;
  static const _webViewKey = ValueKey('menzi-dj-webview-surface');

  @override
  void initState() {
    super.initState();
    debugPrint('[YT_VIEW] host mounted');
    _loadPreset();
  }

  Future<void> _loadPreset() async {
    final saved = await LocalPrefs.instance.djMiniSizePreset;
    if (!mounted || saved == null) return;
    setState(() => _preset = _MiniSizePreset.fromName(saved));
  }

  @override
  void dispose() {
    debugPrint('[YT_VIEW] host disposed');
    super.dispose();
  }

  void _togglePreset() {
    final next = _preset.toggled;
    setState(() {
      _preset = next;
      // El tamaño cambió — la posición guardada en píxeles podría quedar fuera de pantalla o
      // pisando otra cosa; se recalcula al vuelo en el próximo build a través de `_rectForMode`
      // usando el mismo `_miniPosition` (los clamps ahí ya cubren el nuevo tamaño).
    });
    LocalPrefs.instance.setDjMiniSizePreset(next.name);
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[YT_VIEW] host build');
    // Centralizado acá (no en el panel) para que el modo inmersivo del sistema se aplique sin
    // importar desde dónde se haya llamado `setDisplayMode(fullscreen)` — este widget es el
    // único punto que de verdad conoce la transición de/hacia fullscreen.
    ref.listen<MenziDjState>(menziDjProvider, (previous, next) {
      final wasFullscreen = previous?.displayMode == MenziPlayerDisplayMode.fullscreen;
      final isFullscreen = next.displayMode == MenziPlayerDisplayMode.fullscreen;
      if (isFullscreen && !wasFullscreen) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else if (!isFullscreen && wasFullscreen) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    });
    final music = ref.watch(menziDjProvider);
    final controller = ref.watch(menziDjProvider.notifier).controller;
    final location = ref.watch(currentLocationProvider);
    final live = ref.watch(liveProvider);

    // Sin canción: no hay nada que preservar (no hay video cargado en el WebView todavía), así
    // que este SÍ es un árbol legítimamente distinto — no es el caso que causaba el bug (ese
    // pasaba entre modos con una canción activa, alternando estructuras para el MISMO video en
    // reproducción). En la ruta de diagnóstico se oculta para no superponerse con el WebView
    // aislado de esa pantalla (ver comentario de `_diagnosticRoute`).
    if (!music.hasTrack || location == _diagnosticRoute) {
      return const Positioned(
        width: 1,
        height: 1,
        left: -10,
        top: -10,
        child: SizedBox.shrink(),
      );
    }

    final mode = music.displayMode;
    final screenSize = MediaQuery.sizeOf(context);
    final viewPadding = MediaQuery.paddingOf(context);
    // Antes en la sala del propio LIVE solo la píldora (ya eliminada) se ocultaba en esta ruta —
    // el WebView seguía ahí, en la zona de los controles de micrófono/salir (_LiveControls). Acá
    // se usa lo mismo para reposicionar en vez de solo para ocultar.
    final onLiveRoute = location == '/chat/${live.activeRoomId}';
    final rect = _rectForMode(mode, screenSize, viewPadding, onLiveRoute, music.videoSlotRect);
    final draggable = mode == MenziPlayerDisplayMode.mini;
    final borderRadius = switch (mode) {
      MenziPlayerDisplayMode.cinema || MenziPlayerDisplayMode.fullscreen => 0.0,
      _ => 16.0,
    };
    final canModerate =
        live.myRole == LiveParticipantRole.host || live.myRole == LiveParticipantRole.coHost;
    final isPlaying = music.session?.status.name == 'playing';

    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // `onPanUpdate` es `null` en todos los modos salvo `mini` — el tipo del widget
        // (`GestureDetector`) nunca cambia, solo si reacciona o no, así que esto jamás
        // desmonta lo que tiene debajo.
        onPanUpdate: draggable ? (details) => _onDrag(details, rect, screenSize) : null,
        // Tocar el video en mini abre la sala (mismo comportamiento que tenía la píldora vieja);
        // tocar la tapa de oculto solo restaura a mini — es la acción de menor fricción posible,
        // no hace falta saltar a la sala solo para volver a ver el video. Los botones de la franja
        // de controles (más abajo) ganan la arena de gestos frente a este tap ancestro, así que no
        // hay conflicto al tocar mute/ocultar/resize.
        onTap: switch (mode) {
          MenziPlayerDisplayMode.mini => () {
            ref.read(appRouterProvider).push('/chat/${live.activeRoomId}');
            ref.read(menziDjProvider.notifier).setDisplayMode(MenziPlayerDisplayMode.normal);
          },
          MenziPlayerDisplayMode.hidden => () =>
              ref.read(menziDjProvider.notifier).setDisplayMode(MenziPlayerDisplayMode.mini),
          _ => null,
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Stack(
            children: [
              // SIEMPRE el primer (y único hasta acá) hijo — nunca se mueve de posición en la
              // lista, así que nunca se ve afectado por que los hijos opcionales de abajo
              // aparezcan o desaparezcan (ver comentario de clase).
              Positioned.fill(
                child: IgnorePointer(
                  child: WebViewWidget(key: _webViewKey, controller: controller),
                ),
              ),
              if (mode == MenziPlayerDisplayMode.hidden) ...[
                // Fase 3: nunca 1×1/Offstage/Opacity 0 para "ocultar" — eso mismo (una
                // superficie de renderizado casi nula) es lo que Chromium trata como vista
                // inactiva y puede suspender la reproducción, no solo el render. Acá se cubre
                // con una capa opaca real, del mismo tamaño, sin tocar el WebView de abajo.
                const Positioned.fill(
                  child: ColoredBox(color: Color(0xFF07090D)),
                ),
                const Positioned.fill(
                  child: Center(
                    child: Icon(Icons.visibility_outlined, size: 22, color: Colors.white70),
                  ),
                ),
              ],
              if (draggable) ...[
                const Positioned(
                  right: 4,
                  top: 4,
                  child: IgnorePointer(
                    child: Icon(Icons.open_with, size: 14, color: Colors.white70),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _MiniControlStrip(
                    compact: _preset == _MiniSizePreset.compact,
                    muted: music.localMuted,
                    isPlaying: isPlaying,
                    canModerate: canModerate,
                    onToggleMute: () => ref.read(menziDjProvider.notifier).toggleLocalMute(),
                    onTogglePlay: () => isPlaying
                        ? ref.read(menziDjProvider.notifier).pauseTrack()
                        : ref.read(menziDjProvider.notifier).resumeTrack(),
                    onResize: _togglePreset,
                    onHide: () => ref
                        .read(menziDjProvider.notifier)
                        .setDisplayMode(MenziPlayerDisplayMode.hidden),
                  ),
                ),
              ],
              if (mode == MenziPlayerDisplayMode.fullscreen)
                Positioned(
                  right: 8,
                  top: 8,
                  child: SafeArea(
                    child: IconButton(
                      tooltip: 'Salir de pantalla completa',
                      onPressed: () => ref
                          .read(menziDjProvider.notifier)
                          .setDisplayMode(MenziPlayerDisplayMode.normal),
                      icon: const Icon(Icons.close, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _onDrag(DragUpdateDetails details, Rect current, Size screenSize) {
    final maxLeft = (screenSize.width - _preset.width).clamp(0.0, double.infinity);
    final maxTop = (screenSize.height - _preset.height).clamp(0.0, double.infinity);
    final next = current.topLeft + details.delta;
    setState(() {
      _miniPosition = Offset(
        next.dx.clamp(0.0, maxLeft),
        next.dy.clamp(0.0, maxTop),
      );
    });
  }

  Rect _rectForMode(
    MenziPlayerDisplayMode mode,
    Size screenSize,
    EdgeInsets viewPadding,
    bool onLiveRoute,
    Rect? videoSlotRect,
  ) {
    switch (mode) {
      case MenziPlayerDisplayMode.hidden:
      case MenziPlayerDisplayMode.mini:
        final width = _preset.width;
        final height = _preset.height;
        final maxLeft = (screenSize.width - width).clamp(0.0, double.infinity);
        final maxTop = (screenSize.height - height).clamp(0.0, double.infinity);
        // Sala del propio LIVE: `_LiveControls` (mic/salir) vive pegado al borde inferior — un
        // default ahí abajo es justo la colisión reportada. Se ancla arriba a la derecha, debajo
        // de la barra de esa pantalla, en vez de reservar un margen inferior que en pantallas
        // chicas o con el banner de "permiso de micrófono denegado" visible igual no alcanza.
        // Fuera del LIVE: abajo a la izquierda, dejando lugar a la NavigationBar (~80dp) + el
        // inset seguro del sistema — y deliberadamente del lado OPUESTO al default de
        // PersistentVoiceBubble (que arranca cerca del borde derecho, ver esa clase) para que
        // ninguno de los dos tape al otro por defecto.
        final defaultPosition = onLiveRoute
            ? Offset(maxLeft, 96)
            : Offset(8, maxTop - (viewPadding.bottom + 110));
        final position = _miniPosition ?? defaultPosition;
        return Rect.fromLTWH(
          position.dx.clamp(0.0, maxLeft),
          position.dy.clamp(0.0, maxTop),
          width,
          height,
        );
      case MenziPlayerDisplayMode.normal:
      case MenziPlayerDisplayMode.cinema:
        // El panel (menzi_dj_panel.dart) mide y reporta en tiempo real dónde debe ir el video
        // dentro de su propio contenido (reserva ese mismo espacio con un SizedBox para que el
        // resto de sus controles nunca quede tapado — ver MenziDjNotifier.reportVideoSlotRect).
        // Sin ese reporte todavía (primer frame, panel cerrándose) se cae a una posición
        // razonable cerca del tope de la pantalla en vez de desaparecer.
        if (videoSlotRect != null) return videoSlotRect;
        final width = screenSize.width - 32;
        return Rect.fromLTWH(16, 96, width, width * 9 / 16);
      case MenziPlayerDisplayMode.fullscreen:
        return Rect.fromLTWH(0, 0, screenSize.width, screenSize.height);
    }
  }
}

/// Franja de controles superpuesta al video en modo mini — reemplaza a la vieja `MenziDjMiniBar`
/// (píldora aparte, no arrastrable, sin botón de minimizar). En `compact` solo deja lugar para
/// cambiar de tamaño y ocultar (el objetivo explícito del tamaño chico es no ocupar espacio); en
/// `expanded` entran también silenciar y play/pause para quien modera.
class _MiniControlStrip extends StatelessWidget {
  const _MiniControlStrip({
    required this.compact,
    required this.muted,
    required this.isPlaying,
    required this.canModerate,
    required this.onToggleMute,
    required this.onTogglePlay,
    required this.onResize,
    required this.onHide,
  });

  final bool compact;
  final bool muted;
  final bool isPlaying;
  final bool canModerate;
  final VoidCallback onToggleMute;
  final VoidCallback onTogglePlay;
  final VoidCallback onResize;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      decoration: const BoxDecoration(color: Colors.black45),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!compact) ...[
            _StripButton(
              icon: muted ? Icons.volume_off : Icons.volume_up,
              tooltip: muted ? 'Activar música' : 'Silenciar música',
              onTap: onToggleMute,
            ),
            if (canModerate)
              _StripButton(
                icon: isPlaying ? Icons.pause : Icons.play_arrow,
                tooltip: isPlaying ? 'Pausar' : 'Reproducir',
                onTap: onTogglePlay,
              ),
            const Spacer(),
          ] else
            const Spacer(),
          _StripButton(
            icon: compact ? Icons.open_in_full : Icons.close_fullscreen,
            tooltip: compact ? 'Agrandar' : 'Achicar',
            onTap: onResize,
          ),
          _StripButton(
            icon: Icons.visibility_off_outlined,
            tooltip: 'Minimizar DJ Menzi',
            onTap: onHide,
          ),
        ],
      ),
    );
  }
}

class _StripButton extends StatelessWidget {
  const _StripButton({required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}
