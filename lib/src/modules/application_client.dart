import 'package:ycaas_flutter_sdk/src/client/p2x_client.dart';
import 'package:ycaas_flutter_sdk/src/modules/application_models.dart';

/// Per-domain client for the **Applications** module.
///
/// Applications are multi-step submissions a user makes to a subproject —
/// the primary Tier-1 use case is IBD's doctor-onboarding flow
/// (`type: 'doctor_request'`). The mobile app collects wizard answers
/// (specialty, license number, NPI, etc.), the IBD Node backend forwards
/// the final payload to `POST /api/applications`, and the operator
/// console drives the row through `draft → submitted → approved /
/// rejected`.
class ApplicationClient {
  /// Construct with a reference to the shared [P2xClient].
  ApplicationClient(this._client);

  final P2xClient _client;

  /// `GET /api/applications` — list applications belonging to the current
  /// user (scoped server-side by the bearer token + `X-Domain` header).
  Future<List<Application>> list() {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/applications',
      );
      final body = response.data ?? const <String, dynamic>{};
      final raw = body['data'];
      if (raw is! List) return const <Application>[];
      return raw
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => Application.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    });
  }

  /// `POST /api/applications` — submit a new Application.
  ///
  /// [type] is the application kind — e.g. `doctor_request`,
  /// `patient_intake`. [payload] is the free-form structured submission
  /// body (validated server-side per type).
  ///
  /// The SDK's `IdempotencyInterceptor` auto-generates an
  /// `Idempotency-Key` header on this write so retries of the same
  /// in-flight request are de-duped by the backend's Redis middleware.
  Future<Application> create({
    required String type,
    required Map<String, dynamic> payload,
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/applications',
        data: <String, dynamic>{
          'type': type,
          'payload': payload,
        },
      );
      final body = response.data ?? const <String, dynamic>{};
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError('POST /applications returned no "data" object.');
      }
      return Application.fromJson(data);
    });
  }

  /// `GET /api/applications/<id>` — fetch one Application by primary key.
  ///
  /// Throws `NotFoundException` if the row does not exist or is not
  /// visible to the current user.
  Future<Application> show(int id) {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/applications/$id',
      );
      final body = response.data ?? const <String, dynamic>{};
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError('GET /applications/$id returned no "data" object.');
      }
      return Application.fromJson(data);
    });
  }

  /// `PUT /api/applications/<id>` — update a draft Application.
  ///
  /// Either [payload] or [status] (or both) may be supplied. The SDK's
  /// `MethodOverrideInterceptor` rewrites the PUT to POST + `?_method=PUT`
  /// for Laravel compatibility, and `IdempotencyInterceptor` adds an
  /// `Idempotency-Key` header automatically.
  Future<Application> update(
    int id, {
    Map<String, dynamic>? payload,
    String? status,
  }) {
    return _client.request(() async {
      final response = await _client.dio.put<Map<String, dynamic>>(
        '/applications/$id',
        data: <String, dynamic>{
          if (payload != null) 'payload': payload,
          if (status != null) 'status': status,
        },
      );
      final body = response.data ?? const <String, dynamic>{};
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError('PUT /applications/$id returned no "data" object.');
      }
      return Application.fromJson(data);
    });
  }
}
