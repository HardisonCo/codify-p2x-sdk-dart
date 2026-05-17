import 'package:dio/dio.dart';
import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

/// Dio interceptor that attaches an `Idempotency-Key` header to mutating
/// requests (POST/PUT/PATCH/DELETE) so the P2X backend's idempotency
/// middleware (Redis, 24h TTL) can de-duplicate retries.
///
/// Behaviour:
///   * `GET` is never assigned an `Idempotency-Key` (it's idempotent by
///     HTTP definition).
///   * For POST/PUT/PATCH/DELETE, the interceptor checks (in order):
///       1. `extras['skip_idempotency'] == true` → skip header injection.
///       2. An explicit `Idempotency-Key` header on `options.headers` →
///          pass through unchanged.
///       3. `extras['idempotency_key']` (a `String`) → use that value.
///       4. Otherwise → generate a fresh UUID v4 via the `uuid` package.
///   * The same MethodOverrideInterceptor may already have rewritten PUT
///     /PATCH to POST. That's fine — POSTs still need an Idempotency-Key.
class IdempotencyInterceptor extends Interceptor {
  /// Construct. An optional [uuid] generator may be injected for tests
  /// (production callers should rely on the default `Uuid()`).
  IdempotencyInterceptor({@visibleForTesting Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  /// Marker key on `RequestOptions.extra` to skip Idempotency-Key injection
  /// for a single request.
  static const String skipIdempotencyExtra = 'skip_idempotency';

  /// Marker key on `RequestOptions.extra` to supply an explicit
  /// Idempotency-Key value for a single request.
  static const String idempotencyKeyExtra = 'idempotency_key';

  /// HTTP methods that require an Idempotency-Key. `GET` is excluded.
  static const Set<String> _mutatingMethods = <String>{
    'POST',
    'PUT',
    'PATCH',
    'DELETE',
  };

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    final method = options.method.toUpperCase();
    if (!_mutatingMethods.contains(method)) {
      handler.next(options);
      return;
    }

    final skip = options.extra[skipIdempotencyExtra] == true;
    if (skip) {
      handler.next(options);
      return;
    }

    // Honour an explicit header already on the request — caller is in
    // charge of the value.
    if (options.headers.containsKey('Idempotency-Key')) {
      final existing = options.headers['Idempotency-Key'];
      if (existing is String && existing.isNotEmpty) {
        handler.next(options);
        return;
      }
    }

    // Honour a value provided via the extras map.
    final extraKey = options.extra[idempotencyKeyExtra];
    if (extraKey is String && extraKey.isNotEmpty) {
      options.headers['Idempotency-Key'] = extraKey;
      handler.next(options);
      return;
    }

    options.headers['Idempotency-Key'] = _uuid.v4();
    handler.next(options);
  }
}
