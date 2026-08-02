import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/app_router.dart';
import '../../core/router/current_location.dart';
import '../../core/storage/local_prefs.dart';
import '../../core/theme/app_colors.dart';
import 'live_provider.dart';

const _bubbleSize = 60.0;
const _handleWidth = 18.0;

/// Componente genérico de burbuja flotante arrastrable/ocultable de Menzo — hoy solo lo usa
/// [PersistentVoiceBubble] (LIVE de voz), pero queda como widget aparte para poder reusarlo si
/// más adelante hace falta otra burbuja del mismo estilo. Maneja: arrastre libre dentro de
/// [SafeArea], snap a los bordes al soltar, ocultar/restaurar con un "handle" lateral que nunca
/// deja al usuario sin forma de recuperarla, y persistencia local de posición/visibilidad (nunca
/// de datos que vengan del backend — ver LocalPrefs).
class MenzoFloatingBubble extends StatefulWidget {
  const MenzoFloatingBubble({
    super.key,
    required this.child,
    required this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    required this.initialHidden,
    required this.initialPositionFraction,
    required this.onHiddenChanged,
    required this.onPositionChanged,
  });

  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final bool initialHidden;

  /// Fracción (0.0-1.0) de la esquina superior-izquierda dentro del área de arrastre disponible
  /// — `null` si no hay una posición guardada todavía (usa una esquina por defecto).
  final Offset? initialPositionFraction;
  final ValueChanged<bool> onHiddenChanged;
  final ValueChanged<Offset> onPositionChanged;

  @override
  State<MenzoFloatingBubble> createState() => _MenzoFloatingBubbleState();
}

class _MenzoFloatingBubbleState extends State<MenzoFloatingBubble> {
  Offset? _positionFraction;
  late bool _hidden;
  bool _snappedRight = true;

  @override
  void initState() {
    super.initState();
    _positionFraction = widget.initialPositionFraction;
    _hidden = widget.initialHidden;
  }

  void _setHidden(bool value) {
    setState(() => _hidden = value);
    widget.onHiddenChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxLeft = (constraints.maxWidth - _bubbleSize).clamp(0.0, double.infinity);
          final maxTop = (constraints.maxHeight - _bubbleSize).clamp(0.0, double.infinity);
          final fraction = _positionFraction ?? const Offset(0.92, 0.62);
          final position = Offset(fraction.dx * maxLeft, fraction.dy * maxTop);

          if (_hidden) {
            // Nunca deja al usuario sin forma de recuperarla: un handle angosto pegado al borde
            // (izquierdo o derecho, según dónde se ocultó) siempre visible y tocable.
            return Positioned(
              top: position.dy,
              left: _snappedRight ? null : 0,
              right: _snappedRight ? 0 : null,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _setHidden(false),
                  borderRadius: BorderRadius.horizontal(
                    left: _snappedRight ? const Radius.circular(12) : Radius.zero,
                    right: _snappedRight ? Radius.zero : const Radius.circular(12),
                  ),
                  child: Container(
                    width: _handleWidth,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      border: Border.all(color: AppColors.borderStrong),
                      borderRadius: BorderRadius.horizontal(
                        left: _snappedRight ? const Radius.circular(12) : Radius.zero,
                        right: _snappedRight ? Radius.zero : const Radius.circular(12),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      _snappedRight ? Icons.chevron_left : Icons.chevron_right,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            );
          }

          return Positioned(
            left: position.dx,
            top: position.dy,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTap,
              onDoubleTap: widget.onDoubleTap,
              onLongPress: widget.onLongPress,
              onPanUpdate: (details) {
                final next = position + details.delta;
                setState(() {
                  _positionFraction = Offset(
                    maxLeft == 0 ? 0 : (next.dx.clamp(0.0, maxLeft)) / maxLeft,
                    maxTop == 0 ? 0 : (next.dy.clamp(0.0, maxTop)) / maxTop,
                  );
                });
              },
              onPanEnd: (_) {
                // Snap al borde más cercano — se siente intencional en vez de quedar flotando a
                // mitad de pantalla, y deja el resto del contenido despejado.
                final current = _positionFraction ?? fraction;
                final snapToRight = current.dx > 0.5;
                setState(() {
                  _snappedRight = snapToRight;
                  _positionFraction = Offset(snapToRight ? 1.0 : 0.0, current.dy);
                });
                widget.onPositionChanged(_positionFraction!);
              },
              child: widget.child,
            ),
          );
        },
      ),
    );
  }
}

