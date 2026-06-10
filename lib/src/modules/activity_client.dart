import 'package:dio/dio.dart';
import 'package:meta/meta.dart';

import 'package:ycaas_flutter_sdk/src/client/p2x_client.dart';
import 'package:ycaas_flutter_sdk/src/modules/activity_models.dart';

/// Per-domain client for the **Activity** module.
///
/// Used by MOB v2 to persist completed runs (`logRun`), list run
/// history (`listRuns`), and append batches of GPS points to an
/// in-progress run (`appendLocations`). Out of scope for NIO's
/// LAUNCH_NOW critical path, but shipped in Tier 1 so MOB v2 has the
/// surface ready.
class ActivityClient {
  /// Construct with a reference to the shared [P2xClient].
  ActivityClient(this._client);

  final P2xClient _client;

  /// Header name for the idempotency key the SDK sends on writes.
  static const String _idempotencyHeader = 'Idempotency-Key';

  /// `POST /api/activity/runs` — log a completed run.
  ///
  /// The server returns the canonical row including its assigned `id`.
  /// Pass [idempotencyKey] to dedupe double-submits (the device-side
  /// run UUID is a natural choice).
  Future<RunActivity> logRun(RunActivity run, {String? idempotencyKey}) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/activity/runs',
        data: run.toJson(),
        options: _buildOptions(idempotencyKey: idempotencyKey),
      );
      final body = response.data ?? const <String, dynamic>{};
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError('POST /activity/runs returned no "data" object.');
      }
      return RunActivity.fromJson(data);
    });
  }

  /// `GET /api/activity/runs?from=<iso>&to=<iso>&limit=<n>` — list runs
  /// for the current user, optionally bounded by a time window.
  ///
  /// [limit] defaults to 50; the server may cap this lower.
  Future<List<RunActivity>> listRuns({
    DateTime? from,
    DateTime? to,
    int limit = 50,
  }) {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/activity/runs',
        queryParameters: <String, dynamic>{
          if (from != null) 'from': from.toUtc().toIso8601String(),
          if (to != null) 'to': to.toUtc().toIso8601String(),
          'limit': limit,
        },
      );
      final body = response.data ?? const <String, dynamic>{};
      final raw = body['data'];
      if (raw is! List) return const <RunActivity>[];
      return raw
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => RunActivity.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    });
  }

  /// `POST /api/activity/runs/<runId>/locations` — append a batch of
  /// [RunLocationPoint]s to an in-progress run.
  ///
  /// The client may call this periodically while a run is still active.
  /// Pass [idempotencyKey] to dedupe double-submits.
  Future<void> appendLocations({
    required int runId,
    required List<RunLocationPoint> points,
    String? idempotencyKey,
  }) {
    return _client.request(() async {
      await _client.dio.post<dynamic>(
        '/activity/runs/$runId/locations',
        data: <String, dynamic>{
          'points': points.map((p) => p.toJson()).toList(),
        },
        options: _buildOptions(idempotencyKey: idempotencyKey),
      );
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
