import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Sesión cacheada en memoria (lectura instantánea, sin await, para el interceptor de dio) +
/// persistida en Keychain/Keystore vía flutter_secure_storage — mejora respecto al RN/web
/// actual, que guardaba el par de tokens en AsyncStorage/localStorage sin cifrar.
class Session {
  const Session({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
  });

  final String accessToken;
  final String refreshToken;
  final String userId;

  Session copyWith({String? accessToken, String? refreshToken}) => Session(
    accessToken: accessToken ?? this.accessToken,
    refreshToken: refreshToken ?? this.refreshToken,
    userId: userId,
  );
}

class SessionStorage {
  SessionStorage._();
  static final SessionStorage instance = SessionStorage._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyAccess = 'menzo.accessToken';
  static const _keyRefresh = 'menzo.refreshToken';
  static const _keyUserId = 'menzo.userId';

  Session? _cached;
  Session? get cached => _cached;

  Future<Session?> load() async {
    final access = await _storage.read(key: _keyAccess);
    final refresh = await _storage.read(key: _keyRefresh);
    final userId = await _storage.read(key: _keyUserId);
    if (access == null || refresh == null || userId == null) {
      _cached = null;
      return null;
    }
    _cached = Session(
      accessToken: access,
      refreshToken: refresh,
      userId: userId,
    );
    return _cached;
  }

  Future<void> save(Session session) async {
    _cached = session;
    await Future.wait([
      _storage.write(key: _keyAccess, value: session.accessToken),
      _storage.write(key: _keyRefresh, value: session.refreshToken),
      _storage.write(key: _keyUserId, value: session.userId),
    ]);
  }

  Future<void> clear() async {
    _cached = null;
    await Future.wait([
      _storage.delete(key: _keyAccess),
      _storage.delete(key: _keyRefresh),
      _storage.delete(key: _keyUserId),
    ]);
  }
}
