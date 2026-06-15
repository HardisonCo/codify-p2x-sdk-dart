import '../client/p2x_client.dart';

/// Client for the **Step-4 step-claim** sub-surface of the Deal Wizard —
/// `/api/deals/{deal_id}/steps/{step_idx}/*` (`Modules/Deals`,
/// `DealStepController`).
///
/// During execution, each pipeline step is claimed by exactly one actor (an
/// agent, a human, or an external partner) so concurrent workers don't
/// double-pick it. The lifecycle is: [claim] → [submit] (or [release]).
///
/// **Contract notes (derived from `Modules/Deals`, not invented):**
///   * Deal ids are **UUID strings**; step indices are integers.
///   * `claim` body = `{actor_ref}`; returns `{claim_token, expires_at}`.
///   * `submit` body = `{claim_token, result?}`; returns
///     `{ok, contract_validated}`.
///   * `release` body = `{claim_token, reason?}`; returns `{ok}`.
///   * `claim_token` must be a UUID (server-validated on submit/release).
class DealStepClient {
  /// Construct against an existing [P2xClient].
  DealStepClient(this._client);

  final P2xClient _client;

  /// POST `/deals/{deal_id}/steps/{step_idx}/claim` — claim the step for
  /// [actorRef]. Returns the claim envelope (`claim_token`, `expires_at`).
  /// A 409 `already_claimed` surfaces as an [ApiException] with status 409.
  Future<Map<String, dynamic>> claim({
    required String dealId,
    required int stepIdx,
    required String actorRef,
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/deals/$dealId/steps/$stepIdx/claim',
        data: <String, dynamic>{'actor_ref': actorRef},
      );
      return _body(response.data);
    });
  }

  /// POST `/deals/{deal_id}/steps/{step_idx}/submit` — submit evidence /
  /// result for a previously-claimed step. [claimToken] must match the token
  /// returned by [claim]. [result] is step-template-specific. Returns
  /// `{ok, contract_validated}`.
  Future<Map<String, dynamic>> submit({
    required String dealId,
    required int stepIdx,
    required String claimToken,
    Map<String, dynamic>? result,
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/deals/$dealId/steps/$stepIdx/submit',
        data: <String, dynamic>{
          'claim_token': claimToken,
          if (result != null) 'result': result,
        },
      );
      return _body(response.data);
    });
  }

  /// POST `/deals/{deal_id}/steps/{step_idx}/release` — release a claimed
  /// step back to the pool. [claimToken] must match the active claim.
  /// [reason] is optional, free-form. Returns `{ok: true}`.
  Future<Map<String, dynamic>> release({
    required String dealId,
    required int stepIdx,
    required String claimToken,
    String? reason,
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/deals/$dealId/steps/$stepIdx/release',
        data: <String, dynamic>{
          'claim_token': claimToken,
          if (reason != null) 'reason': reason,
        },
      );
      return _body(response.data);
    });
  }

  Map<String, dynamic> _body(Map<String, dynamic>? body) {
    if (body == null) {
      throw StateError('Empty step response');
    }
    return body;
  }
}
