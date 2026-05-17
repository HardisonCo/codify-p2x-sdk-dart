import 'package:meta/meta.dart';

/// A patient **Intake** session — a server-tracked record of a guest's
/// (or user's) progression through the structured intake flow before
/// they're handed off to a downstream subproject (e.g. an IBD doctor).
///
/// Intake lifecycle cycles through
/// `open`→`in_progress`→`voice_pending`→`completed`→`handed_off`. The
/// session optionally carries a free-text [voiceTranscript] and a
/// [voiceUrl] / [voiceDurationSeconds] pair when the patient recorded
/// an audio note (which the server later transcribes into
/// [voiceTranscript]).
///
/// Mirrors the TS SDK's intake response envelope; the underlying server
/// shape is "still maturing" per the TS sibling, so this Dart model
/// fronts the typed fields the SDK guarantees and stuffs raw responses
/// into [answers] verbatim.
@immutable
class Intake {
  /// Construct.
  const Intake({
    required this.id,
    required this.subprojectId,
    required this.answers,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.userId,
    this.audience,
    this.voiceUrl,
    this.voiceDurationSeconds,
    this.voiceTranscript,
  });

  /// Decode from a JSON object. Permissive — missing optional fields
  /// fall back to `null`; timestamps go through [DateTime.parse]; the
  /// [answers] map is copied into a fresh `Map<String, dynamic>`.
  factory Intake.fromJson(Map<String, dynamic> json) {
    final rawAnswers = json['answers'];
    return Intake(
      id: json['id'] as String,
      subprojectId: json['subproject_id'] as String,
      userId: json['user_id'] as String?,
      audience: json['audience'] as String?,
      answers: rawAnswers is Map
          ? Map<String, dynamic>.from(rawAnswers)
          : const <String, dynamic>{},
      voiceUrl: json['voice_url'] as String?,
      voiceDurationSeconds: json['voice_duration_seconds'] as int?,
      voiceTranscript: json['voice_transcript'] as String?,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Primary key — opaque server-issued string id.
  final String id;

  /// Subproject (tenant) this intake belongs to.
  final String subprojectId;

  /// Linked user id once the intake has been bound to a real account
  /// (post-handoff, typically). Null while the intake is still guest.
  final String? userId;

  /// Audience tag — one of `'patient'`, `'family_member'`, `'caregiver'`
  /// (server-driven, not enforced client-side).
  final String? audience;

  /// Structured intake answers — server contract is intentionally
  /// open. The SDK stores them verbatim as a `Map<String, dynamic>`.
  final Map<String, dynamic> answers;

  /// Optional CDN URL of the patient's recorded voice note.
  final String? voiceUrl;

  /// Length of the voice note in whole seconds. Serialized as the
  /// integer count of seconds — see `IntakeClient.voiceRecord` in
  /// `intake_client.dart`.
  final int? voiceDurationSeconds;

  /// Optional server-generated transcription of [voiceUrl].
  final String? voiceTranscript;

  /// One of `open`, `in_progress`, `voice_pending`, `completed`,
  /// `handed_off`. Server-driven — the SDK doesn't enforce the enum.
  final String status;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Last-modified timestamp.
  final DateTime updatedAt;

  /// Encode to a JSON object. Symmetric with [Intake.fromJson]. Null
  /// optional fields are omitted entirely.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'subproject_id': subprojectId,
      if (userId != null) 'user_id': userId,
      if (audience != null) 'audience': audience,
      'answers': answers,
      if (voiceUrl != null) 'voice_url': voiceUrl,
      if (voiceDurationSeconds != null)
        'voice_duration_seconds': voiceDurationSeconds,
      if (voiceTranscript != null) 'voice_transcript': voiceTranscript,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Return a copy with the given fields replaced.
  Intake copyWith({
    String? id,
    String? subprojectId,
    String? userId,
    String? audience,
    Map<String, dynamic>? answers,
    String? voiceUrl,
    int? voiceDurationSeconds,
    String? voiceTranscript,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Intake(
      id: id ?? this.id,
      subprojectId: subprojectId ?? this.subprojectId,
      userId: userId ?? this.userId,
      audience: audience ?? this.audience,
      answers: answers ?? this.answers,
      voiceUrl: voiceUrl ?? this.voiceUrl,
      voiceDurationSeconds: voiceDurationSeconds ?? this.voiceDurationSeconds,
      voiceTranscript: voiceTranscript ?? this.voiceTranscript,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Intake &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          subprojectId == other.subprojectId &&
          userId == other.userId &&
          audience == other.audience &&
          _mapEquals(answers, other.answers) &&
          voiceUrl == other.voiceUrl &&
          voiceDurationSeconds == other.voiceDurationSeconds &&
          voiceTranscript == other.voiceTranscript &&
          status == other.status &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        subprojectId,
        userId,
        audience,
        _mapHash(answers),
        voiceUrl,
        voiceDurationSeconds,
        voiceTranscript,
        status,
        createdAt,
        updatedAt,
      );

  @override
  String toString() => 'Intake(id: $id, status: $status, '
      'subprojectId: $subprojectId, userId: $userId, '
      'audience: $audience, voiceUrl: $voiceUrl)';
}

/// Handoff envelope returned by `POST /api/v1/intake/{id}/handoff` and
/// `POST /api/v1/intake/handoff/{token}/exchange`.
///
/// The originating subproject calls `initiateHandoff` and receives an
/// envelope with [token], [expiresAt], [targetSubprojectDomain] and
/// [exchangeUrl] — but no [intake], since the target subproject hasn't
/// materialised the intake row yet. When the receiving subproject
/// later calls `exchange(token: ...)`, the same envelope shape comes
/// back, this time with [intake] populated to the freshly-materialised
/// intake on the receiving side.
@immutable
class IntakeHandoff {
  /// Construct.
  const IntakeHandoff({
    required this.token,
    required this.expiresAt,
    required this.targetSubprojectDomain,
    required this.exchangeUrl,
    this.intake,
  });

  /// Decode from a JSON object.
  factory IntakeHandoff.fromJson(Map<String, dynamic> json) {
    final rawIntake = json['intake'];
    return IntakeHandoff(
      token: json['token'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      targetSubprojectDomain: json['target_subproject_domain'] as String,
      exchangeUrl: json['exchange_url'] as String,
      intake: rawIntake is Map<String, dynamic>
          ? Intake.fromJson(rawIntake)
          : (rawIntake is Map
              ? Intake.fromJson(Map<String, dynamic>.from(rawIntake))
              : null),
    );
  }

  /// Single-use handoff token. Pass this to `IntakeClient.exchange()`
  /// from the receiving subproject (public — no Bearer required).
  final String token;

  /// When the [token] expires. Server-driven; typically short (~minutes).
  final DateTime expiresAt;

  /// Domain of the subproject that should consume this handoff (sent
  /// as `X-Domain` on the receiving subproject's API calls).
  final String targetSubprojectDomain;

  /// Fully-qualified URL the receiving subproject (or its mobile app's
  /// BFF) should hit to exchange the [token]. Equivalent to
  /// `POST /api/v1/intake/handoff/{token}/exchange` on the target API.
  final String exchangeUrl;

  /// The newly-materialised target-side intake. Null on
  /// `initiateHandoff` (the target hasn't created it yet); non-null on
  /// `exchange` (the target has now created it on its side).
  final Intake? intake;

  /// Encode to a JSON object. Symmetric with [IntakeHandoff.fromJson].
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'token': token,
      'expires_at': expiresAt.toIso8601String(),
      'target_subproject_domain': targetSubprojectDomain,
      'exchange_url': exchangeUrl,
      if (intake != null) 'intake': intake!.toJson(),
    };
  }

  /// Return a copy with the given fields replaced.
  IntakeHandoff copyWith({
    String? token,
    DateTime? expiresAt,
    String? targetSubprojectDomain,
    String? exchangeUrl,
    Intake? intake,
  }) {
    return IntakeHandoff(
      token: token ?? this.token,
      expiresAt: expiresAt ?? this.expiresAt,
      targetSubprojectDomain:
          targetSubprojectDomain ?? this.targetSubprojectDomain,
      exchangeUrl: exchangeUrl ?? this.exchangeUrl,
      intake: intake ?? this.intake,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IntakeHandoff &&
          runtimeType == other.runtimeType &&
          token == other.token &&
          expiresAt == other.expiresAt &&
          targetSubprojectDomain == other.targetSubprojectDomain &&
          exchangeUrl == other.exchangeUrl &&
          intake == other.intake;

  @override
  int get hashCode => Object.hash(
        token,
        expiresAt,
        targetSubprojectDomain,
        exchangeUrl,
        intake,
      );

  @override
  String toString() => 'IntakeHandoff(token: $token, '
      'targetSubprojectDomain: $targetSubprojectDomain, '
      'expiresAt: $expiresAt, hasIntake: ${intake != null})';
}

/// Lightweight poll response for `GET /api/v1/intake/{id}/status`. Used
/// by clients that want to know if an intake is ready to hand off
/// without re-fetching the full [Intake] envelope.
@immutable
class IntakeStatus {
  /// Construct.
  const IntakeStatus({
    required this.intakeId,
    required this.status,
    required this.updatedAt,
    required this.readyForHandoff,
  });

  /// Decode from a JSON object.
  factory IntakeStatus.fromJson(Map<String, dynamic> json) {
    return IntakeStatus(
      intakeId: json['intake_id'] as String,
      status: json['status'] as String,
      updatedAt: DateTime.parse(json['updated_at'] as String),
      readyForHandoff: json['ready_for_handoff'] as bool,
    );
  }

  /// Id of the intake this status snapshot is for.
  final String intakeId;

  /// Same status string as [Intake.status].
  final String status;

  /// Last server-side modification timestamp.
  final DateTime updatedAt;

  /// True when the server considers the intake ready to be handed off
  /// to a downstream subproject (answers complete, voice processed,
  /// audience selected, etc.).
  final bool readyForHandoff;

  /// Encode to a JSON object. Symmetric with [IntakeStatus.fromJson].
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'intake_id': intakeId,
      'status': status,
      'updated_at': updatedAt.toIso8601String(),
      'ready_for_handoff': readyForHandoff,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IntakeStatus &&
          runtimeType == other.runtimeType &&
          intakeId == other.intakeId &&
          status == other.status &&
          updatedAt == other.updatedAt &&
          readyForHandoff == other.readyForHandoff;

  @override
  int get hashCode => Object.hash(intakeId, status, updatedAt, readyForHandoff);

  @override
  String toString() => 'IntakeStatus(intakeId: $intakeId, status: $status, '
      'readyForHandoff: $readyForHandoff, updatedAt: $updatedAt)';
}

bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (!b.containsKey(entry.key)) return false;
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}

int _mapHash(Map<String, dynamic> m) {
  var h = 0;
  for (final entry in m.entries) {
    h = h ^ Object.hash(entry.key, entry.value);
  }
  return h;
}
