import 'dart:async';

/// A poller that repeatedly calls [fetch] until [done] returns true, then
/// resolves with the final value.
///
/// Used to drive long-running wizard / deal / pipeline jobs whose state is
/// observed via repeated GETs. Throws [TimeoutException] if [timeout]
/// elapses first.
///
/// Defaults match the codify-pipeline polling cadence used by the TS SDK:
/// 1500ms between polls, 5 minute timeout.
Future<T> pollUntil<T>({
  required Future<T> Function() fetch,
  required bool Function(T) done,
  Duration interval = const Duration(milliseconds: 1500),
  Duration timeout = const Duration(minutes: 5),
}) async {
  final start = DateTime.now();
  while (true) {
    final value = await fetch();
    if (done(value)) return value;

    final elapsed = DateTime.now().difference(start);
    if (elapsed >= timeout) {
      throw TimeoutException(
        'pollUntil timed out after ${timeout.inSeconds}s',
        timeout,
      );
    }
    await Future<void>.delayed(interval);
  }
}
