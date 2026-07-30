import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';
import '../../utils/relative_time.dart';

final eventsListProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(communityRepositoryProvider).events(),
);

/// 1:1 con menzoweb/app/(app)/events/page.tsx.
class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(eventsListProvider);
    return Scaffold(
      appBar: AppBar(title: Text('Eventos', style: AppTextStyles.h2())),
      body: events.when(
        data: (page) => page.items.isEmpty
            ? Center(
                child: Text(
                  'Todavía no hay eventos programados.',
                  style: AppTextStyles.body(color: AppColors.textMuted),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: page.items.length,
                separatorBuilder: (context, i) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final event = page.items[i];
                  return GestureDetector(
                    onTap: () => context.push('/events/${event.id}'),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (event.coverUri != null)
                            CachedNetworkImage(
                              imageUrl: event.coverUri!,
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(event.title, style: AppTextStyles.h3()),
                                const SizedBox(height: 4),
                                Text(
                                  formatJoinDate(event.startsAt),
                                  style: AppTextStyles.caption(),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${event.attendeeCount} asistentes${event.attendingByMe ? " · Asistes" : ""}',
                                  style: AppTextStyles.caption(
                                    color: event.attendingByMe
                                        ? AppColors.cyan
                                        : AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Text(
            'No pudimos cargar los eventos.',
            style: AppTextStyles.body(color: AppColors.coral),
          ),
        ),
      ),
    );
  }
}
