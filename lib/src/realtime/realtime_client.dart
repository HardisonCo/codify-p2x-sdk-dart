import 'dart:async';

import 'realtime_event.dart';

/// Abstract contract for real-time broadcasting (Pusher Channels / Laravel
/// Echo).
///
/// **Intentionally not depending on `pusher_channels_flutter`** — that
/// package adds a few MB and platform plugins that consumers like MOB
/// (local-only) don't need. Apps that want realtime implement this
/// interface in their own code, wrapping whatever transport they ship with.
///
/// A reference Pusher implementation may land in a sibling package
/// `ycaas_flutter_sdk_pusher` once the consumer apps need it.
///
/// Usage in a consumer app:
///
/// ```dart
/// class MyPusherClient implements RealtimeClient {
///   MyPusherClient(this._pusher);
///   final PusherChannelsFlutter _pusher;
///
///   @override
///   Future<void> connect() async { /* ... */ }
///   @override
///   Future<void> disconnect() async { /* ... */ }
///   @override
///   Stream<RealtimeEvent> subscribe(String channel) { /* ... */ }
///   @override
///   Future<void> unsubscribe(String channel) async { /* ... */ }
/// }
/// ```
abstract class RealtimeClient {
  /// Open the underlying WebSocket. Idempotent.
  Future<void> connect();

  /// Close the underlying WebSocket and tear down all subscriptions.
  Future<void> disconnect();

  /// Subscribe to [channel] and yield every event observed on it.
  ///
  /// Returns a broadcast stream — multiple listeners are supported. The
  /// implementation should de-duplicate channel joins.
  Stream<RealtimeEvent> subscribe(String channel);

  /// Unsubscribe from [channel] (and close its stream).
  Future<void> unsubscribe(String channel);
}

/// A no-op [RealtimeClient] useful in tests and in apps that don't enable
/// realtime yet. All methods complete successfully; subscription streams
/// emit nothing.
class NoopRealtimeClient implements RealtimeClient {
  /// Construct.
  const NoopRealtimeClient();

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  Stream<RealtimeEvent> subscribe(String channel) =>
      const Stream<RealtimeEvent>.empty();

  @override
  Future<void> unsubscribe(String channel) async {}
}
