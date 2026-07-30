import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../shared/menzi_illustration_state.dart';
import '../shared/menzo_avatar.dart';

final membersSearchProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(userRepositoryProvider).search('', size: 30),
);

/// 1:1 con menzoweb/app/(app)/members/page.tsx.
class MembersScreen extends ConsumerWidget {
  const MembersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(membersSearchProvider);
    return Scaffold(
      appBar: AppBar(title: Text('Miembros', style: AppTextStyles.h2())),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(membersSearchProvider),
        child: members.when(
          data: (page) {
            if (page.items.isEmpty) {
              return ListView(
                children: const [
                  MenziIllustrationState(
                    image: MenziIllustration.friends,
                    title: 'Conecta con tu comunidad',
                    description:
                        'Cuando dos personas se siguen mutuamente, aparecen como amigos.',
                  ),
                ],
              );
            }
            final online = page.items.where((u) => u.isOnline).toList();
            final offline = page.items.where((u) => !u.isOnline).toList();
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (online.isNotEmpty) ...[
                  Text('Conectados', style: AppTextStyles.label()),
                  const SizedBox(height: 8),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    children: online
                        .map(
                          (u) => GestureDetector(
                            onTap: () => context.push('/member/${u.id}'),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                MenzoAvatar(
                                  name: u.displayName,
                                  avatarUri: u.avatarUri,
                                  size: 56,
                                  showOnline: true,
                                  online: true,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  u.displayName,
                                  style: AppTextStyles.caption(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 20),
                ],
                if (offline.isNotEmpty) ...[
                  Text('Todos los miembros', style: AppTextStyles.label()),
                  const SizedBox(height: 8),
                  ...offline.map(
                    (u) => ListTile(
                      onTap: () => context.push('/member/${u.id}'),
                      leading: MenzoAvatar(
                        name: u.displayName,
                        avatarUri: u.avatarUri,
                        size: 40,
                      ),
                      title: Text(u.displayName, style: AppTextStyles.label()),
                      subtitle: Text(
                        '@${u.username}',
                        style: AppTextStyles.caption(),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(
            child: Text(
              'No pudimos cargar los miembros.',
              style: AppTextStyles.body(color: AppColors.coral),
            ),
          ),
        ),
      ),
    );
  }
}
