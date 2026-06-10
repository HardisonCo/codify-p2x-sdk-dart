import 'package:flutter_test/flutter_test.dart';
import 'package:ycaas_flutter_sdk/src/utils/retry_policy.dart';
import 'package:ycaas_flutter_sdk/ycaas_flutter_sdk.dart';

void main() {
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
