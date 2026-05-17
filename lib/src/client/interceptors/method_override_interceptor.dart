import 'package:dio/dio.dart';

/// Dio interceptor that rewrites `PUT` and `PATCH` requests into `POST`
/// requests with a `_method=<original>` query parameter.
///
/// This is the Laravel/Symfony **method-override** convention: some hosting
/// stacks (legacy load balancers, certain CDNs, App Engine, etc.) drop or
/// rewrite `PUT`/`PATCH` requests, so Laravel accepts them as a `POST` plus
/// a `_method` form field or query parameter. The P2X backend uses the
/// query-parameter form, matching what the TypeScript sibling SDK
/// (`P2X/sdk/src/api-client.ts`) does for parity.
///
/// Behaviour:
///   * `PUT  /foo` → `POST /foo?_method=PUT`
///   * `PATCH /foo` → `POST /foo?_method=PATCH`
///   * `DELETE`, `GET`, `POST`, and any other method pass through unchanged.
///   * Per-call opt-out via `extras['skip_method_override'] = true` keeps the
///     original method on the wire (useful for endpoints that have not been
///     migrated yet, or for hitting non-Laravel services through the same
///     Dio instance).
///   * Existing query parameters are preserved; `_method` is added alongside.
class MethodOverrideInterceptor extends Interceptor {
  /// Construct.
  MethodOverrideInterceptor();

  /// Marker key on `RequestOptions.extra` to skip the method override rewrite
  /// for a single request.
  static const String skipMethodOverrideExtra = 'skip_method_override';

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    final skip = options.extra[skipMethodOverrideExtra] == true;
    if (skip) {
      handler.next(options);
      return;
    }

    final method = options.method.toUpperCase();
    if (method != 'PUT' && method != 'PATCH') {
      handler.next(options);
      return;
    }

    options
      ..method = 'POST'
      ..queryParameters = <String, dynamic>{
        ...options.queryParameters,
        '_method': method,
      };

    handler.next(options);
  }
}
