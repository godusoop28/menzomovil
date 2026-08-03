import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/communities_models.dart';
import '../storage/local_prefs.dart';
import 'auth_provider.dart';
import 'repository_providers.dart';

/// Estado global de comunidades (Fase A: solo el andamiaje — selector/onboarding/explorar son
/// Fase B). Vive separado de AuthNotifier a propósito: cambiar de comunidad solo debe limpiar
/// cachés *comunitarias* (feed/blogs/chats con communityId, todavía no existen — Fase C), nunca
/// el perfil global, amigos o mensajes privados, que siguen intactos en AuthNotifier.
class CommunityContextState {
  const CommunityContextState({
    this.memberships = const [],
    this.activeCommunityId,
    this.activeCommunityDetail,
    this.loading = false,
    this.error,
  });

  final List<MyCommunity> memberships;
  final String? activeCommunityId;
  // Trae themeConfig/navigationConfig (CommunitySummary, lo que memberships[].community tiene,
  // no los incluye) — es lo que la app lee para aplicar fondos/decoraciones reales del nav/feed/
  // bandeja de mensajes, no solo el editor de apariencia.
  final CommunityDetail? activeCommunityDetail;
  final bool loading;
  final String? error;

  CommunitySummary? get activeCommunity {
    for (final m in memberships) {
      if (m.community.id == activeCommunityId) return m.community;
    }
    return null;
  }

  CommunityContextState copyWith({
    List<MyCommunity>? memberships,
    String? Function()? activeCommunityId,
    CommunityDetail? Function()? activeCommunityDetail,
    bool? loading,
    String? Function()? error,
  }) => CommunityContextState(
    memberships: memberships ?? this.memberships,
    activeCommunityId: activeCommunityId != null ? activeCommunityId() : this.activeCommunityId,
    activeCommunityDetail: activeCommunityDetail != null ? activeCommunityDetail() : this.activeCommunityDetail,
    loading: loading ?? this.loading,
    error: error != null ? error() : this.error,
  );
}

class CommunityContextNotifier extends Notifier<CommunityContextState> {
  @override
  CommunityContextState build() {
    // Reacciona a login/logout — nunca hace falta llamar a load() a mano desde la UI en el flujo
    // normal de arranque de sesión.
    ref.listen(authProvider, (previous, next) {
      final wasAuthenticated = previous?.status == AuthStatus.authenticated;
      final isAuthenticated = next.status == AuthStatus.authenticated;
      if (isAuthenticated && !wasAuthenticated) {
        load();
      } else if (!isAuthenticated && wasAuthenticated) {
        state = const CommunityContextState();
      }
    });
    return const CommunityContextState();
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, error: () => null);
    try {
      final memberships = await ref.read(communitiesRepositoryProvider).my();
      final stored = await LocalPrefs.instance.activeCommunityId;
      final stillValid = stored != null && memberships.any((m) => m.community.id == stored);
      final nextActiveId = stillValid ? stored : memberships.firstOrNullId();
      await LocalPrefs.instance.setActiveCommunityId(nextActiveId);
      state = state.copyWith(
        memberships: memberships,
        activeCommunityId: () => nextActiveId,
        loading: false,
      );
      refreshActiveDetail();
    } catch (_) {
      state = state.copyWith(loading: false, error: () => 'No pudimos cargar tus comunidades.');
    }
  }

  void switchCommunity(String communityId) {
    if (!state.memberships.any((m) => m.community.id == communityId)) return;
    state = state.copyWith(activeCommunityId: () => communityId, activeCommunityDetail: () => null);
    LocalPrefs.instance.setActiveCommunityId(communityId);
    refreshActiveDetail();
  }

  /// Trae CommunityDetail (con themeConfig/navigationConfig) para la comunidad activa —
  /// deliberadamente sin bloquear el switch/join, solo alimenta fondos/decoraciones decorativos;
  /// si falla, la app sigue funcionando con activeCommunity (el summary).
  Future<void> refreshActiveDetail() async {
    final active = state.activeCommunity;
    if (active == null) return;
    try {
      final detail = await ref.read(communitiesRepositoryProvider).getBySlug(active.slug);
      if (state.activeCommunityId == active.id) {
        state = state.copyWith(activeCommunityDetail: () => detail);
      }
    } catch (_) {
      // silencioso — ver el porqué arriba.
    }
  }

  Future<void> joinCommunity(String communityId) async {
    await ref.read(communitiesRepositoryProvider).join(communityId);
    await load();
    switchCommunity(communityId);
  }

  Future<void> leaveCommunity(String communityId) async {
    await ref.read(communitiesRepositoryProvider).leave(communityId);
    if (state.activeCommunityId == communityId) {
      await LocalPrefs.instance.setActiveCommunityId(null);
      state = state.copyWith(activeCommunityId: () => null);
    }
    await load();
  }
}

final communityContextProvider = NotifierProvider<CommunityContextNotifier, CommunityContextState>(
  CommunityContextNotifier.new,
);

extension _FirstMembershipId on List<MyCommunity> {
  String? firstOrNullId() => isEmpty ? null : first.community.id;
}
