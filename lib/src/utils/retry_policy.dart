import 'dart:async';
import 'dart:math' as math;

import '../client/exceptions/api_exception.dart';
import '../client/exceptions/server_exception.dart';

/// Exponential-backoff retry policy for transient HTTP failures.
///
/// Wrap a call with [run] to get up to [maxAttempts] tries, sleeping
/// `baseDelay * 2^(attempt-1)` between attempts (capped at [maxDelay]).
///
/// Only retries [shouldRetry]-positive throws. Default `shouldRetry`
/// considers `ServerException` (5xx) and DioException-shaped network
/// errors retryable; `ValidationException`, `UnauthorizedException`,
/// `ForbiddenException`, `NotFoundException` are not.
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

  static bool _defaultShouldRetry(Object e) {
    if (e is ServerException) return true;
    if (e is ApiException) return false;
    // Anything else (DioException network errors, SocketException, etc.) —
    // assume transient.
    return true;
  }
}
