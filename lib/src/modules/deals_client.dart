import '../client/p2x_client.dart';
import 'deals_models.dart';

/// Client for the YCaaS deal lifecycle.
///
/// Covers `/wizard/deal/*` (lifecycle: define → required-info → codify →
/// select-solution → setup → start → verify) and the `/deals/{id}/steps/*`
/// step-claim surface.
class DealsClient {
  /// Construct against an existing [P2xClient].
  DealsClient(this._client);

  final P2xClient _client;

  /// POST `/wizard/deal/define` — open a new deal from a [statement].
  Future<Deal> define({
    required String statement,
    int? subprojectId,
    String? tld,
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/wizard/deal/define',
        data: <String, dynamic>{
          'statement': statement,
          if (subprojectId != null) 'subproject_id': subprojectId,
          if (tld != null) 'tld': tld,
        },
      );
      return Deal.fromJson(_data(response.data));
    });
  }

  /// GET `/wizard/deal/{deal_id}/status` — full snapshot.
  Future<Deal> status({required int dealId}) {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/wizard/deal/$dealId/status',
      );
      return Deal.fromJson(_data(response.data));
    });
  }

  /// GET `/wizard/deal/{deal_id}/events` — audit trail.
  Future<Map<String, dynamic>> events({
    required int dealId,
    int? perPage,
  }) {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/wizard/deal/$dealId/events',
        queryParameters: <String, dynamic>{
          if (perPage != null) 'per_page': perPage,
        },
      );
      return _data(response.data);
    });
  }

  /// POST `/wizard/deal/{deal_id}/required-info` — answer the codification
  /// pre-questions. Once answered, the server flips the deal to `codified`.
  Future<Deal> requiredInfo({
    required int dealId,
    required Map<String, dynamic> answers,
  }) {
    return _postDeal(
      '/wizard/deal/$dealId/required-info',
      <String, dynamic>{'answers': answers},
    );
  }

  /// POST `/wizard/deal/{deal_id}/codify` — generate solutions /
  /// stakeholders / financing. Empty body.
  Future<Deal> codify({required int dealId}) =>
      _postDeal('/wizard/deal/$dealId/codify', null);

  /// POST `/wizard/deal/{deal_id}/select-solution` — lock in a solution.
  Future<Deal> selectSolution({
    required int dealId,
    required int solutionIdx,
  }) =>
      _postDeal(
        '/wizard/deal/$dealId/select-solution',
        <String, dynamic>{'solution_idx': solutionIdx},
      );

  /// POST `/wizard/deal/{deal_id}/setup` — server builds `pipeline_steps[]`.
  Future<Deal> setup({required int dealId}) =>
      _postDeal('/wizard/deal/$dealId/setup', null);

  /// POST `/wizard/deal/{deal_id}/start` — kick off execution.
  Future<Deal> start({required int dealId}) =>
      _postDeal('/wizard/deal/$dealId/start', null);

  /// POST `/wizard/deal/{deal_id}/verify/{execution_id}` — score the run.
  Future<Deal> verify({
    required int dealId,
    required int executionId,
  }) =>
      _postDeal('/wizard/deal/$dealId/verify/$executionId', null);

  // ─── step-claim sub-surface ─────────────────────────────────────────────

  /// POST `/deals/{deal_id}/steps/{step_idx}/claim` — current user claims
  /// the step (so concurrent workers don't double-pick it).
  Future<Map<String, dynamic>> claimStep({
    required int dealId,
    required int stepIdx,
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/deals/$dealId/steps/$stepIdx/claim',
      );
      return _data(response.data);
    });
  }

  /// POST `/deals/{deal_id}/steps/{step_idx}/submit` — submit evidence /
  /// result. The body shape is step-template-specific.
  Future<Map<String, dynamic>> submitStep({
    required int dealId,
    required int stepIdx,
    required Map<String, dynamic> body,
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/deals/$dealId/steps/$stepIdx/submit',
        data: body,
      );
      return _data(response.data);
    });
  }

  /// POST `/deals/{deal_id}/steps/{step_idx}/release` — release a previously
  /// claimed step back to the pool.
  Future<Map<String, dynamic>> releaseStep({
    required int dealId,
    required int stepIdx,
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/deals/$dealId/steps/$stepIdx/release',
      );
      return _data(response.data);
    });
  }

  /// POST `/deals/{deal_id}/steps/{step_idx}/human-submit` — HITL-gated
  /// evidence submission (clinician approval, ops approval, etc.).
  Future<Map<String, dynamic>> humanSubmitStep({
    required int dealId,
    required int stepIdx,
    required Map<String, dynamic> body,
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/deals/$dealId/steps/$stepIdx/human-submit',
        data: body,
      );
      return _data(response.data);
    });
  }

  // ─── helpers ────────────────────────────────────────────────────────────

  Future<Deal> _postDeal(String path, Map<String, dynamic>? body) {
    return _client.request(() async {
      final response =
          await _client.dio.post<Map<String, dynamic>>(path, data: body);
      return Deal.fromJson(_data(response.data));
    });
  }

  Map<String, dynamic> _data(Map<String, dynamic>? body) {
    if (body == null) throw StateError('Empty deal response');
    final data = body['data'];
    if (data is Map<String, dynamic>) return data;
    if (data == null) return const <String, dynamic>{};
    throw StateError('Malformed deal response — "data" is ${data.runtimeType}');
  }
}
