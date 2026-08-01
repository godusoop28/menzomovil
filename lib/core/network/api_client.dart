import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/session_storage.dart';
import 'api_exception.dart';

/// Cliente HTTP único de la app — replica el comportamiento ya validado en menzoweb/menzomovil
/// (RN) contra un backend de Render free-tier que se duerme: reintentos cada 3s hasta un
/// presupuesto de 75s en errores de red/502/503/504 (un "cold start" se ve como conexión
/// rechazada, no como un cuelgue), timeout duro de 4 minutos, refresh de token una sola vez en
/// 401 (con cola para no disparar dos refresh en paralelo), y una señal de "servidor
/// despertando" a los 6s para que la UI pueda avisar.
class ApiClient {
  ApiClient._internal()
    : _dio = Dio(
        BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          connectTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(minutes: 4),
          receiveTimeout: const Duration(minutes: 4),
          validateStatus: (_) =>
              true, // manejamos el status nosotros, nunca dejamos que dio tire por 4xx/5xx
        ),
      );

  static final ApiClient instance = ApiClient._internal();

  final Dio _dio;

  static const _retryDelay = Duration(seconds: 3);
  static const _retryBudget = Duration(seconds: 75);
  static const _slowThreshold = Duration(seconds: 6);
  static const _retryableStatuses = {502, 503, 504};

  final _slowRequestController = StreamController<bool>.broadcast();
  int _activeSlowRequests = 0;

  /// true cuando al menos una petición lleva más de 6s sin responder — para mostrar "el
  /// servidor puede estar despertando".
  Stream<bool> get onSlowRequestChange => _slowRequestController.stream;

  final _sessionExpiredController = StreamController<void>.broadcast();
  Stream<void> get onSessionExpired => _sessionExpiredController.stream;

  Completer<bool>? _refreshInFlight;

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    bool skipAuth = false,
  }) => _request<T>('GET', path, query: query, skipAuth: skipAuth);

  Future<T> post<T>(String path, {Object? body, bool skipAuth = false}) =>
      _request<T>('POST', path, body: body, skipAuth: skipAuth);

  Future<T> put<T>(String path, {Object? body, bool skipAuth = false}) =>
      _request<T>('PUT', path, body: body, skipAuth: skipAuth);

  Future<T> patch<T>(String path, {Object? body, bool skipAuth = false}) =>
      _request<T>('PATCH', path, body: body, skipAuth: skipAuth);

  Future<T> delete<T>(String path, {Object? body, bool skipAuth = false}) =>
      _request<T>('DELETE', path, body: body, skipAuth: skipAuth);

  /// Sube un archivo a `/api/uploads` (multipart, campo "file") y devuelve la URL resultante —
  /// ver UploadController/FileStorageService (Cloudinary) en menzoapi.
  Future<String> uploadFile(File file) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: file.uri.pathSegments.last,
      ),
    });
    final result = await _request<Map<String, dynamic>>(
      'POST',
      '/api/uploads',
      body: formData,
    );
    return result['url'] as String;
  }

  Future<T> _request<T>(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    bool skipAuth = false,
  }) async {
    Response response = await _attemptWithRetries(
      method,
      path,
      query: query,
      body: body,
      skipAuth: skipAuth,
    );

    if (response.statusCode == 401 &&
        !skipAuth &&
        SessionStorage.instance.cached != null) {
      final refreshed = await _refreshOnce();
      if (refreshed) {
        response = await _attemptWithRetries(
          method,
          path,
          query: query,
          body: body,
          skipAuth: skipAuth,
        );
      } else {
        await SessionStorage.instance.clear();
        _sessionExpiredController.add(null);
      }
    }

    if (response.statusCode == 204 || response.data == null) {
      return null as T;
    }

    final data = response.data;
    if (response.statusCode == null ||
        response.statusCode! < 200 ||
        response.statusCode! >= 300) {
      final err = data is Map<String, dynamic> ? data : <String, dynamic>{};
      throw ApiException(
        response.statusCode ?? 0,
        (err['message'] as String?) ?? 'Error ${response.statusCode}',
        fieldErrors: (err['fieldErrors'] as Map?)?.cast<String, String>(),
        code: err['code'] as String?,
        retryAfterSeconds: err['retryAfterSeconds'] as int?,
      );
    }

    return data as T;
  }

  Future<Response> _attemptWithRetries(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    bool skipAuth = false,
  }) async {
    _beginSlowWatch();
    final deadline = DateTime.now().add(_retryBudget);
    try {
      while (true) {
        try {
          final response = await _attemptOnce(
            method,
            path,
            query: query,
            body: body,
            skipAuth: skipAuth,
          );
          if (_retryableStatuses.contains(response.statusCode) &&
              DateTime.now().isBefore(deadline)) {
            await Future.delayed(_retryDelay);
            continue;
          }
          return response;
        } on DioException catch (e) {
          final isNetworkError =
              e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.unknown;
          final isTimeout =
              e.type == DioExceptionType.sendTimeout ||
              e.type == DioExceptionType.receiveTimeout;
          if (isTimeout) {
            throw const ApiException(
              0,
              'Menzo tardó demasiado en responder. El servidor puede estar iniciando — inténtalo de nuevo en un minuto.',
            );
          }
          if (isNetworkError && DateTime.now().isBefore(deadline)) {
            await Future.delayed(_retryDelay);
            continue;
          }
          throw const ApiException(
            0,
            'No se pudo conectar con el servidor. Revisa tu conexión.',
          );
        }
      }
    } finally {
      _endSlowWatch();
    }
  }

  Future<Response> _attemptOnce(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    bool skipAuth = false,
  }) async {
    final session = SessionStorage.instance.cached;
    final headers = <String, dynamic>{};
    if (!skipAuth && session != null) {
      headers['Authorization'] = 'Bearer ${session.accessToken}';
    }
    final isMultipart = body is FormData;
    if (!isMultipart) headers['Content-Type'] = 'application/json';

    return _dio.request(
      path,
      queryParameters: query,
      data: isMultipart ? body : (body != null ? jsonEncode(body) : null),
      options: Options(method: method, headers: headers),
    );
  }

  /// Para STOMP: a diferencia de REST (que reacciona a un 401 real vía `_request`), un CONNECT
  /// STOMP con un JWT vencido simplemente falla la conexión — no hay forma de "reintentar esta
  /// petición puntual" después. Hay que asegurarse ANTES de conectar/reconectar. Decodifica el
  /// `exp` del access token actual (sin verificar firma — no hace falta, el backend es quien
  /// valida de verdad) y dispara el mismo refresh que usa REST si está por vencer o ya venció.
  Future<String?> ensureFreshAccessToken() async {
    final session = SessionStorage.instance.cached;
    if (session == null) return null;
    if (!_isCloseToExpiry(session.accessToken)) return session.accessToken;
    final refreshed = await _refreshOnce();
    if (refreshed) return SessionStorage.instance.cached?.accessToken;
    // El refresh token también venció/es inválido — mismo tratamiento que el 401 de REST: no
    // tiene sentido seguir reintentando con credenciales muertas, hay que loguear de nuevo.
    await SessionStorage.instance.clear();
    _sessionExpiredController.add(null);
    return null;
  }

  static const _expirySkew = Duration(seconds: 30);

  bool _isCloseToExpiry(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return false;
      final normalized = base64Url.normalize(parts[1]);
      final payload =
          jsonDecode(utf8.decode(base64Url.decode(normalized)))
              as Map<String, dynamic>;
      final exp = payload['exp'];
      if (exp is! int) return false;
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(
        exp * 1000,
        isUtc: true,
      );
      return DateTime.now().toUtc().isAfter(expiresAt.subtract(_expirySkew));
    } catch (_) {
      // Un token que no se puede decodificar no es asunto de este chequeo — que lo rechace el
      // backend como corresponda; acá no bloqueamos la conexión por las dudas.
      return false;
    }
  }

  Future<bool> _refreshOnce() {
    if (_refreshInFlight != null) return _refreshInFlight!.future;
    final completer = Completer<bool>();
    _refreshInFlight = completer;
    _doRefresh().then((value) {
      completer.complete(value);
      _refreshInFlight = null;
    });
    return completer.future;
  }

  Future<bool> _doRefresh() async {
    final session = SessionStorage.instance.cached;
    if (session == null) return false;
    try {
      // Pasa por _request (no una llamada dio cruda) para heredar los mismos reintentos/timeout
      // que el resto de las peticiones: sin esto, un backend recién despertando podía tirar este
      // refresh puntual y desloguear a alguien con una sesión perfectamente válida.
      final data = await _request<Map<String, dynamic>>(
        'POST',
        '/api/auth/refresh',
        body: {'refreshToken': session.refreshToken},
        skipAuth: true,
      );
      await SessionStorage.instance.save(
        Session(
          accessToken: data['accessToken'] as String,
          refreshToken: data['refreshToken'] as String,
          userId: (data['profile'] as Map<String, dynamic>)['id'] as String,
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Timer? _slowTimer;

  void _beginSlowWatch() {
    _activeSlowRequests++;
    _slowTimer ??= Timer(_slowThreshold, () {
      if (_activeSlowRequests > 0) _slowRequestController.add(true);
    });
  }

  void _endSlowWatch() {
    _activeSlowRequests = (_activeSlowRequests - 1).clamp(0, 1 << 30);
    if (_activeSlowRequests == 0) {
      _slowTimer?.cancel();
      _slowTimer = null;
      _slowRequestController.add(false);
    }
  }
}
