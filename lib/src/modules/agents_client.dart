import 'package:dio/dio.dart';

import '../client/interceptors/auth_interceptor.dart';
import '../client/p2x_client.dart';
import 'agents_models.dart';

/// Client for the AI Agents surface — full CRUD on agent records, lifecycle
/// transitions, protocol execution, and the public intelligent intent
/// routing endpoints.
///
/// Most methods return passthrough `Map<String, dynamic>` for the agent
/// payload. The strongly-typed shape lives in the API's `AgentResource` /
/// `AgentExecutionResource` and varies per agent type — flexibility wins.
class AgentsClient {
  /// Construct against an existing [P2xClient].
  AgentsClient(this._client);

  final P2xClient _client;

  // ─── CRUD (authenticated) ──────────────────────────────────────────────

  /// GET `/agents`.
  Future<List<dynamic>> list() => _getList('/agents');

  /// POST `/agents`.
  Future<Map<String, dynamic>> create({
    required String name,
    required String type,
    String? description,
    List<String>? capabilities,
    String? model,
    double? temperature,
    int? maxTokens,
    String? systemPrompt,
    Map<String, dynamic>? metadata,
  }) =>
      _postMap('/agents', <String, dynamic>{
        'name': name,
        'type': type,
        if (description != null) 'description': description,
        if (capabilities != null) 'capabilities': capabilities,
        if (model != null) 'model': model,
        if (temperature != null) 'temperature': temperature,
        if (maxTokens != null) 'max_tokens': maxTokens,
        if (systemPrompt != null) 'system_prompt': systemPrompt,
        if (metadata != null) 'metadata': metadata,
      });

  /// GET `/agents/{uuid}`.
  Future<Map<String, dynamic>> show({required String uuid}) =>
      _getMap('/agents/$uuid');

  /// PUT `/agents/{uuid}` (rides POST + `_method=put`).
  Future<Map<String, dynamic>> update({
    required String uuid,
    Map<String, dynamic>? patch,
  }) {
    return _client.request(() async {
      final response = await _client.dio.put<Map<String, dynamic>>(
        '/agents/$uuid',
        data: patch ?? const <String, dynamic>{},
      );
      return _data(response.data);
    });
  }

  /// DELETE `/agents/{uuid}`.
  Future<void> destroy({required String uuid}) {
    return _client.request(() async {
      await _client.dio.delete<Map<String, dynamic>>('/agents/$uuid');
    });
  }

  // ─── Lifecycle ─────────────────────────────────────────────────────────

  /// POST `/agents/{uuid}/activate`.
  Future<Map<String, dynamic>> activate({required String uuid}) =>
      _postMap('/agents/$uuid/activate', null);

  /// POST `/agents/{uuid}/deactivate`.
  Future<Map<String, dynamic>> deactivate({required String uuid}) =>
      _postMap('/agents/$uuid/deactivate', null);

  /// POST `/agents/{uuid}/clone`.
  Future<Map<String, dynamic>> clone({
    required String uuid,
    required String name,
  }) =>
      _postMap('/agents/$uuid/clone', <String, dynamic>{'name': name});

  // ─── Tools ─────────────────────────────────────────────────────────────

  /// POST `/agents/{uuid}/tools/{tool}`.
  Future<Map<String, dynamic>> addTool({
    required String uuid,
    required String tool,
  }) =>
      _postMap('/agents/$uuid/tools/$tool', null);

  /// DELETE `/agents/{uuid}/tools/{tool}`.
  Future<void> removeTool({
    required String uuid,
    required String tool,
  }) {
    return _client.request(() async {
      await _client.dio.delete<Map<String, dynamic>>(
        '/agents/$uuid/tools/$tool',
      );
    });
  }

  // ─── Protocol execution ────────────────────────────────────────────────

  /// POST `/agents/execute-protocol`.
  Future<Map<String, dynamic>> executeProtocol({
    required int protocolId,
    String? agentId,
    List<Map<String, dynamic>>? input,
  }) =>
      _postMap('/agents/execute-protocol', <String, dynamic>{
        'protocol_id': protocolId,
        if (agentId != null) 'agent_id': agentId,
        if (input != null) 'input': input,
      });

  /// POST `/agents/resume-execution`.
  Future<Map<String, dynamic>> resumeExecution({
    required int executionId,
    required List<Map<String, dynamic>> input,
  }) =>
      _postMap('/agents/resume-execution', <String, dynamic>{
        'execution_id': executionId,
        'input': input,
      });

  /// GET `/agents/{uuid}/executions`.
  Future<List<dynamic>> executions({required String uuid}) =>
      _getList('/agents/$uuid/executions');

  /// GET `/agents/{uuid}/statistics`.
  Future<Map<String, dynamic>> statistics({required String uuid}) =>
      _getMap('/agents/$uuid/statistics');

  /// GET `/protocol/agents/all`.
  Future<List<dynamic>> listAgentProtocols() =>
      _getList('/protocol/agents/all');

  // ─── Resource owner wizard (sys/ "for-others" onboarding) ──────────────

