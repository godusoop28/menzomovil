import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Puente al reproductor de YouTube nativo en segundo plano
/// (`MenziDjBackgroundPlayer`, Android) — una segunda instancia del mismo reproductor oficial,
/// montada en una ventana overlay que sigue "viva" para Android aunque la Activity de Flutter
/// esté detenida. Nunca sustituye al WebView de Flutter, solo se hace cargo del audio mientras
/// la app está en segundo plano; el hand-off en ambas direcciones lo coordina `MenziDjNotifier`
/// (ver menzi_dj_provider.dart).
///
/// [warmUp] se llama apenas hay una canción activa (con la app en primer plano) para dejar
/// montada la ventana + cargado el reproductor de YouTube ANTES de que haga falta — sin esto,
/// [activate] tendría que hacer ese trabajo (que incluye un pedido de red) justo en el instante
/// de minimizar, dejando un hueco audible de silencio real.
class MenziDjBackgroundChannel {
  MenziDjBackgroundChannel._();

  static const _channel = MethodChannel(
    'com.sega2028.menzomovil/menzi_dj_background',
  );

  static Future<bool> warmUp({required String origin}) async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('warmUp', {'origin': origin}) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> activate({
    required String origin,
    required String videoId,
    required double positionSeconds,
    required bool playing,
    required bool muted,
    required int volume,
  }) async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('activate', {
            'origin': origin,
            'videoId': videoId,
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
  /// primer plano retome ahí sin salto audible) y lo pausa+mutea — pero NO lo destruye, queda
  /// precalentado para la próxima vez que se minimice en esta misma sesión.
  static Future<double> pauseAndReportPosition() async {
    if (!Platform.isAndroid) return 0;
    try {
      final result = await _channel.invokeMethod<Map>('pauseAndReportPosition');
      return (result?['positionSeconds'] as num?)?.toDouble() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Destruye de verdad la ventana/WebView de fondo — solo al salir del LIVE o terminar la
  /// sesión de Menzi DJ, no en cada ida y vuelta de primer/segundo plano.
  static Future<void> teardown() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('teardown');
    } catch (_) {}
  }
}
