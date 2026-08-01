import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../core/config/app_config.dart';
import 'menzi_dj_player_html.dart';

/// Pantalla de diagnóstico TEMPORAL — aísla el reproductor de YouTube de todo lo demás: nada de
/// LIVE, Agora, STOMP, MusicService/sincronización. El único propósito es obtener, en la UI y en
/// el dispositivo real, el código exacto de `onError` (2/5/100/101/150/153/otro) — el "ID de
/// reproducción" que YouTube muestra dentro del recuadro de error NO es ese código, es un
/// identificador interno de YouTube sin valor diagnóstico para nosotros.
///
/// No carga nada solo — cada paso (cargar el player, cargar un video, reproducir) requiere un
/// toque explícito, para poder aislar autoplay como variable (Fase 8 del diagnóstico).
///
/// Se llega por Configuración → "Diagnóstico de YouTube" (ver settings_screen.dart) — no forma
/// parte del flujo normal de la app.
class YouTubeMobileDiagnosticScreen extends StatefulWidget {
  const YouTubeMobileDiagnosticScreen({super.key});

  @override
  State<YouTubeMobileDiagnosticScreen> createState() =>
      _YouTubeMobileDiagnosticScreenState();
}

/// Video público, siempre embebible — sirve para distinguir "el WebView/origen está mal" (falla
/// hasta con esto) de "el video específico de Menzi DJ tiene un problema propio" (esto funciona,
/// el otro no).
const _publicVideoId = 'jNQXAC9IVRw';

