import 'package:dio/dio.dart';

import '../client/p2x_client.dart';
import 'deals_models.dart';

/// Client for the YCaaS **Deal Wizard** — the `/api/wizard/deal/*` surface
/// (`Modules/Deals`).
///
/// Drives a deal through the Five-Step Wizard lifecycle, plus the F1/F2
/// intake steps (metadata → details → files → path → submit) that gather
/// structured input before the deal transitions into `awaiting_compute` (the
/// Stripe Compute deposit gate). The step-claim sub-surface
/// (`/deals/{deal_id}/steps/{step_idx}/*`) is exposed by
/// [DealStepClient].
///
/// **Contract notes (derived from `Modules/Deals`, not invented):**
///   * Deal ids are **UUID strings** (`deal_instances.id`).
///   * The wizard endpoints return the deal body **flat** — `DealResource`
///     merged with `{deal_id, state}` — *not* wrapped in the standard
///     `{success, message, data}` envelope. [Deal.fromJson] decodes the
///     top-level body directly.
///   * `define` accepts only `statement` (+ optional `tld`). `subproject_id`
///     is resolved server-side from the X-Domain header and is **ignored**
///     if sent, so this client never sends it.
///   * `metadata`, `details`, and `path` are `PATCH` (rewritten to
///     `POST …?_method=PATCH` by [P2xClient]'s method-override interceptor);
///     `files` is `POST` multipart; `files/{file_id}` is `DELETE`.
class DealsClient {
  /// Construct against an existing [P2xClient].
  DealsClient(this._client);

  final P2xClient _client;

  // ─── Step 1 — define + read ────────────────────────────────────────────

