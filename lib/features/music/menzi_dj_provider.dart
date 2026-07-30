import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Color;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/network/api_exception.dart';
import '../../core/network/stomp_service.dart';
import '../../core/providers/repository_providers.dart';
import '../../data/models/music_models.dart';
import '../live/live_provider.dart';
import 'menzi_dj_player_html.dart';

const _driftCheckInterval = Duration(seconds: 15);
const _driftThresholdSeconds = 2;
const _defaultVolume = 80;

class MenziDjState {
  const MenziDjState({
    this.session,
    this.loading = false,
    this.expanded = false,
    this.localMuted = false,
    this.localVolume = _defaultVolume,
    this.playerReady = false,
  });

  final MusicSession? session;
  final bool loading;
  final bool expanded;
  final bool localMuted;
  final int localVolume;
  final bool playerReady;

  bool get hasTrack => session?.currentVideoId != null;

  MenziDjState copyWith({
    MusicSession? session,
    bool clearSession = false,
    bool? loading,
    bool? expanded,
    bool? localMuted,
    int? localVolume,
    bool? playerReady,
  }) => MenziDjState(
    session: clearSession ? null : (session ?? this.session),
    loading: loading ?? this.loading,
    expanded: expanded ?? this.expanded,
    localMuted: localMuted ?? this.localMuted,
    localVolume: localVolume ?? this.localVolume,
    playerReady: playerReady ?? this.playerReady,
  );
}

/// Menzi DJ — equivalente Flutter de menzoweb/lib/music/MenziDjContext.tsx y su versión
/// React Native (WebView). El WebView del reproductor oficial de YouTube vive montado una sola
/// vez (ver [MenziDjMiniBar]/[MenziDjPanel]) y sobrevive a cualquier navegación. Atado al ciclo
/// de vida de [liveProvider].activeRoomId — no tiene sentido escuchar música de un LIVE al que
/// no estás conectado.
class MenziDjNotifier extends Notifier<MenziDjState> {
  WebViewController? _controller;
  StompChannel? _channel;
  Timer? _driftTimer;
  String? _roomId;
  String? _loadedVideoId;
  void Function(double seconds)? _pendingTimeRequest;

