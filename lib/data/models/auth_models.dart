import 'user_models.dart';

class AuthResponse {
  const AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.email,
    required this.onboardingCompleted,
    required this.profile,
  });

  final String accessToken;
  final String refreshToken;
  final String email;
  final bool onboardingCompleted;
  final UserProfile profile;

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String,
    email: json['email'] as String,
    onboardingCompleted: json['onboardingCompleted'] as bool,
    profile: UserProfile.fromJson(json['profile'] as Map<String, dynamic>),
  );
}
