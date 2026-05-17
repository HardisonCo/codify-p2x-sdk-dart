import 'package:dio/dio.dart';

import 'package:codify_p2x_sdk/src/client/p2x_client.dart';
import 'package:codify_p2x_sdk/src/modules/services_models.dart';

/// Per-domain client for the **Services** module.
///
/// Three endpoints power the patient-facing booking flow:
///
///   * `GET  /api/services/resolve`     — look up a [Service] by `subdomain`
///                                        or `slug`
///   * `GET  /api/services/<id>/slots`  — list available [Schedule] slots
///   * `POST /api/services/<id>/reserve` — reserve a slot → [ScheduleCall]
///
/// Mirrors the TS sibling `ServicesModuleApiClient`. `reserve` is a
/// write — the SDK's interceptor stack auto-attaches a fresh UUID v4
/// `Idempotency-Key` so re-tapping the patient's "Book" button never
/// double-reserves the same slot.
class ServicesClient {
  /// Construct with a reference to the shared [P2xClient].
  ServicesClient(this._client);

  final P2xClient _client;

  /// Header name for the idempotency key the SDK sends on writes.
  static const String _idempotencyHeader = 'Idempotency-Key';

  /// `GET /api/services/resolve` — look up a [Service] by either
  /// [subdomain] or [slug] (or both).
  ///
  /// At least one of the two should be supplied — the server validates
  /// and returns 404 if no matching Service exists.
  Future<Service> resolve({String? subdomain, String? slug}) {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/services/resolve',
        queryParameters: <String, dynamic>{
          if (subdomain != null) 'subdomain': subdomain,
          if (slug != null) 'slug': slug,
        },
      );
      final body = response.data ?? const <String, dynamic>{};
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError(
          'GET /services/resolve returned no "data" object.',
        );
      }
      return Service.fromJson(data);
    });
  }

  /// `GET /api/services/<id>/slots` — list available [Schedule] slots
  /// for the given Service.
  ///
  /// [from] / [to] optionally bound the search window. Server caps the
  /// returned page; pagination is server-driven.
  Future<List<Schedule>> slots(
    int id, {
    DateTime? from,
    DateTime? to,
  }) {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/services/$id/slots',
        queryParameters: <String, dynamic>{
          if (from != null) 'from': from.toUtc().toIso8601String(),
          if (to != null) 'to': to.toUtc().toIso8601String(),
        },
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

  /// `POST /api/services/<id>/reserve` — reserve a specific
  /// [Schedule] slot for the calling patient.
  ///
  /// Returns the freshly-created [ScheduleCall] (`pending` until the
  /// call actually connects). [metadata] forwards arbitrary extra
  /// fields (referral source, voucher code, etc.).
  ///
  /// A fresh UUID v4 `Idempotency-Key` is auto-attached by the SDK's
  /// interceptor stack — pass [idempotencyKey] to override (the
  /// device-side booking UUID is a natural choice).
  Future<ScheduleCall> reserve(
    int id, {
    required int scheduleId,
    Map<String, dynamic>? metadata,
    String? idempotencyKey,
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/services/$id/reserve',
        data: <String, dynamic>{
          'schedule_id': scheduleId,
          if (metadata != null) 'metadata': metadata,
        },
        options: _buildOptions(idempotencyKey: idempotencyKey),
      );
      final body = response.data ?? const <String, dynamic>{};
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError(
          'POST /services/$id/reserve returned no "data" object.',
        );
      }
      return ScheduleCall.fromJson(data);
    });
  }

  Options? _buildOptions({String? idempotencyKey}) {
    if (idempotencyKey == null || idempotencyKey.isEmpty) return null;
    return Options(
      headers: <String, dynamic>{_idempotencyHeader: idempotencyKey},
    );
  }
}
