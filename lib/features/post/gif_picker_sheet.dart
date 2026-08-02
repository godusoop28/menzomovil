import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/gif_models.dart';
import '../shared/menzo_sheet.dart';

/// Buscador de GIFs — 1:1 con menzoweb/components/post/GifPickerSheet.tsx. Le pega solo al proxy
/// propio (ver GifsRepository), nunca directo a Tenor.
Future<void> showGifPickerSheet({
  required BuildContext context,
  required ValueChanged<GifResult> onPick,
}) {
  return showMenzoSheet<void>(
    context: context,
    title: 'Buscar GIF',
    builder: (context) => _GifPickerBody(onPick: onPick),
  );
}

class _GifPickerBody extends ConsumerStatefulWidget {
  const _GifPickerBody({required this.onPick});
  final ValueChanged<GifResult> onPick;

  @override
  ConsumerState<_GifPickerBody> createState() => _GifPickerBodyState();
}

class _GifPickerBodyState extends ConsumerState<_GifPickerBody> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<GifResult> _results = [];
  bool _loading = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _search('');
  }

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
      _error = false;
    });
    try {
      final repo = ref.read(gifsRepositoryProvider);
      final result = query.trim().isEmpty
          ? await repo.trending()
          : await repo.search(query.trim());
      if (!mounted) return;
      setState(() => _results = result.results);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onChanged,
          style: AppTextStyles.body(),
          decoration: const InputDecoration(hintText: 'Buscar en Tenor…'),
        ),
        const SizedBox(height: 12),
        if (_error)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No pudimos buscar GIFs en este momento — probá de nuevo en un rato.',
              style: AppTextStyles.body(color: AppColors.coral),
            ),
          )
        else if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_results.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text('Sin resultados.', style: AppTextStyles.body(color: AppColors.textMuted)),
            ),
          )
        else
          SizedBox(
            height: 360,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: _results.length,
              itemBuilder: (context, i) {
                final gif = _results[i];
                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).maybePop();
                    widget.onPick(gif);
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: gif.previewUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
