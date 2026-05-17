import 'package:meta/meta.dart';

/// A single assessment **Response** row — the canonical write target for
/// arbitrary per-user, per-survey data.
///
/// Used by NIO to persist food-scan results (one Response per scan), by
/// MOB to log workouts, and by IBD to record symptom check-ins. The
/// [payload] is intentionally opaque to the SDK — its shape is owned by
/// the survey definition on the server.
///
/// On `POST /api/response/store` the server fills in [id], [userId],
/// [subprojectId] and [createdAt] from the request context and returns
/// the canonical row.
@immutable
class AssessmentResponse {
  /// Construct.
  const AssessmentResponse({
    required this.surveyKey,
    required this.payload,
    this.id,
    this.userId,
    this.subprojectId,
    this.createdAt,
  });

  /// Decode from a JSON object. Permissive: missing optional fields fall
  /// back to `null`, and a missing `payload` decodes to an empty map.
  factory AssessmentResponse.fromJson(Map<String, dynamic> json) {
    final rawPayload = json['payload'];
    final payload = rawPayload is Map
        ? Map<String, dynamic>.from(rawPayload)
        : <String, dynamic>{};
    return AssessmentResponse(
      id: json['id'] as int?,
      surveyKey: json['survey_key'] as String,
      payload: payload,
      userId: json['user_id'] as int?,
      subprojectId: json['subproject_id'] as int?,
      createdAt: json['created_at'] is String
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  /// Primary key — `null` before the row has been persisted server-side.
  final int? id;

  /// Stable survey identifier — e.g. `food-intake-daily`, `phm-lab-result`.
  /// Maps to a row in the `surveys` table on the server.
  final String surveyKey;

  /// Survey-defined payload. Schema lives on the server; the SDK passes
  /// it through verbatim.
  final Map<String, dynamic> payload;

  /// User who created the response. Server-assigned.
  final int? userId;

  /// Subproject the response belongs to. Server-assigned from the
  /// `X-Domain` header.
  final int? subprojectId;

  /// Creation timestamp. Server-assigned.
  final DateTime? createdAt;

  /// Encode to a JSON object. Symmetric with [AssessmentResponse.fromJson].
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (id != null) 'id': id,
      'survey_key': surveyKey,
      'payload': payload,
      if (userId != null) 'user_id': userId,
      if (subprojectId != null) 'subproject_id': subprojectId,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  /// Return a copy with the given fields replaced.
  AssessmentResponse copyWith({
    int? id,
    String? surveyKey,
    Map<String, dynamic>? payload,
    int? userId,
    int? subprojectId,
    DateTime? createdAt,
  }) {
    return AssessmentResponse(
      id: id ?? this.id,
      surveyKey: surveyKey ?? this.surveyKey,
      payload: payload ?? this.payload,
      userId: userId ?? this.userId,
      subprojectId: subprojectId ?? this.subprojectId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AssessmentResponse) return false;
    if (id != other.id) return false;
    if (surveyKey != other.surveyKey) return false;
    if (userId != other.userId) return false;
    if (subprojectId != other.subprojectId) return false;
    if (createdAt != other.createdAt) return false;
    if (payload.length != other.payload.length) return false;
    for (final entry in payload.entries) {
      if (!other.payload.containsKey(entry.key)) return false;
      if (other.payload[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    var payloadHash = 0;
    for (final entry in payload.entries) {
      payloadHash ^= Object.hash(entry.key, entry.value);
    }
    return Object.hash(
      id,
      surveyKey,
      payloadHash,
      userId,
      subprojectId,
      createdAt,
    );
  }

  @override
  String toString() => 'AssessmentResponse(id: $id, surveyKey: $surveyKey, '
      'userId: $userId, subprojectId: $subprojectId, '
      'createdAt: $createdAt, payload: $payload)';
}

/// A paginated list of [AssessmentResponse] rows.
///
/// Mirrors Laravel's default paginator shape:
/// `{ data: [...], total: N, per_page: 50, current_page: 1 }`.
/// All fields except [data] are best-effort — endpoints that return a
/// non-paginated list still decode cleanly.
@immutable
class AssessmentResponseList {
  /// Construct.
  const AssessmentResponseList({
    required this.data,
    required this.total,
    this.perPage,
    this.currentPage,
  });

  /// Decode from a JSON object. Permissive: missing `data` decodes to
  /// an empty list; missing `total` falls back to `data.length`.
  factory AssessmentResponseList.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final items = <AssessmentResponse>[];
    if (rawData is List) {
      for (final row in rawData) {
        if (row is Map) {
          items.add(
            AssessmentResponse.fromJson(Map<String, dynamic>.from(row)),
          );
        }
      }
    }
    return AssessmentResponseList(
      data: items,
      total: json['total'] is int ? json['total'] as int : items.length,
      perPage: json['per_page'] as int?,
      currentPage: json['current_page'] as int?,
    );
  }

  /// The page of rows.
  final List<AssessmentResponse> data;

  /// Total row count across all pages.
  final int total;

  /// Page size, when paginated.
  final int? perPage;

  /// 1-indexed current page, when paginated.
  final int? currentPage;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AssessmentResponseList) return false;
    if (total != other.total) return false;
    if (perPage != other.perPage) return false;
    if (currentPage != other.currentPage) return false;
    if (data.length != other.data.length) return false;
    for (var i = 0; i < data.length; i++) {
      if (data[i] != other.data[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    var dataHash = 0;
    for (final r in data) {
      dataHash ^= r.hashCode;
    }
    return Object.hash(dataHash, total, perPage, currentPage);
  }

  @override
  String toString() => 'AssessmentResponseList(total: $total, '
      'perPage: $perPage, currentPage: $currentPage, '
      'count: ${data.length})';
}
