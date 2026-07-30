import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Estado local (nunca se manda al backend hasta el paso final) del wizard de onboarding —
/// 1:1 con menzoweb/lib/OnboardingDraftContext.tsx.
class OnboardingDraft {
  const OnboardingDraft({
    this.displayName = '',
    this.aura = 'fuego',
    this.avatarUri,
    this.interests = const [],
  });

  final String displayName;
  final String aura;
  final String? avatarUri;
  final List<String> interests;

  OnboardingDraft copyWith({
    String? displayName,
    String? aura,
    String? avatarUri,
    List<String>? interests,
  }) => OnboardingDraft(
    displayName: displayName ?? this.displayName,
    aura: aura ?? this.aura,
    avatarUri: avatarUri ?? this.avatarUri,
    interests: interests ?? this.interests,
  );
}

class OnboardingDraftNotifier extends Notifier<OnboardingDraft> {
  @override
  OnboardingDraft build() => const OnboardingDraft();

  void setDisplayName(String value) =>
      state = state.copyWith(displayName: value);
  void setAura(String value) => state = state.copyWith(aura: value);
  void setAvatarUri(String? value) => state = OnboardingDraft(
    displayName: state.displayName,
    aura: state.aura,
    avatarUri: value,
    interests: state.interests,
  );

  void toggleInterest(String id) {
    final current = List<String>.from(state.interests);
    if (current.contains(id)) {
      current.remove(id);
    } else if (current.length < 5) {
      current.add(id);
    }
    state = state.copyWith(interests: current);
  }
}

final onboardingDraftProvider =
    NotifierProvider<OnboardingDraftNotifier, OnboardingDraft>(
      OnboardingDraftNotifier.new,
    );

const onboardingSteps = ['name', 'aura', 'avatar', 'interests', 'confirm'];