  /// POST `/wizard/deal/define` — open a new deal from a [statement].
  ///
  /// [tld] is optional and accepts either the bare (`healthcare`) or prefixed
  /// (`codify.healthcare`) form; the server normalises it. When omitted the
  /// server resolves the tld from the X-Domain tenant.
  Future<Deal> define({
    required String statement,
    String? tld,
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/wizard/deal/define',
        data: <String, dynamic>{
          'statement': statement,
          if (tld != null) 'tld': tld,
        },
      );
      return Deal.fromJson(_body(response.data));
    });
  }

  /// GET `/wizard/deal/{deal_id}/status` — the full [Deal] snapshot.
  Future<Deal> status({required String dealId}) {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/wizard/deal/$dealId/status',
      );
      return Deal.fromJson(_body(response.data));
    });
  }

  /// GET `/wizard/deal/{deal_id}/events` — the append-only audit log,
  /// paginated. [perPage] is clamped server-side to 1..200 (default 50).
  Future<DealEventsPage> events({
    required String dealId,
    int? perPage,
  }) {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/wizard/deal/$dealId/events',
        queryParameters: <String, dynamic>{
          if (perPage != null) 'per_page': perPage,
        },
      );
      return DealEventsPage.fromJson(_body(response.data));
    });
  }

  // ─── Step 1 continuation / Step 2 — codification ───────────────────────

  /// POST `/wizard/deal/{deal_id}/required-info` — answer the
  /// codification pre-questions. [answers] is a `{key: value}` map; every
  /// declared required key must be present. Advances `analyzing → codified`.
  Future<Deal> requiredInfo({
    required String dealId,
    required Map<String, dynamic> answers,
  }) {
    return _postDeal(
      '/wizard/deal/$dealId/required-info',
      <String, dynamic>{'answers': answers},
    );
  }

  /// POST `/wizard/deal/{deal_id}/codify` — generate solutions, stakeholders
  /// and financing. Empty body; the deal must already be in `codified`.
  Future<Deal> codify({required String dealId}) =>
      _postDeal('/wizard/deal/$dealId/codify', null);

  /// POST `/wizard/deal/{deal_id}/select-solution` — pick one of the
  /// generated solutions by 0-based [solutionIdx].
  Future<Deal> selectSolution({
    required String dealId,
    required int solutionIdx,
  }) =>
      _postDeal(
        '/wizard/deal/$dealId/select-solution',
        <String, dynamic>{'solution_idx': solutionIdx},
      );

  // ─── Step 3/4 — setup + start ──────────────────────────────────────────

  /// POST `/wizard/deal/{deal_id}/setup` — materialise the pipeline steps and
  /// advance `codified → setup`. Empty body.
  Future<Deal> setup({required String dealId}) =>
      _postDeal('/wizard/deal/$dealId/setup', null);

  /// POST `/wizard/deal/{deal_id}/start` — begin execution, advancing
  /// `setup → executing`. Empty body.
  Future<Deal> start({required String dealId}) =>
      _postDeal('/wizard/deal/$dealId/start', null);

  // ─── F1/F2 intake steps ────────────────────────────────────────────────

  /// PATCH `/wizard/deal/{deal_id}/metadata` — intake step 1.
  ///
  /// [applicantType] must be one of `Builder`, `Organizer`, `Promoter`.
  /// [description] must be 50..5000 chars. [relatedIndustries] is optional.
  Future<Deal> patchMetadata({
    required String dealId,
    required String title,
    required String description,
    required String applicantType,
    List<dynamic>? relatedIndustries,
  }) {
    return _patchDeal(
      '/wizard/deal/$dealId/metadata',
      <String, dynamic>{
        'title': title,
        'description': description,
        'applicant_type': applicantType,
        if (relatedIndustries != null) 'related_industries': relatedIndustries,
      },
    );
  }

  /// PATCH `/wizard/deal/{deal_id}/details` — intake step 2.
  ///
  /// [budgetTier] must be one of `lt5k`, `lt30k`, `lt100k`, `gte100k`.
  /// [customerUserId], [startDate] and [endDate] are optional.
  Future<Deal> patchDetails({
    required String dealId,
    required String budgetTier,
    int? customerUserId,
    String? startDate,
    String? endDate,
  }) {
    return _patchDeal(
      '/wizard/deal/$dealId/details',
      <String, dynamic>{
        'budget_tier': budgetTier,
        if (customerUserId != null) 'customer_user_id': customerUserId,
        if (startDate != null) 'start_date': startDate,
        if (endDate != null) 'end_date': endDate,
      },
    );
  }

  /// POST (multipart) `/wizard/deal/{deal_id}/files` — intake step 3.
  ///
  /// Uploads a single [file] of [fileType] (`document`, `image`, or `logo`).
  /// Provide either a local [filePath] or in-memory [bytes] (with a
  /// [filename]). Returns the created [DealFile] (HTTP 201).
  Future<DealFile> uploadFile({
    required String dealId,
    required String fileType,
    String? filePath,
    List<int>? bytes,
    String? filename,
  }) {
    assert(
      (filePath != null) ^ (bytes != null),
      'Provide exactly one of filePath or bytes',
    );
    return _client.request(() async {
      final MultipartFile multipart;
      if (filePath != null) {
        multipart = await MultipartFile.fromFile(filePath, filename: filename);
      } else {
        multipart = MultipartFile.fromBytes(
          bytes!,
          filename: filename ?? 'upload',
        );
      }
      final formData = FormData.fromMap(<String, dynamic>{
        'file': multipart,
        'file_type': fileType,
      });
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/wizard/deal/$dealId/files',
        data: formData,
      );
      return DealFile.fromJson(_body(response.data));
    });
  }

  /// DELETE `/wizard/deal/{deal_id}/files/{file_id}` — un-attach a file.
  /// Idempotent — returns normally on a 204.
  Future<void> deleteFile({
    required String dealId,
    required int fileId,
  }) {
    return _client.request(() async {
      await _client.dio.delete<dynamic>(
        '/wizard/deal/$dealId/files/$fileId',
      );
    });
  }

  /// PATCH `/wizard/deal/{deal_id}/path` — intake step 4.
  ///
  /// [pathTier] must be one of `pink`, `green`, `blue`, `red`, `black`.
  Future<Deal> patchPath({
    required String dealId,
    required String pathTier,
  }) {
    return _patchDeal(
      '/wizard/deal/$dealId/path',
      <String, dynamic>{'path_tier': pathTier},
    );
  }

  /// POST `/wizard/deal/{deal_id}/submit` — intake step 5. Validates the
  /// prior intake steps then transitions the deal into `awaiting_compute`.
  /// Empty body.
  Future<Deal> submit({required String dealId}) =>
      _postDeal('/wizard/deal/$dealId/submit', null);

  /// POST `/wizard/deal/{deal_id}/compute-deposit` — mint a Stripe
  /// PaymentIntent for the F3 5-tier Compute deposit. [amountCents] must be
  /// one of `100`, `1000`, `10000`, `100000`, `1000000`. Returns the
  /// PaymentIntent client secret.
  Future<ComputeDeposit> computeDeposit({
    required String dealId,
    required int amountCents,
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/wizard/deal/$dealId/compute-deposit',
        data: <String, dynamic>{'amount_cents': amountCents},
      );
      return ComputeDeposit.fromJson(_body(response.data));
    });
  }

  // ─── Step 5 — verify ───────────────────────────────────────────────────

  /// POST `/wizard/deal/{deal_id}/verify/{execution_id}` — score the run.
  /// Empty body; returns a bespoke [DealVerificationResult] (not a [Deal]).
  Future<DealVerificationResult> verify({
    required String dealId,
    required int executionId,
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/wizard/deal/$dealId/verify/$executionId',
      );
      return DealVerificationResult.fromJson(_body(response.data));
    });
  }

  // ─── helpers ────────────────────────────────────────────────────────────

  Future<Deal> _postDeal(String path, Map<String, dynamic>? body) {
    return _client.request(() async {
      final response =
          await _client.dio.post<Map<String, dynamic>>(path, data: body);
      return Deal.fromJson(_body(response.data));
    });
  }

  Future<Deal> _patchDeal(String path, Map<String, dynamic> body) {
    return _client.request(() async {
      final response =
          await _client.dio.patch<Map<String, dynamic>>(path, data: body);
      return Deal.fromJson(_body(response.data));
    });
  }

  Map<String, dynamic> _body(Map<String, dynamic>? body) {
    if (body == null) {
      throw StateError('Empty deal response');
    }
    return body;
  }
}
