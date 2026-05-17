import 'package:dio/dio.dart';

import '../p2x_client_config.dart';

/// Dio interceptor that injects the `X-Domain` header from
/// [P2xClientConfig.getDomain].
///
/// P2X uses the `X-Domain` header to resolve the current **subproject** via
/// `SubprojectContextService` server-side. The value is typically the
/// hostname of the current product (e.g., `nutriscan.codify.ai`,
/// `phm.ai`, `ibd.healthcare`, `runtracker.codify.ai`).
///
/// Behaviour:
///   * If `getDomain` is `null` (not configured), no header is added.
///   * If `getDomain` returns `null` or an empty string, no header is added.
///   * Per-call override: callers can pass `extras['x_domain_override']` in
///     request options to send a different domain for a single request.
class SubprojectInterceptor extends Interceptor {
  /// Construct.
  SubprojectInterceptor(this._config);

  final P2xClientConfig _config;

  /// Marker key on `RequestOptions.extra` to override the `X-Domain` value
  /// for a single request.
  static const String overrideDomainExtra = 'x_domain_override';

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    final override = options.extra[overrideDomainExtra] as String?;
    if (override != null && override.isNotEmpty) {
      options.headers['X-Domain'] = override;
      handler.next(options);
      return;
    }

    final getDomain = _config.getDomain;
    if (getDomain == null) {
      handler.next(options);
      return;
    }

    final domain = getDomain();
    if (domain == null || domain.isEmpty) {
      handler.next(options);
      return;
    }

    options.headers['X-Domain'] = domain;
    handler.next(options);
  }
}
