import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/native/background_audio_channel.dart';
import '../../core/network/stomp_service.dart';
import '../../core/providers/repository_providers.dart';
import '../../data/models/live_models.dart';

const _speakingRoles = {
  LiveParticipantRole.host,
  LiveParticipantRole.coHost,
  LiveParticipantRole.speaker,
};

class LiveState {
  const LiveState({
    this.watchedRoomId,
    this.viewingState,
    this.activeRoomId,
    this.session,
    this.connected = false,
    this.connecting = false,
    this.myRole,
    this.muted = true,
    this.microphoneChanging = false,
    this.localAudioPublished = false,
    this.lastMicrophoneError,
    this.microphonePermissionDenied = false,
    this.participants = const [],
    this.speakingLevels = const {},
    this.speakingRequests = const [],
  });

  final String? watchedRoomId;
  final LiveSession? viewingState;
  final String? activeRoomId;
  final LiveSession? session;
  final bool connected;
  final bool connecting;
  final LiveParticipantRole? myRole;
  final bool muted;
  final bool microphoneChanging;
  final bool localAudioPublished;
  final String? lastMicrophoneError;
  final bool microphonePermissionDenied;
  final List<LiveParticipant> participants;
  final Map<String, double> speakingLevels;
  final List<LiveParticipant> speakingRequests;

  bool get canSpeak => _speakingRoles.contains(myRole);
  bool get canModerate =>
      myRole == LiveParticipantRole.host ||
      myRole == LiveParticipantRole.coHost;

  LiveState copyWith({
    String? watchedRoomId,
    bool clearWatchedRoomId = false,
    LiveSession? viewingState,
    bool clearViewingState = false,
    String? activeRoomId,
    bool clearActiveRoomId = false,
    LiveSession? session,
    bool clearSession = false,
    bool? connected,
    bool? connecting,
    LiveParticipantRole? myRole,
    bool clearMyRole = false,
    bool? muted,
    bool? microphoneChanging,
    bool? localAudioPublished,
    String? lastMicrophoneError,
    bool clearLastMicrophoneError = false,
    bool? microphonePermissionDenied,
    List<LiveParticipant>? participants,
    Map<String, double>? speakingLevels,
    List<LiveParticipant>? speakingRequests,
  }) => LiveState(
    watchedRoomId: clearWatchedRoomId
        ? null
        : (watchedRoomId ?? this.watchedRoomId),
    viewingState: clearViewingState
        ? null
        : (viewingState ?? this.viewingState),
    activeRoomId: clearActiveRoomId
        ? null
        : (activeRoomId ?? this.activeRoomId),
    session: clearSession ? null : (session ?? this.session),
    connected: connected ?? this.connected,
    connecting: connecting ?? this.connecting,
    myRole: clearMyRole ? null : (myRole ?? this.myRole),
    muted: muted ?? this.muted,
    microphoneChanging: microphoneChanging ?? this.microphoneChanging,
    localAudioPublished: localAudioPublished ?? this.localAudioPublished,
    lastMicrophoneError: clearLastMicrophoneError
        ? null
        : (lastMicrophoneError ?? this.lastMicrophoneError),
    microphonePermissionDenied:
        microphonePermissionDenied ?? this.microphonePermissionDenied,
    participants: participants ?? this.participants,
    speakingLevels: speakingLevels ?? this.speakingLevels,
    speakingRequests: speakingRequests ?? this.speakingRequests,
  );
}

/// Equivalente de LiveRoomContext (web) / VoiceRoomContext (RN) — el proveedor global de la
/// conexión de voz Agora, montado una sola vez sobre el router para que sobreviva a cualquier
/// navegación (ver [PersistentVoiceBubble]).
///
/// Flujo de micrófono (ver la corrección aplicada esta misma sesión al bug de
/// TRACK_IS_DISABLED en menzoweb — acá el equivalente nativo, que YA seguía el orden correcto
/// en la app RN): 1) enableLocalAudio(true), 2) updateChannelMediaOptions
/// (publishMicrophoneTrack: true) — publicar mientras está habilitado, 3) recién ahí
/// muteLocalAudioStream(true). Jamás se llama enableLocalAudio(false) antes de publicar, y
/// mutear/desmutear después de la publicación inicial es siempre muteLocalAudioStream, nunca
/// una nueva publicación.
class LiveNotifier extends Notifier<LiveState> {
  RtcEngine? _engine;
  StompChannel? _liveChannel;
  String? _myUid;

