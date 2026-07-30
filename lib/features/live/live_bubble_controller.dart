import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/native/bubble_preference.dart';
import '../../core/native/live_bubble_channel.dart';
import 'live_provider.dart';

/// Orquesta la burbuja flotante nativa a partir del único estado real del LIVE
/// ([liveProvider]) — la burbuja en sí (`LiveBubbleService`, Android) no sabe nada de Agora ni
/// del foreground service de audio, solo dibuja lo que este controller le manda y reporta
/// toques de vuelta acá. Se instancia una sola vez (ver `liveBubbleControllerProvider`, leído
/// desde `app.dart` junto al resto de providers "siempre activos").
class LiveBubbleController with WidgetsBindingObserver {
  LiveBubbleController(this.ref) {
    WidgetsBinding.instance.addObserver(this);
    LiveBubbleChannel.events.listen(_handleBubbleEvent);
    ref.listen<LiveState>(liveProvider, (previous, next) {
      if (previous?.connected == true && !next.connected) {
        LiveBubbleChannel.hide();
        return;
      }
      if (_backgrounded && next.connected) {
        _syncBubbleState(next);
      }
    });
  }

  final Ref ref;
  bool _backgrounded = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final live = ref.read(liveProvider);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _backgrounded = true;
      if (live.connected) _maybeShowBubble(live);
    } else if (state == AppLifecycleState.resumed) {
      _backgrounded = false;
      LiveBubbleChannel.hide();
    }
  }

  Future<void> _maybeShowBubble(LiveState live) async {
    final enabled = await BubblePreference.isEnabled();
    if (!enabled) return;
    // Nunca se asume concedido — se vuelve a comprobar cada vez, incluso si el usuario lo
    // aceptó antes: pudo revocarlo desde Ajustes del sistema entre una vez y la otra.
    final granted = await LiveBubbleChannel.checkPermission();
    if (!granted) return;
    if (!_backgrounded)
      return; // volvió a primer plano mientras se resolvían los futures
    await LiveBubbleChannel.show(
      canSpeak: live.canSpeak,
      muted: live.muted || !live.localAudioPublished,
    );
  }

  Future<void> _syncBubbleState(LiveState live) async {
    await LiveBubbleChannel.updateState(
      canSpeak: live.canSpeak,
      muted: live.muted || !live.localAudioPublished,
    );
  }

  void _handleBubbleEvent(Map<String, dynamic> event) {
    switch (event['action']) {
      case 'toggle_mute':
        ref.read(liveProvider.notifier).toggleMute();
      case 'leave':
        ref.read(liveProvider.notifier).leave();
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}

final liveBubbleControllerProvider = Provider<LiveBubbleController>((ref) {
  final controller = LiveBubbleController(ref);
  ref.onDispose(controller.dispose);
  return controller;
});
