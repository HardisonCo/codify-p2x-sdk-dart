import 'package:dio/dio.dart';

import '../p2x_client_config.dart';

/// Dio interceptor that injects the `Authorization: Bearer <token>` header
/// from [P2xClientConfig.getToken].
///
/// Behaviour:
///   * If `getToken` is `null` (not configured), no header is added.
///   * If `getToken` returns `null` or an empty string, no header is added.
///   * Otherwise the header is set to `Bearer <token>` (with the Bearer prefix —
///     unlike the legacy IBD backend's `Authorization: <jwt>` raw format, P2X
///     uses Bearer per Laravel Sanctum convention).
///   * Per-call opt-out: callers can pass `extras['skip_auth'] = true` in
///     request options to suppress the header for a single request (used for
///     public endpoints like `/api/load`, Stripe webhook).
class AuthInterceptor extends Interceptor {
  /// Construct.
  AuthInterceptor(this._config);

  final P2xClientConfig _config;

  /// Marker key on `RequestOptions.extra` to skip auth header injection for
  /// a single request.
  static const String skipAuthExtra = 'skip_auth';

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    final skip = options.extra[skipAuthExtra] == true;
    if (skip) {
      handler.next(options);
      return;
    }

    final getToken = _config.getToken;
    if (getToken == null) {
      handler.next(options);
      return;
    }

    final token = getToken();
    if (token == null || token.isEmpty) {
      handler.next(options);
      return;
    }

    options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }
}
