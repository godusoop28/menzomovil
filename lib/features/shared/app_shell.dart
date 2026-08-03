import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/providers/community_context_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/communities_models.dart';
import '../../data/models/user_models.dart';
import '../communities/community_badge.dart';
import 'menzo_avatar.dart';
import 'menzo_sheet.dart';

/// Clave del [Scaffold] del shell — los botones "menú" de Home/Perfil viven en el AppBar de
/// cada pantalla del tab (su propio Scaffold anidado), así que no pueden usar
/// `Scaffold.of(context).openDrawer()` directo; en cambio abren el drawer del shell exterior a
/// través de esta clave compartida.
final shellScaffoldKeyProvider = Provider<GlobalKey<ScaffoldState>>(
  (ref) => GlobalKey<ScaffoldState>(),
);

/// Shell de navegación principal — reemplaza el sidebar/bottom-tabs responsive de
/// menzoweb/components/AppShell.tsx; acá siempre es la variante móvil (bottom tabs) + un drawer
/// lateral estilo Amino para los accesos secundarios (chats públicos, buscar, eventos,
/// notificaciones, configuración) — ver [MenzoDrawer].
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _labels = ['Inicio', 'Miembros', 'Chats', 'Perfil'];
  static const _icons = [
    Icons.home_rounded,
    Icons.groups_rounded,
    Icons.chat_bubble_rounded,
    Icons.person_rounded,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      key: ref.watch(shellScaffoldKeyProvider),
      drawer: const MenzoDrawer(),
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppColors.surface,
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: List.generate(
          _labels.length,
          (i) =>
              NavigationDestination(icon: Icon(_icons[i]), label: _labels[i]),
        ),
      ),
    );
  }
}

