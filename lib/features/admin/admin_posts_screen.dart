import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/post_models.dart';
import '../../data/models/user_models.dart';
import '../shared/reason_dialog.dart';

/// 1:1 con menzoweb/app/(app)/admin/posts/page.tsx.
class AdminPostsScreen extends ConsumerStatefulWidget {
  const AdminPostsScreen({super.key});

  @override
  ConsumerState<AdminPostsScreen> createState() => _AdminPostsScreenState();
}

class _AdminPostsScreenState extends ConsumerState<AdminPostsScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<Post> _results = [];
  bool _loading = false;
  bool _searched = false;

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value));
  }

  Future<void> _search(String query) async {
    setState(() {
      _loading = true;
      _searched = true;
    });
    try {
      final page = await ref.read(adminRepositoryProvider).searchPosts(query);
      if (!mounted) return;
      setState(() => _results = page.items);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _hide(Post post) async {
    final reason = await showReasonDialog(
      context,
      title: 'Ocultar publicación',
      description: 'El motivo queda registrado en el log de moderación.',
    );
    if (reason == null) return;
    try {
      await ref.read(adminRepositoryProvider).hidePost(post.id, reason);
      if (!mounted) return;
      setState(() => _results = _results.map((p) => p.id == post.id ? p.copyWith(hidden: true) : p).toList());
    } catch (_) {}
  }

  Future<void> _unhide(Post post) async {
    final reason = await showReasonDialog(
      context,
      title: 'Mostrar publicación',
      description: 'El motivo queda registrado en el log de moderación.',
    );
    if (reason == null) return;
    try {
      await ref.read(adminRepositoryProvider).unhidePost(post.id, reason);
      if (!mounted) return;
      setState(() => _results = _results.map((p) => p.id == post.id ? p.copyWith(hidden: false) : p).toList());
    } catch (_) {}
  }

  Future<void> _delete(Post post) async {
    final reason = await showReasonDialog(
      context,
      title: 'Eliminar publicación',
      description: 'El motivo queda registrado en el log de moderación.',
      confirmLabel: 'Eliminar',
    );
    if (reason == null) return;
    try {
      await ref.read(postRepositoryProvider).remove(post.id, reason: reason);
      if (!mounted) return;
      setState(() => _results.removeWhere((p) => p.id == post.id));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authProvider).profile;
    final isLeaderPlus = profile?.globalRole == GlobalRole.leader || profile?.globalRole == GlobalRole.master;

    return Scaffold(
      appBar: AppBar(title: Text('Publicaciones', style: AppTextStyles.h2())),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              onChanged: _onChanged,
              style: AppTextStyles.body(),
              decoration: const InputDecoration(hintText: 'Buscar por texto o título…'),
            ),
            const SizedBox(height: 12),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (!_loading && _searched && _results.isEmpty)
              Text('Sin resultados.', style: AppTextStyles.body(color: AppColors.textMuted)),
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, i) {
                  final post = _results[i];
                  return Card(
                    color: AppColors.surface,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      side: const BorderSide(color: AppColors.borderSoft),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  post.title?.isNotEmpty == true ? post.title! : post.body,
                                  style: AppTextStyles.body(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (post.hidden)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceSecondary,
                                    borderRadius: BorderRadius.circular(AppRadius.pill),
                                  ),
                                  child: Text('Oculta', style: AppTextStyles.caption()),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: () => post.hidden ? _unhide(post) : _hide(post),
                                child: Text(post.hidden ? 'Mostrar' : 'Ocultar'),
                              ),
                              if (isLeaderPlus)
                                OutlinedButton(
                                  onPressed: () => _delete(post),
                                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.coral),
                                  child: const Text('Eliminar'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
