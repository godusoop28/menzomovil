import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Puente al reproductor de YouTube nativo en segundo plano
/// (`MenziDjBackgroundPlayerService`, Android) — una segunda instancia del mismo reproductor
/// oficial, montada en una ventana overlay que sigue "viva" para Android aunque la Activity de
/// Flutter esté detenida. Nunca sustituye al WebView de Flutter, solo se hace cargo del audio
/// mientras la app está en segundo plano; el hand-off en ambas direcciones lo coordina
/// `MenziDjNotifier` (ver menzi_dj_provider.dart).
class MenziDjBackgroundChannel {
  MenziDjBackgroundChannel._();

  static const _channel = MethodChannel(
    'com.sega2028.menzomovil/menzi_dj_background',
  );

  /// true si se pudo montar el reproductor nativo (requiere permiso de overlay ya concedido,
  /// el mismo que la burbuja del LIVE). Si es false, Dart no debe pausar su propio WebView —
  /// no hay nadie que tome la posta, así que la música simplemente se pausará como antes de
  /// esta mejora.
  static Future<bool> enterBackground({
    required String videoId,
    required String origin,
    required double positionSeconds,
    required bool playing,
    required bool muted,
    required int volume,
  }) async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('enterBackground', {
            'videoId': videoId,
            'origin': origin,
            'positionSeconds': positionSeconds,
            'playing': playing,
            'muted': muted,
            'volume': volume,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> updateTrack({
    required String videoId,
    required double positionSeconds,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('updateTrack', {
        'videoId': videoId,
        'positionSeconds': positionSeconds,
      });
    } catch (_) {}
  }

  static Future<void> updateAudioState({
    required bool muted,
    required int volume,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('updateAudioState', {
        'muted': muted,
        'volume': volume,
      });
    } catch (_) {}
  }

  /// Devuelve la posición real alcanzada por el reproductor de fondo (para que el WebView de
  /// primer plano retome ahí sin salto audible) y apaga el servicio nativo.
  static Future<double> exitBackground() async {
    if (!Platform.isAndroid) return 0;
    try {
      final result = await _channel.invokeMethod<Map>('exitBackground');
      return (result?['positionSeconds'] as num?)?.toDouble() ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
