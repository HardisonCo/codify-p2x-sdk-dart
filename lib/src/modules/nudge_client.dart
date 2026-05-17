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
}