/// 1:1 con menzoweb/components/PersistentVoiceBubble.tsx — burbuja flotante que se ve en
/// cualquier pantalla mientras haya un LIVE activo, salvo en la propia pantalla de esa sala.
/// Ver [MenzoFloatingBubble] para el comportamiento de arrastre/ocultar/persistencia.
class PersistentVoiceBubble extends ConsumerStatefulWidget {
  const PersistentVoiceBubble({super.key});

  @override
  ConsumerState<PersistentVoiceBubble> createState() => _PersistentVoiceBubbleState();
}

class _PersistentVoiceBubbleState extends ConsumerState<PersistentVoiceBubble> {
  bool _hidden = false;
  Offset? _positionFraction;
  bool _loadedPrefs = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final hidden = await LocalPrefs.instance.voiceBubbleHidden;
    final position = await LocalPrefs.instance.voiceBubblePositionFraction;
    if (!mounted) return;
    setState(() {
      _hidden = hidden;
      _positionFraction = position;
      _loadedPrefs = true;
    });
  }

  void _showActions(BuildContext context, LiveState live) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.live_tv_outlined),
              title: const Text('Volver al LIVE'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                ref.read(appRouterProvider).push('/chat/${live.activeRoomId}');
              },
            ),
            if (live.canSpeak)
              ListTile(
                leading: Icon(live.muted ? Icons.mic_off : Icons.mic),
                title: Text(live.muted ? 'Activar micrófono' : 'Silenciar micrófono'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  ref.read(liveProvider.notifier).toggleMute();
                },
              ),
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined),
              title: const Text('Ocultar burbuja'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _setHidden(true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.call_end, color: AppColors.coral),
              title: const Text('Salir del LIVE', style: TextStyle(color: AppColors.coral)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                ref.read(liveProvider.notifier).leave();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _setHidden(bool value) {
    setState(() => _hidden = value);
    LocalPrefs.instance.setVoiceBubbleHidden(value);
  }

  void _setPositionFraction(Offset value) {
    setState(() => _positionFraction = value);
    LocalPrefs.instance.setVoiceBubblePositionFraction(value);
  }

  @override
  Widget build(BuildContext context) {
    final live = ref.watch(liveProvider);
    final location = ref.watch(currentLocationProvider);
    final panelOpen = ref.watch(isLiveRoomPanelOpenProvider);
    final hiddenHere = location == '/chat/${live.activeRoomId}' || panelOpen;

    if (!_loadedPrefs || !live.connected || live.activeRoomId == null || hiddenHere) {
      return const SizedBox.shrink();
    }

    final micLooksOff = live.muted || !live.localAudioPublished;
    // Cualquier nivel de voz > 0 en la sala (propio o de otro hablante) — animación sutil, no
    // hace falta saber de quién es específicamente para esta burbuja compacta.
    final voiceActive =
        live.speakingLevels.values.any((level) => level > 0.08) && !micLooksOff;

    return MenzoFloatingBubble(
      initialHidden: _hidden,
      initialPositionFraction: _positionFraction,
      onHiddenChanged: _setHidden,
      onPositionChanged: _setPositionFraction,
      onTap: () => ref.read(appRouterProvider).push('/chat/${live.activeRoomId}'),
      onLongPress: () => _showActions(context, live),
      child: _BubbleFace(voiceActive: voiceActive, micLooksOff: micLooksOff),
    );
  }
}

class _BubbleFace extends StatelessWidget {
  const _BubbleFace({required this.voiceActive, required this.micLooksOff});
  final bool voiceActive;
  final bool micLooksOff;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.0, end: voiceActive ? 1.12 : 1.0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: Container(
        width: _bubbleSize,
        height: _bubbleSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [AppColors.cyan, AppColors.orange],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: voiceActive ? AppColors.cyan : AppColors.borderStrong,
            width: voiceActive ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (voiceActive ? AppColors.cyan : Colors.black).withValues(
                alpha: voiceActive ? 0.45 : 0.35,
              ),
              blurRadius: voiceActive ? 18 : 12,
              spreadRadius: voiceActive ? 2 : 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Center(
              child: Icon(Icons.graphic_eq, color: Colors.white, size: 26),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: micLooksOff ? AppColors.textMuted : AppColors.coral,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 2),
                ),
                child: Icon(
                  micLooksOff ? Icons.mic_off : Icons.podcasts,
                  size: 10,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
