import 'package:meta/meta.dart';

/// A single timestamped location point sampled during a run.
///
/// MOB v2 emits these continuously while a run is in-progress and
/// batches them via `ActivityClient.appendLocations`. After the run
/// finishes the full ordered list is persisted on the
/// [RunActivity.route] field.
@immutable
class RunLocationPoint {
  /// Construct.
  const RunLocationPoint({
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    this.altitudeMeters,
    this.accuracyMeters,
  });

  /// Decode from a JSON object. Permissive — integer numerics are
  /// coerced to `double`, optional fields fall back to `null`.
  factory RunLocationPoint.fromJson(Map<String, dynamic> json) {
    return RunLocationPoint(
      latitude: _readDouble(json['latitude']),
      longitude: _readDouble(json['longitude']),
      altitudeMeters: _readNullableDouble(json['altitude_meters']),
      accuracyMeters: _readNullableDouble(json['accuracy_meters']),
      recordedAt: DateTime.parse(json['recorded_at'] as String),
    );
  }

  /// WGS-84 latitude in degrees.
  final double latitude;

  /// WGS-84 longitude in degrees.
  final double longitude;

  /// Optional altitude in meters above sea level.
  final double? altitudeMeters;

  /// Optional horizontal accuracy in meters as reported by the device.
  final double? accuracyMeters;

  /// When the point was sampled.
  final DateTime recordedAt;

