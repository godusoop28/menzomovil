import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/post_models.dart';

/// Único renderer de `blocks` en toda la app — cada bloque se mapea a un widget de Flutter
/// conocido (Text/Image/Divider), nunca a un parser de HTML/markdown. 1:1 con
/// menzoweb/components/post/PostBlockRenderer.tsx — mismo motivo: sin bloques no hace falta
/// sanitizar nada, es la propiedad de seguridad real de elegir bloques sobre "subir el body a
/// HTML enriquecido".
class PostBlockRenderer extends StatelessWidget {
  const PostBlockRenderer({super.key, required this.blocks});
  final List<PostBlock> blocks;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final block in blocks) ...[
          _buildBlock(block),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildBlock(PostBlock block) {
    switch (block.type) {
      case PostBlockType.heading:
        return Text(block.text ?? '', style: AppTextStyles.h3());
      case PostBlockType.paragraph:
        return Text(block.text ?? '', style: AppTextStyles.body());
      case PostBlockType.image:
      case PostBlockType.gif:
        if (block.url == null) return const SizedBox.shrink();
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: CachedNetworkImage(
            imageUrl: block.url!,
            width: double.infinity,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              height: 200,
              color: AppColors.surfaceSecondary,
            ),
          ),
        );
      case PostBlockType.divider:
        return const Divider(color: AppColors.borderSoft);
    }
  }
}
