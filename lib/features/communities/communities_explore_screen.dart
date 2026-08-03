import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers/community_context_provider.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/communities_models.dart';
import 'community_badge.dart';

final _communitiesListProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(communitiesRepositoryProvider).list(size: 50),
);

/// 1:1 con menzoweb/app/(app)/communities/page.tsx — versión mínima: lista + unirse/abandonar.
class CommunitiesExploreScreen extends ConsumerWidget {
  const CommunitiesExploreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final communities = ref.watch(_communitiesListProvider);
    final contextState = ref.watch(communityContextProvider);
    final joinedIds = contextState.memberships.map((m) => m.community.id).toSet();

    return Scaffold(
      appBar: AppBar(title: Text('Explorar comunidades', style: AppTextStyles.h2())),
      body: communities.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Text('No pudimos cargar las comunidades.', style: AppTextStyles.body(color: AppColors.textMuted)),
        ),
        data: (page) {
          if (page.items.isEmpty) {
            return Center(
              child: Text('Todavía no hay comunidades.', style: AppTextStyles.body(color: AppColors.textMuted)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: page.items.length,
            itemBuilder: (context, i) {
              final community = page.items[i];
              final joined = joinedIds.contains(community.id);
              return Card(
                color: AppColors.surface,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  side: const BorderSide(color: AppColors.borderSoft),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      CommunityBadge(name: community.name, iconUrl: community.iconUrl, color: community.primaryColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(community.name, style: AppTextStyles.label()),
                            Text(
                              '${community.memberCount} miembros${community.category != null ? ' · ${community.category}' : ''}',
                              style: AppTextStyles.caption(),
                            ),
                          ],
                        ),
                      ),
                      if (joined)
                        TextButton(
                          onPressed: () {
                            ref.read(communityContextProvider.notifier).switchCommunity(community.id);
                            context.pop();
                          },
                          child: const Text('Cambiar acá'),
                        )
                      else
                        ElevatedButton(
                          onPressed: () => _join(context, ref, community.id),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(_parseColor(community.primaryColor)),
                            foregroundColor: Colors.white,
                          ),
                          child: Text(community.accessType == CommunityAccessType.open_ ? 'Unirme' : 'Solicitar'),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

Future<void> _join(BuildContext context, WidgetRef ref, String communityId) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(communityContextProvider.notifier).joinCommunity(communityId);
    ref.invalidate(_communitiesListProvider);
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.coral));
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('No pudimos unirte a esta comunidad.'), backgroundColor: AppColors.coral),
    );
  }
}

int _parseColor(String? hex) {
  if (hex == null) return 0xFFE74C3C;
  try {
    return int.parse(hex.replaceFirst('#', '0xFF'));
  } catch (_) {
    return 0xFFE74C3C;
  }
}
