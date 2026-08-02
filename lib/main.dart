import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/diagnostics/app_diagnostic_logger.dart';
import 'core/diagnostics/device_info_snapshot.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_MX');
  // No bloquea el arranque — best-effort, ver DeviceInfoSnapshot.capture (cada campo tiene su
  // propio try/catch, así que en el peor caso el log de [BUILD] sale con campos en null/desconocido
  // en vez de retrasar/romper el primer frame de la app.
  unawaited(_logBuildInfo());
  runApp(const ProviderScope(child: MenzoApp()));
}

Future<void> _logBuildInfo() async {
  final snapshot = await DeviceInfoSnapshot.capture();
  AppDiagnosticLogger.instance.log(
    DiagnosticCategory.build,
    MenziLogLevel.info,
    'app started',
    data: snapshot.toLogData(),
  );
}
