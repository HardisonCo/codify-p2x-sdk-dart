import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ycaas_flutter_sdk/src/client/interceptors/idempotency_interceptor.dart';
import 'package:ycaas_flutter_sdk/src/utils/retry_policy.dart';
import 'package:ycaas_flutter_sdk/ycaas_flutter_sdk.dart';

void main() {
  group('RetryPolicy — method-aware default (TS parity item 4)', () {
    Future<int> countCalls(Object error) async {
      var calls = 0;
      const policy = RetryPolicy(
        maxAttempts: 3,
        baseDelay: Duration(milliseconds: 1),
        jitter: false,
      );
      try {
        await policy.run<void>(() async {
          calls++;
          throw error;
        });
      } catch (_) {
        // swallow — we only assert the attempt count
      }
      return calls;
    }

    ServerException server(String method, {bool pinned = false}) =>
        ServerException(
          status: 500,
          message: 'x',
          originalError: <String, dynamic>{
            'status': 500,
            'method': method,
            'idempotencyKeyPinned': pinned,
          },
        );

    test('retries idempotent 5xx (GET/PUT/DELETE) up to maxAttempts', () async {
      expect(await countCalls(server('GET')), 3);
      expect(await countCalls(server('PUT')), 3);
      expect(await countCalls(server('DELETE')), 3);
    });

    test('does NOT retry POST/PATCH 5xx without a pinned idempotency key',
        () async {
      expect(await countCalls(server('POST')), 1);
      expect(await countCalls(server('PATCH')), 1);
    });

    test('retries POST/PATCH 5xx when a stable idempotency key is pinned',
        () async {
      expect(await countCalls(server('POST', pinned: true)), 3);
      expect(await countCalls(server('PATCH', pinned: true)), 3);
    });

    test('never retries 4xx', () async {
      expect(await countCalls(UnauthorizedException(message: 'x')), 1); // 401
      expect(await countCalls(ApiException(status: 429, message: 'x')), 1);
      expect(await countCalls(ApiException(status: 404, message: 'x')), 1);
    });

    test('classifies a raw DioException by method (no HTTP response)', () async {
      DioException dio(
        String method, {
        Map<String, dynamic>? query,
        Map<String, dynamic>? extra,
      }) =>
          DioException(
            requestOptions: RequestOptions(
              path: '/x',
              method: method,
              queryParameters: query ?? const <String, dynamic>{},
              extra: extra ?? const <String, dynamic>{},
            ),
          );

      expect(await countCalls(dio('GET')), 3); // idempotent transport → retry
      expect(await countCalls(dio('POST')), 1); // non-idempotent → no retry
      // MethodOverride recovery: wire verb POST but original PUT → idempotent.
      expect(await countCalls(dio('POST', query: {'_method': 'PUT'})), 3);
      // Caller-pinned key on a POST → safe to retry.
      expect(
        await countCalls(
          dio('POST', extra: {IdempotencyInterceptor.idempotencyKeyExtra: 'k'}),
        ),
        3,
      );
    });

    test('preserves opt-in retry for context-less (non-HTTP) errors', () async {
      expect(await countCalls(const _Transient()), 3);
    });
  });

  test('retries up to maxAttempts then rethrows', () async {
    var calls = 0;
    final policy = RetryPolicy(
      maxAttempts: 3,
      baseDelay: const Duration(milliseconds: 1),
      jitter: false,
    );

    await expectLater(
      policy.run<int>(() async {
        calls++;
        throw const _Transient();
      }),
      throwsA(isA<_Transient>()),
    );
    expect(calls, 3);
  });

  test('returns first successful result', () async {
    var calls = 0;
    final policy = RetryPolicy(
      maxAttempts: 5,
      baseDelay: const Duration(milliseconds: 1),
      jitter: false,
    );

    final value = await policy.run<int>(() async {
      calls++;
      if (calls < 3) throw const _Transient();
      return 42;
    });
    expect(value, 42);
    expect(calls, 3);
  });

  test('does NOT retry on ValidationException by default', () async {
    var calls = 0;
    final policy = RetryPolicy(
      maxAttempts: 5,
      baseDelay: const Duration(milliseconds: 1),
      jitter: false,
    );

    await expectLater(
      policy.run<void>(() async {
        calls++;
        throw ValidationException(
          message: 'bad',
          errors: const <String, List<String>>{},
        );
      }),
      throwsA(isA<ValidationException>()),
    );
    expect(calls, 1);
  });
}

class _Transient implements Exception {
  const _Transient();
}
