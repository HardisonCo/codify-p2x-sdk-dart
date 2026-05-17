import 'package:dio/dio.dart';

import 'package:codify_p2x_sdk/src/client/p2x_client.dart';
import 'package:codify_p2x_sdk/src/modules/follow_ups_models.dart';

/// Per-domain client for the **FollowUps** module.
///
/// Six endpoints powering the doctor's post-visit follow-up surface
/// (mirrors the TS sibling `FollowUpsModuleApiClient`):
///
///   * `GET    /api/follow-ups`                       — list
///   * `POST   /api/follow-ups`                       — create
///   * `GET    /api/follow-ups/<id>`                  — get by id
///   * `PUT    /api/follow-ups/<id>`                  — update
///   * `POST   /api/follow-ups/<id>/voice/record`     — attach audio
///   * `POST   /api/follow-ups/<id>/voice/finalize`   — mark transcribable
///
/// PUT requests transit the wire as `POST` + `?_method=PUT` (Laravel
/// method-override convention). Writes auto-receive a fresh UUID v4
/// `Idempotency-Key`.
class FollowUpsClient {
  /// Construct with a reference to the shared [P2xClient].
  FollowUpsClient(this._client);

  final P2xClient _client;

  /// Header name for the idempotency key the SDK sends on writes.
  static const String _idempotencyHeader = 'Idempotency-Key';

  /// `GET /api/follow-ups?patient_id=<id>&status=<status>` — list
  /// follow-ups visible to the caller, optionally filtered.
  Future<List<FollowUp>> list({String? patientId, String? status}) {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/follow-ups',
        queryParameters: <String, dynamic>{
          if (patientId != null) 'patient_id': patientId,
          if (status != null) 'status': status,
        },
      );
      final body = response.data ?? const <String, dynamic>{};
      final raw = body['data'];
      if (raw is! List) return const <FollowUp>[];
      return raw
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => FollowUp.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    });
  }

  /// `POST /api/follow-ups` — create a new follow-up.
  ///
  /// A fresh UUID v4 `Idempotency-Key` is auto-attached by the SDK's
  /// interceptor stack — pass [idempotencyKey] to override.
  Future<FollowUp> create({
    required int patientId,
    required int providerId,
    required DateTime dueAt,
    String status = 'pending',
    String? notes,
    String? idempotencyKey,
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/follow-ups',
        data: <String, dynamic>{
          'patient_id': patientId,
          'provider_id': providerId,
          'due_at': dueAt.toIso8601String(),
          'status': status,
          if (notes != null) 'notes': notes,
        },
        options: _buildOptions(idempotencyKey: idempotencyKey),
      );
      return _decode(response.data, 'POST /follow-ups');
    });
  }

  /// `GET /api/follow-ups/<id>` — fetch one follow-up by primary key.
  Future<FollowUp> get(int id) {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/follow-ups/$id',
      );
      return _decode(response.data, 'GET /follow-ups/$id');
    });
  }

  /// `PUT /api/follow-ups/<id>` — update an existing follow-up.
  ///
  /// Only the fields you pass are forwarded (sparse update). The PUT
  /// travels as `POST /api/follow-ups/<id>?_method=PUT` per the
  /// Laravel method-override convention; callers don't care.
  Future<FollowUp> update(
    int id, {
    DateTime? dueAt,
    String? status,
    String? notes,
  }) {
    return _client.request(() async {
      final data = <String, dynamic>{
        if (dueAt != null) 'due_at': dueAt.toIso8601String(),
        if (status != null) 'status': status,
        if (notes != null) 'notes': notes,
      };
      final response = await _client.dio.put<Map<String, dynamic>>(
        '/follow-ups/$id',
        data: data,
      );
      return _decode(response.data, 'PUT /follow-ups/$id');
    });
  }

  /// `POST /api/follow-ups/<id>/voice/record` — attach a recorded
  /// audio note to a follow-up.
  ///
  /// The patient app uploads the recording to its own CDN (e.g. a
  /// signed S3 URL) and then calls this endpoint with the resulting
  /// [audioUrl] plus the [duration]. The server stores the URL and
  /// length and updates the follow-up. The [duration] is serialized
  /// as integer seconds.
  ///
  /// A fresh UUID v4 `Idempotency-Key` is auto-attached by the SDK's
  /// interceptor stack — pass [idempotencyKey] to override.
  Future<FollowUp> recordVoice(
    int id, {
    required String audioUrl,
    required Duration duration,
    String? idempotencyKey,
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/follow-ups/$id/voice/record',
        data: <String, dynamic>{
          'audio_url': audioUrl,
          'duration_seconds': duration.inSeconds,
        },
        options: _buildOptions(idempotencyKey: idempotencyKey),
      );
      return _decode(response.data, 'POST /follow-ups/$id/voice/record');
    });
  }

  /// `POST /api/follow-ups/<id>/voice/finalize` — mark the attached
  /// voice note as ready for transcription. Idempotent server-side.
  ///
  /// A fresh UUID v4 `Idempotency-Key` is auto-attached by the SDK's
  /// interceptor stack.
  Future<FollowUp> finalizeVoice(int id) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/follow-ups/$id/voice/finalize',
      );
      return _decode(response.data, 'POST /follow-ups/$id/voice/finalize');
    });
  }

  FollowUp _decode(Map<String, dynamic>? body, String label) {
    final data = (body ?? const <String, dynamic>{})['data'];
    if (data is! Map<String, dynamic>) {
      throw StateError('$label returned no "data" object.');
    }
    return FollowUp.fromJson(data);
  }

  Options? _buildOptions({String? idempotencyKey}) {
    if (idempotencyKey == null || idempotencyKey.isEmpty) return null;
    return Options(
      headers: <String, dynamic>{_idempotencyHeader: idempotencyKey},
    );
  }
}
