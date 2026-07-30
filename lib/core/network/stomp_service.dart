import 'dart:convert';

import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../config/app_config.dart';
import '../storage/session_storage.dart';

/// Un cliente STOMP por "canal" (mensajes de una sala, LIVE, música, muro...) — mismo patrón
/// que menzoweb/menzomovil-RN, que abren un StompJs.Client independiente por hook/contexto en
/// vez de multiplexar todo sobre una sola conexión. `reconnectDelay: 3000` igual que la web.
///
/// El handshake HTTP no lleva el token (un cliente nativo no puede mandar headers custom en el
/// upgrade) — el backend valida el JWT leyendo el header STOMP `Authorization` DENTRO del frame
/// CONNECT (ver StompAuthChannelInterceptor en menzoapi), que es justo lo que `stompConnectHeaders`
/// hace acá.
class StompChannel {
  StompChannel();

  StompClient? _client;
  final Map<String, void Function(Map<String, dynamic>)> _handlers = {};
  final Map<String, StompUnsubscribe> _subs = {};
  bool _connected = false;

  void connect({required void Function() onConnected}) {
    final session = SessionStorage.instance.cached;
    _client = StompClient(
      config: StompConfig(
        url: AppConfig.wsUrl,
        stompConnectHeaders: session != null
            ? {'Authorization': 'Bearer ${session.accessToken}'}
            : {},
        reconnectDelay: const Duration(seconds: 3),
        heartbeatOutgoing: const Duration(seconds: 10),
        heartbeatIncoming: const Duration(seconds: 10),
        onConnect: (frame) {
          _connected = true;
          // Re-suscribe todo lo que ya estaba pedido antes de reconectar.
          for (final topic in _handlers.keys) {
            _subscribeNow(topic);
          }
          onConnected();
        },
        onWebSocketError: (dynamic error) {},
        onStompError: (frame) {},
      ),
    );
    _client!.activate();
  }

  /// Devuelve el payload ya decodificado como Map — todos los eventos del backend son objetos
  /// JSON (ver LiveEvent/MusicEvent/RoomModerationEvent/TypingEvent).
  void subscribe(
    String topic,
    void Function(Map<String, dynamic> payload) onMessage,
  ) {
    _handlers[topic] = onMessage;
    if (_connected) _subscribeNow(topic);
  }

  void _subscribeNow(String topic) {
    _subs[topic]?.call();
    _subs[topic] = _client!.subscribe(
      destination: topic,
      callback: (frame) {
        if (frame.body == null || frame.body!.isEmpty) return;
        final handler = _handlers[topic];
        if (handler == null) return;
        try {
          handler(jsonDecode(frame.body!) as Map<String, dynamic>);
        } catch (_) {
          // Cuerpo inesperado — se ignora, no debe tumbar el socket.
        }
      },
    );
  }

  /// Publica al servidor (prefijo /app) — hoy solo lo usa el indicador de "escribiendo".
  void send(String destination, Map<String, dynamic> body) {
    if (!_connected) return;
    _client?.send(destination: destination, body: jsonEncode(body));
  }

  void dispose() {
    for (final unsub in _subs.values) {
      unsub.call();
    }
    _subs.clear();
    _handlers.clear();
    _client?.deactivate();
    _connected = false;
  }
}
