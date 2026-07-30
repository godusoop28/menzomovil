import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../shared/gradient_button.dart';
import '../shared/menzo_toast.dart';
import '../../utils/relative_time.dart';

final eventProvider = FutureProvider.family.autoDispose(
  (ref, String id) => ref.watch(communityRepositoryProvider).getEvent(id),
);

/// 1:1 con menzoweb/app/(app)/events/[id]/page.tsx.
class EventDetailScreen extends ConsumerStatefulWidget {
  const EventDetailScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  bool _busy = false;

  Future<void> _toggleAttend(bool attending) async {
    setState(() => _busy = true);
    try {
      if (attending) {
        await ref.read(communityRepositoryProvider).unattend(widget.id);
      } else {
        await ref.read(communityRepositoryProvider).attend(widget.id);
      }
      ref.invalidate(eventProvider(widget.id));
    } catch (_) {
      if (mounted)
        showMenzoToast(context, 'No pudimos actualizar tu asistencia.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = ref.watch(eventProvider(widget.id));
    return Scaffold(
      appBar: AppBar(),
      body: event.when(
        data: (e) => ListView(
          children: [
            if (e.coverUri != null)
              CachedNetworkImage(
                imageUrl: e.coverUri!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.title, style: AppTextStyles.h1()),
                  const SizedBox(height: 6),
                  Text(
                    formatJoinDate(e.startsAt),
                    style: AppTextStyles.body(color: AppColors.textSecondary),
                  ),
                  if (e.description != null) ...[
                    const SizedBox(height: 12),
                    Text(e.description!, style: AppTextStyles.body()),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    '${e.attendeeCount} personas van a asistir',
                    style: AppTextStyles.caption(),
                  ),
                  const SizedBox(height: 16),
                  GradientButton(
                    label: e.attendingByMe ? 'Cancelar asistencia' : 'Asistir',
                    loading: _busy,
                    onPressed: () => _toggleAttend(e.attendingByMe),
                  ),
                ],
              ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(
          child: Text(
            'No pudimos cargar este evento.',
            style: AppTextStyles.body(color: AppColors.coral),
          ),
        ),
      ),
    );
  }
}
