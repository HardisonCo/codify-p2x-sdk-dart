import 'package:meta/meta.dart';

/// A YCaaS **Deal** — the persistent unit driven through the Five-Step
/// Wizard lifecycle (**analyze → codify → setup → execute → verify**).
///
/// Decoded from the flat JSON body returned by the `/wizard/deal/*`
/// endpoints. The Laravel side returns `DealResource::toArray()` merged with
/// `{deal_id, state}` (the `define` step additionally aliases it as `id`) —
/// the payload is **not** wrapped in the usual `{success, message, data}`
/// envelope, so this model decodes from the top-level body directly.
///
/// The deal id is a **UUID string** (`deal_instances.id` is a `HasUuids`
/// key), never an integer. Most of the long-tail JSON columns (solutions,
/// stakeholders, financing, expertise, pipeline_steps, problem, …) are
/// surfaced as loosely-typed structures so the SDK doesn't need a release
/// every time the server extends a step. The lifecycle scalars are lifted to
/// first-class fields.
@immutable
class Deal {
  /// Construct.
  const Deal({
    required this.id,
    required this.state,
    this.userId,
    this.subprojectId,
    this.tld,
    this.wizardStep,
    this.currentStepIdx,
    this.problem = const <String, dynamic>{},
    this.solutions = const <dynamic>[],
    this.selectedSolutionIdx,
    this.stakeholders = const <dynamic>[],
    this.financing = const <String, dynamic>{},
    this.expertise = const <String, dynamic>{},
    this.pipelineSteps = const <dynamic>[],
    this.outcomeScore,
    this.outcomeReport,
    this.ontologyClass,
    this.ontologyVersion,
    this.applicantType,
    this.budgetTier,
    this.pathTier,
    this.createdAt,
    this.updatedAt,
    this.completedAt,
    this.extras = const <String, dynamic>{},
  });

  /// Decode from the flat JSON body of a `/wizard/deal/*` response.
  factory Deal.fromJson(Map<String, dynamic> json) {
    const known = <String>{
      'id',
      'deal_id',
      'user_id',
      'subproject_id',
      'tld',
      'state',
      'wizard_step',
      'current_step_idx',
      'problem',
      'solutions',
      'selected_solution_idx',
      'stakeholders',
      'financing',
      'expertise',
      'pipeline_steps',
      'outcome_score',
      'outcome_report',
      'ontology_class',
      'ontology_version',
      'applicant_type',
      'budget_tier',
      'path_tier',
      'created_at',
      'updated_at',
      'completed_at',
    };
    final extras = <String, dynamic>{
      for (final MapEntry<String, dynamic> e in json.entries)
        if (!known.contains(e.key)) e.key: e.value,
    };

    final rawId = json['deal_id'] ?? json['id'];

    return Deal(
      id: rawId?.toString() ?? '',
      state: (json['state'] ?? '') as String,
      userId: _asInt(json['user_id']),
      subprojectId: _asInt(json['subproject_id']),
      tld: json['tld'] as String?,
      wizardStep: _asInt(json['wizard_step']),
      currentStepIdx: _asInt(json['current_step_idx']),
      problem: _asMap(json['problem']),
      solutions: _asList(json['solutions']),
      selectedSolutionIdx: _asInt(json['selected_solution_idx']),
      stakeholders: _asList(json['stakeholders']),
      financing: _asMap(json['financing']),
      expertise: _asMap(json['expertise']),
      pipelineSteps: _asList(json['pipeline_steps']),
      outcomeScore: _asInt(json['outcome_score']),
      outcomeReport: json['outcome_report'] is Map
          ? Map<String, dynamic>.from(json['outcome_report'] as Map)
          : null,
      ontologyClass: json['ontology_class'] as String?,
      ontologyVersion: json['ontology_version'] as String?,
      applicantType: json['applicant_type'] as String?,
      budgetTier: json['budget_tier'] as String?,
      pathTier: json['path_tier'] as String?,
      createdAt: _asDate(json['created_at']),
      updatedAt: _asDate(json['updated_at']),
      completedAt: _asDate(json['completed_at']),
      extras: extras,
    );
  }

