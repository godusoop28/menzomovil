/// Espejo de ErrorResponse de menzoapi (ver GlobalExceptionHandler/ErrorResponse.java) y de
/// ApiError en menzoweb/menzomovil-RN — mismos campos, incluido `code` (p. ej.
/// "YOUTUBE_QUOTA_EXCEEDED", "LIVE_NOT_ACTIVE") y `retryAfterSeconds` (solo en 429
/// MENZI_DJ_RATE_LIMITED).
class ApiException implements Exception {
  const ApiException(
    this.status,
    this.message, {
    this.fieldErrors,
    this.code,
    this.retryAfterSeconds,
  });

  final int status;
  final String message;
  final Map<String, String>? fieldErrors;
  final String? code;
  final int? retryAfterSeconds;

  @override
  String toString() => 'ApiException($status, code=$code, $message)';
}
