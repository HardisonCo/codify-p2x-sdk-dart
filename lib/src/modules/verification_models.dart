import 'package:meta/meta.dart';

/// A P2X **Verification** — a record of a document a user has submitted for
/// credential review (medical license, DEA registration, malpractice
/// insurance, etc.).
///
/// IBD's doctor-onboarding flow is the primary Tier-1 consumer. The
/// document itself is uploaded to object storage (S3 / DO Spaces /
/// equivalent) out-of-band; the Verification record only carries the URL
/// and metadata that the operator console uses to review and approve or
/// reject the submission.
@immutable
class Verification {
  /// Construct.
  const Verification({
    required this.id,
    required this.subprojectId,
    required this.documentType,
    required this.documentUrl,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.reviewerNotes,
  });

  /// Decode from a JSON object. Permissive — unrecognized top-level keys
  /// are ignored and `reviewer_notes` defaults to `null`.
  factory Verification.fromJson(Map<String, dynamic> json) {
    return Verification(
      id: json['id'] as int,
      subprojectId: json['subproject_id'] as int,
      documentType: json['document_type'] as String,
      documentUrl: json['document_url'] as String,
      status: json['status'] as String,
      reviewerNotes: json['reviewer_notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Primary key.
  final int id;

  /// The subproject this verification belongs to (server-assigned from
  /// the `X-Domain` header at creation time).
  final int subprojectId;

  /// Document category — e.g. `medical_license`, `dea`,
  /// `malpractice_insurance`. Server-driven; the SDK doesn't enforce the
  /// enum so new document types flow through unchanged.
  final String documentType;

  /// URL to the uploaded document on object storage. The Verification
  /// record only stores metadata — the upload itself happens
  /// out-of-band.
  final String documentUrl;

  /// One of `pending`, `in_review`, `verified`, `rejected`. Server-driven
  /// — the SDK doesn't enforce the enum so additional statuses flow
  /// through unchanged.
  final String status;

  /// Free-form reviewer feedback (typically set when [status] is
  /// `rejected`). `null` until a reviewer has commented.
  final String? reviewerNotes;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Last-modified timestamp.
  final DateTime updatedAt;

  /// Encode to a JSON object. Symmetric with [Verification.fromJson].
  /// `reviewerNotes` is omitted when `null`.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'subproject_id': subprojectId,
      'document_type': documentType,
      'document_url': documentUrl,
      'status': status,
      if (reviewerNotes != null) 'reviewer_notes': reviewerNotes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Return a copy with the given fields replaced.
  Verification copyWith({
    int? id,
    int? subprojectId,
    String? documentType,
    String? documentUrl,
    String? status,
    String? reviewerNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Verification(
      id: id ?? this.id,
      subprojectId: subprojectId ?? this.subprojectId,
      documentType: documentType ?? this.documentType,
      documentUrl: documentUrl ?? this.documentUrl,
      status: status ?? this.status,
      reviewerNotes: reviewerNotes ?? this.reviewerNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Verification &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          subprojectId == other.subprojectId &&
          documentType == other.documentType &&
          documentUrl == other.documentUrl &&
          status == other.status &&
          reviewerNotes == other.reviewerNotes &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        subprojectId,
        documentType,
        documentUrl,
        status,
        reviewerNotes,
        createdAt,
        updatedAt,
      );

  @override
  String toString() => 'Verification(id: $id, subprojectId: $subprojectId, '
      'documentType: $documentType, status: $status, '
      'reviewerNotes: $reviewerNotes)';
}
