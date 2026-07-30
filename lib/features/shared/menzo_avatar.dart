import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/level_tier.dart';

/// 1:1 con menzoweb/components/Avatar.tsx — circular, imagen de red si hay, si no la inicial
/// sobre un degradado; punto verde si está online; anillo de color/degradado según el nivel.
class MenzoAvatar extends StatelessWidget {
  const MenzoAvatar({
    super.key,
    required this.name,
    this.avatarUri,
    this.gradient = GradientId.fire,
    this.size = 44,
    this.showOnline = false,
    this.online = false,
    this.level,
  });

  final String name;
  final String? avatarUri;
  final GradientId gradient;
  final double size;
  final bool showOnline;
  final bool online;
  final int? level;

  @override
  Widget build(BuildContext context) {
    final tier = level != null ? levelTier(level!) : null;
    final ringColor = tier?.color ?? AppColors.borderStrong;

    Widget avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: ringColor,
          width: tier != null && tier.glow ? 2.5 : 1.5,
        ),
        boxShadow: tier != null && tier.glow
            ? [
                BoxShadow(
                  color: ringColor.withValues(alpha: 0.5),
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.all(1.5),
      child: ClipOval(
        child: avatarUri != null && avatarUri!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: avatarUri!,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => _fallback(),
                placeholder: (context, url) => _fallback(),
              )
            : _fallback(),
      ),
    );

    if (!showOnline) return avatar;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        if (online)
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: size * 0.28,
              height: size * 0.28,
              decoration: BoxDecoration(
                color: AppColors.online,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.background, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _fallback() {
    final initial = name.trim().isNotEmpty
        ? name.trim().substring(0, 1).toUpperCase()
        : '?';
    return Container(
      decoration: BoxDecoration(gradient: AppGradients.linear(gradient)),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: AppTextStyles.display(
          size: size * 0.4,
          color: AppColors.textOnAccent,
        ),
      ),
    );
  }
}