/// Drawer lateral inspirado en el sidebar de comunidad de Amino: fondo decorativo, avatar +
/// nombre + nivel arriba, accesos principales y secundarios abajo con ícono en burbuja de
/// color — reemplaza el [SecondaryNavSheet] (bottom sheet plano) que había antes.
class MenzoDrawer extends ConsumerWidget {
  const MenzoDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authProvider).profile;
    final navBackgroundUrl = ref.watch(communityContextProvider).activeCommunityDetail?.themeConfig['navBackgroundUrl'] as String?;
    final primaryItems = <(IconData, String, String)>[
      (Icons.home_rounded, 'Inicio', '/'),
      (Icons.groups_rounded, 'Miembros', '/members'),
      (Icons.chat_bubble_rounded, 'Chats', '/chat'),
      (Icons.person_rounded, 'Mi perfil', '/profile'),
    ];
    final secondaryItems = <(IconData, String, String)>[
      (Icons.groups_2_outlined, 'Chats públicos', '/chat/public'),
      (Icons.search, 'Buscar', '/search'),
      (Icons.calendar_month_outlined, 'Eventos', '/events'),
      (Icons.notifications_outlined, 'Notificaciones', '/notifications'),
      (Icons.settings_outlined, 'Configuración', '/settings'),
      if (profile != null && profile.globalRole != GlobalRole.user)
        (Icons.shield_outlined, 'Admin', '/admin'),
    ];

    void go(String path) {
      Navigator.of(context).pop();
      context.push(path);
    }

    return Drawer(
      backgroundColor: AppColors.backgroundDeep,
      child: Stack(
        fit: StackFit.expand,
        children: [
          (navBackgroundUrl != null && navBackgroundUrl.isNotEmpty)
              ? CachedNetworkImage(
                  imageUrl: navBackgroundUrl,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => Image.asset(
                    'assets/backgrounds/background-drawer.png',
                    fit: BoxFit.cover,
                  ),
                )
              : Image.asset(
                  'assets/backgrounds/background-drawer.png',
                  fit: BoxFit.cover,
                ),
          const ColoredBox(color: Color(0xB007090D)),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Row(
                    children: [
                      MenzoAvatar(
                        name: profile?.displayName ?? '',
                        avatarUri: profile?.avatarUri,
                        gradient: gradientIdFromName(profile?.avatarGradient),
                        size: 56,
                        level: profile?.level,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              profile?.displayName ?? '',
                              style: AppTextStyles.h3(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (profile != null)
                              Text(
                                '@${profile.username} · Nivel ${profile.level}',
                                style: AppTextStyles.caption(),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: _CommunitySwitcherRow(),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.borderSoft),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    children: [
                      ...primaryItems.map(
                        (item) => _DrawerTile(
                          icon: item.$1,
                          label: item.$2,
                          color: AppColors.orange,
                          onTap: () => go(item.$3),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: Divider(height: 1, color: AppColors.borderSoft),
                      ),
                      ...secondaryItems.map(
                        (item) => _DrawerTile(
                          icon: item.$1,
                          label: item.$2,
                          color: AppColors.cyan,
                          onTap: () => go(item.$3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Selector de comunidad en el drawer — ver Contexto §8/§23 del pedido original ("icono de
/// comunidad, nombre, flecha de cambio" en el encabezado; al tocar, bottom sheet con mis
/// comunidades, favoritas, explorar). Versión mínima: mis comunidades + explorar.
class _CommunitySwitcherRow extends ConsumerWidget {
  const _CommunitySwitcherRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final communityState = ref.watch(communityContextProvider);
    final active = communityState.activeCommunity;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: () => _openSwitcherSheet(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            CommunityBadge(name: active?.name, iconUrl: active?.iconUrl, color: active?.primaryColor, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                communityState.loading ? 'Cargando…' : (active?.name ?? 'Elegí una comunidad'),
                style: AppTextStyles.label(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.unfold_more, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  void _openSwitcherSheet(BuildContext context, WidgetRef ref) {
    showMenzoSheet<void>(
      context: context,
      title: 'Comunidades',
      builder: (sheetContext) => Consumer(
        builder: (context, ref, _) {
          final communityState = ref.watch(communityContextProvider);
          final profile = ref.watch(authProvider).profile;
          final globalRole = profile?.globalRole;
          final isGlobalStaff = globalRole == GlobalRole.leader || globalRole == GlobalRole.master;
          CommunityMembership? activeMembership;
          for (final m in communityState.memberships) {
            if (m.community.id == communityState.activeCommunityId) {
              activeMembership = m.membership;
              break;
            }
          }
          // COMMUNITY_CURATOR+ — igual que CommunityPermissionEvaluator.requireCanEditAppearance
          // en el backend (curador, moderador, admin u owner).
          final isCommunityStaff = activeMembership != null &&
              (activeMembership.communityRole == CommunityRole.curator ||
                  activeMembership.communityRole == CommunityRole.moderator ||
                  activeMembership.communityRole == CommunityRole.admin ||
                  activeMembership.communityRole == CommunityRole.owner);
          final canEditAppearance = communityState.activeCommunity != null && (isGlobalStaff || isCommunityStaff);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final m in communityState.memberships)
                ListTile(
                  leading: CommunityBadge(name: m.community.name, iconUrl: m.community.iconUrl, color: m.community.primaryColor, size: 32),
                  title: Text(m.community.name, style: AppTextStyles.label()),
                  trailing: m.community.id == communityState.activeCommunityId
                      ? const Icon(Icons.check, color: AppColors.orange)
                      : null,
                  onTap: () {
                    ref.read(communityContextProvider.notifier).switchCommunity(m.community.id);
                    Navigator.of(sheetContext).maybePop();
                  },
                ),
              if (communityState.memberships.isEmpty && !communityState.loading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Todavía no sos miembro de ninguna comunidad.',
                    style: AppTextStyles.caption(),
                  ),
                ),
              const Divider(height: 1, color: AppColors.borderSoft),
              ListTile(
                leading: const Icon(Icons.explore_outlined, color: AppColors.cyan),
                title: Text('Explorar comunidades', style: AppTextStyles.label(color: AppColors.cyan)),
                onTap: () {
                  Navigator.of(sheetContext).maybePop();
                  context.push('/communities');
                },
              ),
              if (canEditAppearance)
                ListTile(
                  leading: const Icon(Icons.palette_outlined, color: AppColors.textSecondary),
                  title: Text('Editar apariencia', style: AppTextStyles.label()),
                  onTap: () {
                    Navigator.of(sheetContext).maybePop();
                    context.push('/communities/${communityState.activeCommunity!.slug}/appearance');
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: color),
      ),
      title: Text(label, style: AppTextStyles.label()),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    );
  }
}
