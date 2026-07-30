import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';

/// Shell de navegación principal — reemplaza el sidebar/bottom-tabs responsive de
/// menzoweb/components/AppShell.tsx; acá siempre es la variante móvil (bottom tabs), ver
/// NAV_ITEMS en la web: Inicio/Miembros/Chats/Perfil. Los accesos secundarios (chats
/// públicos, buscar, eventos, notificaciones, configuración) viven en un botón "más" en el
/// AppBar de cada pantalla del shell, no acá — ver [SecondaryNavSheet].
class AppShell extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
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

/// El menú de accesos secundarios (Chats públicos / Buscar / Eventos / Notificaciones /
/// Configuración) — equivalente móvil de `SECONDARY_ITEMS` en AppShell.tsx web, que ahí vive
/// en el sidebar de escritorio. Se invoca desde un botón en el AppBar de Inicio/Perfil/etc.
class SecondaryNavSheet extends StatelessWidget {
  const SecondaryNavSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, String)>[
      (Icons.groups_2_outlined, 'Chats públicos', '/chat/public'),
      (Icons.search, 'Buscar', '/search'),
      (Icons.calendar_month_outlined, 'Eventos', '/events'),
      (Icons.notifications_outlined, 'Notificaciones', '/notifications'),
      (Icons.settings_outlined, 'Configuración', '/settings'),
    ];
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: items
            .map(
              (item) => ListTile(
                leading: Icon(item.$1, color: AppColors.textPrimary),
                title: Text(
                  item.$2,
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  context.push(item.$3);
                },
              ),
            )
            .toList(),
      ),
    );
  }
}