class _YouTubeMobileDiagnosticScreenState
    extends State<YouTubeMobileDiagnosticScreen> {
  WebViewController? _controller;
  final _customVideoIdController = TextEditingController();

  bool _pageLoaded = false;
  bool _iframeReady = false;
  String? _requestedVideoId;
  int? _lastErrorCode;
  String? _lastErrorActualVideoId;
  String? _documentOrigin;
  String? _documentReferrer;
  String? _userAgent;
  int? _playerState;
  bool? _muted;
  double? _volume;
  double? _currentTime;
  bool _autoplayBlocked = false;
  DateTime? _lastEventAt;
  String _log = '';

  @override
  void initState() {
    super.initState();
    _setUp();
  }

  @override
  void dispose() {
    _customVideoIdController.dispose();
    super.dispose();
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
    // `autoplay=0`: nada se reproduce solo — cada paso de acá abajo requiere un toque real, así
    // un error no puede confundirse con un bloqueo de autoplay del WebView.
    final url = '${AppConfig.menziDjPlayerUrl}?autoplay=0';
    _appendLog('loading $url');
    controller.loadRequest(Uri.parse(url));
    _controller = controller;
  }

  void _appendLog(String line) {
    final ts = DateTime.now().toIso8601String().substring(11, 19);
    setState(() => _log = '$_log[$ts] $line\n');
  }

  void _onMessage(JavaScriptMessage message) {
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(message.message) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    setState(() {
      _lastEventAt = DateTime.now();
      switch (msg['type']) {
        case 'ready':
          _iframeReady = true;
          _appendLog('iframe ready');
        case 'error':
          _lastErrorCode = (msg['errorCode'] as num?)?.toInt();
          _requestedVideoId = msg['requestedVideoId'] as String?;
          _lastErrorActualVideoId = msg['actualVideoId'] as String?;
          _documentOrigin = msg['documentOrigin'] as String?;
          _documentReferrer = msg['documentReferrer'] as String?;
          _userAgent = msg['userAgent'] as String?;
          _playerState = (msg['playerState'] as num?)?.toInt();
          _muted = msg['muted'] as bool?;
          _volume = (msg['volume'] as num?)?.toDouble();
          _currentTime = (msg['currentTime'] as num?)?.toDouble();
          _appendLog(
            'ERROR errorCode=${msg['errorCode']} requestedVideoId=${msg['requestedVideoId']} '
            'actualVideoId=${msg['actualVideoId']} documentOrigin=${msg['documentOrigin']} '
            'documentReferrer=${msg['documentReferrer']} playerState=${msg['playerState']} '
            'muted=${msg['muted']} volume=${msg['volume']}',
          );
        case 'stateChange':
          _requestedVideoId = msg['requestedVideoId'] as String? ?? _requestedVideoId;
          _playerState = (msg['state'] as num?)?.toInt();
          _muted = msg['muted'] as bool?;
          _volume = (msg['volume'] as num?)?.toDouble();
          _currentTime = (msg['currentTime'] as num?)?.toDouble();
          _appendLog(
            'stateChange state=${msg['state']} muted=${msg['muted']} volume=${msg['volume']}',
          );
        case 'autoplayBlocked':
          _autoplayBlocked = true;
          _playerState = (msg['playerState'] as num?)?.toInt();
          _muted = msg['muted'] as bool?;
          _volume = (msg['volume'] as num?)?.toDouble();
          _appendLog(
            'autoplayBlocked requestedVideoId=${msg['requestedVideoId']} '
            'playerState=${msg['playerState']} muted=${msg['muted']} volume=${msg['volume']}',
          );
      }
    });
  }

  void _send(String cmd, [Map<String, dynamic>? args]) {
    _controller?.runJavaScript(
      'window.handleMenziCommand(${jsonEncode(jsonEncode({'cmd': cmd, ...?args}))})',
    );
  }

  void _loadAndPlay(String videoId) {
    setState(() {
      _lastErrorCode = null;
      _lastErrorActualVideoId = null;
      _autoplayBlocked = false;
    });
    _appendLog('user tapped: load+play $videoId');
    // Secuencia gesto-a-gesto pedida en el diagnóstico: load -> play -> unmute, cada uno
    // disparado por ESTE toque real, nunca automático al abrir la pantalla.
    _send('load', {'videoId': videoId});
    _send('play');
    _send('unmute', {'volume': 80});
  }

  Future<void> _openInChrome(String videoId) async {
    final uri = Uri.parse('${AppConfig.menziDjPlayerUrl}?videoId=$videoId&autoplay=0');
    _appendLog('opening in external browser: $uri');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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
            height: 200,
            child: controller == null
                ? const Center(child: CircularProgressIndicator())
                : WebViewWidget(controller: controller),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton(
                      onPressed: _iframeReady
                          ? () => _loadAndPlay(_publicVideoId)
                          : null,
                      child: const Text('Probar video público'),
                    ),
                    ElevatedButton(
                      onPressed: () => _openInChrome(_publicVideoId),
                      child: const Text('Abrir video público en Chrome'),
                    ),
                    ElevatedButton(
                      onPressed: () => _send('pause'),
                      child: const Text('Pausar'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _customVideoIdController,
                  decoration: const InputDecoration(
                    labelText: 'videoId de la canción que falló en Menzi DJ',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton(
                      onPressed: _iframeReady
                          ? () {
                              final id = _customVideoIdController.text.trim();
                              if (id.isNotEmpty) _loadAndPlay(id);
                            }
                          : null,
                      child: const Text('Probar canción actual'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        final id = _customVideoIdController.text.trim();
                        if (id.isNotEmpty) _openInChrome(id);
                      },
                      child: const Text('Abrir canción actual en Chrome'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estado (Fase 2 del diagnóstico)',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  _DiagnosticRow('pageUrl', AppConfig.menziDjPlayerUrl),
                  _DiagnosticRow('configuredOrigin', AppConfig.menziDjOrigin),
                  _DiagnosticRow('documentOrigin (del último error)', _documentOrigin),
                  _DiagnosticRow('documentReferrer (del último error)', _documentReferrer),
                  _DiagnosticRow('userAgent (del último error)', _userAgent),
                  _DiagnosticRow('pageLoaded', '$_pageLoaded'),
                  _DiagnosticRow('iframeReady', '$_iframeReady'),
                  _DiagnosticRow('requestedVideoId', _requestedVideoId),
                  _DiagnosticRow(
                    'onError code',
                    _lastErrorCode == null
                        ? '-'
                        : '${_lastErrorCode!} (${YtPlayerError.describe(_lastErrorCode!)})',
                  ),
                  _DiagnosticRow('actualVideoId (del último error)', _lastErrorActualVideoId),
                  _DiagnosticRow('playerState', '${_playerState ?? '-'}'),
                  _DiagnosticRow('muted', '${_muted ?? '-'}'),
                  _DiagnosticRow('volume', '${_volume ?? '-'}'),
                  _DiagnosticRow('currentTime', '${_currentTime ?? '-'}'),
                  _DiagnosticRow('autoplayBlocked', '$_autoplayBlocked'),
                  _DiagnosticRow(
                    'timestamp último evento',
                    _lastEventAt?.toIso8601String() ?? '-',
                  ),
                  const SizedBox(height: 12),
                  Text('Log', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 6),
                  SelectableText(
                    _log,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow(this.label, this.value);
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: SelectableText.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            TextSpan(text: value ?? '-', style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
