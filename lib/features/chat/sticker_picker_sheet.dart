import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/sticker_models.dart';
import '../shared/menzo_sheet.dart';

/// Modelado sobre gif_picker_sheet.dart (mismo patrón: sheet, buscador, grilla, estados de carga/
/// vacío) pero de dos niveles — primero se navegan los packs (que agrupan varios stickers, a
/// diferencia de la grilla plana de Tenor), después se entra a uno para elegir un sticker puntual.
Future<void> showStickerPickerSheet({
  required BuildContext context,
  required ValueChanged<Sticker> onPick,
}) {
  return showMenzoSheet<void>(
    context: context,
    title: 'Stickers',
    builder: (context) => _StickerPickerBody(onPick: onPick),
  );
}

class _StickerPickerBody extends ConsumerStatefulWidget {
  const _StickerPickerBody({required this.onPick});
  final ValueChanged<Sticker> onPick;

  @override
  ConsumerState<_StickerPickerBody> createState() => _StickerPickerBodyState();
}

class _StickerPickerBodyState extends ConsumerState<_StickerPickerBody> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<StickerPackSummary> _packs = [];
  StickerPackDetail? _openPack;
  bool _loading = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _searchPacks('');
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _searchPacks(value));
  }

  Future<void> _searchPacks(String query) async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final repo = ref.read(stickerRepositoryProvider);
      final page = await repo.listPacks(query: query.trim().isEmpty ? null : query.trim());
      if (!mounted) return;
      setState(() => _packs = page.items);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _createPack() {
    Navigator.of(context).maybePop();
    context.push('/stickers/create');
  }

  Future<void> _openPackDetail(StickerPackSummary pack) async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final repo = ref.read(stickerRepositoryProvider);
      final detail = await repo.getPack(pack.id);
      if (!mounted) return;
      setState(() => _openPack = detail);
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
        if (_openPack != null)
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _openPack = null),
                icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
              ),
              Expanded(
                child: Text(
                  _openPack!.name,
                  style: AppTextStyles.h3(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          )
        else
          TextField(
            controller: _controller,
            autofocus: true,
            onChanged: _onChanged,
            style: AppTextStyles.body(),
            decoration: const InputDecoration(hintText: 'Buscar un pack…'),
          ),
        const SizedBox(height: 12),
        if (_error)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No pudimos cargar los stickers — probá de nuevo en un rato.',
              style: AppTextStyles.body(color: AppColors.coral),
            ),
          )
        else if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_openPack == null && _packs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _controller.text.trim().isEmpty
                        ? 'Todavía no hay packs de stickers.'
                        : 'Sin resultados.',
                    style: AppTextStyles.body(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _createPack,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.coral,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Crear tu propio pack'),
                  ),
                ],
              ),
            ),
          )
        else if (_openPack != null && _openPack!.stickers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                'Este pack no tiene stickers.',
                style: AppTextStyles.body(color: AppColors.textMuted),
              ),
            ),
          )
        else if (_openPack == null)
          SizedBox(
            height: 360,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: _packs.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return GestureDetector(
                    onTap: _createPack,
                    child: Column(
                      children: [
                        Expanded(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.borderStrong),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.add, color: AppColors.textMuted),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Crear pack',
                          style: AppTextStyles.caption(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                }
                final pack = _packs[i - 1];
                return GestureDetector(
                  onTap: () => _openPackDetail(pack),
                  child: Column(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            color: AppColors.surfaceSecondary,
                            child: pack.coverImageUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: pack.coverImageUrl!,
                                    fit: BoxFit.contain,
                                  )
                                : const Center(child: Text('🏷️', style: TextStyle(fontSize: 28))),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pack.name,
                        style: AppTextStyles.caption(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              },
            ),
          )
        else
          SizedBox(
            height: 360,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: _openPack!.stickers.length,
              itemBuilder: (context, i) {
                final sticker = _openPack!.stickers[i];
                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).maybePop();
                    widget.onPick(sticker);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: CachedNetworkImage(imageUrl: sticker.imageUrl, fit: BoxFit.contain),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
