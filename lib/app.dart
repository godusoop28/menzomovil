import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/live/live_bubble_controller.dart';
import 'features/live/persistent_voice_bubble.dart';
import 'features/music/menzi_dj_mini_bar.dart';
import 'features/music/menzi_dj_player_host.dart';
import 'features/notifications/notification_stream_controller.dart';

/// Overlays persistentes montados por encima de TODA la app (cualquier ruta, no solo las 4
/// pestañas principales) — igual que PersistentVoiceBubble/MenziDjPlayerHost montados en la
/// raíz de menzoweb (AppShell.tsx) / menzomovil-RN (_layout.tsx), por encima del router entero.
class _RootOverlays extends StatelessWidget {
  const _RootOverlays({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        const MenziDjPlayerHost(),
        const MenziDjMiniBar(),
        const PersistentVoiceBubble(),
      ],
    );
  }
}

class MenzoApp extends ConsumerWidget {
  const MenzoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    // Se instancia una sola vez acá (Riverpod cachea el resultado) para que el observer de
    // lifecycle de la burbuja flotante quede activo durante toda la vida de la app.
    ref.watch(liveBubbleControllerProvider);
    ref.watch(notificationStreamControllerProvider);
    return MaterialApp.router(
      title: 'MENZO',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      darkTheme: buildAppTheme(),
      themeMode: ThemeMode.dark,
      routerConfig: router,
      builder: (context, child) =>
          _RootOverlays(child: child ?? const SizedBox.shrink()),
    );
  }
}
