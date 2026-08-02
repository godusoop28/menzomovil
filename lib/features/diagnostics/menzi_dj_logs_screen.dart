import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/diagnostics/app_diagnostic_logger.dart';
import '../../core/diagnostics/device_info_snapshot.dart';
import '../../core/diagnostics/diagnostic_export.dart';

/// Argumentos opcionales para abrir [MenziDjLogsScreen] ya filtrada — se pasan como `extra` de
/// go_router (ver core/router/app_router.dart, ruta `/debug/menzi-dj-logs`). El botón "Ver
/// diagnóstico" del panel de Menzi DJ (menzi_dj_panel.dart) arma uno con las categorías
/// relevantes al player; la entrada de Configuración → Diagnóstico no pasa ninguno (todas las
/// categorías, sin filtrar).
class MenziDjLogsScreenArgs {
  const MenziDjLogsScreenArgs({this.categories, this.onlyErrors = false});
  final Set<DiagnosticCategory>? categories;
  final bool onlyErrors;
}

/// Pantalla de logs de Menzi DJ/LIVE — SIN depuración USB, SIN ADB, SIN computadora. Todo lo que
/// necesita para diagnosticar un dispositivo real vive en esta pantalla y en el archivo que
/// genera "Compartir archivo" (ver diagnostic_export.dart). Accesible desde
/// Configuración → Diagnóstico → "Logs de Menzi DJ".
///
/// [initialCategories]/[onlyErrorsInitially] permiten abrir la pantalla ya filtrada — el botón
/// "Ver diagnóstico" del panel de Menzi DJ la abre así, con las categorías relevantes al player
/// (ver menzi_dj_panel.dart), sin que el usuario tenga que armar el filtro a mano cada vez.
class MenziDjLogsScreen extends StatefulWidget {
  const MenziDjLogsScreen({
    super.key,
    this.initialCategories,
    this.onlyErrorsInitially = false,
  });

  final Set<DiagnosticCategory>? initialCategories;
  final bool onlyErrorsInitially;

  @override
  State<MenziDjLogsScreen> createState() => _MenziDjLogsScreenState();
}

class _MenziDjLogsScreenState extends State<MenziDjLogsScreen> {
  late Set<DiagnosticCategory> _selectedCategories;
  late bool _onlyErrors;
  bool _autoScroll = true;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedCategories = widget.initialCategories?.toSet() ?? {};
    _onlyErrors = widget.onlyErrorsInitially;
    AppDiagnosticLogger.instance.revision.addListener(_onNewEntry);
  }

  @override
  void dispose() {
    AppDiagnosticLogger.instance.revision.removeListener(_onNewEntry);
    _scrollController.dispose();
    super.dispose();
  }

  void _onNewEntry() {
    if (!mounted) return;
    setState(() {});
    if (_autoScroll && _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      });
    }
  }

  List<DiagnosticLogEntry> get _filtered => AppDiagnosticLogger.instance.filtered(
        categories: _selectedCategories,
        onlyErrors: _onlyErrors,
      );

  Future<DeviceInfoSnapshot> _captureDeviceInfo() => DeviceInfoSnapshot.capture();

  Future<void> _copyAll() async {
    final text = _filtered.map((e) => e.toLine()).join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_filtered.length} líneas copiadas')),
    );
  }

  Future<String> _buildReport() async {
    final device = await _captureDeviceInfo();
    return buildDiagnosticReportText(device: device, entries: AppDiagnosticLogger.instance.entries);
  }

  Future<void> _shareFile() async {
    final report = await _buildReport();
    final fileName = diagnosticFileName(DateTime.now());
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(report);
    if (!mounted) return;
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], fileNameOverrides: [fileName]),
    );
  }

  Future<void> _saveTxt() async {
    final report = await _buildReport();
    final fileName = diagnosticFileName(DateTime.now());
    Directory? dir;
    try {
      dir = await getExternalStorageDirectory();
    } catch (_) {}
    dir ??= await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(report);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Guardado en ${file.path}')),
    );
  }

  void _clear() {
    AppDiagnosticLogger.instance.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs de Menzi DJ'),
        actions: [
          IconButton(
            tooltip: 'Limpiar',
            onPressed: _clear,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final category in DiagnosticCategory.values)
                  FilterChip(
                    label: Text(category.label),
                    selected: _selectedCategories.contains(category),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedCategories.add(category);
                        } else {
                          _selectedCategories.remove(category);
                        }
                      });
                    },
                  ),
                FilterChip(
                  label: const Text('Solo errores'),
                  selected: _onlyErrors,
                  onSelected: (v) => setState(() => _onlyErrors = v),
                  selectedColor: Colors.red.withValues(alpha: 0.25),
                ),
                FilterChip(
                  label: const Text('Autoscroll'),
                  selected: _autoScroll,
                  onSelected: (v) => setState(() => _autoScroll = v),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Text('${filtered.length} líneas (de ${AppDiagnosticLogger.instance.entries.length})'),
                const Spacer(),
                TextButton.icon(
                  onPressed: _copyAll,
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copiar todo'),
                ),
                TextButton.icon(
                  onPressed: _saveTxt,
                  icon: const Icon(Icons.save_alt, size: 16),
                  label: const Text('Guardar TXT'),
                ),
                TextButton.icon(
                  onPressed: _shareFile,
                  icon: const Icon(Icons.share, size: 16),
                  label: const Text('Compartir'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('Sin registros para este filtro'))
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final entry = filtered[index];
                      final color = switch (entry.level) {
                        MenziLogLevel.error => Colors.redAccent,
                        MenziLogLevel.warning => Colors.amber,
                        MenziLogLevel.info => null,
                      };
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        child: SelectableText(
                          entry.toLine(),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: color,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
