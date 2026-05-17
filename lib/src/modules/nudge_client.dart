import 'package:dio/dio.dart';
import 'package:meta/meta.dart';

import 'package:codify_p2x_sdk/src/client/p2x_client.dart';
import 'package:codify_p2x_sdk/src/modules/nudge_models.dart';

/// Per-domain client for the **Nudge** module.
///
/// Nudges are server-driven prompts (meal-log reminders, coin-earning
/// celebrations, daily streak nudges). NIO and MOB list the active set
/// and report back to the server when the user acknowledges or
/// dismisses one. The server owns trigger logic and quiet hours — the
/// client just renders what it gets.
class NudgeClient {
  /// Construct with a reference to the shared [P2xClient].
  NudgeClient(this._client);

  final P2xClient _client;

  /// Header name for the idempotency key the SDK sends on writes.
  static const String _idempotencyHeader = 'Idempotency-Key';

  /// `GET /api/nudges?status=<status>` — list nudges currently visible to
  /// the user.
  ///
  /// The default [status] filter is `active` (nudges that have not yet
  /// been acknowledged or dismissed). Pass `status: null` to fetch the
  /// full history including already-handled rows.
  Future<List<Nudge>> list({String? status = 'active'}) {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/nudges',
        queryParameters: <String, dynamic>{
          if (status != null) 'status': status,
        },
      );
      final body = response.data ?? const <String, dynamic>{};
      final raw = body['data'];
      if (raw is! List) return const <Nudge>[];
      return raw
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => Nudge.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    });
  }

  /// `POST /api/nudges/<id>/ack` — mark a nudge as acknowledged by the
  /// user. The server returns the updated row with `acknowledged_at` set.
  ///
  /// Pass [idempotencyKey] to dedupe double-submits.
  Future<Nudge> ack(int id, {String? idempotencyKey}) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/nudges/$id/ack',
        options: _buildOptions(idempotencyKey: idempotencyKey),
      );
      final body = response.data ?? const <String, dynamic>{};
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError('POST /nudges/$id/ack returned no "data" object.');
      }
      return Nudge.fromJson(data);
    });
  }

  /// `POST /api/nudges/<id>/dismiss` — mark a nudge as dismissed (don't
  /// show again, but no positive acknowledgement). The server returns
  /// the updated row with `dismissed_at` set.
  ///
  /// Pass [idempotencyKey] to dedupe double-submits.
  Future<Nudge> dismiss(int id, {String? idempotencyKey}) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/nudges/$id/dismiss',
        options: _buildOptions(idempotencyKey: idempotencyKey),
      );
      final body = response.data ?? const <String, dynamic>{};
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError(
          'POST /nudges/$id/dismiss returned no "data" object.',
        );
      }
      return Nudge.fromJson(data);
    });
  }

  Options? _buildOptions({String? idempotencyKey}) {
    if (idempotencyKey == null || idempotencyKey.isEmpty) return null;
    return Options(
      headers: <String, dynamic>{_idempotencyHeader: idempotencyKey},
    );
  }

  /// Test seam: the [Options] object the client uses internally for a
  /// given [idempotencyKey]. Test-only.
  @visibleForTesting
  static Options idempotencyOptionsForTest(String idempotencyKey) {
    return Options(
      headers: <String, dynamic>{_idempotencyHeader: idempotencyKey},
    );
  }

  /// `POST /api/nudges/check-in` — record that the user has been
  /// reached on the given [channel] (one of `push`, `sms`, `email`,
  /// `in_app`, `voice`) for the [Nudge] identified by [nudgeId].
  ///
  /// Used by the mobile apps to confirm receipt-of-render — the server
  /// tracks per-channel delivery so quiet-hours and channel-rotation
  /// logic can react. Free-form [payload] lets clients attach extra
  /// context (e.g. `{"rendered_at": "2026-05-01T08:00:00Z"}`).
  ///
  /// Idempotent via the auto-injected `Idempotency-Key` header.
  Future<Nudge> checkIn({
    required int nudgeId,
    required String channel,
    Map<String, dynamic>? payload,
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/nudges/check-in',
        data: <String, dynamic>{
          'nudge_id': nudgeId,
          'channel': channel,
          if (payload != null) 'payload': payload,
        },
      );
      final body = response.data ?? const <String, dynamic>{};
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError('POST /nudges/check-in returned no "data" object.');
      }
      return Nudge.fromJson(data);
    });
  }

  /// `GET /api/nudges/channels` — list the [NudgeChannel]s configured
  /// for the current subproject. The client renders preferences UI
  /// against this list and writes user choices back via the
  /// per-user-prefs surface (not part of this client).
  Future<List<NudgeChannel>> channels() {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/nudges/channels',
      );
      final body = response.data ?? const <String, dynamic>{};
      final raw = body['data'];
      if (raw is! List) return const <NudgeChannel>[];
      return raw
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => NudgeChannel.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    });
  }

  /// `POST /api/nudges/<id>/snooze` — defer a nudge by [duration]. The
  /// server clears the snooze and re-surfaces the nudge once
  /// `Duration.inSeconds` elapses.
  ///
  /// The [Duration] is serialized as an integer `seconds` field — the
  /// server's preferred wire format — so `Duration(hours: 2)` becomes
  /// `{"seconds": 7200}`.
  ///
  /// Idempotent via the auto-injected `Idempotency-Key` header.
  Future<Nudge> snooze(int id, {required Duration duration}) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/nudges/$id/snooze',
        data: <String, dynamic>{
          'seconds': duration.inSeconds,
        },
      );
      final body = response.data ?? const <String, dynamic>{};
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError('POST /nudges/$id/snooze returned no "data" object.');
      }
      return Nudge.fromJson(data);
    });
  }

  /// `DELETE /api/nudges/<id>` — permanently delete the nudge.
  ///
  /// Admin/owner-only on the server; mobile users typically use [ack]
  /// or [dismiss] instead. The `IdempotencyInterceptor` still attaches
  /// an `Idempotency-Key` so a retried DELETE doesn't 404 noisily.
  Future<void> destroy(int id) {
    return _client.request(() async {
      await _client.dio.delete<dynamic>('/nudges/$id');
    });
  }
}
