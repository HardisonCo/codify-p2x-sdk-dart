import 'api_exception.dart';

/// HTTP 401 — the request was missing or had an invalid bearer token.
///
/// The SDK ALSO fires the `onUnauthorized` callback configured on
/// [P2xClientConfig] when this exception is about to be thrown; the host app
/// typically wires that callback to its logout flow. Callers don't have to
/// catch this exception unless they want to surface a specific message.
class UnauthorizedException extends ApiException {
  /// Construct.
  UnauthorizedException({
    required super.message,
    super.data,
    super.originalError,
  }) : super(status: 401);
}
