import 'package:meta/meta.dart';

/// A P2X **Application** — the canonical record of a multi-step submission a
/// user makes to a subproject (doctor onboarding, patient intake, program
/// enrollment, etc.).
///
/// IBD's doctor-onboarding flow is the primary Tier-1 consumer: a doctor
/// completes a multi-screen wizard in the IBD Flutter app, the IBD Node
/// backend forwards the final payload to
/// `POST /api/applications` on P2X, and the application then progresses
/// through `draft → submitted → approved/rejected` driven by the operator
/// console.
@immutable
class Application {
  /// Construct.
  const Application({
    required this.id,
    required this.subprojectId,
    required this.type,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.payload = const <String, dynamic>{},
  });

  /// Decode from a JSON object. Permissive — a missing `payload` decodes
  /// to an empty map, and unrecognized top-level keys are ignored.
  factory Application.fromJson(Map<String, dynamic> json) {
    final rawPayload = json['payload'];
    final payload = rawPayload is Map
        ? Map<String, dynamic>.from(rawPayload)
        : <String, dynamic>{};
    return Application(
      id: json['id'] as int,
      subprojectId: json['subproject_id'] as int,
      type: json['type'] as String,
      status: json['status'] as String,
      payload: payload,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Primary key.
  final int id;

  /// The subproject this application belongs to (server-assigned from the
  /// `X-Domain` header at creation time).
  final int subprojectId;

  /// Stable type identifier — e.g. `doctor_request`, `patient_intake`,
  /// `program_enrollment`. Server-driven; the SDK doesn't enforce the
  /// enum so new server-side types flow through unchanged.
  final String type;

  /// One of `draft`, `submitted`, `approved`, `rejected`. Server-driven —
  /// the SDK doesn't enforce the enum so additional statuses flow through
  /// unchanged.
  final String status;

  /// Free-form structured payload — wizard answers, license metadata, etc.
  /// Schema is per-`type` and validated server-side.
  final Map<String, dynamic> payload;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Last-modified timestamp.
  final DateTime updatedAt;

  /// Encode to a JSON object. Symmetric with [Application.fromJson].
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'subproject_id': subprojectId,
      'type': type,
      'status': status,
      'payload': payload,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Return a copy with the given fields replaced.
  Application copyWith({
    int? id,
    int? subprojectId,
    String? type,
    String? status,
    Map<String, dynamic>? payload,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Application(
      id: id ?? this.id,
      subprojectId: subprojectId ?? this.subprojectId,
      type: type ?? this.type,
      status: status ?? this.status,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Application) return false;
    if (id != other.id) return false;
    if (subprojectId != other.subprojectId) return false;
    if (type != other.type) return false;
    if (status != other.status) return false;
    if (createdAt != other.createdAt) return false;
    if (updatedAt != other.updatedAt) return false;
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
      subprojectId,
      type,
      status,
      createdAt,
      updatedAt,
      payloadHash,
    );
  }

  @override
  String toString() =>
      'Application(id: $id, subprojectId: $subprojectId, type: $type, '
      'status: $status, createdAt: $createdAt, updatedAt: $updatedAt)';
}
