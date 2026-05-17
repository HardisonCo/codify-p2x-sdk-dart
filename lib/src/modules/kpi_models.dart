import 'package:meta/meta.dart';

/// A single point-in-time KPI reading.
///
/// KPIs are the simplest measurement primitive in P2X: one [key], one
/// numeric [value], one [unit], a timestamp, and (server-assigned) which
/// subproject owns it. NIO writes daily-calorie snapshots from food
/// scans; MOB v2 writes water/weight/step snapshots from the activity
/// dashboard; IBD writes adherence snapshots from doctor reviews.
@immutable
class KpiSnapshot {
  /// Construct.
  const KpiSnapshot({
    required this.key,
    required this.value,
    required this.unit,
    required this.recordedAt,
    this.subprojectId,
  });

  /// Decode from a JSON object. Permissive — integer [value]s are coerced
  /// to `double` so callers don't have to guess the wire shape.
  factory KpiSnapshot.fromJson(Map<String, dynamic> json) {
    final rawValue = json['value'];
    final value = rawValue is num
        ? rawValue.toDouble()
        : double.parse(rawValue.toString());
    return KpiSnapshot(
      key: json['key'] as String,
      value: value,
      unit: json['unit'] as String,
      recordedAt: DateTime.parse(json['recorded_at'] as String),
      subprojectId: json['subproject_id'] as int?,
    );
  }

  /// Stable KPI key (e.g. `daily-calories`, `water-intake`, `weight`,
  /// `steps`). Matches a row in the server's `kpi_definitions` table.
  final String key;

  /// The numeric reading.
  final double value;

  /// Unit string (e.g. `kcal`, `ml`, `kg`, `count`). Free-form — the
  /// server stores it verbatim, the UI renders it.
  final String unit;

  /// When the reading was taken. Client-supplied so back-dated
  /// retroactive logging works.
  final DateTime recordedAt;

  /// Subproject this KPI belongs to. Server-assigned from the `X-Domain`
  /// header.
  final int? subprojectId;

  /// Encode to a JSON object. Symmetric with [KpiSnapshot.fromJson].
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'key': key,
      'value': value,
      'unit': unit,
      'recorded_at': recordedAt.toIso8601String(),
      if (subprojectId != null) 'subproject_id': subprojectId,
    };
  }

  /// Return a copy with the given fields replaced.
  KpiSnapshot copyWith({
    String? key,
    double? value,
    String? unit,
    DateTime? recordedAt,
    int? subprojectId,
  }) {
    return KpiSnapshot(
      key: key ?? this.key,
      value: value ?? this.value,
      unit: unit ?? this.unit,
      recordedAt: recordedAt ?? this.recordedAt,
      subprojectId: subprojectId ?? this.subprojectId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KpiSnapshot &&
          runtimeType == other.runtimeType &&
          key == other.key &&
          value == other.value &&
          unit == other.unit &&
          recordedAt == other.recordedAt &&
          subprojectId == other.subprojectId;

  @override
  int get hashCode => Object.hash(key, value, unit, recordedAt, subprojectId);

  @override
  String toString() => 'KpiSnapshot(key: $key, value: $value, unit: $unit, '
      'recordedAt: $recordedAt, subprojectId: $subprojectId)';
}