  /// POST `/wizard/resource-owner` — persist a new resource listing in
  /// `draft` (Phase 3.J). The tenant subproject is resolved server-side from
  /// the X-Domain header.
  ///
  /// [owner] is `{name, contact}`; [listing] is `{listing_type, name,
  /// description, metadata}`; [autoRules] is the optional Phase 3.K DSL blob
  /// (persisted verbatim).
  Future<ResourceListingDraft> createResourceListing({
    required Map<String, dynamic> owner,
    required Map<String, dynamic> listing,
    Map<String, dynamic>? autoRules,
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/wizard/resource-owner',
        data: <String, dynamic>{
          'owner': owner,
          'listing': listing,
          if (autoRules != null) 'auto_rules': autoRules,
        },
      );
      return ResourceListingDraft.fromJson(_data(response.data));
    });
  }

  /// POST `/wizard/resource-owner/{listing}/activate` — spawn the L3 resource
  /// agent and flip the listing `draft → active`. A listing outside the
  /// current tenant → 404; a non-draft listing → 422.
  Future<ResourceListingActivation> activateResourceListing({
    required int listingId,
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/wizard/resource-owner/$listingId/activate',
      );
      return ResourceListingActivation.fromJson(_data(response.data));
    });
  }

  /// POST `/wizard/resource-owner/{listing}/claim` — Staffing v2: a worker
  /// claims a market gig slot. Flag-gated: 404 when staffing v2 is off for
  /// the tenant. When the auto-rules escalate, the response is HTTP 202 with
  /// [ResourceListingClaim.isEscalated] true; an auto-rules reject → 422.
  ///
  /// [onBehalfOfUserId] is honoured only for machine (`subproject:writer`)
  /// principals — codify-careers' server-to-server claim-back; ignored for
  /// every other caller. [rateAsked] feeds the auto-rules proposal.
  Future<ResourceListingClaim> claimResourceListing({
    required int listingId,
    int? onBehalfOfUserId,
    num? rateAsked,
  }) {
    return _client.request(() async {
      final body = <String, dynamic>{
        if (onBehalfOfUserId != null) 'on_behalf_of_user_id': onBehalfOfUserId,
        if (rateAsked != null) 'rate_asked': rateAsked,
      };
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/wizard/resource-owner/$listingId/claim',
        data: body.isEmpty ? null : body,
      );
      return ResourceListingClaim.fromJson(_data(response.data));
    });
  }

  // ─── Intelligent intent routing (public) ───────────────────────────────

  /// POST `/agents/intelligent/intent/process` — classify an intent, identify
  /// entities, and return a routing suggestion. **Public** — no Bearer.
  Future<Map<String, dynamic>> processIntent({
    required String intent,
    Map<String, dynamic>? context,
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/agents/intelligent/intent/process',
        data: <String, dynamic>{
          'intent': intent,
          if (context != null) 'context': context,
        },
        options: _publicOptions(),
      );
      return Map<String, dynamic>.from(response.data ?? <String, dynamic>{});
    });
  }

  /// POST `/agents/intelligent/intent/batch` — classify up to 100 intents.
  /// **Public**.
  Future<Map<String, dynamic>> batchProcessIntent({
    required List<String> intents,
    Map<String, dynamic>? context,
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/agents/intelligent/intent/batch',
        data: <String, dynamic>{
          'intents': intents,
          if (context != null) 'context': context,
        },
        options: _publicOptions(),
      );
      return Map<String, dynamic>.from(response.data ?? <String, dynamic>{});
    });
  }

  /// POST `/agents/intelligent/entity/identify` — name → regulatory agency.
  /// **Public**.
  Future<Map<String, dynamic>> identifyEntity({required String entity}) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/agents/intelligent/entity/identify',
        data: <String, dynamic>{'entity': entity},
        options: _publicOptions(),
      );
      return Map<String, dynamic>.from(response.data ?? <String, dynamic>{});
    });
  }

  /// POST `/agents/intelligent/search` — search agents by capability,
  /// agency, state, type. **Public**.
  Future<Map<String, dynamic>> searchAgents({
    String? capability,
    String? agency,
    String? state,
    String? type,
    int limit = 10,
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/agents/intelligent/search',
        data: <String, dynamic>{
          if (capability != null) 'capability': capability,
          if (agency != null) 'agency': agency,
          if (state != null) 'state': state,
          if (type != null) 'type': type,
          'limit': limit,
        },
        options: _publicOptions(),
      );
      return Map<String, dynamic>.from(response.data ?? <String, dynamic>{});
    });
  }

  /// GET `/agents/intelligent/statistics`. **Public**.
  Future<Map<String, dynamic>> intelligentStatistics() {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/agents/intelligent/statistics',
        options: _publicOptions(),
      );
      return Map<String, dynamic>.from(response.data ?? <String, dynamic>{});
    });
  }

  // ─── helpers ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _getMap(String path) {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(path);
      return _data(response.data);
    });
  }

  Future<List<dynamic>> _getList(String path) {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(path);
      final data = response.data?['data'];
      return data is List ? List<dynamic>.from(data) : const <dynamic>[];
    });
  }

  Future<Map<String, dynamic>> _postMap(
    String path,
    Map<String, dynamic>? body,
  ) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        path,
        data: body,
      );
      return _data(response.data);
    });
  }

  Map<String, dynamic> _data(Map<String, dynamic>? body) {
    if (body == null) throw StateError('Empty agents response');
    final data = body['data'];
    if (data is Map<String, dynamic>) return data;
    if (data == null) return const <String, dynamic>{};
    throw StateError('Malformed agents response — "data" is ${data.runtimeType}');
  }

  Options _publicOptions() {
    return Options(
      extra: <String, dynamic>{
        AuthInterceptor.skipAuthExtra: true,
      },
    );
  }
}
