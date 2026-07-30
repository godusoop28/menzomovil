import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Puente a la burbuja flotante nativa (Android, `LiveBubbleService`) — visible sobre otras
/// apps mientras hay un LIVE de voz activo y Menzo está en segundo plano. Opt-in explícito: el
/// permiso `SYSTEM_ALERT_WINDOW` nunca se pide solo (siempre después de que el usuario acepta
/// la explicación contextual, ver `BubblePreference`/`LiveBubbleController`), y el resultado de
/// `requestPermission` nunca se asume concedido — Android no devuelve un resultado confiable de
/// esa pantalla de ajustes, así que `checkPermission` se vuelve a llamar cada vez que hace
/// falta saber el estado real.
class LiveBubbleChannel {
  LiveBubbleChannel._();

  static const _method = MethodChannel('com.sega2028.menzomovil/live_bubble');
  static const _events = EventChannel(
    'com.sega2028.menzomovil/live_bubble_events',
  );

  static Future<bool> checkPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _method.invokeMethod<bool>('checkPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Abre la pantalla de ajustes del sistema para conceder "Mostrar sobre otras apps". No
  /// espera ni asume el resultado — quien llama debe volver a comprobar con [checkPermission]
  /// cuando la app recupere el foco.
  static Future<void> requestPermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _method.invokeMethod('requestPermission');
    } catch (_) {}
  }

  static Future<bool> show({
    required bool canSpeak,
    required bool muted,
  }) async {
    if (!Platform.isAndroid) return false;
    try {
      return await _method.invokeMethod<bool>('show', {
            'canSpeak': canSpeak,
            'muted': muted,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> updateState({
    required bool canSpeak,
    required bool muted,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _method.invokeMethod('updateState', {
        'canSpeak': canSpeak,
        'muted': muted,
      });
    } catch (_) {}
  }

  static Future<void> hide() async {
    if (!Platform.isAndroid) return;
    try {
      await _method.invokeMethod('hide');
    } catch (_) {}
  }

  /// Eventos originados por toques en la burbuja: `{'action': 'toggle_mute'|'leave'|'open'}`.
  static Stream<Map<String, dynamic>> get events {
    if (!Platform.isAndroid) return const Stream.empty();
    return _events.receiveBroadcastStream().map(
      (e) => Map<String, dynamic>.from(e as Map),
    );
  }
}
