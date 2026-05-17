/// Base class for all SDK exceptions.
///
/// Per-status subtypes ([UnauthorizedException], [ForbiddenException],
/// [NotFoundException], [ValidationException], [ServerException]) carry
/// status-specific structure; callers can `catch` the base type or any of
/// the leaves depending on how granular their error handling needs to be.
///
/// Mirrors the TS SDK's `ApiError` shape — see
/// `P2X/sdk/src/api/error-handling.ts`.
class ApiException implements Exception {
  /// Construct.
  ApiException({
    required this.status,
    required this.message,
    this.data,
    this.originalError,
  });

  /// HTTP status code that triggered this exception.
  final int status;

  /// Server-emitted message, or the SDK's best-effort string if the body
  /// didn't include one.
  final String message;

  /// Parsed response body, if any. Typically the `data` field of the
  /// envelope; `null` for network errors or opaque responses.
  final dynamic data;

  /// The original error object — typically a `DioException` — preserved
  /// so callers can inspect status text, raw body, etc.
  final Object? originalError;

  @override
  String toString() => 'ApiException($status): $message';
}
