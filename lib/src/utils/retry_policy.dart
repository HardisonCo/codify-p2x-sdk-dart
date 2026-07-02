import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:ycaas_flutter_sdk/src/client/exceptions/api_exception.dart';
import 'package:ycaas_flutter_sdk/src/client/interceptors/idempotency_interceptor.dart';

/// Exponential-backoff retry policy for transient HTTP failures.
///
/// Wrap a call with [run] to get up to [maxAttempts] tries, sleeping
/// `baseDelay * 2^(attempt-1)` between attempts (capped at [maxDelay]).
///
/// Only retries [shouldRetry]-positive throws. The default `shouldRetry` is
/// status- AND method-aware (parity with the TS SDK): it retries transient
/// failures (5xx or a no-response transport error) for idempotent methods
/// (GET/HEAD/OPTIONS/DELETE/PUT) — and for POST/PATCH ONLY when the caller
/// pinned a stable Idempotency-Key. It NEVER retries a 4xx, and never retries
/// a non-idempotent write without a pinned key (so a create/charge cannot be
/// duplicated). Context-less (non-HTTP) throws keep the opt-in transient-retry
/// behavior.
///
/// **Not used by default** — the SDK does not auto-retry. Per-domain
/// callers can opt-in:
///
/// ```dart
/// final retry = RetryPolicy();
/// final result = await retry.run(() => p2x.something.flaky());
/// ```
class RetryPolicy {
  /// Construct.
  const RetryPolicy({
    this.maxAttempts = 3,
    this.baseDelay = const Duration(milliseconds: 250),
    this.maxDelay = const Duration(seconds: 8),
    this.jitter = true,
  });

  /// Maximum number of attempts (including the initial). Minimum 1.
  final int maxAttempts;

  /// Initial delay; the actual sleep grows exponentially.
  final Duration baseDelay;

  /// Cap on individual sleep durations.
  final Duration maxDelay;

  /// If `true`, applies +/-20% random jitter to each sleep — useful when
  /// many clients retry simultaneously.
  final bool jitter;

  /// Run [call] under this policy. Re-throws the last error if every
  /// attempt fails.
  Future<T> run<T>(
    Future<T> Function() call, {
    bool Function(Object error)? shouldRetry,
  }) async {
    assert(maxAttempts >= 1, 'maxAttempts must be >= 1');
    final retryCheck = shouldRetry ?? _defaultShouldRetry;
    Object? lastError;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await call();
      } on Object catch (e) {
        lastError = e;
        if (attempt == maxAttempts || !retryCheck(e)) rethrow;
        await Future<void>.delayed(_delayFor(attempt));
      }
    }
    // Unreachable — the loop either returns or rethrows.
    throw lastError ?? StateError('RetryPolicy exhausted without an error');
  }

  Duration _delayFor(int attempt) {
    final exp = math.pow(2, attempt - 1).toDouble();
    var ms = (baseDelay.inMilliseconds * exp).round();
    if (ms > maxDelay.inMilliseconds) ms = maxDelay.inMilliseconds;
    if (jitter) {
      final jitterMs = (ms * 0.2).round();
      final delta = math.Random().nextInt(jitterMs * 2 + 1) - jitterMs;
      ms = math.max(0, ms + delta);
    }
    return Duration(milliseconds: ms);
  }

  /// HTTP methods safe to retry without an idempotency guard.
  static const Set<String> _idempotentMethods = <String>{
    'GET',
    'HEAD',
    'OPTIONS',
    'DELETE',
    'PUT',
  };

  /// Default retry predicate — status- and method-aware so a non-idempotent
  /// write is never silently duplicated (parity with the TS SDK's
  /// `isRetryableRequest`, P2X/sdk/src/api/hms-api-client.ts):
  ///   * Non-HTTP (context-less) errors keep the opt-in transient-retry
  ///     behavior — there is no HTTP method, so nothing to duplicate.
  ///   * 4xx is never retried (definitive client error).
  ///   * Only a transient HTTP failure (5xx, or a transport error with no
  ///     response) is eligible, AND only for an idempotent method — or a
  ///     POST/PATCH whose caller PINNED a stable Idempotency-Key. Unknown
  ///     method → fail closed.
  static bool _defaultShouldRetry(Object e) {
    final int status;
    if (e is ApiException) {
      status = e.status;
    } else if (e is DioException) {
      status = e.response?.statusCode ?? 0;
    } else {
      // Context-less error (SocketException, custom Exception, …): the caller
      // explicitly opted into retry and there is no write to duplicate.
      return true;
    }

    if (status >= 400 && status < 500) return false; // never retry 4xx
    // status == 0 => transport failure (no HTTP response); 5xx => server error.
    final transient = status == 0 || (status >= 500 && status < 600);
    if (!transient) return false;

    final method = _effectiveMethod(e);
    if (method == null) return false; // can't prove idempotence → fail closed
    if (_idempotentMethods.contains(method)) return true;
    if (method == 'POST' || method == 'PATCH') return _idempotencyKeyPinned(e);
    return false;
  }

  /// The effective HTTP verb, undoing `MethodOverrideInterceptor`'s
  /// PUT/PATCH→POST rewrite. Read from the sanitized `originalError` map on a
  /// typed [ApiException] (the normal path via `P2xClient.request`), or from
  /// the raw [DioException] when callers wrap a bare Dio call.
  static String? _effectiveMethod(Object e) {
    if (e is ApiException) {
      final orig = e.originalError;
      if (orig is Map && orig['method'] is String) {
        return (orig['method'] as String).toUpperCase();
      }
      return null;
    }
    if (e is DioException) {
      final ro = e.requestOptions;
      final override = ro.queryParameters['_method'];
      if (override is String && override.isNotEmpty) {
        return override.toUpperCase();
      }
      return ro.method.toUpperCase();
    }
    return null;
  }

  /// True only when the CALLER pinned a stable Idempotency-Key (auto-generated
  /// keys regenerate per attempt, so their presence is not a safe retry
  /// signal — see [IdempotencyInterceptor]).
  static bool _idempotencyKeyPinned(Object e) {
    if (e is ApiException) {
      final orig = e.originalError;
      return orig is Map && orig['idempotencyKeyPinned'] == true;
    }
    if (e is DioException) {
      return e.requestOptions.extra[IdempotencyInterceptor.idempotencyKeyExtra]
          is String;
    }
    return false;
  }
}
