import 'package:codify_p2x_sdk/src/client/p2x_client.dart';
import 'package:codify_p2x_sdk/src/modules/verification_models.dart';

/// Per-domain client for the **Verifications** module.
///
/// Verifications record credential documents users have submitted for
/// review — IBD's primary Tier-1 use is doctor license uploads (medical
/// license, DEA, malpractice insurance). The document itself is uploaded
/// to object storage out-of-band; this endpoint only records the URL
/// plus per-document-type metadata that the operator console uses for
/// review.
class VerificationClient {
  /// Construct with a reference to the shared [P2xClient].
  VerificationClient(this._client);

  final P2xClient _client;

  /// `GET /api/verifications` — list verification submissions belonging
  /// to the current user (scoped server-side by the bearer token +
  /// `X-Domain` header).
  Future<List<Verification>> list() {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/verifications',
      );
      final body = response.data ?? const <String, dynamic>{};
      final raw = body['data'];
      if (raw is! List) return const <Verification>[];
      return raw
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => Verification.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    });
  }

  /// `POST /api/verifications` — submit a new Verification.
  ///
  /// [documentType] selects the credential kind — e.g. `medical_license`,
  /// `dea`, `malpractice_insurance`. [documentUrl] points at the
  /// already-uploaded document on object storage. [metadata] is a
  /// free-form structured map (license number, expiry, issuing state,
  /// etc.) — schema is per-document-type and validated server-side.
  ///
  /// The SDK's `IdempotencyInterceptor` auto-generates an
  /// `Idempotency-Key` header on this write so retries of the same
  /// in-flight request are de-duped by the backend's Redis middleware.
  Future<Verification> create({
    required String documentType,
    required String documentUrl,
    required Map<String, dynamic> metadata,
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/verifications',
        data: <String, dynamic>{
          'document_type': documentType,
          'document_url': documentUrl,
          'metadata': metadata,
        },
      );
      final body = response.data ?? const <String, dynamic>{};
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError('POST /verifications returned no "data" object.');
      }
      return Verification.fromJson(data);
    });
  }

  /// `GET /api/verifications/<id>` — fetch one Verification by primary
  /// key.
  ///
  /// Throws `NotFoundException` if the row does not exist or is not
  /// visible to the current user.
  Future<Verification> show(int id) {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/verifications/$id',
      );
      final body = response.data ?? const <String, dynamic>{};
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError(
          'GET /verifications/$id returned no "data" object.',
        );
      }
      return Verification.fromJson(data);
    });
  }

  /// `PUT /api/verifications/<id>` — update a Verification (typically to
  /// resubmit a new [documentUrl] or [metadata] after a rejection).
  ///
  /// Any subset of [documentUrl], [metadata], or [status] may be passed.
  /// The SDK's `MethodOverrideInterceptor` rewrites the PUT to
  /// POST + `?_method=PUT` for Laravel compatibility, and
  /// `IdempotencyInterceptor` adds an `Idempotency-Key` header
  /// automatically.
  Future<Verification> update(
    int id, {
    String? documentUrl,
    Map<String, dynamic>? metadata,
    String? status,
  }) {
    return _client.request(() async {
      final response = await _client.dio.put<Map<String, dynamic>>(
        '/verifications/$id',
        data: <String, dynamic>{
          if (documentUrl != null) 'document_url': documentUrl,
          if (metadata != null) 'metadata': metadata,
          if (status != null) 'status': status,
        },
      );
      final body = response.data ?? const <String, dynamic>{};
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError(
          'PUT /verifications/$id returned no "data" object.',
        );
      }
      return Verification.fromJson(data);
    });
  }
}