  /// The deal's UUID (`deal_instances.id`).
  final String id;

  /// Lifecycle state — `analyzing`, `codified`, `setup`, `awaiting_compute`,
  /// `executing`, `verifying`, `completed`, … Server-driven; the SDK does
  /// not enforce the enum.
  final String state;

  /// FK into `users` — the deal creator. `null` for anonymous define.
  final int? userId;

  /// FK into `subprojects` — resolved server-side from the X-Domain header.
  final int? subprojectId;

  /// The codify tld this deal is scoped to (e.g. `codify.healthcare`).
  final String? tld;

  /// 1-based wizard step the deal has reached.
  final int? wizardStep;

  /// 0-based index of the currently-executing pipeline step.
  final int? currentStepIdx;

  /// The problem envelope (statement, intent_slug, classification,
  /// required_info, answers, title, description, related_industries, …).
  final Map<String, dynamic> problem;

  /// The ≥3 generated solutions (set after `codify`).
  final List<dynamic> solutions;

  /// 0-based index of the chosen solution (set after `selectSolution`).
  final int? selectedSolutionIdx;

  /// Identified stakeholders with O*NET codes / actor refs.
  final List<dynamic> stakeholders;

  /// The financing envelope (total_cents, breakdown[], insurance_coverage…).
  final Map<String, dynamic> financing;

  /// The expertise envelope (agent refs, tools_required, codesets…).
  final Map<String, dynamic> expertise;

  /// The materialised pipeline steps (set after `setup`).
  final List<dynamic> pipelineSteps;

  /// Integer 0..100 outcome score set after verification.
  final int? outcomeScore;

  /// The full outcome report (set after verification).
  final Map<String, dynamic>? outcomeReport;

  /// OWL ontology class assigned at define time.
  final String? ontologyClass;

  /// Ontology version (e.g. `v3`).
  final String? ontologyVersion;

  /// Intake metadata — `Builder` | `Organizer` | `Promoter`.
  final String? applicantType;

  /// Intake details budget tier — `lt5k` | `lt30k` | `lt100k` | `gte100k`.
  final String? budgetTier;

  /// Intake path tier — `pink` | `green` | `blue` | `red` | `black`.
  final String? pathTier;

  /// Creation timestamp.
  final DateTime? createdAt;

  /// Last-update timestamp.
  final DateTime? updatedAt;

  /// Completion timestamp (set on `completed`).
  final DateTime? completedAt;

  /// Any other top-level fields not lifted to a first-class property.
  final Map<String, dynamic> extras;

  static int? _asInt(Object? v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static DateTime? _asDate(Object? v) =>
      v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;

  static Map<String, dynamic> _asMap(Object? v) =>
      v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{};

  static List<dynamic> _asList(Object? v) =>
      v is List ? List<dynamic>.from(v) : const <dynamic>[];

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Deal && other.id == id && other.state == state;
  }

  @override
  int get hashCode => Object.hash(id, state);

  @override
  String toString() => 'Deal(id: $id, state: $state)';
}

/// A `deal_files` row — the metadata anchor for a document / image / logo
/// uploaded into a deal during the intake wizard. Returned (HTTP 201) by
/// `POST /wizard/deal/{deal_id}/files`.
@immutable
class DealFile {
  /// Construct.
  const DealFile({
    required this.id,
    required this.dealId,
    required this.filePath,
    required this.fileType,
    this.mimeType,
    this.uploadedByUserId,
    this.createdAt,
    this.updatedAt,
  });

  /// Decode from the flat `deal_files` row body.
  factory DealFile.fromJson(Map<String, dynamic> json) => DealFile(
        id: Deal._asInt(json['id']) ?? 0,
        dealId: (json['deal_id'] ?? '').toString(),
        filePath: (json['file_path'] ?? '') as String,
        fileType: (json['file_type'] ?? '') as String,
        mimeType: json['mime_type'] as String?,
        uploadedByUserId: Deal._asInt(json['uploaded_by_user_id']),
        createdAt: Deal._asDate(json['created_at']),
        updatedAt: Deal._asDate(json['updated_at']),
      );

  /// Primary key (`deal_files.id`).
  final int id;

