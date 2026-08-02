import 'dart:io' show Platform;

import 'package:permission_handler/permission_handler.dart';

/// Pide de entrada, apenas el usuario está adentro de la app (home), los permisos que
/// DJ Menzi/LIVE van a necesitar de todos modos — así el primer "crear LIVE" o "unirme a un
/// LIVE" no se topa recién ahí con el diálogo del sistema (o, peor, con un micrófono que
/// Android nunca llegó a conceder de verdad, que es justo lo que rompía el foreground service
/// de tipo `microphone` en targetSdk 34+). El permiso de overlay (burbuja flotante) queda
/// fuera a propósito: ese es opt-in explícito (ver `_BubbleOptInPrompt` en live_room_panel.dart)
/// porque manda al usuario a una pantalla de ajustes del sistema, no un diálogo in-app.
Future<void> requestStartupPermissions() async {
  if (!Platform.isAndroid && !Platform.isIOS) return;
  try {
    await Permission.microphone.request();
    if (Platform.isAndroid) {
      await Permission.notification.request();
    }
  } catch (_) {
    // Nunca debe tumbar el arranque de la app por esto — si falla, los flujos que
    // realmente necesitan el permiso (unirse a un LIVE) lo vuelven a pedir en su momento.
  }
}
