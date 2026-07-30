import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ubicación actual del router, expuesta como estado de Riverpod en vez de vía `BuildContext`.
///
/// `MaterialApp.router`'s `builder` envuelve el árbol POR ENCIMA del `Router`/go_router — ni
/// `GoRouterState.of(context)` ni `GoRouter.of(context)` funcionan ahí (tiran "No GoRouter found
/// in context" o un GoError, y como eso pasa en el primer build, la app nunca llega a pintar su
/// primer frame — pantalla en blanco permanente). Los overlays persistentes
/// ([PersistentVoiceBubble], [MenziDjMiniBar]) viven justo en ese `builder`, así que en vez de
/// leer la ruta desde el `context` leen este provider, que se actualiza desde
/// `appRouterProvider` escuchando al propio `GoRouter` (ver core/router/app_router.dart).
final currentLocationProvider = StateProvider<String>((ref) => '/');
