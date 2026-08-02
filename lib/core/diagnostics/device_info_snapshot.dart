import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../config/app_config.dart';
import 'device_session.dart';

/// Info de build/dispositivo para el encabezado del TXT exportado (Fase 5 del diagnóstico) y para
/// el log [DiagnosticCategory.build] al arrancar la app. Cada campo se obtiene con su propio
/// try/catch — un solo plugin fallando (un OEM raro, una versión vieja de Android) NUNCA debe
/// tumbar el resto del diagnóstico ni impedir compartir el archivo.
class DeviceInfoSnapshot {
  const DeviceInfoSnapshot({
    required this.appVersion,
    required this.buildNumber,
    required this.commit,
    required this.deviceModel,
    required this.androidVersion,
    required this.webViewVersion,
    required this.deviceId,
  });

  final String appVersion;
  final String buildNumber;
  final String commit;
  final String? deviceModel;
  final String? androidVersion;
  final String? webViewVersion;
  final String deviceId;

  static Future<DeviceInfoSnapshot> capture() async {
    String appVersion = 'desconocida';
    String buildNumber = 'desconocido';
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion = info.version;
      buildNumber = info.buildNumber;
    } catch (_) {}

    String? deviceModel;
    String? androidVersion;
    String? webViewVersion;
    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      deviceModel = '${androidInfo.manufacturer} ${androidInfo.model}';
      androidVersion = 'Android ${androidInfo.version.release} (SDK ${androidInfo.version.sdkInt})';
      // No hay API pública en device_info_plus para la versión exacta del paquete Android System
      // WebView instalado en el dispositivo (es un componente actualizable de Play Store aparte
      // del OS) — se deja constancia explícita de que no se pudo obtener en vez de omitir el
      // campo o inventar un valor, para no sugerir falsamente que se confirmó.
      webViewVersion = 'no disponible vía API pública en este dispositivo';
    } catch (_) {}

    return DeviceInfoSnapshot(
      appVersion: appVersion,
      buildNumber: buildNumber,
      // Se pasa por --dart-define=GIT_COMMIT=$(git rev-parse --short HEAD) al compilar — ver
      // README/instrucciones de build. Sin ese define, queda "unknown" en vez de inventar algo.
      commit: AppConfig.gitCommit,
      deviceModel: deviceModel,
      androidVersion: androidVersion,
      webViewVersion: webViewVersion,
      deviceId: DeviceSession.id,
    );
  }

  Map<String, dynamic> toLogData() => {
        'appVersion': appVersion,
        'buildNumber': buildNumber,
        'commit': commit,
        'deviceModel': deviceModel,
        'androidVersion': androidVersion,
      };

  String toBlock() => [
        'appVersion: $appVersion',
        'buildNumber: $buildNumber',
        'commit: $commit',
        'deviceModel: ${deviceModel ?? '-'}',
        'androidVersion: ${androidVersion ?? '-'}',
        'webViewVersion: ${webViewVersion ?? '-'}',
        'deviceId: $deviceId',
      ].join('\n');
}
