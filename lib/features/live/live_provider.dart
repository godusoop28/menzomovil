import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/diagnostics/device_session.dart';
import '../../core/native/background_audio_channel.dart';
import '../../core/network/api_exception.dart';
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
    this.forceMuted = false,
    this.microphoneChanging = false,
    this.localAudioPublished = false,
    this.lastMicrophoneError,
    this.microphonePermissionDenied = false,
    this.reconnecting = false,
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

  /// true cuando el último cambio a `muted` vino de un FORCE_MUTE de un anfitrión/coanfitrión
  /// (ver `_applyRemoteMicrophoneChange`), no de un `toggleMute()` propio — mientras esté en
  /// `true`, `toggleMute()` no puede desmutear localmente (ver el guard ahí). Se limpia con el
  /// siguiente `_publishMic` (rejoin, o al ser re-aprobado para hablar tras una democión).
  final bool forceMuted;
  final bool microphoneChanging;
  final bool localAudioPublished;
  final String? lastMicrophoneError;
  final bool microphonePermissionDenied;
  final bool reconnecting;
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
    bool? forceMuted,
    bool? microphoneChanging,
    bool? localAudioPublished,
    String? lastMicrophoneError,
    bool clearLastMicrophoneError = false,
    bool? microphonePermissionDenied,
    bool? reconnecting,
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
    forceMuted: forceMuted ?? this.forceMuted,
    microphoneChanging: microphoneChanging ?? this.microphoneChanging,
    localAudioPublished: localAudioPublished ?? this.localAudioPublished,
    lastMicrophoneError: clearLastMicrophoneError
        ? null
        : (lastMicrophoneError ?? this.lastMicrophoneError),
    microphonePermissionDenied:
        microphonePermissionDenied ?? this.microphonePermissionDenied,
    reconnecting: reconnecting ?? this.reconnecting,
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
  StompChannel? _watchChannel;
  Timer? _heartbeatTimer;
  String? _myUid;
  int _watchRequestSeq = 0;

  @override
  LiveState build() {
    ref.onDispose(() {
      _liveChannel?.dispose();
      _watchChannel?.dispose();
      _heartbeatTimer?.cancel();
      _engine?.release();
    });
    return const LiveState();
  }

  /// Solo mirar el estado del LIVE (para la cabecera/badge de la sala) sin unirse al audio —
  /// 1:1 con menzoweb/lib/live/LiveRoomContext.tsx `watchRoom`. Antes esto solo hacía UN fetch
  /// REST puntual y nunca más se actualizaba: si alguien iniciaba un LIVE mientras otro usuario
  /// ya tenía la sala abierta (o la sala aparecía en el carrusel de "en vivo" de home), esa
  /// persona nunca se enteraba — la sala parecía sin LIVE y no aparecía forma de unirse, hasta
  /// que cerraba y volvía a abrir la pantalla. Ahora también se suscribe a
  /// `/topic/rooms/{roomId}/live` y refresca en cualquier evento relevante.
  void watchRoom(String roomId) {
    state = state.copyWith(watchedRoomId: roomId);
    _refreshViewingState(roomId);

    final channel = StompChannel();
    _watchChannel?.dispose();
    _watchChannel = channel;
    channel.connect(
      // Un corte de red breve mientras solo se está "mirando" la sala (sin unirse al audio)
      // podía perderse el evento de que un LIVE arrancó/terminó justo durante ese lapso — STOMP
      // no reentrega lo que pasó mientras el socket estuvo caído.
      onReconnected: () => _refreshViewingState(roomId),
      onConnected: () {
        channel.subscribe('/topic/rooms/$roomId/live', (payload) {
          if (state.watchedRoomId != roomId) return;
          final type = payload['type'] as String?;
          if (type == 'CHAT_LIVE_ENDED') {
            final current = state.viewingState;
            if (current != null) {
              state = state.copyWith(
                viewingState: LiveSession(
                  id: current.id,
                  roomId: current.roomId,
                  status: 'ENDED',
                  title: current.title,
                  description: current.description,
                  announcement: current.announcement,
                  startedAt: current.startedAt,
                  participantCount: current.participantCount,
                  speakerCount: current.speakerCount,
                  myRole: current.myRole,
                  myMicrophoneEnabled: current.myMicrophoneEnabled,
                  hasPendingSpeakRequest: current.hasPendingSpeakRequest,
                ),
              );
            }
            return;
          }
          _refreshViewingState(roomId);
        });
      },
    );
  }

  /// `requestSeq` descarta una respuesta que llegue tarde después de una más nueva (dos
  /// eventos casi juntos), para que el estado nunca "rebote" hacia uno viejo.
  Future<void> _refreshViewingState(String roomId) async {
    final seq = ++_watchRequestSeq;
    try {
      final session = await ref.read(liveRepositoryProvider).state(roomId);
      if (state.watchedRoomId != roomId || seq != _watchRequestSeq) return;
      state = state.copyWith(
        viewingState: session,
        clearViewingState: session == null,
      );
    } catch (_) {
      if (state.watchedRoomId == roomId && seq == _watchRequestSeq) {
        state = state.copyWith(clearViewingState: true);
      }
    }
  }

  void unwatchRoom(String roomId) {
    if (state.watchedRoomId == roomId) {
      _watchChannel?.dispose();
      _watchChannel = null;
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
      // `channelProfileCommunication` (el perfil correcto para un LIVE de voz simple) tiene como
      // ruta de audio POR DEFECTO el auricular de arriba (volumen bajísimo, pensado para
      // sostener el teléfono contra la oreja) — así lo documenta la propia Agora: "Voice call:
      // Earpiece". Nada lo cambiaba, así que tanto las voces como el audio del WebView de Menzi
      // DJ (que comparte la misma sesión de audio del proceso) salían por ahí en cada teléfono.
      // Con una sola persona en la sala no se nota tanto (el que prueba se pone el teléfono en
      // la oreja); apenas hay varias, el resto no escucha nada perceptible y parece que "el bot
      // no suena" — en realidad sonaba, pero casi inaudible. Se fuerza altavoz para que tanto la
      // llamada como Menzi DJ se escuchen a volumen normal en todos los dispositivos.
      //
      // `try/catch` a propósito: esto es una preferencia de audio, nunca debe poder tumbar la
      // conexión entera al LIVE si algún OEM/versión de Android la rechaza — antes una falla acá
      // (antes de siquiera unirse al canal) abortaba TODO el intento de conectar, dejando al
      // usuario de nuevo en la pantalla de "Escuchar" sin ningún LIVE, sin aviso de qué pasó.
      try {
        await engine.setDefaultAudioRouteToSpeakerphone(true);
      } catch (_) {}
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
          // Red de seguridad: si Agora reporta que la captura/codificación de audio falló de
          // verdad (no solo un mute nuestro, que no pasa por acá), el estado local
          // (`localAudioPublished`) se corrige solo en vez de quedar mintiendo que el
          // micrófono sigue publicado cuando en los hechos dejó de estarlo.
          onLocalAudioStateChanged: (connection, audioState, reason) {
            if (audioState ==
                LocalAudioStreamState.localAudioStreamStateFailed) {
              state = state.copyWith(
                localAudioPublished: false,
                lastMicrophoneError:
                    'Se perdió la conexión con tu micrófono. Volvé a intentarlo.',
              );
            }
          },
          // El SDK de Agora ya reintenta reconectar solo ante cortes de red (hasta 20 min) —
          // acá solo reflejamos ese estado en la UI, para que "sin audio unos segundos" se vea
          // como "reconectando" en vez de parecer que el LIVE se rompió sin explicación.
          onConnectionStateChanged: (connection, connState, reason) {
            if (connState == ConnectionStateType.connectionStateReconnecting) {
              state = state.copyWith(reconnecting: true);
            } else if (connState ==
                ConnectionStateType.connectionStateConnected) {
              state = state.copyWith(
                reconnecting: false,
                clearLastMicrophoneError: true,
              );
            } else if (connState == ConnectionStateType.connectionStateFailed) {
              state = state.copyWith(
                reconnecting: false,
                lastMicrophoneError:
                    'Se perdió la conexión de voz. Salí y volvé a entrar al LIVE.',
              );
            }
          },
          // El token de Agora expira a la hora (TOKEN_EXPIRE_SECONDS en LiveService.getToken) —
          // sin renovarlo, cualquier LIVE que dure más que eso desconecta a todos de golpe (audio
          // y Menzi DJ incluidos) sin ningún aviso previo. `onTokenPrivilegeWillExpire` da margen
          // para pedir uno nuevo y aplicarlo con `renewToken` ANTES de que el actual venza — sin
          // salir del canal, sin tocar mute/rol/nada más del estado del LIVE.
          onTokenPrivilegeWillExpire: (connection, token) async {
            debugPrint(
              '[Agora][${DeviceSession.id}] token renewal (willExpire)',
            );
            try {
              final fresh = await ref
                  .read(liveRepositoryProvider)
                  .token(roomId);
              await engine.renewToken(fresh.token);
            } catch (_) {
              // Best-effort: si falla, Agora reintentará este mismo callback más cerca del
              // vencimiento real; no hay nada seguro que hacer acá aparte de reintentar después.
            }
          },
          onRequestToken: (connection) async {
            // Menos común que willExpire (dispara si el token YA venció del lado del servidor de
            // Agora antes de que el SDK avisara) — mismo remedio: pedir uno nuevo y aplicarlo.
            try {
              final fresh = await ref
                  .read(liveRepositoryProvider)
                  .token(roomId);
              await engine.renewToken(fresh.token);
            } catch (_) {}
          },
        ),
      );
      await engine.enableAudioVolumeIndication(
        interval: 300,
        smooth: 3,
        reportVad: true,
      );

      final canSpeak = _speakingRoles.contains(session.myRole);
      // El backend firma el token con el esquema de "User Account" (un string, el UUID real
      // del usuario — ver LiveService.getToken/RtcTokenBuilder2.buildTokenWithUserAccount), no
      // con un uid numérico. `joinChannel(uid: ...)` esperaba un entero, y `int.tryParse` sobre
      // un UUID (con guiones y letras) siempre devuelve null → CADA usuario entraba con
      // `uid: 0`, todos exactamente el mismo. Con una sola persona en el LIVE eso no se nota
      // (no hay otro con quien chocar); apenas se suma una segunda persona real, Agora tiene
      // dos participantes reclamando la misma identidad en el mismo canal — de ahí que audio,
      // sincronización y todo lo demás se sintiera roto justo (y solo) con 2+ personas.
      // `channelProfileCommunication` (perfil de llamada 1 a 1 estilo WhatsApp) es lo que se
      // venía usando, pero la propia documentación del SDK de Agora lo dice explícito: "Agora
      // recommends using the live broadcasting profile for a better audio and video
      // experience." Esta sala es exactamente el escenario de una "sala de audio en vivo"
      // (host/co-host/hablantes + audiencia + música de fondo) para el que existe
      // `channelProfileLiveBroadcasting` — el perfil de llamada aplica un procesamiento de voz
      // pensado para tener el teléfono pegado a la boca (de ahí el micrófono sonando bajo) y
      // compite más agresivamente por el foco de audio de Android contra la reproducción del
      // WebView de Menzi DJ (de ahí que la música dejara de escuchársele a quien no fuera quien
      // la controlaba). Además, `clientRoleType` (broadcaster/audience, la distinción real
      // entre quién puede hablar y quién no) solo tiene efecto real a nivel del SDK bajo este
      // perfil — bajo el de llamada era un valor sin efecto práctico.
      await engine.joinChannelWithUserAccount(
        token: token.token,
        channelId: token.channelName,
        userAccount: token.uid,
        options: ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
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
      // Agora documenta `setEnableSpeakerphone` como la ruta de audio "del canal actual" —a
      // diferencia de `setDefaultAudioRouteToSpeakerphone` (seguro de llamar antes de unirse),
      // este solo tiene sentido pedirlo una vez adentro del canal. Best-effort: si falla, la
      // llamada de todas formas ya está conectada (lo importante), solo puede quedar en
      // auricular en vez de altavoz en ese dispositivo puntual.
      try {
        await engine.setEnableSpeakerphone(true);
      } catch (_) {}
      _subscribeLiveEvents(roomId);
      _startHeartbeat(roomId);
      await refreshParticipants(roomId);
      if (state.canModerate) await refreshSpeakingRequests(roomId);

      if (canSpeak) {
        await _requestMicAndPublish(initialMuted: true);
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
      // `clearActiveRoomId`/`connected: false` a propósito: si el fallo ocurrió DESPUÉS de que
      // ya se habían puesto en true (por ejemplo, un refresco de participantes que falló justo
      // tras conectar el canal de Agora), sin esto el estado quedaba a medio camino — la UI
      // creía seguir conectada a este roomId aunque `_cleanupEngine()` ya hubiera liberado el
      // motor real, y como el guard de arriba (`state.activeRoomId == roomId`) hace que un
      // reintento se ignore silenciosamente, la pantalla de "Escuchar" volvía a aparecer pero
      // tocarla ya no hacía nada. Ahora cualquier fallo dentro de este bloque deja un estado
      // limpio y consistente, listo para reintentar de verdad.
      // Antes esto era siempre el mismo texto genérico sin importar la causa real — si el
      // backend rechaza el join con un motivo concreto (p. ej. "tenés que unirte a la sala
      // antes", un LIVE que ya terminó, etc.) eso quedaba oculto detrás de "intentá de nuevo",
      // imposible de diagnosticar sin logs del servidor. Mostrar el mensaje real cuando es un
      // ApiException (viene del backend, siempre en español y pensado para el usuario) deja ver
      // la causa de verdad; solo se usa el genérico para errores nativos/de Agora sin mensaje
      // útil para mostrar.
      state = state.copyWith(
        connecting: false,
        connected: false,
        clearActiveRoomId: true,
        clearSession: true,
        clearMyRole: true,
        lastMicrophoneError: e is ApiException
            ? e.message
            : 'No pudimos conectar al LIVE. Intenta de nuevo.',
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
  Future<void> _requestMicAndPublish({required bool initialMuted}) async {
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
    await _publishMic(initialMuted: initialMuted);
    await BackgroundAudioChannel.start(
      mode: BackgroundAudioMode.speak,
      title: 'MENZO · en vivo',
      text: 'Tu micrófono está activo en un LIVE',
    );
  }

  /// [initialMuted] distingue el join automático (entra publicado pero silenciado — ver
  /// LiveService.startLive, que ahora crea al HOST con `microphoneEnabled=false` para coincidir)
  /// del primer toque real del usuario en "activar micrófono" (que sí debe terminar
  /// desmutuado, sin pedir un segundo toque — ver el guard viejo en `toggleMute` que llamaba
  /// esto mismo y después hacía `return` sin desmutear nunca).
  Future<void> _publishMic({required bool initialMuted}) async {
    final engine = _engine;
    if (engine == null) return;
    // Mientras esto está en vuelo, el botón de mutear debe quedar deshabilitado (igual que
    // durante un `toggleMute()`) — sin este flag, un tap del usuario justo durante la
    // publicación inicial (por ejemplo, apenas creado el LIVE) entraba en carrera con esta
    // misma función: `toggleMute()` veía `localAudioPublished` todavía en `false` y llamaba
    // a `_publishMic()` por segunda vez en paralelo, que siempre termina dejando `muted: true`
    // — así el toggle del usuario quedaba pisado sin que la UI reflejara jamás lo que tocó.
    state = state.copyWith(microphoneChanging: true);
    try {
      await engine.enableLocalAudio(true);
      await engine.updateChannelMediaOptions(
        const ChannelMediaOptions(publishMicrophoneTrack: true),
      );
      await engine.muteLocalAudioStream(initialMuted);
      state = state.copyWith(
        localAudioPublished: true,
        muted: initialMuted,
        // Un publish nuevo (join, o volver a hablar tras una democión) es un estado conocido y
        // deliberado — ya no aplica un FORCE_MUTE anterior de una etapa previa del LIVE.
        forceMuted: false,
        clearLastMicrophoneError: true,
      );
      // Confirma al backend el estado REAL que Agora acaba de aplicar — sin esto, el resto de
      // los participantes (que arman la insignia de micrófono desde
      // LiveParticipantResponse.microphoneEnabled, no desde Agora) podían ver a este usuario
      // como "con micrófono" mientras seguía mudo de verdad, o viceversa.
      final roomId = state.activeRoomId;
      if (roomId != null) {
        ref
            .read(liveRepositoryProvider)
            .setMicrophone(roomId, !initialMuted)
            .catchError((_) {});
      }
    } catch (e) {
      state = state.copyWith(
        localAudioPublished: false,
        lastMicrophoneError:
            'No pudimos acceder a tu micrófono. Revisa los permisos.',
      );
    } finally {
      state = state.copyWith(microphoneChanging: false);
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
      await _requestMicAndPublish(initialMuted: true);
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
    if (state.forceMuted && state.muted) {
      // Un anfitrión/coanfitrión forzó el mute — no es un mute propio que el usuario pueda
      // simplemente revertir tocando el botón de nuevo (ver `_applyRemoteMicrophoneChange`).
      state = state.copyWith(
        lastMicrophoneError:
            'Un anfitrión silenció tu micrófono — no podés reactivarlo vos.',
      );
      return;
    }

    state = state.copyWith(
      microphoneChanging: true,
      clearLastMicrophoneError: true,
    );
    try {
      if (!state.localAudioPublished) {
        // El usuario está tocando "activar micrófono" ahora mismo — a diferencia del join
        // automático (que entra silenciado a propósito), esta es una intención explícita de
        // hablar: debe terminar desmutuado sin pedir un segundo toque. Antes esto llamaba
        // `_publishMic()` directo (sin re-pedir el permiso de RECORD_AUDIO si se había negado
        // antes) y siempre dejaba `muted: true`, así que el primer toque nunca activaba nada.
        await _requestMicAndPublish(initialMuted: false);
        return;
      }
      final next = !state.muted;
      // Optimista: el ícono cambia al instante, no cuando Agora confirma — con "Discord-level"
      // de responsividad no alcanza con esperar el round-trip nativo antes de pintar el
      // cambio. Si `muteLocalAudioStream` falla, se revierte abajo.
      state = state.copyWith(muted: next);
      try {
        await engine.muteLocalAudioStream(next);
      } catch (e) {
        state = state.copyWith(
          muted: !next,
          lastMicrophoneError:
              'No pudimos cambiar el micrófono. Intenta de nuevo.',
        );
        return;
      }
      ref
          .read(liveRepositoryProvider)
          .setMicrophone(roomId, !next)
          .catchError((_) {});
    } finally {
      state = state.copyWith(microphoneChanging: false);
    }
  }

  Future<void> requestToSpeak(String roomId) =>
      ref.read(liveRepositoryProvider).requestToSpeak(roomId);
  Future<void> cancelSpeakRequest(String roomId) =>
      ref.read(liveRepositoryProvider).cancelSpeakRequest(roomId);

  Future<void> refreshParticipants(String roomId) async {
    try {
      final list = await ref.read(liveRepositoryProvider).participants(roomId);
      state = state.copyWith(participants: list);
    } catch (_) {
      // No debe poder tumbar el flujo de `join()` — antes, sin este try/catch, un fallo acá
      // (llamado justo después de conectar el canal de Agora) se propagaba hasta el catch de
      // `join()` DESPUÉS de que `activeRoomId`/`connected` ya se habían puesto en true, dejando
      // el estado a medio camino: la UI creía estar conectada pero el motor ya se había
      // liberado. Un fallo puntual acá simplemente deja la lista de participantes vieja por un
      // momento — se corrige solo con el próximo evento STOMP o el siguiente refresco.
    }
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

  /// Sin este ping periódico, el backend da por terminada la sesión sola a los 30-45s de
  /// inactividad de join/leave (ver LiveService.heartbeat) — un LIVE tranquilo (nadie entra o
  /// sale, solo se escucha) se "auto-terminaba" en silencio pasado ese lapso, y cualquier acción
  /// posterior (buscar una canción en Menzi DJ, por ejemplo) chocaba con "no hay un LIVE activo
  /// en esta sala" aunque el LIVE siguiera genuinamente en curso.
  void _startHeartbeat(String roomId) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      ref.read(liveRepositoryProvider).heartbeat(roomId).catchError((_) {});
    });
  }

  void _subscribeLiveEvents(String roomId) {
    final channel = StompChannel();
    _liveChannel = channel;
    channel.connect(
      // STOMP no reentrega eventos publicados mientras el socket estuvo caído — sin este
      // refetch, un corte de red breve podía dejar la lista de participantes (o de solicitudes
      // para hablar, si moderás) desactualizada para siempre, hasta el próximo evento que
      // llegara a pasar. Mismo patrón que `onReconnected` en chat_room_screen.dart.
      onReconnected: () {
        refreshParticipants(roomId);
        if (state.canModerate) refreshSpeakingRequests(roomId);
      },
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
          if (isMe && type == 'CHAT_LIVE_PARTICIPANT_LEFT') {
            // Mismo tipo de evento que un `leave()` propio, pero uno voluntario ya destruyó
            // `_liveChannel` antes de que este mensaje pudiera llegarnos — si de verdad lo
            // recibimos siendo nosotros el `user` del payload, es porque un anfitrión/coanfitrión
            // nos expulsó (`removeParticipant`), no porque nos hayamos ido solos. Sin esto, el
            // expulsado seguía publicando/escuchando Agora y con el foreground service activo
            // hasta que notara la app trabada y saliera a mano.
            state = state.copyWith(
              lastMicrophoneError: 'Un anfitrión te expulsó de este LIVE.',
            );
            leave();
            return;
          } else if (isMe && type == 'CHAT_LIVE_MICROPHONE_CHANGED') {
            final micEnabled =
                (payload['payload']
                        as Map<String, dynamic>?)?['microphoneEnabled']
                    as bool?;
            if (micEnabled != null) _applyRemoteMicrophoneChange(micEnabled);
          } else if (isMe && type == 'CHAT_LIVE_SPEAKING_APPROVED') {
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

  /// Reacciona a un CHAT_LIVE_MICROPHONE_CHANGED dirigido a este mismo usuario. El backend solo
  /// manda un booleano (`microphoneEnabled`), sin decir quién lo cambió — pero si el nuevo valor
  /// CONTRADICE lo que ya creíamos localmente (`state.muted`), no pudo haber salido de nuestro
  /// propio `toggleMute()`/`_publishMic()` (esos ya actualizan `state.muted` de manera optimista
  /// antes de que este eco vuelva), así que tiene que ser un FORCE_MUTE de un anfitrión/
  /// coanfitrión (`LiveService.forceMute`, la única otra vía que toca este campo). Si coincide
  /// con lo que ya aplicamos, es solo el eco de nuestro propio cambio — no hay nada que hacer.
  Future<void> _applyRemoteMicrophoneChange(bool microphoneEnabled) async {
    final shouldBeMuted = !microphoneEnabled;
    if (shouldBeMuted == state.muted) return;
    debugPrint(
      '[Live][${DeviceSession.id}] remote microphone change: microphoneEnabled=$microphoneEnabled (force)',
    );
    final engine = _engine;
    if (engine != null) {
      try {
        await engine.muteLocalAudioStream(shouldBeMuted);
      } catch (_) {}
    }
    state = state.copyWith(
      muted: shouldBeMuted,
      forceMuted: shouldBeMuted,
      lastMicrophoneError: shouldBeMuted
          ? 'Un anfitrión o coanfitrión silenció tu micrófono.'
          : null,
      clearLastMicrophoneError: !shouldBeMuted,
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
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
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

/// true mientras [LiveRoomPanel] está montado (pantalla completa del LIVE). Los overlays
/// persistentes (mini-bar, burbuja de voz) lo comprueban para nunca superponerse a los propios
/// controles del panel (mic/salir) — más robusto que inferirlo comparando la ruta actual como
/// string, que depende de que el panel siempre se haya abierto desde exactamente `/chat/:id`.
final isLiveRoomPanelOpenProvider = StateProvider<bool>((ref) => false);
