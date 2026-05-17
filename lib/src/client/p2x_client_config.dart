import 'package:meta/meta.dart';

/// Configuration for [P2xClient].
///
/// The SDK is **SSR-safe and storage-agnostic**: it never reads browser
/// globals, `SharedPreferences`, or `flutter_secure_storage` at construction
/// time. Instead, the host app provides closures via [getToken] and
/// [getDomain] that the client invokes on every request. This matches the TS
/// SDK's contract (`P2X/sdk/CLAUDE.md` § "HTTP layer contract").
///
/// All callbacks are optional. The minimal viable config is just [baseUrl].
@immutable
class P2xClientConfig {
  /// Construct a config.
  ///
  /// [baseUrl] is the API root — typically `https://api.project20x.com/api`.
  /// Trailing slash is recommended for consistency but the client handles
  /// either form.
  const P2xClientConfig({
    required this.baseUrl,
    this.getToken,
    this.getDomain,
    this.onUnauthorized,
    this.onValidationError,
    this.connectTimeout = const Duration(seconds: 15),
    this.receiveTimeout = const Duration(seconds: 30),
    this.sendTimeout = const Duration(seconds: 30),
    this.extraHeaders = const <String, String>{},
  });

  /// API root URL. Required.
  final String baseUrl;

  /// Returns the current Sanctum bearer token, or `null` to omit
  /// the `Authorization` header.
  ///
  /// Invoked on every request — token rotation works without
  /// reconstructing the client.
  final String? Function()? getToken;

  /// Returns the current subproject domain, sent as the `X-Domain` header,
  /// or `null` to omit. Matches the JS SDK's
  /// `getDomain: () => string | null | undefined` shape.
  final String? Function()? getDomain;

  /// Fired exactly once per 401 response. Wire to your logout flow.
  /// The SDK never navigates.
  final void Function()? onUnauthorized;

  /// Fired exactly once per 422 response with the parsed field-keyed
  /// validation map. Optional — most consumers prefer to `catch`
  /// `ValidationException` at the call site instead.
  final void Function(Map<String, List<String>> errors)? onValidationError;

  /// Connection timeout. Defaults to 15s.
  final Duration connectTimeout;

  /// Receive timeout. Defaults to 30s.
  final Duration receiveTimeout;

  /// Send timeout. Defaults to 30s.
  final Duration sendTimeout;

  /// Additional headers to apply to every request. Useful for app-version /
  /// platform / locale headers. The SDK's own headers (Authorization,
  /// X-Domain, Idempotency-Key, Content-Type) take precedence.
  final Map<String, String> extraHeaders;
}