  @override
  LiveState build() {
    ref.onDispose(() {
      _liveChannel?.dispose();
      _engine?.release();
    });
    return const LiveState();
  }

  void watchRoom(String roomId) {
    state = state.copyWith(watchedRoomId: roomId);
    ref.read(liveRepositoryProvider).state(roomId).then((session) {
      if (state.watchedRoomId == roomId)
        state = state.copyWith(
          viewingState: session,
          clearViewingState: session == null,
        );
    });
  }

  void unwatchRoom(String roomId) {
    if (state.watchedRoomId == roomId) {
      state = state.copyWith(clearWatchedRoomId: true, clearViewingState: true);
    }
  }

  Future<void> join(String roomId) async {
    if (state.connecting || state.activeRoomId == roomId) return;
    state = state.copyWith(connecting: true, clearLastMicrophoneError: true);
    try {
      final liveRepo = ref.read(liveRepositoryProvider);
      final session = await liveRepo.join(roomId);
      final token = await liveRepo.token(roomId);
      _myUid = token.uid;

      final engine = createAgoraRtcEngine();
      await engine.initialize(RtcEngineContext(appId: token.appId));
      await engine.enableAudio();
      _engine = engine;

      engine.registerEventHandler(
        RtcEngineEventHandler(
          onAudioVolumeIndication:
              (connection, speakers, speakerNumber, totalVolume) {
                final levels = <String, double>{};
                for (final speaker in speakers) {
                  levels[(speaker.uid ?? 0).toString()] =
                      ((speaker.volume ?? 0) / 255).clamp(0.0, 1.0);
                }
                state = state.copyWith(speakingLevels: levels);
              },
        ),
      );
      await engine.enableAudioVolumeIndication(
        interval: 300,
        smooth: 3,
        reportVad: true,
      );

      final canSpeak = _speakingRoles.contains(session.myRole);
      await engine.joinChannel(
        token: token.token,
        channelId: token.channelName,
        uid: int.tryParse(token.uid) ?? 0,
        options: ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: canSpeak
              ? ClientRoleType.clientRoleBroadcaster
              : ClientRoleType.clientRoleAudience,
          publishMicrophoneTrack: false,
          autoSubscribeAudio: true,
        ),
      );

      state = state.copyWith(
        activeRoomId: roomId,
        session: session,
        connected: true,
        connecting: false,
        myRole: session.myRole,
      );
      _subscribeLiveEvents(roomId);
      await refreshParticipants(roomId);
      if (state.canModerate) await refreshSpeakingRequests(roomId);

      if (canSpeak) {
        await _requestMicAndPublish();
      } else {
        // Audiencia: nunca se pide RECORD_AUDIO ni se declara el tipo `microphone` del
        // foreground service — solo `mediaPlayback`, para que Menzi DJ siga sonando en
        // segundo plano. Pedir el permiso o el tipo microphone acá sería exactamente el bug
        // que tiraba `SecurityException` (Android lo rechaza sin el permiso concedido).
        await BackgroundAudioChannel.start(
          mode: BackgroundAudioMode.listen,
          title: 'MENZO · en vivo',
          text: 'Escuchando un LIVE',
        );
      }
    } catch (e) {
      state = state.copyWith(
        connecting: false,
        lastMicrophoneError: 'No pudimos conectar al LIVE. Intenta de nuevo.',
      );
      await _cleanupEngine();
      await BackgroundAudioChannel.stop();
    }
  }

  /// Único punto que pide `RECORD_AUDIO` en toda la app. Se llama siempre con la Activity
  /// visible (nunca desde un timer, un callback de WebSocket en background, ni desde
  /// `initState` sin que el usuario haya pedido entrar/hablar en un LIVE) — es lo que exige
  /// Android para poder mostrar el diálogo del sistema. Solo después de un resultado
  /// `granted` se publica el micrófono y se le pide al foreground service el tipo
  /// `microphone`; si se rechaza, el usuario queda como hablante "silenciado sin permiso" en
  /// vez de cerrarse la app.
  Future<void> _requestMicAndPublish() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      state = state.copyWith(
        microphonePermissionDenied: true,
        localAudioPublished: false,
        lastMicrophoneError:
            'No pudimos acceder a tu micrófono. Actívalo desde los ajustes de la app para hablar.',
      );
      await BackgroundAudioChannel.start(
        mode: BackgroundAudioMode.listen,
        title: 'MENZO · en vivo',
        text: 'Escuchando un LIVE',
      );
      return;
    }
    state = state.copyWith(microphonePermissionDenied: false);
    await _publishMic();
    await BackgroundAudioChannel.start(
      mode: BackgroundAudioMode.speak,
      title: 'MENZO · en vivo',
      text: 'Tu micrófono está activo en un LIVE',
    );
  }

  Future<void> _publishMic() async {
    final engine = _engine;
    if (engine == null) return;
    try {
      await engine.enableLocalAudio(true);
      await engine.updateChannelMediaOptions(
        const ChannelMediaOptions(publishMicrophoneTrack: true),
      );
      await engine.muteLocalAudioStream(true);
      state = state.copyWith(
        localAudioPublished: true,
        muted: true,
        clearLastMicrophoneError: true,
      );
    } catch (e) {
      state = state.copyWith(
        localAudioPublished: false,
        lastMicrophoneError:
            'No pudimos acceder a tu micrófono. Revisa los permisos.',
      );
    }
  }

  Future<void> becomeSpeaker(String roomId) async {
    final engine = _engine;
    if (engine == null) return;
    try {
      final token = await ref.read(liveRepositoryProvider).token(roomId);
      await engine.renewToken(token.token);
      await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      state = state.copyWith(myRole: LiveParticipantRole.speaker);
      await _requestMicAndPublish();
    } catch (e) {
      state = state.copyWith(
        lastMicrophoneError: 'No pudimos activar tu lugar como hablante.',
      );
    }
  }

  Future<void> becomeAudience() async {
    final engine = _engine;
    final roomId = state.activeRoomId;
    if (engine != null) {
      try {
        await engine.muteLocalAudioStream(true);
        await engine.updateChannelMediaOptions(
          const ChannelMediaOptions(publishMicrophoneTrack: false),
        );
        await engine.enableLocalAudio(false);
        await engine.setClientRole(role: ClientRoleType.clientRoleAudience);
      } catch (_) {}
    }
    state = state.copyWith(
      muted: true,
      localAudioPublished: false,
      microphonePermissionDenied: false,
      clearLastMicrophoneError: true,
    );
    // Bajamos el foreground service a solo `mediaPlayback` — seguimos en el LIVE como
    // audiencia (y Menzi DJ puede seguir sonando), pero ya no corresponde el tipo `microphone`.
    await BackgroundAudioChannel.start(
      mode: BackgroundAudioMode.listen,
      title: 'MENZO · en vivo',
      text: 'Escuchando un LIVE',
    );
    if (engine != null && roomId != null) {
      try {
        final token = await ref.read(liveRepositoryProvider).token(roomId);
        await engine.renewToken(token.token);
      } catch (_) {}
    }
  }

  /// Único punto que muta/desmuta — nunca vuelve a publicar la pista (ver comentario de clase).
  Future<void> toggleMute() async {
    if (state.microphoneChanging || !state.canSpeak) return;
    final roomId = state.activeRoomId;
    final engine = _engine;
    if (roomId == null || engine == null) return;

    state = state.copyWith(
      microphoneChanging: true,
      clearLastMicrophoneError: true,
    );
    try {
      if (!state.localAudioPublished) {
        await _publishMic();
        return;
      }
      final next = !state.muted;
      await engine.muteLocalAudioStream(next);
      state = state.copyWith(muted: next);
      ref
          .read(liveRepositoryProvider)
          .setMicrophone(roomId, !next)
          .catchError((_) {});
    } catch (_) {
      state = state.copyWith(
        lastMicrophoneError:
            'No pudimos cambiar el micrófono. Intenta de nuevo.',
      );
    } finally {
      state = state.copyWith(microphoneChanging: false);
    }
  }

  Future<void> requestToSpeak(String roomId) =>
      ref.read(liveRepositoryProvider).requestToSpeak(roomId);
  Future<void> cancelSpeakRequest(String roomId) =>
      ref.read(liveRepositoryProvider).cancelSpeakRequest(roomId);

  Future<void> refreshParticipants(String roomId) async {
    final list = await ref.read(liveRepositoryProvider).participants(roomId);
    state = state.copyWith(participants: list);
  }

  Future<void> refreshSpeakingRequests(String roomId) async {
    try {
      final list = await ref
          .read(liveRepositoryProvider)
          .speakingRequests(roomId);
      state = state.copyWith(speakingRequests: list);
    } catch (_) {}
  }

  Future<void> approveSpeaking(String roomId, String userId) async {
    await ref.read(liveRepositoryProvider).approveSpeaking(roomId, userId);
    await Future.wait([
      refreshParticipants(roomId),
      refreshSpeakingRequests(roomId),
    ]);
  }

  Future<void> rejectSpeaking(String roomId, String userId) async {
    await ref.read(liveRepositoryProvider).rejectSpeaking(roomId, userId);
    await Future.wait([
      refreshParticipants(roomId),
      refreshSpeakingRequests(roomId),
    ]);
  }

  Future<void> demoteParticipant(String roomId, String userId) async {
    await ref.read(liveRepositoryProvider).demoteParticipant(roomId, userId);
    await refreshParticipants(roomId);
  }

  Future<void> muteParticipant(String roomId, String userId) async {
    await ref.read(liveRepositoryProvider).muteParticipant(roomId, userId);
    await refreshParticipants(roomId);
  }

  Future<void> removeParticipant(String roomId, String userId) async {
    await ref.read(liveRepositoryProvider).removeParticipant(roomId, userId);
    await refreshParticipants(roomId);
  }

  Future<void> updateAnnouncement(String roomId, String announcement) async {
    final session = await ref.read(liveRepositoryProvider).update(roomId, {
      'announcement': announcement,
    });
    state = state.copyWith(session: session);
  }

  Future<void> endLiveForAll(String roomId) async {
    await ref.read(liveRepositoryProvider).end(roomId);
    await leave();
  }

  void _subscribeLiveEvents(String roomId) {
    final channel = StompChannel();
    _liveChannel = channel;
    channel.connect(
      onConnected: () {
        channel.subscribe('/topic/rooms/$roomId/live', (payload) {
          final type = payload['type'] as String?;
          if (type == 'CHAT_LIVE_ENDED') {
            leave();
            return;
          }
          refreshParticipants(roomId);
          if (state.canModerate) refreshSpeakingRequests(roomId);
          final myPayloadUser =
              (payload['payload'] as Map<String, dynamic>?)?['user']
                  as Map<String, dynamic>?;
          final isMe = myPayloadUser != null && myPayloadUser['id'] == _myUid;
          if (isMe && type == 'CHAT_LIVE_SPEAKING_APPROVED') {
            becomeSpeaker(roomId);
          } else if (isMe &&
              (type == 'CHAT_LIVE_PARTICIPANT_DEMOTED' ||
                  type == 'CHAT_LIVE_SPEAKING_REJECTED')) {
            becomeAudience();
          } else if (type == 'CHAT_LIVE_ANNOUNCEMENT_UPDATED') {
            final announcement = payload['payload'] is Map<String, dynamic>
                ? (payload['payload'] as Map<String, dynamic>)['announcement']
                      as String?
                : null;
            final current = state.session;
            if (current != null) {
              state = state.copyWith(
                session: LiveSession(
                  id: current.id,
                  roomId: current.roomId,
                  status: current.status,
                  title: current.title,
                  description: current.description,
                  announcement: announcement,
                  startedAt: current.startedAt,
                  participantCount: current.participantCount,
                  speakerCount: current.speakerCount,
                  myRole: current.myRole,
                  myMicrophoneEnabled: current.myMicrophoneEnabled,
                  hasPendingSpeakRequest: current.hasPendingSpeakRequest,
                ),
              );
            }
          }
        });
      },
    );
  }

  Future<void> leave() async {
    final roomId = state.activeRoomId;
    await _cleanupEngine();
    state = const LiveState();
    await BackgroundAudioChannel.stop();
    if (roomId != null) {
      await ref.read(liveRepositoryProvider).leave(roomId).catchError((_) {});
    }
  }

  Future<void> _cleanupEngine() async {
    _liveChannel?.dispose();
    _liveChannel = null;
    try {
      await _engine?.leaveChannel();
      await _engine?.release();
    } catch (_) {}
    _engine = null;
  }
}

final liveProvider = NotifierProvider<LiveNotifier, LiveState>(
  LiveNotifier.new,
);
