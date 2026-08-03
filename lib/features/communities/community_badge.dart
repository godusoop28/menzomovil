import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Insignia circular de comunidad — icono si hay, si no la inicial sobre su color primario.
/// Equivalente mínimo de MenzoAvatar pero para comunidades (colores literales, no GradientId).
class CommunityBadge extends StatelessWidget {
  const CommunityBadge({super.key, this.name, this.iconUrl, this.color, this.size = 40});

  final String? name;
  final String? iconUrl;
  final String? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = (name?.trim().isNotEmpty ?? false) ? name!.trim()[0].toUpperCase() : '?';
    Color background;
    try {
      background = color != null ? Color(int.parse(color!.replaceFirst('#', '0xFF'))) : const Color(0xFF2A2A38);
    } catch (_) {
      background = const Color(0xFF2A2A38);
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: iconUrl != null && iconUrl!.isNotEmpty
          ? CachedNetworkImage(imageUrl: iconUrl!, fit: BoxFit.cover, width: size, height: size)
          : Text(
              initial,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: size * 0.4),
            ),
    );
  }
}
