import 'package:dio/dio.dart';
import 'package:meta/meta.dart';

import 'package:codify_p2x_sdk/src/client/p2x_client.dart';
import 'package:codify_p2x_sdk/src/modules/assessments_models.dart';

/// Per-domain client for the **Assessments / Responses** module.
///
/// On the server every "thing the user did" is persisted as a Response
/// against a Survey. NIO writes one Response per food scan; MOB writes
/// one per workout; IBD writes symptom check-ins. This client is the
/// thin Dart facade over the two endpoints involved.
class AssessmentsClient {
  /// Construct with a reference to the shared [P2xClient].
  AssessmentsClient(this._client);

  final P2xClient _client;

  /// Header name for the idempotency key the SDK sends on writes. Falls
  /// through Agent A's `IdempotencyInterceptor` unchanged when present.
  static const String _idempotencyHeader = 'Idempotency-Key';

  /// `POST /api/response/store` — persist a new [AssessmentResponse].
  ///
  /// The server returns the canonical row including its assigned `id`.
  /// Pass [idempotencyKey] to dedupe double-submits — the scan UUID on
  /// the device is a natural choice. The SDK forwards the value through
  /// to the `Idempotency-Key` request header.
  Future<AssessmentResponse> storeResponse({
    required String surveyKey,
    required Map<String, dynamic> payload,
    String? idempotencyKey,
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/response/store',
        data: <String, dynamic>{
          'survey_key': surveyKey,
          'payload': payload,
        },
        options: _buildOptions(idempotencyKey: idempotencyKey),
      );
      final body = response.data ?? const <String, dynamic>{};
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError('POST /response/store returned no "data" object.');
      }
      return AssessmentResponse.fromJson(data);
    });
  }

  /// `GET /api/responses?source=<source>&limit=<n>&page=<n>` — list
  /// stored Responses, optionally filtered by [source]
  /// (e.g. `nio-scan`, `phm-lab-result`).
  Future<AssessmentResponseList> list({
    String? source,
    int limit = 50,
    int page = 1,
  }) {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/responses',
        queryParameters: <String, dynamic>{
          if (source != null) 'source': source,
          'limit': limit,
          'page': page,
        },
      );
      final body = response.data ?? const <String, dynamic>{};
      return AssessmentResponseList.fromJson(body);
    });
  }

  Options? _buildOptions({String? idempotencyKey}) {
    if (idempotencyKey == null || idempotencyKey.isEmpty) {
      return null;
    }
    return Options(
      headers: <String, dynamic>{_idempotencyHeader: idempotencyKey},
    );
  }

  /// Test seam: returns the same [Options] object the client uses
  /// internally for a given [idempotencyKey]. Test-only — the production
  /// path goes through [_buildOptions]. Exposed because the test surface
  /// asserts the precise header shape the SDK emits.
  @visibleForTesting
  static Options idempotencyOptionsForTest(String idempotencyKey) {
    return Options(
      headers: <String, dynamic>{_idempotencyHeader: idempotencyKey},
    );
  }
}
