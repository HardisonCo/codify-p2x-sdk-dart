import 'package:dio/dio.dart';

import 'package:ycaas_flutter_sdk/src/client/p2x_client.dart';
import 'package:ycaas_flutter_sdk/src/modules/schedule_models.dart';

/// Per-domain client for the **Schedule** module.
///
/// Two resources powering IBD's doctor↔patient telehealth flow:
///
///   * `/api/schedule`       — bookable provider slots
///   * `/api/schedule-call`  — live (or completed) calls against a slot
///
/// Mirrors the TS sibling `ScheduleApiClient`. PUT requests transit the
/// wire as `POST` + `?_method=PUT` (Laravel method-override convention,
/// handled centrally by [P2xClient]'s interceptor stack). Writes
/// auto-receive a fresh UUID v4 `Idempotency-Key`.
class ScheduleClient {
  /// Construct with a reference to the shared [P2xClient].
  ScheduleClient(this._client);

  final P2xClient _client;

  /// Header name for the idempotency key the SDK sends on writes.
  static const String _idempotencyHeader = 'Idempotency-Key';

  // ─── /api/schedule ───────────────────────────────────────────────────

  /// `GET /api/schedule` — list every schedule slot visible to the
  /// caller. Filtering is server-side via [P2xClient]'s `X-Domain`
  /// header.
  Future<List<Schedule>> list() {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/schedule',
      );
      final body = response.data ?? const <String, dynamic>{};
      final raw = body['data'];
      if (raw is! List) return const <Schedule>[];
      return raw
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => Schedule.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    });
  }

  /// `POST /api/schedule` — create a new schedule slot.
  ///
  /// [providerId] owns the slot. [startsAt] / [endsAt] bound the
  /// window. [capacity] defaults to `1` for 1:1 telehealth bookings.
  /// [status] defaults to `open`. [metadata] is opaque to the SDK.
  ///
  /// A fresh UUID v4 `Idempotency-Key` is auto-attached by the SDK's
  /// interceptor stack — pass [idempotencyKey] to override.
  Future<Schedule> create({
    required int providerId,
    required DateTime startsAt,
    required DateTime endsAt,
    int capacity = 1,
    String status = 'open',
    Map<String, dynamic> metadata = const <String, dynamic>{},
    String? idempotencyKey,
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/schedule',
        data: <String, dynamic>{
          'provider_id': providerId,
          'starts_at': startsAt.toIso8601String(),
          'ends_at': endsAt.toIso8601String(),
          'capacity': capacity,
          'status': status,
          'metadata': metadata,
        },
        options: _buildOptions(idempotencyKey: idempotencyKey),
      );
      return _decodeSchedule(response.data, 'POST /schedule');
    });
  }

  /// `GET /api/schedule/<id>` — fetch one schedule slot by primary key.
  Future<Schedule> get(int id) {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/schedule/$id',
      );
      return _decodeSchedule(response.data, 'GET /schedule/$id');
    });
  }

  /// `PUT /api/schedule/<id>` — update an existing schedule slot.
  ///
  /// Only the fields you pass are forwarded to the server (sparse
  /// update). The PUT travels as `POST /api/schedule/<id>?_method=PUT`
  /// per the Laravel method-override convention; callers don't care.
  Future<Schedule> update(
    int id, {
    DateTime? startsAt,
    DateTime? endsAt,
    int? capacity,
    String? status,
    Map<String, dynamic>? metadata,
  }) {
    return _client.request(() async {
      final data = <String, dynamic>{
        if (startsAt != null) 'starts_at': startsAt.toIso8601String(),
        if (endsAt != null) 'ends_at': endsAt.toIso8601String(),
        if (capacity != null) 'capacity': capacity,
        if (status != null) 'status': status,
        if (metadata != null) 'metadata': metadata,
      };
      final response = await _client.dio.put<Map<String, dynamic>>(
        '/schedule/$id',
        data: data,
      );
      return _decodeSchedule(response.data, 'PUT /schedule/$id');
    });
  }

  /// `DELETE /api/schedule/<id>` — remove a schedule slot.
  Future<void> destroy(int id) {
    return _client.request(() async {
      await _client.dio.delete<dynamic>('/schedule/$id');
    });
  }

  // ─── /api/schedule-call ──────────────────────────────────────────────

  /// `GET /api/schedule-call` — list every schedule call visible to
  /// the caller.
  Future<List<ScheduleCall>> listCalls() {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/schedule-call',
      );
      final body = response.data ?? const <String, dynamic>{};
      final raw = body['data'];
      if (raw is! List) return const <ScheduleCall>[];
      return raw
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => ScheduleCall.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    });
  }

  /// `POST /api/schedule-call` — create a new schedule call against a
  /// booked slot.
  ///
  /// A fresh UUID v4 `Idempotency-Key` is auto-attached by the SDK's
  /// interceptor stack — pass [idempotencyKey] to override.
  Future<ScheduleCall> createCall({
    required int scheduleId,
    required int patientId,
    required int providerId,
    String status = 'pending',
    Map<String, dynamic> metadata = const <String, dynamic>{},
    String? idempotencyKey,
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/schedule-call',
        data: <String, dynamic>{
          'schedule_id': scheduleId,
          'patient_id': patientId,
          'provider_id': providerId,
          'status': status,
          'metadata': metadata,
        },
        options: _buildOptions(idempotencyKey: idempotencyKey),
      );
      return _decodeCall(response.data, 'POST /schedule-call');
    });
  }

  /// `GET /api/schedule-call/<id>` — fetch one schedule call by
  /// primary key.
  Future<ScheduleCall> getCall(int id) {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/schedule-call/$id',
      );
      return _decodeCall(response.data, 'GET /schedule-call/$id');
    });
  }

  /// `PUT /api/schedule-call/<id>` — update a schedule call (commonly
  /// to transition `pending`→`connected`→`ended`).
  ///
  /// The PUT travels as `POST /api/schedule-call/<id>?_method=PUT` per
  /// the Laravel method-override convention; callers don't care.
  Future<ScheduleCall> updateCall(
    int id, {
    String? status,
    DateTime? startedAt,
    DateTime? endedAt,
    String? livekitRoom,
    Map<String, dynamic>? metadata,
  }) {
    return _client.request(() async {
      final data = <String, dynamic>{
        if (status != null) 'status': status,
        if (startedAt != null) 'started_at': startedAt.toIso8601String(),
        if (endedAt != null) 'ended_at': endedAt.toIso8601String(),
        if (livekitRoom != null) 'livekit_room': livekitRoom,
        if (metadata != null) 'metadata': metadata,
      };
      final response = await _client.dio.put<Map<String, dynamic>>(
        '/schedule-call/$id',
        data: data,
      );
      return _decodeCall(response.data, 'PUT /schedule-call/$id');
    });
  }

  /// `DELETE /api/schedule-call/<id>` — remove a schedule call.
  Future<void> destroyCall(int id) {
    return _client.request(() async {
      await _client.dio.delete<dynamic>('/schedule-call/$id');
    });
  }

  // ─── helpers ─────────────────────────────────────────────────────────

  Schedule _decodeSchedule(Map<String, dynamic>? body, String label) {
    final data = (body ?? const <String, dynamic>{})['data'];
    if (data is! Map<String, dynamic>) {
      throw StateError('$label returned no "data" object.');
    }
    return Schedule.fromJson(data);
  }

  ScheduleCall _decodeCall(Map<String, dynamic>? body, String label) {
    final data = (body ?? const <String, dynamic>{})['data'];
    if (data is! Map<String, dynamic>) {
      throw StateError('$label returned no "data" object.');
    }
    return ScheduleCall.fromJson(data);
  }

  Options? _buildOptions({String? idempotencyKey}) {
    if (idempotencyKey == null || idempotencyKey.isEmpty) return null;
    return Options(
      headers: <String, dynamic>{_idempotencyHeader: idempotencyKey},
    );
  }
}
