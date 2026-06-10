import 'package:dio/dio.dart';
import 'package:meta/meta.dart';

import 'package:ycaas_flutter_sdk/src/client/p2x_client.dart';
import 'package:ycaas_flutter_sdk/src/modules/kpi_models.dart';

/// Per-domain client for the **KPI snapshots** module.
///
/// One numeric reading per call. NIO writes one daily-calories snapshot
/// per food scan; MOB v2 writes water/weight/step snapshots from the
/// activity dashboard. The four `record*` helpers lock down the standard
/// key/unit pairs to avoid drift between callers.
class KpiClient {
  /// Construct with a reference to the shared [P2xClient].
  KpiClient(this._client);

  final P2xClient _client;

  /// Header name for the idempotency key the SDK sends on writes.
  static const String _idempotencyHeader = 'Idempotency-Key';

  /// `POST /api/kpi/snapshots` — record a single KPI reading.
  ///
  /// [recordedAt] defaults to `DateTime.now().toUtc()` if `null`.
  /// Pass [idempotencyKey] to dedupe double-submits.
  Future<KpiSnapshot> record({
    required String key,
    required double value,
    required String unit,
    DateTime? recordedAt,
    String? idempotencyKey,
  }) {
    return _client.request(() async {
      final timestamp = (recordedAt ?? DateTime.now().toUtc()).toUtc();
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/kpi/snapshots',
        data: <String, dynamic>{
          'key': key,
          'value': value,
          'unit': unit,
          'recorded_at': timestamp.toIso8601String(),
        },
        options: _buildOptions(idempotencyKey: idempotencyKey),
      );
      final body = response.data ?? const <String, dynamic>{};
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError('POST /kpi/snapshots returned no "data" object.');
      }
      return KpiSnapshot.fromJson(data);
    });
  }

  /// `GET /api/kpi/snapshots?key=<key>&from=<iso>&to=<iso>` — list
  /// snapshots for one KPI within an optional time window.
  Future<List<KpiSnapshot>> list({
    required String key,
    DateTime? from,
    DateTime? to,
  }) {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/kpi/snapshots',
        queryParameters: <String, dynamic>{
          'key': key,
          if (from != null) 'from': from.toUtc().toIso8601String(),
          if (to != null) 'to': to.toUtc().toIso8601String(),
        },
      );
      final body = response.data ?? const <String, dynamic>{};
      final raw = body['data'];
      if (raw is! List) return const <KpiSnapshot>[];
      return raw
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => KpiSnapshot.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    });
  }

  /// Convenience helper: record a `daily-calories` snapshot in `kcal`.
  Future<KpiSnapshot> recordCalories(double kcal, {String? idempotencyKey}) {
    return record(
      key: 'daily-calories',
      value: kcal,
      unit: 'kcal',
      idempotencyKey: idempotencyKey,
    );
  }

  /// Convenience helper: record a `water-intake` snapshot in `ml`.
  Future<KpiSnapshot> recordWater(
    double milliliters, {
    String? idempotencyKey,
  }) {
    return record(
      key: 'water-intake',
      value: milliliters,
      unit: 'ml',
      idempotencyKey: idempotencyKey,
    );
  }

  /// Convenience helper: record a `weight` snapshot in `kg`.
  Future<KpiSnapshot> recordWeight(
    double kilograms, {
    String? idempotencyKey,
  }) {
    return record(
      key: 'weight',
      value: kilograms,
      unit: 'kg',
      idempotencyKey: idempotencyKey,
    );
  }

  /// Convenience helper: record a `steps` snapshot with unit `count`.
  /// Accepts an integer step count and stores it as a `double` on the wire.
  Future<KpiSnapshot> recordSteps(int count, {String? idempotencyKey}) {
    return record(
      key: 'steps',
      value: count.toDouble(),
      unit: 'count',
      idempotencyKey: idempotencyKey,
    );
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
