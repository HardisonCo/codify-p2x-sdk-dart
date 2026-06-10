import 'package:meta/meta.dart';

/// A normalized event surfaced by [RealtimeClient] subscriptions.
///
/// Wrapping the underlying transport's event types (Pusher's
/// `PusherEvent`, Echo's similar shape) so consumers can switch transports
/// without rewriting their event-handling code.
@immutable
class RealtimeEvent {
  /// Construct.
  const RealtimeEvent({
    required this.channel,
    required this.event,
    this.data = const <String, dynamic>{},
  });

  /// Channel name the event was received on (see [ChannelNames]).
  final String channel;

  /// Event name — e.g. `nudge.created`, `pipeline.progress`,
  /// `agent.executed`.
  final String event;

  /// Decoded JSON payload.
  final Map<String, dynamic> data;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RealtimeEvent &&
        other.channel == channel &&
        other.event == event;
  }

  @override
  int get hashCode => Object.hash(channel, event);

  @override
  String toString() => 'RealtimeEvent($channel#$event)';
}
