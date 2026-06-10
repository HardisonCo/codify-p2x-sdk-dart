import 'package:ycaas_flutter_sdk/src/client/p2x_client.dart';
import 'package:ycaas_flutter_sdk/src/comms/notification_models.dart';

/// Per-domain client for the **Notification** module.
///
/// Server-side companion to the FCM push pipeline. Mobile apps render
/// the live push when delivered; on foreground / sync they call this
/// client to backfill anything the push layer missed.
///
/// The `start-task` endpoint is the operator-side trigger for bulk
/// fan-out jobs (e.g. send tomorrow's appointment reminders) — the
/// server queues the work and the SDK returns once enqueued.
class NotificationClient {
  /// Construct with a reference to the shared [P2xClient].
  NotificationClient(this._client);

  final P2xClient _client;

  /// `GET /api/notification?limit=<n>` — list the current user's
  /// notifications, optionally capped at [limit] rows (server enforces a
  /// hard upper bound).
  Future<List<AppNotification>> list({int? limit}) {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/notification',
        queryParameters: <String, dynamic>{
          if (limit != null) 'limit': limit,
        },
      );
      final body = response.data ?? const <String, dynamic>{};
      final raw = body['data'];
      if (raw is! List) return const <AppNotification>[];
      return raw
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => AppNotification.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    });
  }

  /// `GET /api/notification/unread` — list unread notifications only.
  ///
  /// Server filters by `read_at IS NULL`. Common UI pattern: badge the
  /// notification bell with `unread().length` on foreground.
  Future<List<AppNotification>> unread() {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/notification/unread',
      );
      final body = response.data ?? const <String, dynamic>{};
      final raw = body['data'];
      if (raw is! List) return const <AppNotification>[];
      return raw
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => AppNotification.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    });
  }

  /// `DELETE /api/notification/<id>` — soft-delete one notification.
  ///
  /// Server enforces ownership — the recipient (and operators) can
  /// delete; anyone else gets a 403.
  Future<void> delete(int id) {
    return _client.request(() async {
      await _client.dio.delete<dynamic>('/notification/$id');
    });
  }

  /// `POST /api/notification/start-task` — kick off a server-side
  /// notification task (bulk fan-out, retry queue drain, etc.).
  ///
  /// [taskKey] is a stable identifier the server maps to a registered
  /// task handler. [payload] is optional and forwarded verbatim — the
  /// task handler owns its schema.
  ///
  /// Idempotent: the SDK's auto-generated `Idempotency-Key` makes
  /// double-submits safe within the 24h Redis TTL window.
  Future<void> startTask({
    required String taskKey,
    Map<String, dynamic>? payload,
  }) {
    return _client.request(() async {
      await _client.dio.post<dynamic>(
        '/notification/start-task',
        data: <String, dynamic>{
          'task_key': taskKey,
          if (payload != null) 'payload': payload,
        },
      );
    });
  }
}
