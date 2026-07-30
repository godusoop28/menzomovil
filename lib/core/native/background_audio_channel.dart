import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Puente a [BackgroundAudioService] (Android) — mantiene el micrófono del LIVE y/o la música
/// de Menzi DJ activos cuando la app pasa a segundo plano, vía un foreground service real con
/// notificación persistente. Sin esto, Android 8+ corta el audio poco después de minimizar la
/// app aunque los permisos estén declarados en el manifest. No-op en otras plataformas.
class BackgroundAudioChannel {
  BackgroundAudioChannel._();

  static const _channel = MethodChannel(
    'com.sega2028.menzomovil/background_audio',
  );

  static Future<void> start({
    required String title,
    required String text,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('start', {'title': title, 'text': text});
    } catch (_) {}
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('stop');
    } catch (_) {}
  }
}
