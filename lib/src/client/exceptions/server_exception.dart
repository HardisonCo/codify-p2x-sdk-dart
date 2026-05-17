import 'api_exception.dart';

/// HTTP 5xx — server-side error. The SDK does not retry automatically;
/// callers that want retries should layer their own policy (e.g., via
/// `utils/retry_policy.dart` once that ships).
class ServerException extends ApiException {
  /// Construct.
  ServerException({
    required super.status,
    required super.message,
    super.data,
    super.originalError,
  });
}
