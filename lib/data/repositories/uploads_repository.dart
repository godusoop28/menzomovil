import 'dart:io';

import '../../core/network/api_client.dart';

class UploadsRepository {
  UploadsRepository(this._client);
  final ApiClient _client;

  Future<String> upload(File file) => _client.uploadFile(file);

  /// Solo sube si `uri` es un archivo local (no ya una URL http remota) — evita resubir una
  /// imagen que ya vive en Cloudinary, igual que `ensureUploaded` en menzoweb.
  Future<String> ensureUploaded(String? uri) async {
    if (uri == null || uri.isEmpty) return '';
    if (uri.startsWith('http://') || uri.startsWith('https://')) return uri;
    return upload(File(uri));
  }
}
