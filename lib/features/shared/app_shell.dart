import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/user_models.dart';
import 'menzo_avatar.dart';

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
          Image.asset(
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
