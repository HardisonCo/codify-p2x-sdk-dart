import 'package:meta/meta.dart';

/// A P2X **subproject** — the operational tenant that owns a domain, set
/// of users, branding, and feature flags.
///
/// Subprojects form a self-referencing hierarchy via [parentId]: agencies
/// may have child subprojects (e.g. a state Department of Health rolling
/// out a sub-program).
///
/// Mirrors the `subprojects` row returned by `GET /api/v1/subprojects/current`.
@immutable
class Subproject {
  /// Construct.
  const Subproject({
    required this.id,
    required this.slug,
    required this.name,
    required this.domain,
    this.kind,
    this.parentId,
    this.createdAt,
  });

  /// Decode from a JSON object. Permissive — unknown keys are ignored and
  /// missing optional fields fall back to `null`.
  factory Subproject.fromJson(Map<String, dynamic> json) {
    return Subproject(
      id: json['id'] as int,
      slug: json['slug'] as String,
      name: json['name'] as String,
      domain: json['domain'] as String,
      kind: json['kind'] as String?,
      parentId: json['parent_id'] as int?,
      createdAt: json['created_at'] is String
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  /// Primary key on the `subprojects` table.
  final int id;

  /// URL-safe slug — used in some legacy routes.
  final String slug;

  /// Human-readable display name (e.g. "Crohnie AI").
  final String name;

  /// Canonical hostname for the subproject (e.g. `crohnie.ai`). Sent on
  /// every authenticated API request as the `X-Domain` header.
  final String domain;

  /// One of `agency`, `health-system`, `ngo`, `business`, `platform`.
  /// Optional — older subprojects predate the field.
  final String? kind;

  /// Self-foreign-key for agency-style hierarchies (a sub-program belongs
  /// to a parent subproject). `null` for top-level subprojects.
  final int? parentId;

  /// Creation timestamp.
  final DateTime? createdAt;

  /// Encode to a JSON object. Symmetric with [Subproject.fromJson].
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'slug': slug,
      'name': name,
      'domain': domain,
      if (kind != null) 'kind': kind,
      if (parentId != null) 'parent_id': parentId,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  /// Return a copy with the given fields replaced.
  Subproject copyWith({
    int? id,
    String? slug,
    String? name,
    String? domain,
    String? kind,
    int? parentId,
    DateTime? createdAt,
  }) {
    return Subproject(
      id: id ?? this.id,
      slug: slug ?? this.slug,
      name: name ?? this.name,
      domain: domain ?? this.domain,
      kind: kind ?? this.kind,
      parentId: parentId ?? this.parentId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Subproject &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          slug == other.slug &&
          name == other.name &&
          domain == other.domain &&
          kind == other.kind &&
          parentId == other.parentId &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(
        id,
        slug,
        name,
        domain,
        kind,
        parentId,
        createdAt,
      );

  @override
  String toString() => 'Subproject(id: $id, slug: $slug, name: $name, '
      'domain: $domain, kind: $kind, parentId: $parentId, '
      'createdAt: $createdAt)';
}

/// Per-subproject feature flag map returned by `GET /api/v1/settings/features`.
///
/// Consumed by `gov` middleware on the server and by client apps that need
/// to gate UI on capability. Keys are stable strings
/// (e.g. `ibd_doctor_request`, `phm_labs`); values are booleans.
@immutable
class SubprojectFeatures {
  /// Construct.
  const SubprojectFeatures({required this.flags});

  /// Decode from a JSON object. The shape is `{ "flags": { ... } }`.
  /// Permissive — a missing or non-map `flags` decodes to an empty map.
  factory SubprojectFeatures.fromJson(Map<String, dynamic> json) {
    final raw = json['flags'];
    if (raw is! Map) {
      return const SubprojectFeatures(flags: <String, bool>{});
    }
    final out = <String, bool>{};
    raw.forEach((dynamic k, dynamic v) {
      if (k is String && v is bool) {
        out[k] = v;
      }
    });
    return SubprojectFeatures(flags: out);
  }

  /// The flag map. Stable keys; boolean values.
  final Map<String, bool> flags;

  /// Returns `true` if the named flag is set to `true`. Returns `false`
  /// when the flag is missing or explicitly `false`.
  bool isEnabled(String key) => flags[key] ?? false;

  /// Encode to a JSON object. Symmetric with [SubprojectFeatures.fromJson].
  Map<String, dynamic> toJson() => <String, dynamic>{'flags': flags};

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SubprojectFeatures) return false;
    if (flags.length != other.flags.length) return false;
    for (final entry in flags.entries) {
      if (other.flags[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    // Order-independent hash over the (key,value) pairs.
    var h = 0;
    for (final entry in flags.entries) {
      h ^= Object.hash(entry.key, entry.value);
    }
    return h;
  }

  @override
  String toString() => 'SubprojectFeatures(flags: $flags)';
}
