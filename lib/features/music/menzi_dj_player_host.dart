import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'menzi_dj_provider.dart';

const _expandedWidth = 200.0;
const _expandedHeight = 112.0;

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

    if (!music.hasTrack) {
      return const Positioned(
        width: 1,
        height: 1,
        left: -10,
        top: -10,
        child: SizedBox.shrink(),
      );
    }

    // El video visible solo aparece si el panel lo pidió expandido Y el usuario no lo ocultó
    // desde ahí — en cualquier otro caso el WebView sigue montado igual (el audio no se
    // interrumpe), solo se deja de mostrar/mover el recuadro. CRÍTICO: nunca a tamaño 1×1 con
    // Opacity 0 acá — Chromium (WebView de Android) trata una superficie prácticamente sin
    // área visible como inactiva y puede suspender su reproducción, no solo su render, lo que
    // explicaba por qué el segundo usuario (que nunca tenía el panel expandido) no escuchaba
    // Menzi DJ estando DENTRO de la app. Mismas dimensiones reales que el estado expandido,
    // solo que posicionado fuera del viewport — visible para Chromium, invisible para el ojo.
    if (!music.expanded || music.videoHidden) {
      return Positioned(
        left: -_expandedWidth - 50,
        top: -_expandedHeight - 50,
        width: _expandedWidth,
        height: _expandedHeight,
        child: IgnorePointer(child: WebViewWidget(controller: controller)),
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