  /// UUID FK → the owning deal.
  final String dealId;

  /// Storage path on the application disk (S3 / local).
  final String filePath;

  /// `document` | `image` | `logo`.
  final String fileType;

  /// MIME type detected at upload time.
  final String? mimeType;

  /// FK into `users` — who uploaded the file.
  final int? uploadedByUserId;

  /// Creation timestamp.
  final DateTime? createdAt;

  /// Last-update timestamp.
  final DateTime? updatedAt;
}

/// A page of `deal_events` — the append-only audit log. Returned by
/// `GET /wizard/deal/{deal_id}/events` as `{events: [...], pagination: {...}}`.
@immutable
class DealEventsPage {
  /// Construct.
  const DealEventsPage({
    required this.events,
    required this.total,
    required this.perPage,
    required this.currentPage,
    required this.lastPage,
  });

  /// Decode from the `{events, pagination}` body.
  factory DealEventsPage.fromJson(Map<String, dynamic> json) {
    final pagination = json['pagination'] is Map
        ? Map<String, dynamic>.from(json['pagination'] as Map)
        : const <String, dynamic>{};
    return DealEventsPage(
      events: json['events'] is List
          ? List<Map<String, dynamic>>.from(
              (json['events'] as List).map(
                (dynamic e) => e is Map
                    ? Map<String, dynamic>.from(e)
                    : <String, dynamic>{},
              ),
            )
          : const <Map<String, dynamic>>[],
      total: Deal._asInt(pagination['total']) ?? 0,
      perPage: Deal._asInt(pagination['per_page']) ?? 0,
      currentPage: Deal._asInt(pagination['current_page']) ?? 1,
      lastPage: Deal._asInt(pagination['last_page']) ?? 1,
    );
  }

  /// The events on this page, ordered by `sequence`.
  final List<Map<String, dynamic>> events;

  /// Total number of events across all pages.
  final int total;

  /// Events per page.
  final int perPage;

  /// Current (1-based) page number.
  final int currentPage;

  /// Last (1-based) page number.
  final int lastPage;
}

/// The result of `POST /wizard/deal/{deal_id}/verify/{execution_id}`.
///
/// Distinct from [Deal] — verification returns a bespoke body
/// `{deal_id, state, outcome_score, outcome_class, outcome_report}` rather
/// than a `DealResource`.
@immutable
class DealVerificationResult {
  /// Construct.
  const DealVerificationResult({
    required this.dealId,
    required this.state,
    this.outcomeScore,
    this.outcomeClass,
    this.outcomeReport = const <String, dynamic>{},
  });

  /// Decode from the verify response body.
  factory DealVerificationResult.fromJson(Map<String, dynamic> json) =>
      DealVerificationResult(
        dealId: (json['deal_id'] ?? '').toString(),
        state: (json['state'] ?? '') as String,
        outcomeScore: Deal._asInt(json['outcome_score']),
        outcomeClass: json['outcome_class'] as String?,
        outcomeReport: json['outcome_report'] is Map
            ? Map<String, dynamic>.from(json['outcome_report'] as Map)
            : const <String, dynamic>{},
      );

  /// The verified deal's UUID.
  final String dealId;

  /// Resulting lifecycle state — typically `completed`.
  final String state;

  /// Integer 0..100 score (e.g. `75`).
  final int? outcomeScore;

  /// Outcome class — e.g. `success`, `partial_success`, `failure`.
  final String? outcomeClass;

  /// The full structured outcome report.
  final Map<String, dynamic> outcomeReport;
}

/// The result of `POST /wizard/deal/{deal_id}/compute-deposit` — a Stripe
/// PaymentIntent `client_secret` the client uses to confirm the F3 5-tier
/// Compute deposit. The deal launches once the deposit's webhook lands.
@immutable
class ComputeDeposit {
  /// Construct.
  const ComputeDeposit({required this.clientSecret});

  /// Decode from the `{client_secret}` body.
  factory ComputeDeposit.fromJson(Map<String, dynamic> json) =>
      ComputeDeposit(clientSecret: (json['client_secret'] ?? '') as String);

  /// The Stripe PaymentIntent client secret.
  final String clientSecret;
}
