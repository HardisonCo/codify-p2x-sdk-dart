import 'package:meta/meta.dart';

/// A post-visit **FollowUp** — a server-tracked task the provider has
/// scheduled for the patient after a schedule call (see
/// `ScheduleCall` in `schedule_models.dart`) completed.
///
/// FollowUps lifecycle through `pending`→`in_progress`→`completed`
/// (or `skipped`). They optionally carry a free-text [notes] field and
/// a [voiceUrl] / [voiceDurationSeconds] pair when the patient
/// recorded an audio note (which the server later transcribes into
/// [notes]).
@immutable
class FollowUp {
  /// Construct.
  const FollowUp({
    required this.id,
    required this.patientId,
    required this.providerId,
    required this.dueAt,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.notes,
    this.voiceUrl,
    this.voiceDurationSeconds,
  });

  /// Decode from a JSON object. Permissive — missing optional fields
  /// fall back to `null`; timestamps go through [DateTime.parse].
  factory FollowUp.fromJson(Map<String, dynamic> json) {
    return FollowUp(
      id: json['id'] as int,
      patientId: json['patient_id'] as int,
      providerId: json['provider_id'] as int,
      dueAt: DateTime.parse(json['due_at'] as String),
      status: json['status'] as String,
      notes: json['notes'] as String?,
      voiceUrl: json['voice_url'] as String?,
      voiceDurationSeconds: json['voice_duration_seconds'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Primary key.
  final int id;

  /// The patient this follow-up belongs to.
  final int patientId;

  /// The provider that scheduled the follow-up.
  final int providerId;

  /// When the follow-up is due.
  final DateTime dueAt;

  /// One of `pending`, `in_progress`, `completed`, `skipped`. Server-
  /// driven — the SDK doesn't enforce the enum.
  final String status;

  /// Optional free-text notes — typically the patient's typed reply
  /// or the server-generated transcription of [voiceUrl].
  final String? notes;

  /// Optional CDN URL of the patient's recorded voice note.
  final String? voiceUrl;

  /// Length of the voice note in whole seconds. Serialized as the
  /// integer count of seconds — see `FollowUpsClient.recordVoice` in
  /// `follow_ups_client.dart`.
  final int? voiceDurationSeconds;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Last-modified timestamp.
  final DateTime updatedAt;

  /// Encode to a JSON object. Symmetric with [FollowUp.fromJson].
  /// Null optional fields are omitted entirely.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'patient_id': patientId,
      'provider_id': providerId,
      'due_at': dueAt.toIso8601String(),
      'status': status,
      if (notes != null) 'notes': notes,
      if (voiceUrl != null) 'voice_url': voiceUrl,
      if (voiceDurationSeconds != null)
        'voice_duration_seconds': voiceDurationSeconds,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Return a copy with the given fields replaced.
  FollowUp copyWith({
    int? id,
    int? patientId,
    int? providerId,
    DateTime? dueAt,
    String? status,
    String? notes,
    String? voiceUrl,
    int? voiceDurationSeconds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FollowUp(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      providerId: providerId ?? this.providerId,
      dueAt: dueAt ?? this.dueAt,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      voiceUrl: voiceUrl ?? this.voiceUrl,
      voiceDurationSeconds: voiceDurationSeconds ?? this.voiceDurationSeconds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FollowUp &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          patientId == other.patientId &&
          providerId == other.providerId &&
          dueAt == other.dueAt &&
          status == other.status &&
          notes == other.notes &&
          voiceUrl == other.voiceUrl &&
          voiceDurationSeconds == other.voiceDurationSeconds &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        patientId,
        providerId,
        dueAt,
        status,
        notes,
        voiceUrl,
        voiceDurationSeconds,
        createdAt,
        updatedAt,
      );

  @override
  String toString() => 'FollowUp(id: $id, status: $status, '
      'patientId: $patientId, providerId: $providerId, '
      'dueAt: $dueAt, voiceUrl: $voiceUrl)';
}
