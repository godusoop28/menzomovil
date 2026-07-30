import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../shared/menzi_illustration_state.dart';
import '../shared/menzo_avatar.dart';

final connectionsProvider = FutureProvider.family
    .autoDispose<dynamic, (String, String)>((ref, args) {
      final (userId, kind) = args;
      final repo = ref.watch(userRepositoryProvider);
      return kind == 'followers'
          ? repo.followers(userId)
          : repo.following(userId);
    });

/// 1:1 con menzoweb/app/(app)/connections/[id]/[kind]/page.tsx.
class ConnectionsScreen extends ConsumerWidget {
  const ConnectionsScreen({
    super.key,
    required this.userId,
    required this.kind,
  });
  final String userId;
  final String kind;

  bool get _isFollowers => kind == 'followers';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(connectionsProvider((userId, kind)));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isFollowers ? 'Seguidores' : 'Siguiendo',
          style: AppTextStyles.h2(),
        ),
      ),
      body: result.when(
        data: (page) {
          final items = page.items as List;
          if (items.isEmpty) {
            return Center(
              child: MenziIllustrationState(
                image: MenziIllustration.friends,
                description: _isFollowers
                    ? 'Todavía no tiene seguidores.'
                    : 'Todavía no sigue a nadie.',
                size: MenziIllustrationSize.small,
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final user = items[i];
              return ListTile(
                onTap: () => context.push('/member/${user.id}'),
                leading: MenzoAvatar(
                  name: user.displayName,
                  avatarUri: user.avatarUri,
                  size: 40,
                  showOnline: true,
                  online: user.isOnline,
                ),
                title: Text(user.displayName, style: AppTextStyles.label()),
                subtitle: Text(
                  '@${user.username}',
                  style: AppTextStyles.caption(),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Text(
            'No pudimos cargar la lista.',
            style: AppTextStyles.body(color: AppColors.coral),
          ),
        ),
      ),
    );
  }
}
