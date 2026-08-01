import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../core/config/app_config.dart';
import 'menzi_dj_player_html.dart';

/// Pantalla de diagnóstico TEMPORAL (Fase 9 del pedido de estabilización) — aísla el reproductor
/// de YouTube de todo lo demás: nada de LIVE, Agora, STOMP, MusicService/sincronización. Sirve
/// para responder una única pregunta con evidencia directa en el dispositivo: ¿el WebView de
/// Android puede reproducir un video público embebido cargando la página real de
/// AppConfig.menziDjPlayerUrl, sí o no? Si esto falla acá, no tiene sentido seguir tocando
/// MusicService/Agora — el problema está en el WebView/página del player, no en la
/// sincronización.
///
/// Se llega por Configuración → "Diagnóstico de YouTube" (ver settings_screen.dart) — no forma
/// parte del flujo normal de la app.
class YouTubeMobileDiagnosticScreen extends StatefulWidget {
  const YouTubeMobileDiagnosticScreen({super.key});

  @override
  State<YouTubeMobileDiagnosticScreen> createState() =>
      _YouTubeMobileDiagnosticScreenState();
}

/// Video público, siempre embebible, usado solo para esta prueba aislada — no tiene relación
/// con ninguna sala/cola real.
const _diagnosticVideoId = 'jNQXAC9IVRw';

class _YouTubeMobileDiagnosticScreenState
    extends State<YouTubeMobileDiagnosticScreen> {
  WebViewController? _controller;
  bool _pageLoaded = false;
  bool _iframeReady = false;
  int? _lastErrorCode;
  int? _playerState;
  bool? _muted;
  double? _volume;
  double? _currentTime;
  String? _documentOrigin;
  String? _log;

  @override
  void initState() {
    super.initState();
    _setUp();
  }

  void _setUp() {
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }
    final controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000))
      ..addJavaScriptChannel('MenziBridge', onMessageReceived: _onMessage)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            setState(() {
              _pageLoaded = true;
              _appendLog('page loaded: $url');
            });
          },
        ),
      );
    final platform = controller.platform;
    if (platform is AndroidWebViewController) {
      platform.setMediaPlaybackRequiresUserGesture(false);
    }
    _appendLog('loading ${AppConfig.menziDjPlayerUrl}');
    controller.loadRequest(Uri.parse(AppConfig.menziDjPlayerUrl));
    _controller = controller;
  }

  void _appendLog(String line) {
    final ts = DateTime.now().toIso8601String().substring(11, 19);
    _log = '${_log ?? ''}[$ts] $line\n';
  }

  void _onMessage(JavaScriptMessage message) {
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(message.message) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    setState(() {
      switch (msg['type']) {
        case 'ready':
          _iframeReady = true;
          _appendLog('iframe ready');
        case 'error':
          _lastErrorCode = (msg['code'] as num?)?.toInt();
          _documentOrigin = msg['documentOrigin'] as String?;
          _appendLog(
            'onError code=${msg['code']} documentOrigin=${msg['documentOrigin']} documentReferrer=${msg['documentReferrer']}',
          );
        case 'stateChange':
          _playerState = (msg['state'] as num?)?.toInt();
          _muted = msg['muted'] as bool?;
          _volume = (msg['volume'] as num?)?.toDouble();
          _currentTime = (msg['currentTime'] as num?)?.toDouble();
          _appendLog(
            'stateChange state=${msg['state']} muted=${msg['muted']} volume=${msg['volume']}',
          );
        case 'autoplayBlocked':
          _appendLog('autoplayBlocked');
      }
    });
  }

  void _send(String cmd, [Map<String, dynamic>? args]) {
    _controller?.runJavaScript(
      'window.handleMenziCommand(${jsonEncode(jsonEncode({'cmd': cmd, ...?args}))})',
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnóstico de YouTube (temporal)')),
      body: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 220,
            child: controller == null
                ? const Center(child: CircularProgressIndicator())
                : WebViewWidget(controller: controller),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () => _send('load', {
                    'videoId': _diagnosticVideoId,
                    'startSeconds': 0,
                  }),
                  child: const Text('Cargar video de prueba'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _send('play');
                    _send('unmute', {'volume': 80});
                  },
                  child: const Text('Reproducir'),
                ),
                ElevatedButton(
                  onPressed: () => _send('pause'),
                  child: const Text('Pausar'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('pageLoaded: $_pageLoaded'),
                Text('iframeReady: $_iframeReady'),
                Text(
                  'onError code: ${_lastErrorCode ?? '-'} '
                  '${_lastErrorCode != null ? '(${YtPlayerError.describe(_lastErrorCode!)})' : ''}',
                ),
                Text('playerState: ${_playerState ?? '-'}'),
                Text('muted: ${_muted ?? '-'}'),
                Text('volume: ${_volume ?? '-'}'),
                Text('currentTime: ${_currentTime ?? '-'}'),
                Text('documentOrigin (del último error, si hubo): ${_documentOrigin ?? '-'}'),
                Text('configuredOrigin: ${AppConfig.menziDjOrigin}'),
                Text('pageUrl: ${AppConfig.menziDjPlayerUrl}'),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Text(
                _log ?? '',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
