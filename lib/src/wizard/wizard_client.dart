import '../client/p2x_client.dart';
import 'wizard_models.dart';

/// The YCaaS Five-Step Wizard client.
///
/// Drives a deal through the canonical YCaaS lifecycle —
/// **define problem → codify solution → setup program → execute program →
/// verify outcome**. Most methods take a `protocol` (int) path param after
/// the initial [start] call returns it; deal-flavoured calls live on
/// [DealsClient].
///
/// The wizard surface is **fluid by design** — many step responses are
/// step-template-specific. Most methods return the inner `data` block as a
/// `Map<String, dynamic>` so the SDK doesn't need a release when the server
/// extends a step. The strongly-typed [WizardStartResponse] covers the only
/// response shape we depend on hard (`deal_id`, `state`).
class WizardClient {
  /// Construct against an existing [P2xClient].
  WizardClient(this._client);

  final P2xClient _client;

  // ─── Step 1: start ────────────────────────────────────────────────────────

  /// POST `/wizard/start` — entry point. Creates a fresh deal + protocol
  /// and seeds it with the user's [problem] statement and optional
  /// [metadata] (name, related_to, budget, time_frame, teammates, tools,
  /// customer, …).
  Future<WizardStartResponse> start({
    required String problem,
    String? category,
    Map<String, dynamic>? metadata,
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/wizard/start',
        data: <String, dynamic>{
          'problem': problem,
          if (category != null) 'category': category,
          if (metadata != null) 'metadata': metadata,
        },
      );
      return WizardStartResponse.fromJson(_data(response.data));
    });
  }

  // ─── State & navigation ───────────────────────────────────────────────────

  /// GET `/wizard/get-state/{protocol}` — full wizard state snapshot.
  Future<Map<String, dynamic>> getState({required int protocol}) {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/wizard/get-state/$protocol',
      );
      return _data(response.data);
    });
  }

  /// GET `/wizard/step-back/{protocol}` — undo the last forward transition.
  Future<Map<String, dynamic>> stepBack({required int protocol}) =>
      _getMap('/wizard/step-back/$protocol');

  /// POST `/wizard/codify/{protocol}` — advance the wizard one step. The
  /// payload contents are step-specific.
  Future<Map<String, dynamic>> codify({
    required int protocol,
    Map<String, dynamic>? payload,
  }) =>
      _postMap('/wizard/codify/$protocol', payload);

  // ─── Assessment ───────────────────────────────────────────────────────────

  /// GET `/wizard/get-required-roles/{protocol}`.
  Future<List<dynamic>> getRequiredRoles({required int protocol}) =>
      _getList('/wizard/get-required-roles/$protocol');

  /// GET `/wizard/assessment/questions/{protocol}`.
  Future<List<dynamic>> getAssessmentQuestions({required int protocol}) =>
      _getList('/wizard/assessment/questions/$protocol');

  /// GET `/wizard/assessment/answers/{protocol}`.
  Future<Map<String, dynamic>> getAssessmentAnswers({required int protocol}) =>
      _getMap('/wizard/assessment/answers/$protocol');

  // ─── Finances ─────────────────────────────────────────────────────────────

  /// GET `/wizard/finances/{protocol}`.
  Future<Map<String, dynamic>> getFinances({required int protocol}) =>
      _getMap('/wizard/finances/$protocol');

  /// POST `/wizard/set-finances/{protocol}` — write the budget / pricing
  /// payload for this protocol.
  Future<Map<String, dynamic>> setFinances({
    required int protocol,
    required Map<String, dynamic> payload,
  }) =>
      _postMap('/wizard/set-finances/$protocol', payload);

  // ─── Team & invitations ───────────────────────────────────────────────────

  /// GET `/wizard/team/roles-to-invite/{protocol}`.
  Future<List<dynamic>> getRolesToInvite({required int protocol}) =>
      _getList('/wizard/team/roles-to-invite/$protocol');

  /// POST `/wizard/find-members` — search the directory.
  Future<List<dynamic>> findMembers({
    required String search,
    int? roleId,
  }) async {
    final body = <String, dynamic>{
      'search': search,
      if (roleId != null) 'role_id': roleId,
    };
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/wizard/find-members',
        data: body,
      );
      final data = response.data?['data'];
      return data is List ? List<dynamic>.from(data) : const <dynamic>[];
    });
  }

  /// POST `/wizard/validate-email`. Returns `true` if [email] is valid + free.
  Future<bool> validateEmail({required String email}) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/wizard/validate-email',
        data: <String, dynamic>{'email': email},
      );
      final data = response.data?['data'];
      if (data is Map<String, dynamic> && data['valid'] is bool) {
        return data['valid'] as bool;
      }
      if (data is bool) return data;
      return false;
    });
  }

  /// POST `/wizard/invite-members/{protocol}`.
  Future<Map<String, dynamic>> inviteMembers({
    required int protocol,
    required List<Map<String, dynamic>> members,
  }) =>
      _postMap('/wizard/invite-members/$protocol', <String, dynamic>{
        'members': members,
      });

  // ─── Program data & preview ───────────────────────────────────────────────

  /// GET `/wizard/program-data/{protocol}`.
  Future<Map<String, dynamic>> getProgramData({required int protocol}) =>
      _getMap('/wizard/program-data/$protocol');

  /// POST `/wizard/confirm-preview/{protocol}`.
  Future<Map<String, dynamic>> confirmPreview({
    required int protocol,
    required Map<String, dynamic> payload,
  }) =>
      _postMap('/wizard/confirm-preview/$protocol', payload);

  /// POST `/wizard/set-agent/{protocol}`.
  Future<Map<String, dynamic>> setAgent({
    required int protocol,
    required int agentId,
  }) =>
      _postMap('/wizard/set-agent/$protocol', <String, dynamic>{
        'agent_id': agentId,
      });

  // ─── Account & profile ────────────────────────────────────────────────────

  /// POST `/wizard/confirm-account/{protocol}`.
  Future<Map<String, dynamic>> confirmAccount({
    required int protocol,
    required Map<String, dynamic> account,
  }) =>
      _postMap('/wizard/confirm-account/$protocol', account);

  /// POST `/wizard/confirm-code/{protocol}`.
  Future<Map<String, dynamic>> confirmCode({
    required int protocol,
    required String code,
  }) =>
      _postMap('/wizard/confirm-code/$protocol', <String, dynamic>{
        'code': code,
      });

  /// POST `/wizard/complete-profile/{protocol}`.
  Future<Map<String, dynamic>> completeProfile({
    required int protocol,
    required Map<String, dynamic> profile,
  }) =>
      _postMap('/wizard/complete-profile/$protocol', profile);

  /// POST `/wizard/creator-request/{protocol}`.
  Future<Map<String, dynamic>> sendCreatorRequest({
    required int protocol,
    required Map<String, dynamic> body,
  }) =>
      _postMap('/wizard/creator-request/$protocol', body);

  // ─── Stripe / publish / finalize ──────────────────────────────────────────

  /// GET `/wizard/connect-stripe/{protocol}` — returns the Stripe Connect URL.
  Future<String> connectStripe({required int protocol}) {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/wizard/connect-stripe/$protocol',
      );
      final data = response.data?['data'];
      if (data is Map<String, dynamic> && data['url'] is String) {
        return data['url'] as String;
      }
      if (data is String) return data;
      throw StateError('connect-stripe response missing URL');
    });
  }

  /// GET `/wizard/verify-stripe/{protocol}`.
  Future<Map<String, dynamic>> verifyStripe({required int protocol}) =>
      _getMap('/wizard/verify-stripe/$protocol');

  /// POST `/wizard/set-distribution-type/{protocol}`.
  Future<Map<String, dynamic>> setDistributionType({
    required int protocol,
    required String distributionType,
  }) =>
      _postMap('/wizard/set-distribution-type/$protocol', <String, dynamic>{
        'distribution_type': distributionType,
      });

  /// POST `/wizard/publish-program/{protocol}`.
  Future<Map<String, dynamic>> publishProgram({
    required int protocol,
    required Map<String, dynamic> settings,
  }) =>
      _postMap('/wizard/publish-program/$protocol', settings);

  /// POST `/wizard/invite-users/{protocol}`.
  Future<Map<String, dynamic>> inviteUsers({
    required int protocol,
    required List<dynamic> invites,
  }) =>
      _postMap('/wizard/invite-users/$protocol', <String, dynamic>{
        'invites': invites,
      });

  /// GET `/wizard/start-program/{protocol}` — begins program execution.
  Future<Map<String, dynamic>> startProgram({required int protocol}) =>
      _getMap('/wizard/start-program/$protocol');

  /// GET `/wizard/retry-creation/{protocol}` — re-attempts failed creation.
  Future<Map<String, dynamic>> retryCreation({required int protocol}) =>
      _getMap('/wizard/retry-creation/$protocol');

  /// GET `/wizard/finalization-state/{protocol}` — useful for polling.
  Future<Map<String, dynamic>> getFinalizationState({required int protocol}) =>
      _getMap('/wizard/finalization-state/$protocol');

  /// GET `/wizard/public-program-created/{protocol}` — has the wizard
  /// produced a public-facing program yet?
  Future<bool> publicProgramCreated({required int protocol}) {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/wizard/public-program-created/$protocol',
      );
      final data = response.data?['data'];
      if (data is bool) return data;
      if (data is Map<String, dynamic> && data['created'] is bool) {
        return data['created'] as bool;
      }
      return false;
    });
  }

  // ─── helpers ──────────────────────────────────────────────────────────────

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
    if (body == null) throw StateError('Empty wizard response');
    final data = body['data'];
    if (data is Map<String, dynamic>) return data;
    if (data == null) return const <String, dynamic>{};
    throw StateError('Malformed wizard response — "data" is ${data.runtimeType}');
  }
}
