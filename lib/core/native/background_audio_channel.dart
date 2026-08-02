import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Modo del foreground service nativo — determina qué `foregroundServiceType` declara Android.
/// `listen` NUNCA requiere `RECORD_AUDIO` (solo `mediaPlayback`); `speak` agrega
/// `microphone` y en Android 13+ ese tipo específico exige que `RECORD_AUDIO` ya esté
/// concedido en tiempo real o el sistema tira `SecurityException` — por eso Dart nunca debe
/// pedir `speak` sin haber confirmado el permiso primero (ver `live_provider.dart`).
enum BackgroundAudioMode { listen, speak }

/// Puente a [BackgroundAudioService] (Android) — mantiene el micrófono del LIVE y/o la música
/// de DJ Menzi activos cuando la app pasa a segundo plano, vía un foreground service real con
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
    required BackgroundAudioMode mode,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('start', {
        'title': title,
        'text': text,
        'mode': mode.name,
      });
    } catch (_) {}
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('stop');
    } catch (_) {}
  }
}
