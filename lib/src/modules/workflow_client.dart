import 'package:dio/dio.dart';

import 'package:openyc_flutter_sdk/src/client/interceptors/auth_interceptor.dart';
import 'package:openyc_flutter_sdk/src/client/p2x_client.dart';
import 'package:openyc_flutter_sdk/src/modules/workflow_models.dart';

/// Client for the **codify-pipeline** workflow surface.
///
/// The codify-pipeline is the AI-driven, multi-step interview that walks an
/// anonymous user through codifying a problem into a structured program.
/// Calls are keyed by a client-generated `session` string (5–40 chars). Most
/// routes are **public** — no Bearer required — and the server tracks state
/// against the session id alone.
///
/// `pipes/invoke` is the lower-level entry point for invoking a single named
/// "pipe" against a tenant. It requires authentication and a subproject id.
class WorkflowClient {
  /// Construct against an existing [P2xClient].
  WorkflowClient(this._client);

  final P2xClient _client;

  // ─── codify-pipeline (public) ──────────────────────────────────────────

  /// POST `/workflow/codify-pipeline/start` — kick off a new interview.
  ///
  /// Exactly one of [problem] or [url] must be supplied (the endpoint also
  /// accepts a file upload, which this method does not yet expose).
  /// [session] is a client-generated 5–40 char identifier. [timezone] is the
  /// IANA timezone string.
  Future<Map<String, dynamic>> startPipeline({
    required String session,
    required String timezone,
    String? problem,
    String? url,
  }) {
    final body = <String, dynamic>{
      'session': session,
      'timezone': timezone,
      if (problem != null) 'problem': problem,
      if (url != null) 'url': url,
    };
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/workflow/codify-pipeline/start',
        data: body,
        options: _publicOptions(),
      );
      return _dataOrWhole(response.data);
    });
  }

  /// GET `/workflow/codify-pipeline/check-pipeline/{session}` — poll the
  /// pipeline state. Returns `progress`, `interaction`, and (when finished)
  /// `program`, `account`, `agent`.
  Future<Map<String, dynamic>> checkPipeline({required String session}) =>
      _publicGetMap('/workflow/codify-pipeline/check-pipeline/$session');

  /// GET `/workflow/codify-pipeline/stop/{session}` — abort + return final
  /// snapshot.
  Future<Map<String, dynamic>> stopPipeline({required String session}) =>
      _publicGetMap('/workflow/codify-pipeline/stop/$session');

  /// POST `/workflow/codify-pipeline/save-response` — answer the most-recent
  /// follow-up question.
  Future<Map<String, dynamic>> saveResponse({
    required String session,
    required String question,
    required String answer,
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/workflow/codify-pipeline/save-response',
        data: <String, dynamic>{
          'session': session,
          'question': question,
          'answer': answer,
        },
        options: _publicOptions(),
      );
      return _dataOrWhole(response.data);
    });
  }

  // ─── pipes (authenticated) ─────────────────────────────────────────────

  /// GET `/protocol/workflow/all` — list all workflow protocol integrations
  /// (requires Sanctum).
  Future<List<dynamic>> listWorkflowProtocols() {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/protocol/workflow/all',
      );
      final data = response.data?['data'];
      return data is List ? List<dynamic>.from(data) : const <dynamic>[];
    });
  }

  /// POST `/pipes/invoke` — invoke a named pipe against a tenant.
  ///
  /// [pipeName] must exist in `canonical_pipes`. [subprojectId] / [domain]
  /// identify the tenant. [params] is the pipe-specific payload.
  Future<Map<String, dynamic>> invokePipe({
    required String pipeName,
    required int subprojectId,
    required String domain,
    Map<String, dynamic> params = const <String, dynamic>{},
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/pipes/invoke',
        data: <String, dynamic>{
          'pipe_name': pipeName,
          'subproject_id': subprojectId,
          'domain': domain,
          'params': params,
        },
      );
      final body = response.data;
      if (body == null) {
        throw StateError('Empty body from /pipes/invoke');
      }
      // /pipes/invoke returns a flat top-level shape: {ok, pipe_name,
      // subproject_id, domain, result}. The server does NOT wrap it in
      // `data`. Return the whole body.
      return Map<String, dynamic>.from(body);
    });
  }

  // ─── admin: per-tenant pipe-config overrides (SuperAdmin) ──────────────

  /// GET `/admin/subproject/{subproject}/pipe-config` — list every
  /// canonical-pipe → provider override for [subprojectId]. **SuperAdmin
  /// only.** Unknown subproject → 404.
  Future<List<SubprojectPipeConfig>> listPipeConfigs({
    required int subprojectId,
  }) {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/admin/subproject/$subprojectId/pipe-config',
      );
      final data = response.data?['data'];
      if (data is! List) return const <SubprojectPipeConfig>[];
      return data
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (row) =>
                SubprojectPipeConfig.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
    });
  }

  /// POST `/admin/subproject/{subproject}/pipe-config` — create an override.
  ///
  /// [pipeName] is the canonical pipe name (must exist in `canonical_pipes`);
  /// [providerClass] is the FQN of a `CanonicalPipeProvider` subclass.
  /// Duplicate (subproject, pipe) inserts surface as a 422 keyed on
  /// `pipe_name`. **SuperAdmin only.** Returns the created row (HTTP 201).
  Future<SubprojectPipeConfig> createPipeConfig({
    required int subprojectId,
    required String pipeName,
    required String providerClass,
    Map<String, dynamic>? settings,
    bool? isActive,
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/admin/subproject/$subprojectId/pipe-config',
        data: <String, dynamic>{
          'pipe_name': pipeName,
          'provider_class': providerClass,
          if (settings != null) 'settings': settings,
          if (isActive != null) 'is_active': isActive,
        },
      );
      return SubprojectPipeConfig.fromJson(_pipeConfigBody(response.data));
    });
  }

  /// PATCH `/admin/subproject/{subproject}/pipe-config/{id}` (rides
  /// `POST …?_method=PATCH`). At least one of [providerClass], [settings],
  /// or [isActive] must be supplied. Pass [clearProviderClass] to send an
  /// explicit `null` provider_class (clears the override, keeps the row).
  /// **SuperAdmin only.** Unknown id → 404.
  Future<SubprojectPipeConfig> updatePipeConfig({
    required int subprojectId,
    required int id,
    String? providerClass,
    bool clearProviderClass = false,
    Map<String, dynamic>? settings,
    bool? isActive,
  }) {
    return _client.request(() async {
      final body = <String, dynamic>{
        if (clearProviderClass)
          'provider_class': null
        else if (providerClass != null)
          'provider_class': providerClass,
        if (settings != null) 'settings': settings,
        if (isActive != null) 'is_active': isActive,
      };
      final response = await _client.dio.patch<Map<String, dynamic>>(
        '/admin/subproject/$subprojectId/pipe-config/$id',
        data: body,
      );
      return SubprojectPipeConfig.fromJson(_pipeConfigBody(response.data));
    });
  }

  /// DELETE `/admin/subproject/{subproject}/pipe-config/{id}` — remove the
  /// override entirely; subsequent lookups fall back to the canonical
  /// default chain. **SuperAdmin only.** Returns `true` on success. Unknown
  /// id → 404.
  Future<bool> deletePipeConfig({
    required int subprojectId,
    required int id,
  }) {
    return _client.request(() async {
      final response = await _client.dio.delete<Map<String, dynamic>>(
        '/admin/subproject/$subprojectId/pipe-config/$id',
      );
      return response.data?['deleted'] == true;
    });
  }

  // ─── helpers ───────────────────────────────────────────────────────────

  /// The pipe-config admin store/update endpoints return the resource
  /// wrapped in the standard `{data: …}` envelope.
  Map<String, dynamic> _pipeConfigBody(Map<String, dynamic>? body) {
    if (body == null) throw StateError('Empty pipe-config response');
    final data = body['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return Map<String, dynamic>.from(body);
  }

  Future<Map<String, dynamic>> _publicGetMap(String path) {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        path,
        options: _publicOptions(),
      );
      return _dataOrWhole(response.data);
    });
  }

  Map<String, dynamic> _dataOrWhole(Map<String, dynamic>? body) {
    if (body == null) throw StateError('Empty workflow response');
    final data = body['data'];
    if (data is Map<String, dynamic>) return data;
    // Codify-pipeline routes sometimes return a flat shape (no envelope).
    return Map<String, dynamic>.from(body);
  }

  Options _publicOptions() {
    return Options(
      extra: <String, dynamic>{
        AuthInterceptor.skipAuthExtra: true,
      },
    );
  }
}
