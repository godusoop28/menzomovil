import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/router/current_location.dart';
import 'menzi_dj_provider.dart';

/// Ruta de [YouTubeMobileDiagnosticScreen] (ver core/router/app_router.dart) — esa pantalla
/// monta su PROPIO WebViewController/YT.Player aislado a propósito (sin LIVE/STOMP/Agora), pero
/// `_RootOverlays` (app.dart) sigue envolviendo esa ruta igual que cualquier otra, así que sin
/// este chequeo el player global de acá abajo también queda visible encima — dos reproductores
/// de YouTube superpuestos en pantalla al mismo tiempo (uno real, uno de diagnóstico), que es
/// exactamente la duplicación reportada. No es un bug de instancias duplicadas del MISMO player:
/// son dos widgets distintos, cada uno con su propio WebView, montados a la vez sin querer.
const _diagnosticRoute = '/debug/youtube-player';

const _expandedWidth = 280.0;
const _expandedHeight = 200.0;

// YouTube no garantiza un embed confiable por debajo de este tamaño — y, más importante
// todavía, un WebView con una superficie de renderizado casi nula (el 1×1 con Opacity 0 que
// usaba esta pantalla antes) es tratado por Chromium como una vista inactiva, que puede
// suspender no solo el render sino también la reproducción. Por eso el estado "mini" (panel no
// expandido) sigue siendo un WebView de tamaño real dentro del viewport, nunca 1×1/Opacity 0/
// fuera de pantalla — se lo tapa con controles propios reales (la mini-bar, que se pinta encima
// en el mismo Stack de AppShell), no con trucos de invisibilidad sobre el WebView.
const _miniWidth = 200.0;
const _miniHeight = 200.0;

/// Único WebView del reproductor oficial de YouTube para toda la app — vive montado siempre
/// (ver AppShell), y solo cambia de tamaño entre invisible / miniatura / expandido. Nunca se
/// destruye ni se vuelve a crear al navegar o minimizar — eso lo controla [MenziDjNotifier], no
/// este widget. 1:1 con menzoweb/components/music/MenziDjPlayerHost.tsx.
///
/// Cuando está expandido (panel de Menzi DJ abierto) el video queda VISIBLE de verdad, no es
/// audio-only — en esa posición puede terminar tapando controles propios del panel/LIVE, así
/// que es arrastrable: el usuario lo mueve a donde no le moleste.
class MenziDjPlayerHost extends ConsumerStatefulWidget {
  const MenziDjPlayerHost({super.key});

  @override
  ConsumerState<MenziDjPlayerHost> createState() => _MenziDjPlayerHostState();
}

class _MenziDjPlayerHostState extends ConsumerState<MenziDjPlayerHost> {
  Offset? _position;

  @override
  Widget build(BuildContext context) {
    final music = ref.watch(menziDjProvider);
    final controller = ref.watch(menziDjProvider.notifier).controller;
    final location = ref.watch(currentLocationProvider);

    if (!music.hasTrack || location == _diagnosticRoute) {
      return const Positioned(
        width: 1,
        height: 1,
        left: -10,
        top: -10,
        child: SizedBox.shrink(),
      );
    }

    // El video se ve más grande y arrastrable solo si el panel lo pidió expandido Y el usuario
    // no lo ocultó desde ahí. En cualquier otro caso el WebView sigue reproduciendo igual (el
    // audio no se interrumpe) como un mini reproductor real y visible en una esquina fija —
    // NUNCA a tamaño 1×1, con Opacity 0, en Offstage, ni con coordenadas negativas que lo saquen
    // del viewport: eso es justo lo que causaba que el segundo usuario (que nunca tenía el panel
    // expandido) no escuchara Menzi DJ estando DENTRO de la app — Chromium trata una superficie
    // de renderizado prácticamente nula como una vista inactiva y puede suspender también la
    // reproducción, no solo el render.
    if (!music.expanded || music.videoHidden) {
      return Positioned(
        left: 8,
        bottom: 8,
        width: _miniWidth,
        height: _miniHeight,
        child: IgnorePointer(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: WebViewWidget(controller: controller),
          ),
        ),
      );
    }

    final screenSize = MediaQuery.sizeOf(context);
    final maxLeft = (screenSize.width - _expandedWidth).clamp(
      0.0,
      double.infinity,
    );
    final maxTop = (screenSize.height - _expandedHeight).clamp(
      0.0,
      double.infinity,
    );
    final defaultPosition = Offset(maxLeft - 16, 60);
    final position = _position ?? defaultPosition;

    return Positioned(
      left: position.dx.clamp(0.0, maxLeft),
      top: position.dy.clamp(0.0, maxTop),
      width: _expandedWidth,
      height: _expandedHeight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) {
          setState(() {
            final next = position + details.delta;
            _position = Offset(
              next.dx.clamp(0.0, maxLeft),
              next.dy.clamp(0.0, maxTop),
            );
          });
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // `IgnorePointer` es a propósito acá: la burbuja solo se puede mover, nunca
              // tocar — cualquier control de play/pause/skip vive en el panel de Menzi DJ, no
              // en esta vista previa flotante. Sin esto, un tap sobre el iframe de YouTube
              // podía llegar a la superficie embebida (mostrar sus propios controles nativos,
              // pausarla, etc.) por fuera del estado que maneja el resto de la sala.
              Positioned.fill(
                child: IgnorePointer(
                  child: WebViewWidget(controller: controller),
                ),
              ),
              // Solo indica que se puede arrastrar — no intercepta toques, el
              // GestureDetector de más arriba ya cubre toda el área.
              const Positioned(
                right: 4,
                top: 4,
                child: IgnorePointer(
                  child: Icon(Icons.open_with, size: 14, color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
