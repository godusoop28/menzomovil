import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/chat/chat_list_screen.dart';
import '../../features/chat/chat_public_screen.dart';
import '../../features/chat/chat_room_screen.dart';
import '../../features/chat/room_members_screen.dart';
import '../../features/events/event_detail_screen.dart';
import '../../features/events/events_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/members/members_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/onboarding/onboarding_flow.dart';
import '../../features/post/post_detail_screen.dart';
import '../../features/profile/connections_screen.dart';
import '../../features/profile/edit_profile_screen.dart';
import '../../features/profile/member_profile_screen.dart';
import '../../features/profile/own_profile_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shared/app_shell.dart';
import '../providers/auth_provider.dart';
import 'current_location.dart';

/// Notifica a go_router cada vez que cambia [authProvider] — reemplaza el
/// `useEffect(() => { if (!hydrated) return; ... router.replace(...) }, [...])` de
/// `app/(app)/layout.tsx` en la web por un guard declarativo de go_router.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen(authProvider, (previous, next) {
      if (previous?.status != next.status ||
          previous?.onboardingCompleted != next.onboardingCompleted) {
        notifyListeners();
      }
    });
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _AuthRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final loc = state.matchedLocation;
      final isAuthRoute = loc == '/login' || loc == '/register';
      final isOnboardingRoute = loc.startsWith('/onboarding');

      if (auth.status == AuthStatus.loading)
        return null; // splash implícito: no redirige todavía
      if (auth.status == AuthStatus.unauthenticated) {
        return isAuthRoute ? null : '/login';
      }
      // Autenticado:
      if (isAuthRoute) return '/';
      if (!auth.onboardingCompleted && !isOnboardingRoute)
        return '/onboarding/name';
      if (auth.onboardingCompleted && isOnboardingRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/onboarding/:step',
        builder: (context, state) =>
            OnboardingFlowScreen(step: state.pathParameters['step']!),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/events',
        builder: (context, state) => const EventsScreen(),
      ),
      GoRoute(
        path: '/events/:id',
        builder: (context, state) =>
            EventDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/post/:id',
        builder: (context, state) =>
            PostDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/member/:id',
        builder: (context, state) =>
            MemberProfileScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/connections/:id/:kind',
        builder: (context, state) => ConnectionsScreen(
          userId: state.pathParameters['id']!,
          kind: state.pathParameters['kind']!,
        ),
      ),
      GoRoute(
        path: '/chat/public',
        builder: (context, state) => const ChatPublicScreen(),
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (context, state) =>
            ChatRoomScreen(roomId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/chat/:id/members',
        builder: (context, state) =>
            RoomMembersScreen(roomId: state.pathParameters['id']!),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/members',
                builder: (context, state) => const MembersScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chat',
                builder: (context, state) => const ChatListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const OwnProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  // Mantiene [currentLocationProvider] al día con cada navegación — es lo único que los
  // overlays persistentes (montados en el `builder` de MaterialApp.router, fuera del árbol de
  // rutas — ver current_location.dart) pueden usar para saber en qué pantalla está el usuario.
  void syncLocation() {
    ref.read(currentLocationProvider.notifier).state = router.routerDelegate.currentConfiguration.uri.toString();
  }

  router.routerDelegate.addListener(syncLocation);
  ref.onDispose(() => router.routerDelegate.removeListener(syncLocation));
  // No se llama de una: modificar otro provider en medio de la construcción de este (durante
  // el build) tira "Tried to modify a provider while the widget tree was building" en Riverpod.
  Future.microtask(syncLocation);

  return router;
});
