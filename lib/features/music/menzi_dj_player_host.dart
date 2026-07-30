import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'menzi_dj_provider.dart';

/// Único WebView del reproductor oficial de YouTube para toda la app — vive montado siempre
/// (ver AppShell), y solo cambia de tamaño entre invisible / miniatura / expandido. Nunca se
/// destruye ni se vuelve a crear al navegar o minimizar — eso lo controla [MenziDjNotifier], no
/// este widget. 1:1 con menzoweb/components/music/MenziDjPlayerHost.tsx.
class MenziDjPlayerHost extends ConsumerWidget {
  const MenziDjPlayerHost({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    return Positioned(
      top: music.expanded ? 60 : null,
      right: music.expanded ? 16 : null,
      bottom: music.expanded ? null : 170,
      left: music.expanded ? null : 16,
      width: music.expanded ? 200 : 1,
      height: music.expanded ? 112 : 1,
      child: IgnorePointer(
        ignoring: !music.expanded,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(music.expanded ? 16 : 0),
          child: Opacity(
            opacity: music.expanded ? 1 : 0,
            child: WebViewWidget(controller: controller),
          ),
        ),
      ),
    );
  }
}
