import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../config/app_config.dart';
import '../diagnostics/app_diagnostic_logger.dart';
import '../diagnostics/device_session.dart';
import 'api_client.dart';

/// Un cliente STOMP por "canal" (mensajes de una sala, LIVE, música, muro...) — mismo patrón
/// que menzoweb/menzomovil-RN, que abren un StompJs.Client independiente por hook/contexto en
/// vez de multiplexar todo sobre una sola conexión.
///
/// El handshake HTTP no lleva el token (un cliente nativo no puede mandar headers custom en el
/// upgrade) — el backend valida el JWT leyendo el header STOMP `Authorization` DENTRO del frame
/// CONNECT (ver StompAuthChannelInterceptor en menzoapi), que es justo lo que `stompConnectHeaders`
/// hace acá.
///
/// El reconnect automático de `stomp_dart_client` reutiliza el `StompConfig` original tal cual —
/// incluido el mapa de `stompConnectHeaders` capturado en el primer `connect()` — así que un JWT
/// que venció entre el primer connect y una reconexión más tarde (el access token dura 15 min,
/// ver JwtProperties) quedaba pegado ahí para siempre: cada reintento repetía el mismo header
/// vencido y fallaba en bucle, sin que nada lo notara ni lo corrigiera. La librería sí expone
/// `beforeConnect` (una función async que corre antes de CADA intento, inicial o reconexión —
/// ver `StompClient._connect` en el paquete), así que en vez de un `Map` nuevo por conexión se
/// usa un único `Map` MUTABLE (`_headers`) referenciado por el `StompConfig`: `beforeConnect`
/// pide un token fresco y lo escribe ahí adentro antes de que el cliente arme el frame CONNECT.
class StompChannel {
  StompChannel();

  StompClient? _client;
  final Map<String, void Function(Map<String, dynamic>)> _handlers = {};
  final Map<String, StompUnsubscribe> _subs = {};
  final Map<String, String> _headers = {};
  bool _connected = false;
  bool _hasConnectedBefore = false;
  bool _disposed = false;

  int _reconnectAttempt = 0;
  static const _baseDelay = Duration(seconds: 1);
  static const _maxDelay = Duration(seconds: 30);
  final Random _jitter = Random();

  void Function()? _onConnected;
  void Function()? _onReconnected;

  /// [onConnected] se llama en la primera conexión y en cada reconexión (para volver a
  /// suscribirse y pedir un snapshot de reconciliación — ver menzi_dj_provider._setup). Es
  /// deliberado que sea el mismo callback en ambos casos: STOMP no reentrega mensajes perdidos
  /// de un topic mientras el socket estuvo caído, así que cualquier reconexión necesita el mismo
  /// tratamiento que la conexión inicial. [onReconnected] es un extra, llamado solo a partir de
  /// la segunda vez, para quien necesite distinguir "recién conectado" de "se cayó y volvió".
  void connect({
    required void Function() onConnected,
    void Function()? onReconnected,
  }) {
    _onConnected = onConnected;
    _onReconnected = onReconnected;
    _reconnectAttempt = 0;
    _buildAndActivate();
  }

  void _buildAndActivate() {
    if (_disposed) return;
    _client = StompClient(
      config: StompConfig(
        url: AppConfig.wsUrl,
        stompConnectHeaders: _headers,
        // El backoff/reconexión los manejamos nosotros (ver _scheduleManualReconnect) para poder
        // hacerlo exponencial con jitter y para poder refrescar el JWT en cada intento real, no
        // solo en el primero — la librería solo soporta un delay fijo constante.
        reconnectDelay: Duration.zero,
        heartbeatOutgoing: const Duration(seconds: 10),
        heartbeatIncoming: const Duration(seconds: 10),
        beforeConnect: () async {
          final token = await ApiClient.instance.ensureFreshAccessToken();
          if (token != null) {
            _headers['Authorization'] = 'Bearer $token';
          } else {
            _headers.remove('Authorization');
          }
        },
        onConnect: (frame) {
          _connected = true;
          final wasReconnect = _hasConnectedBefore;
          _reconnectAttempt = 0;
          debugPrint(
            '[STOMP][${DeviceSession.id}] ${wasReconnect ? "reconnected" : "connected"} url=${AppConfig.wsUrl}',
          );
          AppDiagnosticLogger.instance.log(
            DiagnosticCategory.stomp,
            MenziLogLevel.info,
            wasReconnect ? 'reconnected' : 'connected',
            data: {'topics': _handlers.keys.toList()},
          );
          // Re-suscribe todo lo que ya estaba pedido antes de reconectar.
          for (final topic in _handlers.keys) {
            _subscribeNow(topic);
            debugPrint('[STOMP][${DeviceSession.id}] subscribed topic=$topic');
          }
          _onConnected?.call();
          if (wasReconnect) {
            _onReconnected?.call();
          } else {
            _hasConnectedBefore = true;
          }
        },
        onDisconnect: (frame) {
          _connected = false;
          debugPrint(
            '[STOMP][${DeviceSession.id}] disconnect frame recibido: ${frame.command}',
          );
        },
        onWebSocketDone: () {
          _connected = false;
          debugPrint(
            '[STOMP][${DeviceSession.id}] websocket done — reconnecting',
          );
          AppDiagnosticLogger.instance.log(
            DiagnosticCategory.stomp,
            MenziLogLevel.warning,
            'websocket done — reconnecting',
          );
          _scheduleManualReconnect();
        },
        onWebSocketError: (dynamic error) {
          _connected = false;
          debugPrint('[STOMP][${DeviceSession.id}] error de WebSocket: $error');
          AppDiagnosticLogger.instance.log(
            DiagnosticCategory.stomp,
            MenziLogLevel.error,
            'websocket error',
            data: {'error': error.toString()},
          );
          _scheduleManualReconnect();
        },
        onStompError: (frame) {
          debugPrint(
            '[STOMP][${DeviceSession.id}] ERROR frame: ${frame.headers['message'] ?? frame.body}',
          );
        },
      ),
    );
    _client!.activate();
  }

  /// Backoff exponencial con jitter (1s, 2s, 4s, 8s, ..., tope 30s) — un delay fijo (lo único
  /// que ofrece la librería) o bien reintenta demasiado rápido contra un backend que está
  /// reiniciando (satura al pedo) o tarda de más contra un corte breve. El jitter evita que,
  /// si esto le pasa a muchos clientes a la vez (un deploy, un restart), todos reintenten en el
  /// mismo instante exacto.
  void _scheduleManualReconnect() {
    if (_disposed) return;
    final exponent = min(
      _reconnectAttempt,
      5,
    ); // 2^5 * 1s = 32s, ya cerca del tope
    final raw = _baseDelay * pow(2, exponent).toInt();
    final capped = raw > _maxDelay ? _maxDelay : raw;
    final jitterMs = _jitter.nextInt(400);
    final delay = capped + Duration(milliseconds: jitterMs);
    _reconnectAttempt++;
    debugPrint(
      '[STOMP][${DeviceSession.id}] reconnectAttempt=$_reconnectAttempt delayMs=${delay.inMilliseconds}',
    );
    Future.delayed(delay, () {
      if (_disposed) return;
      _buildAndActivate();
    });
  }

  bool get isConnected => _connected;

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
    _disposed = true;
    for (final unsub in _subs.values) {
      unsub.call();
    }
    _subs.clear();
    _handlers.clear();
    _client?.deactivate();
    _connected = false;
  }
}