  WebViewController get controller {
    return _controller ??= WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000))
      ..addJavaScriptChannel(
        'MenziBridge',
        onMessageReceived: _handleBridgeMessage,
      )
      ..loadHtmlString(menziDjPlayerHtml);
  }

  @override
  MenziDjState build() {
    ref.listen<LiveState>(liveProvider, (previous, next) {
      final roomId = next.activeRoomId;
      if (roomId == _roomId) return;
      _teardownChannel();
      _roomId = roomId;
      state = const MenziDjState();
      if (roomId != null) _setup(roomId);
    });
    ref.onDispose(_teardownChannel);
    return const MenziDjState();
  }

  void _setup(String roomId) {
    refresh();
    final channel = StompChannel();
    _channel = channel;
    channel.connect(
      onConnected: () {
        channel.subscribe('/topic/rooms/$roomId/music', (_) => refresh());
      },
    );
    _driftTimer = Timer.periodic(_driftCheckInterval, (_) {
      final current = state.session;
      if (current == null || current.status != MusicSessionStatus.playing)
        return;
      _pendingTimeRequest = (seconds) {
        final drift = (seconds - current.positionSeconds).abs();
        if (drift > _driftThresholdSeconds)
          _sendCommand('seek', {'seconds': current.positionSeconds});
      };
      _sendCommand('getTime');
    });
  }

  void _teardownChannel() {
    _channel?.dispose();
    _channel = null;
    _driftTimer?.cancel();
    _driftTimer = null;
    _loadedVideoId = null;
  }

  void _sendCommand(String cmd, [Map<String, dynamic>? args]) {
    _controller?.runJavaScript(
      'window.handleMenziCommand(${jsonEncode(jsonEncode({'cmd': cmd, ...?args}))})',
    );
  }

  void _applyLocalAudioState() {
    if (state.localMuted) {
      _sendCommand('mute');
    } else {
      _sendCommand('unmute', {'volume': state.localVolume});
    }
  }

  void _handleBridgeMessage(JavaScriptMessage message) {
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(message.message) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final type = msg['type'] as String?;
    if (type == 'ready') {
      state = state.copyWith(playerReady: true);
      _syncPlayerToSession(state.session);
    } else if (type == 'time' && msg['seconds'] is num) {
      _pendingTimeRequest?.call((msg['seconds'] as num).toDouble());
      _pendingTimeRequest = null;
    }
  }

  void _syncPlayerToSession(MusicSession? session) {
    if (session == null || session.currentVideoId == null) return;
    if (_loadedVideoId != session.currentVideoId) {
      _loadedVideoId = session.currentVideoId;
      _sendCommand('load', {'videoId': session.currentVideoId});
    }
    if (session.status == MusicSessionStatus.playing) {
      _sendCommand('seek', {'seconds': session.positionSeconds});
      _sendCommand('play');
      _applyLocalAudioState();
    } else if (session.status == MusicSessionStatus.paused) {
      _sendCommand('seek', {'seconds': session.positionSeconds});
      _sendCommand('pause');
    }
  }

  Future<void> refresh() async {
    final roomId = _roomId;
    if (roomId == null) return;
    state = state.copyWith(loading: true);
    try {
      final session = await ref.read(musicRepositoryProvider).snapshot(roomId);
      state = state.copyWith(session: session, loading: false);
      if (state.playerReady) _syncPlayerToSession(session);
    } catch (_) {
      state = state.copyWith(clearSession: true, loading: false);
    }
  }

  void setExpanded(bool value) => state = state.copyWith(expanded: value);

  void toggleLocalMute() {
    final next = !state.localMuted;
    state = state.copyWith(localMuted: next);
    if (next) {
      _sendCommand('mute');
    } else {
      _sendCommand('unmute', {'volume': state.localVolume});
    }
  }

  void setLocalVolume(int value) {
    final clamped = value.clamp(0, 100);
    state = state.copyWith(localVolume: clamped);
    if (!state.localMuted) _sendCommand('volume', {'volume': clamped});
  }

  int? get _version => state.session?.version;

  Future<List<YoutubeSearchResult>> searchSongs(String query) async {
    final roomId = _roomId;
    if (roomId == null) return const [];
    return ref.read(musicRepositoryProvider).search(roomId, query);
  }

  Future<void> addToQueue(String videoId, {bool playNow = false}) async {
    final roomId = _roomId;
    if (roomId == null) return;
    final session = await ref
        .read(musicRepositoryProvider)
        .addToQueue(
          roomId,
          videoId: videoId,
          expectedVersion: _version,
          playNow: playNow,
        );
    state = state.copyWith(session: session);
    _syncPlayerToSession(session);
  }

  Future<void> requestSong(String videoId) async {
    final roomId = _roomId;
    if (roomId == null) return;
    await ref.read(musicRepositoryProvider).requestSong(roomId, videoId);
    await refresh();
  }

  Future<void> approveRequest(String id) async {
    if (_roomId == null) return;
    await ref.read(musicRepositoryProvider).approveRequest(_roomId!, id);
    await refresh();
  }

  Future<void> rejectRequest(String id) async {
    if (_roomId == null) return;
    await ref.read(musicRepositoryProvider).rejectRequest(_roomId!, id);
    await refresh();
  }

  Future<void> _applyControl(
    Future<MusicSession> Function(String roomId, {int? expectedVersion}) action,
  ) async {
    final roomId = _roomId;
    if (roomId == null) return;
    final session = await action(roomId, expectedVersion: _version);
    state = state.copyWith(session: session);
    _syncPlayerToSession(session);
  }

  Future<void> play() => _applyControl(ref.read(musicRepositoryProvider).play);
  Future<void> pauseTrack() =>
      _applyControl(ref.read(musicRepositoryProvider).pause);
  Future<void> resumeTrack() =>
      _applyControl(ref.read(musicRepositoryProvider).resume);
  Future<void> skip() => _applyControl(ref.read(musicRepositoryProvider).skip);
  Future<void> stopMusic() =>
      _applyControl(ref.read(musicRepositoryProvider).stop);

  Future<void> removeQueueItem(String id) async {
    if (_roomId == null) return;
    await ref.read(musicRepositoryProvider).removeQueueItem(_roomId!, id);
    await refresh();
  }
}

final menziDjProvider = NotifierProvider<MenziDjNotifier, MenziDjState>(
  MenziDjNotifier.new,
);

/// Re-exporta ApiException para las pantallas de música (evita otro import en cada archivo).
typedef MenziApiException = ApiException;
