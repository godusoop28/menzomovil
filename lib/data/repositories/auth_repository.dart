import '../../core/network/api_client.dart';
import '../../core/storage/session_storage.dart';
import '../models/auth_models.dart';

class AuthRepository {
  AuthRepository(this._client);
  final ApiClient _client;

  Future<AuthResponse> register(String email, String password) async {
    final json = await _client.post<Map<String, dynamic>>(
      '/api/auth/register',
      body: {'email': email, 'password': password},
      skipAuth: true,
    );
    final response = AuthResponse.fromJson(json);
    await _saveSession(response);
    return response;
  }

  Future<AuthResponse> login(String email, String password) async {
    final json = await _client.post<Map<String, dynamic>>(
      '/api/auth/login',
      body: {'email': email, 'password': password},
      skipAuth: true,
    );
    final response = AuthResponse.fromJson(json);
    await _saveSession(response);
    return response;
  }

  Future<void> logout() async {
    final session = SessionStorage.instance.cached;
    if (session != null) {
      try {
        await _client.post<void>(
          '/api/auth/logout',
          body: {'refreshToken': session.refreshToken},
        );
      } catch (_) {
        // Si falla el logout remoto igual limpiamos la sesión local.
      }
    }
    await SessionStorage.instance.clear();
  }

  Future<void> _saveSession(AuthResponse response) =>
      SessionStorage.instance.save(
        Session(
          accessToken: response.accessToken,
          refreshToken: response.refreshToken,
          userId: response.profile.id,
        ),
      );
}
