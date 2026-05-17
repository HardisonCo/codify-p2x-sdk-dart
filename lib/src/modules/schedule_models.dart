import 'package:meta/meta.dart';

/// A bookable appointment **Schedule** slot.
///
/// Schedules are owned by a provider (a doctor in IBD, a coach in MOB)
/// and represent a window of time during which a patient may book a
/// call. The server enforces capacity and overlap rules — clients just
/// list, create, and book against them.
///
/// IBD's doctor↔patient telehealth flow is the canonical Tier-1 use:
/// the doctor publishes open slots, the patient lists/reserves one,
/// and the resulting [ScheduleCall] carries the LiveKit room handle.
@immutable
class Schedule {
  /// Construct.
  const Schedule({
    required this.id,
    required this.subprojectId,
    required this.providerId,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.capacity,
    required this.createdAt,
    required this.updatedAt,
    this.metadata = const <String, dynamic>{},
  });

  /// Decode from a JSON object. Permissive — missing `metadata` decodes
  /// to an empty map; timestamps go through [DateTime.parse].
  factory Schedule.fromJson(Map<String, dynamic> json) {
    final rawMeta = json['metadata'];
    final metadata = rawMeta is Map
        ? Map<String, dynamic>.from(rawMeta)
        : <String, dynamic>{};
    return Schedule(
      id: json['id'] as int,
      subprojectId: json['subproject_id'] as int,
      providerId: json['provider_id'] as int,
      startsAt: DateTime.parse(json['starts_at'] as String),
      endsAt: DateTime.parse(json['ends_at'] as String),
      status: json['status'] as String,
      capacity: json['capacity'] as int,
      metadata: metadata,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Primary key.
  final int id;

  /// Subproject this slot belongs to (server-assigned at create time).
  final int subprojectId;

  /// The provider (doctor / coach) the slot is owned by.
  final int providerId;

  /// Slot window start.
  final DateTime startsAt;

  /// Slot window end.
  final DateTime endsAt;

  /// One of `open`, `reserved`, `booked`, `cancelled`. Server-driven —
  /// the SDK doesn't enforce the enum, so new statuses flow through
  /// unchanged.
  final String status;

  /// How many patients can book this slot. Most 1:1 telehealth use
  /// cases pass `1`; group sessions raise it.
  final int capacity;

  /// Optional structured metadata — room labels, internal notes,
  /// pricing overrides, etc.
  final Map<String, dynamic> metadata;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Last-modified timestamp.
  final DateTime updatedAt;

  /// Encode to a JSON object. Symmetric with [Schedule.fromJson].
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'subproject_id': subprojectId,
      'provider_id': providerId,
      'starts_at': startsAt.toIso8601String(),
      'ends_at': endsAt.toIso8601String(),
      'status': status,
      'capacity': capacity,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Return a copy with the given fields replaced.
  Schedule copyWith({
    int? id,
    int? subprojectId,
    int? providerId,
    DateTime? startsAt,
    DateTime? endsAt,
    String? status,
    int? capacity,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Schedule(
      id: id ?? this.id,
      subprojectId: subprojectId ?? this.subprojectId,
      providerId: providerId ?? this.providerId,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      status: status ?? this.status,
      capacity: capacity ?? this.capacity,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Schedule) return false;
    if (id != other.id) return false;
    if (subprojectId != other.subprojectId) return false;
    if (providerId != other.providerId) return false;
    if (startsAt != other.startsAt) return false;
    if (endsAt != other.endsAt) return false;
    if (status != other.status) return false;
    if (capacity != other.capacity) return false;
    if (createdAt != other.createdAt) return false;
    if (updatedAt != other.updatedAt) return false;
    if (metadata.length != other.metadata.length) return false;
    for (final entry in metadata.entries) {
      if (!other.metadata.containsKey(entry.key)) return false;
      if (other.metadata[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    var metaHash = 0;
    for (final entry in metadata.entries) {
      metaHash ^= Object.hash(entry.key, entry.value);
    }
    return Object.hash(
      id,
      subprojectId,
      providerId,
      startsAt,
      endsAt,
      status,
      capacity,
      createdAt,
      updatedAt,
      metaHash,
    );
  }

  @override
  String toString() => 'Schedule(id: $id, status: $status, '
      'providerId: $providerId, startsAt: $startsAt, '
      'endsAt: $endsAt, capacity: $capacity)';
}

/// A **ScheduleCall** — the live (or completed) telehealth call that a
/// patient initiated against a booked [Schedule] slot.
///
/// One ScheduleCall row per booking. Tracks pending→connected→ended
/// lifecycle, plus the LiveKit room handle the apps hand to the
/// LiveKit SDK to join the actual A/V session.
@immutable
class ScheduleCall {
  /// Construct.
  const ScheduleCall({
    required this.id,
    required this.scheduleId,
    required this.patientId,
    required this.providerId,
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.endedAt,
    this.livekitRoom,
    this.metadata = const <String, dynamic>{},
  });

  /// Decode from a JSON object. Permissive — missing optionals fall
  /// back to `null`; missing `metadata` decodes to an empty map.
  factory ScheduleCall.fromJson(Map<String, dynamic> json) {
    final rawMeta = json['metadata'];
    final metadata = rawMeta is Map
        ? Map<String, dynamic>.from(rawMeta)
        : <String, dynamic>{};
    return ScheduleCall(
      id: json['id'] as int,
      scheduleId: json['schedule_id'] as int,
      patientId: json['patient_id'] as int,
      providerId: json['provider_id'] as int,
      status: json['status'] as String,
      startedAt: json['started_at'] is String
          ? DateTime.parse(json['started_at'] as String)
          : null,
      endedAt: json['ended_at'] is String
          ? DateTime.parse(json['ended_at'] as String)
          : null,
      livekitRoom: json['livekit_room'] as String?,
      metadata: metadata,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Primary key.
  final int id;

  /// The [Schedule] this call is booked against.
  final int scheduleId;

  /// The patient that booked the call.
  final int patientId;

  /// The provider on the other end of the call.
  final int providerId;

  /// One of `pending`, `connected`, `ended`, `failed`. Server-driven.
  final String status;

  /// When the call became `connected`. `null` while still `pending`.
  final DateTime? startedAt;

  /// When the call became `ended` (or `failed`). `null` while in
  /// progress.
  final DateTime? endedAt;

  /// LiveKit room handle the client hands to the LiveKit SDK to join
  /// the A/V session. `null` until the server provisions a room.
  final String? livekitRoom;

  /// Optional structured metadata — recording URLs, post-call
  /// transcripts, etc.
  final Map<String, dynamic> metadata;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Encode to a JSON object. Symmetric with [ScheduleCall.fromJson].
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'schedule_id': scheduleId,
      'patient_id': patientId,
      'provider_id': providerId,
      'status': status,
      if (startedAt != null) 'started_at': startedAt!.toIso8601String(),
      if (endedAt != null) 'ended_at': endedAt!.toIso8601String(),
      if (livekitRoom != null) 'livekit_room': livekitRoom,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Return a copy with the given fields replaced.
  ScheduleCall copyWith({
    int? id,
    int? scheduleId,
    int? patientId,
    int? providerId,
    String? status,
    DateTime? startedAt,
    DateTime? endedAt,
    String? livekitRoom,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
  }) {
    return ScheduleCall(
      id: id ?? this.id,
      scheduleId: scheduleId ?? this.scheduleId,
      patientId: patientId ?? this.patientId,
      providerId: providerId ?? this.providerId,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      livekitRoom: livekitRoom ?? this.livekitRoom,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ScheduleCall) return false;
    if (id != other.id) return false;
    if (scheduleId != other.scheduleId) return false;
    if (patientId != other.patientId) return false;
    if (providerId != other.providerId) return false;
    if (status != other.status) return false;
    if (startedAt != other.startedAt) return false;
    if (endedAt != other.endedAt) return false;
    if (livekitRoom != other.livekitRoom) return false;
    if (createdAt != other.createdAt) return false;
    if (metadata.length != other.metadata.length) return false;
    for (final entry in metadata.entries) {
      if (!other.metadata.containsKey(entry.key)) return false;
      if (other.metadata[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    var metaHash = 0;
    for (final entry in metadata.entries) {
      metaHash ^= Object.hash(entry.key, entry.value);
    }
    return Object.hash(
      id,
      scheduleId,
      patientId,
      providerId,
      status,
      startedAt,
      endedAt,
      livekitRoom,
      createdAt,
      metaHash,
    );
  }

  @override
  String toString() => 'ScheduleCall(id: $id, status: $status, '
      'scheduleId: $scheduleId, patientId: $patientId, '
      'providerId: $providerId, livekitRoom: $livekitRoom)';
}
