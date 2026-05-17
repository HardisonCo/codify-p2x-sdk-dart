import 'api_exception.dart';

/// HTTP 404 — the requested resource does not exist (or is not visible to
/// the current user/subproject).
class NotFoundException extends ApiException {
  /// Construct.
  NotFoundException({
    required super.message,
    super.data,
    super.originalError,
  }) : super(status: 404);
}