  /// Encode to a JSON object. Symmetric with [RunLocationPoint.fromJson].
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
      if (altitudeMeters != null) 'altitude_meters': altitudeMeters,
      if (accuracyMeters != null) 'accuracy_meters': accuracyMeters,
      'recorded_at': recordedAt.toIso8601String(),
    };
  }

  /// Return a copy with the given fields replaced.
  RunLocationPoint copyWith({
    double? latitude,
    double? longitude,
    double? altitudeMeters,
    double? accuracyMeters,
    DateTime? recordedAt,
  }) {
    return RunLocationPoint(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitudeMeters: altitudeMeters ?? this.altitudeMeters,
      accuracyMeters: accuracyMeters ?? this.accuracyMeters,
      recordedAt: recordedAt ?? this.recordedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RunLocationPoint &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          altitudeMeters == other.altitudeMeters &&
          accuracyMeters == other.accuracyMeters &&
          recordedAt == other.recordedAt;

  @override
  int get hashCode => Object.hash(
        latitude,
        longitude,
        altitudeMeters,
        accuracyMeters,
        recordedAt,
      );

  @override
  String toString() =>
      'RunLocationPoint(latitude: $latitude, longitude: $longitude, '
      'altitudeMeters: $altitudeMeters, accuracyMeters: $accuracyMeters, '
      'recordedAt: $recordedAt)';
}

/// A completed (or in-progress) **run** activity.
///
/// MOB v2 writes one row per run via `ActivityClient.logRun`. The
/// `duration` field is exchanged on the wire as `duration_seconds`
/// (int) but exposed on the Dart side as a `Duration` for ergonomics.
@immutable
class RunActivity {
  /// Construct.
  const RunActivity({
    required this.distanceMeters,
    required this.duration,
    required this.startedAt,
    required this.route,
    this.id,
    this.avgSpeedMps,
    this.caloriesKcal,
    this.endedAt,
    this.source,
    this.subprojectId,
  });

  /// Decode from a JSON object. Permissive — integer numerics are
  /// coerced to `double`, optional fields fall back to `null`, missing
  /// route decodes to an empty list.
  factory RunActivity.fromJson(Map<String, dynamic> json) {
    final rawRoute = json['route'];
    final route = <RunLocationPoint>[];
    if (rawRoute is List) {
      for (final raw in rawRoute) {
        if (raw is Map) {
          route.add(RunLocationPoint.fromJson(Map<String, dynamic>.from(raw)));
        }
      }
    }
    return RunActivity(
      id: json['id'] as int?,
      distanceMeters: _readDouble(json['distance_meters']),
      duration: Duration(seconds: json['duration_seconds'] as int),
      avgSpeedMps: _readNullableDouble(json['avg_speed_mps']),
      caloriesKcal: json['calories_kcal'] as int?,
      startedAt: DateTime.parse(json['started_at'] as String),
      endedAt: json['ended_at'] is String
          ? DateTime.parse(json['ended_at'] as String)
          : null,
      route: route,
      source: json['source'] as String?,
      subprojectId: json['subproject_id'] as int?,
    );
  }

  /// Primary key. `null` before the row has been persisted server-side.
  final int? id;

  /// Total distance covered, in meters.
  final double distanceMeters;

  /// Elapsed time. Serialized as int seconds on the wire.
  final Duration duration;

  /// Optional average speed in meters per second. Nullable for indoor
  /// or treadmill modes where speed isn't meaningful.
  final double? avgSpeedMps;

  /// Optional energy burned in kilocalories.
  final int? caloriesKcal;

  /// When the run started.
  final DateTime startedAt;

  /// When the run ended. `null` while the run is still in progress.
  final DateTime? endedAt;

  /// Ordered, timestamped GPS points. Empty for indoor / treadmill runs.
  final List<RunLocationPoint> route;

  /// Optional source identifier — one of `mob`, `mob-import`, `manual`.
  final String? source;

  /// Subproject this run belongs to. Server-assigned from the
  /// `X-Domain` header.
  final int? subprojectId;

  /// Encode to a JSON object. Symmetric with [RunActivity.fromJson].
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (id != null) 'id': id,
      'distance_meters': distanceMeters,
      'duration_seconds': duration.inSeconds,
      if (avgSpeedMps != null) 'avg_speed_mps': avgSpeedMps,
      if (caloriesKcal != null) 'calories_kcal': caloriesKcal,
      'started_at': startedAt.toIso8601String(),
      if (endedAt != null) 'ended_at': endedAt!.toIso8601String(),
      'route': route.map((p) => p.toJson()).toList(),
      if (source != null) 'source': source,
      if (subprojectId != null) 'subproject_id': subprojectId,
    };
  }

  /// Return a copy with the given fields replaced.
  RunActivity copyWith({
    int? id,
    double? distanceMeters,
    Duration? duration,
    double? avgSpeedMps,
    int? caloriesKcal,
    DateTime? startedAt,
    DateTime? endedAt,
    List<RunLocationPoint>? route,
    String? source,
    int? subprojectId,
  }) {
    return RunActivity(
      id: id ?? this.id,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      duration: duration ?? this.duration,
      avgSpeedMps: avgSpeedMps ?? this.avgSpeedMps,
      caloriesKcal: caloriesKcal ?? this.caloriesKcal,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      route: route ?? this.route,
      source: source ?? this.source,
      subprojectId: subprojectId ?? this.subprojectId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! RunActivity) return false;
    if (id != other.id) return false;
    if (distanceMeters != other.distanceMeters) return false;
    if (duration != other.duration) return false;
    if (avgSpeedMps != other.avgSpeedMps) return false;
    if (caloriesKcal != other.caloriesKcal) return false;
    if (startedAt != other.startedAt) return false;
    if (endedAt != other.endedAt) return false;
    if (source != other.source) return false;
    if (subprojectId != other.subprojectId) return false;
    if (route.length != other.route.length) return false;
    for (var i = 0; i < route.length; i++) {
      if (route[i] != other.route[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    var routeHash = 0;
    for (final p in route) {
      routeHash ^= p.hashCode;
    }
    return Object.hash(
      id,
      distanceMeters,
      duration,
      avgSpeedMps,
      caloriesKcal,
      startedAt,
      endedAt,
      routeHash,
      source,
      subprojectId,
    );
  }

  @override
  String toString() => 'RunActivity(id: $id, distanceMeters: $distanceMeters, '
      'duration: $duration, startedAt: $startedAt, endedAt: $endedAt, '
      'source: $source, subprojectId: $subprojectId, '
      'routePoints: ${route.length})';
}

double _readDouble(Object? raw) {
  if (raw is num) return raw.toDouble();
  return double.parse(raw.toString());
}

double? _readNullableDouble(Object? raw) {
  if (raw == null) return null;
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw.toString());
}
