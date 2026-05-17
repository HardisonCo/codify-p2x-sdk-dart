import 'api_exception.dart';

/// HTTP 403 — the user is authenticated but lacks permission for the
/// requested resource (wrong role, wrong subproject, cross-subproject
/// access without a sharing allowlist row, etc.).
class ForbiddenException extends ApiException {
  /// Construct.
  ForbiddenException({
    required super.message,
    super.data,
    super.originalError,
  }) : super(status: 403);
}
