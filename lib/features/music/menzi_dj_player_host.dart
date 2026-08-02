import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemChrome, SystemUiMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/router/current_location.dart';
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

const _miniWidth = 200.0;
const _miniHeight = 122.0; // ~16:9

/// Único WebView del reproductor oficial de YouTube para toda la app — vive montado siempre (ver
/// AppShell) y NUNCA se destruye ni se vuelve a crear al navegar, minimizar o cambiar de modo
/// visual (ver [MenziPlayerDisplayMode]). 1:1 con menzoweb/components/music/MenziDjPlayerHost.tsx.
///
/// CAUSA RAÍZ CONFIRMADA (auditoría de widget tree, logs reales): la versión anterior tenía TRES
/// ramas `return` distintas (oculto/mini/expandido), cada una construyendo su PROPIO
/// `WebViewWidget(controller: controller)` en una posición estructuralmente distinta del árbol
/// (`Positioned > SizedBox` vs `Positioned > IgnorePointer > ClipRRect > WebViewWidget` vs
/// `Positioned > GestureDetector > ClipRRect > Stack > ...`). Aunque las tres pasaban el MISMO
/// `controller`, Flutter reconcilia por TIPO en la misma posición del árbol — al cambiar de rama
/// (p. ej. abrir el panel de DJ Menzi, que llama `setDisplayMode(normal)`), el framework
/// desmontaba el `WebViewWidget` viejo y montaba uno nuevo, lo que fuerza a Android a
/// destruir/recrear el `PlatformView` (la superficie nativa real del WebView) — y ESO es lo que
/// hacía que YouTube reportara `state=2` sin que existiera ningún pause global ni local real: no
/// era una pausa, era el WebView completo reapareciendo de cero.
///
/// La corrección: un ÚNICO árbol de widgets, con la MISMA forma estructural en todos los modos
/// (`Positioned > GestureDetector > ClipRRect > Stack > [Positioned.fill(WebViewWidget), extra?]`)
/// — el modo solo cambia propiedades (tamaño/posición/radio/si el GestureDetector reacciona a
/// arrastre/si hay una capa extra encima), nunca el TIPO ni la profundidad de los widgets. El
/// único hijo condicional (drag-icon en `mini`, capa opaca en `hidden`) siempre es el ÚLTIMO de
/// la lista dentro de `Stack`, así que agregarlo/quitarlo nunca perturba al `WebViewWidget`, que
/// siempre es el primero.
class MenziDjPlayerHost extends ConsumerStatefulWidget {
  const MenziDjPlayerHost({super.key});

  @override
  ConsumerState<MenziDjPlayerHost> createState() => _MenziDjPlayerHostState();
}

class _MenziDjPlayerHostState extends ConsumerState<MenziDjPlayerHost> {
  Offset? _miniPosition;
  static const _webViewKey = ValueKey('menzi-dj-webview-surface');

  @override
  void initState() {
    super.initState();
    debugPrint('[YT_VIEW] host mounted');
  }

  @override
  void dispose() {
    debugPrint('[YT_VIEW] host disposed');
    super.dispose();
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
    final rect = _rectForMode(context, mode, screenSize, music.videoSlotRect);
    final draggable = mode == MenziPlayerDisplayMode.mini;
    final borderRadius = switch (mode) {
      MenziPlayerDisplayMode.cinema || MenziPlayerDisplayMode.fullscreen => 0.0,
      _ => 16.0,
    };

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
        onPanUpdate: draggable
            ? (details) => _onDrag(details, rect, screenSize)
            : null,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Stack(
            children: [
              // SIEMPRE el primer (y único hasta acá) hijo — nunca se mueve de posición en la
              // lista, así que nunca se ve afectado por que el segundo hijo opcional aparezca o
              // desaparezca (ver comentario de clase).
              Positioned.fill(
                child: IgnorePointer(
                  child: WebViewWidget(key: _webViewKey, controller: controller),
                ),
              ),
              if (mode == MenziPlayerDisplayMode.hidden)
                // Fase 3: nunca 1×1/Offstage/Opacity 0 para "ocultar" — eso mismo (una
                // superficie de renderizado casi nula) es lo que Chromium trata como vista
                // inactiva y puede suspender la reproducción, no solo el render. Acá se cubre
                // con una capa opaca real, del mismo tamaño, sin tocar el WebView de abajo.
                const Positioned.fill(
                  child: ColoredBox(color: Color(0xFF07090D)),
                ),
              if (draggable)
                const Positioned(
                  right: 4,
                  top: 4,
                  child: IgnorePointer(
                    child: Icon(Icons.open_with, size: 14, color: Colors.white70),
                  ),
                ),
              if (mode == MenziPlayerDisplayMode.fullscreen)
                Positioned(
                  right: 8,
                  top: 8,
                  child: SafeArea(
                    child: IconButton(
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
    final maxLeft = (screenSize.width - _miniWidth).clamp(0.0, double.infinity);
    final maxTop = (screenSize.height - _miniHeight).clamp(0.0, double.infinity);
    final next = current.topLeft + details.delta;
    setState(() {
      _miniPosition = Offset(
        next.dx.clamp(0.0, maxLeft),
        next.dy.clamp(0.0, maxTop),
      );
    });
  }

  Rect _rectForMode(
    BuildContext context,
    MenziPlayerDisplayMode mode,
    Size screenSize,
    Rect? videoSlotRect,
  ) {
    switch (mode) {
      case MenziPlayerDisplayMode.hidden:
      case MenziPlayerDisplayMode.mini:
        final maxLeft = (screenSize.width - _miniWidth).clamp(0.0, double.infinity);
        final maxTop = (screenSize.height - _miniHeight).clamp(0.0, double.infinity);
        final defaultPosition = Offset(8, maxTop - 92);
        final position = _miniPosition ?? defaultPosition;
        return Rect.fromLTWH(
          position.dx.clamp(0.0, maxLeft),
          position.dy.clamp(0.0, maxTop),
          _miniWidth,
          _miniHeight,
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
