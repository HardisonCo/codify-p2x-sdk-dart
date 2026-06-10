import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ycaas_flutter_sdk/src/utils/poll_until.dart';

void main() {
  test('resolves when done() becomes true', () async {
    var calls = 0;
    final result = await pollUntil<int>(
      fetch: () async {
        calls++;
        return calls;
      },
      done: (n) => n >= 3,
      interval: const Duration(milliseconds: 1),
      timeout: const Duration(seconds: 1),
    );
    expect(result, 3);
    expect(calls, 3);
  });

  test('throws TimeoutException when timeout elapses', () async {
    await expectLater(
      pollUntil<int>(
        fetch: () async => 0,
        done: (_) => false,
        interval: const Duration(milliseconds: 1),
        timeout: const Duration(milliseconds: 20),
      ),
      throwsA(isA<TimeoutException>()),
    );
  });
}
