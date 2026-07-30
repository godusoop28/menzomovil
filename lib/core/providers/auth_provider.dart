import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/user_models.dart';
import '../network/api_exception.dart';
import '../storage/local_prefs.dart';
import '../storage/session_storage.dart';
import 'repository_providers.dart';

enum AuthStatus { loading, authenticated, unauthenticated }

class AuthState {
  const AuthState({
    required this.status,
    this.profile,
    this.onboardingCompleted = false,
  });

  final AuthStatus status;
  final UserProfile? profile;
  final bool onboardingCompleted;

  AuthState copyWith({
    AuthStatus? status,
    UserProfile? profile,
    bool? onboardingCompleted,
  }) => AuthState(
    status: status ?? this.status,
    profile: profile ?? this.profile,
    onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
  );

  static const initial = AuthState(status: AuthStatus.loading);
}

/// Reemplaza el pedazo de auth/perfil de AppStateContext (web/RN) — hidrata al arrancar
/// leyendo la sesión guardada, y si hay una, pide el perfil fresco a `/api/users/me` (con la
/// versión cacheada localmente como respaldo instantáneo si esa llamada tarda, igual que el
/// `localStorage.getItem("menzo.profile")` de la web).
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    _hydrate();
    return AuthState.initial;
  }

  Future<void> _hydrate() async {
    final session = await SessionStorage.instance.load();
    if (session == null) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }
    try {
      final profile = await ref.read(userRepositoryProvider).me();
      final onboardingCompleted = await LocalPrefs.instance.onboardingCompleted;
      state = AuthState(
        status: AuthStatus.authenticated,
        profile: profile,
        onboardingCompleted: onboardingCompleted,
      );
    } catch (_) {
      // El token guardado ya no sirve (ApiClient ya intentó refrescarlo antes de llegar acá).
      await SessionStorage.instance.clear();
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> login(String email, String password) async {
    await ref.read(authRepositoryProvider).login(email, password);
    await _afterAuth();
  }

  Future<void> register(String email, String password) async {
    await ref.read(authRepositoryProvider).register(email, password);
    await _afterAuth();
  }

  Future<void> _afterAuth() async {
    final profile = await ref.read(userRepositoryProvider).me();
    // Un registro nuevo nunca completó onboarding; un login puede o no haberlo hecho —
    // se decide por si el perfil ya tiene displayName real (ver AuthController.register:
    // el back arranca con "Nuevo usuario" hasta que se llama a /users/me/onboarding).
    final onboardingCompleted = profile.displayName != 'Nuevo usuario';
    await LocalPrefs.instance.setOnboardingCompleted(onboardingCompleted);
    state = AuthState(
      status: AuthStatus.authenticated,
      profile: profile,
      onboardingCompleted: onboardingCompleted,
    );
  }

  Future<void> completeOnboarding({
    required String displayName,
    required String aura,
    String? avatarUri,
    required String avatarGradient,
    required List<String> interests,
  }) async {
    final profile = await ref
        .read(userRepositoryProvider)
        .completeOnboarding(
          displayName: displayName,
          aura: aura,
          avatarUri: avatarUri,
          avatarGradient: avatarGradient,
          interests: interests,
        );
    await LocalPrefs.instance.setOnboardingCompleted(true);
    state = state.copyWith(profile: profile, onboardingCompleted: true);
  }

  Future<void> refreshProfile() async {
    try {
      final profile = await ref.read(userRepositoryProvider).me();
      state = state.copyWith(profile: profile);
    } on ApiException {
      // Silencioso — un refresh en segundo plano no debe tumbar la sesión actual.
    }
  }

  void setProfile(UserProfile profile) =>
      state = state.copyWith(profile: profile);

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    await LocalPrefs.instance.clear();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
