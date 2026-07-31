import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// Prepara una imagen recién elegida en la galería para subirla.
///
/// `ImagePicker.pickImage(imageQuality: ...)` recomprime SIEMPRE mediante un
/// re-encode de bitmap nativo que no soporta cuadros múltiples — si el
/// archivo elegido es un GIF animado, ese recomprimido lo aplana a un solo
/// cuadro estático. Por eso el picker ya no recibe `imageQuality` en ningún
/// lugar de la app: para GIFs devolvemos el archivo tal cual (animación
/// intacta de punta a punta hasta Cloudinary), y para el resto de formatos
/// hacemos la compresión acá, en Dart puro, después de saber el tipo real.
Future<String> prepareImageForUpload(XFile picked) async {
  final lowerPath = picked.path.toLowerCase();
  if (lowerPath.endsWith('.gif')) {
    return picked.path;
  }

  final bytes = await picked.readAsBytes();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    // Formato que no reconocemos (o ya viene liviano): subir sin tocar en
    // vez de arriesgar corromperlo.
    return picked.path;
  }

  final needsResize = decoded.width > 1600 || decoded.height > 1600;
  final resized = needsResize
      ? img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? 1600 : null,
          height: decoded.height > decoded.width ? 1600 : null,
        )
      : decoded;

  final jpg = img.encodeJpg(resized, quality: 85);
  final tempDir = await Directory.systemTemp.createTemp('menzo_upload');
  final outFile = File(
    '${tempDir.path}/${DateTime.now().microsecondsSinceEpoch}.jpg',
  );
  await outFile.writeAsBytes(jpg);
  return outFile.path;
}
