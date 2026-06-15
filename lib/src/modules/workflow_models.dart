import 'package:meta/meta.dart';

/// A per-tenant **canonical-pipe → provider override** row — the
/// `subproject_pipe_config` record the `CanonicalPipeRegistry` inspects ahead
/// of the `pipe_providers` fallback when resolving a pipe.
///
/// Decoded from `SubprojectPipeConfigResource::toArray()` (the wire shape of
/// the SuperAdmin-gated `/api/admin/subproject/{id}/pipe-config` surface in
/// `Modules/Workflow`). `pipe_name` is the eager-loaded canonical pipe name
/// (`canonical_pipes.name`) and may be `null` when the relation was not
/// loaded. `provider_class` is the fully-qualified provider FQN, which the
/// admin API allows to be cleared (set to `null`) without deleting the row.
@immutable
class SubprojectPipeConfig {
  /// Construct.
  const SubprojectPipeConfig({
    required this.id,
    required this.subprojectId,
    required this.canonicalPipeId,
    this.pipeName,
    this.providerClass,
    this.settings = const <String, dynamic>{},
    this.isActive = true,
    this.effectiveFrom,
    this.createdAt,
    this.updatedAt,
  });

  /// Decode from a `SubprojectPipeConfigResource` body.
  factory SubprojectPipeConfig.fromJson(Map<String, dynamic> json) =>
      SubprojectPipeConfig(
        id: _asInt(json['id']) ?? 0,
        subprojectId: _asInt(json['subproject_id']) ?? 0,
        canonicalPipeId: _asInt(json['canonical_pipe_id']) ?? 0,
        pipeName: json['pipe_name'] as String?,
        providerClass: json['provider_class'] as String?,
        settings: json['settings'] is Map
            ? Map<String, dynamic>.from(json['settings'] as Map)
            : const <String, dynamic>{},
        isActive: json['is_active'] == null || json['is_active'] == true,
        effectiveFrom: _asDate(json['effective_from']),
        createdAt: _asDate(json['created_at']),
        updatedAt: _asDate(json['updated_at']),
      );

  /// Primary key (`subproject_pipe_config.id`).
  final int id;

  /// FK → the owning tenant subproject.
  final int subprojectId;

  /// FK → `canonical_pipes.id`.
  final int canonicalPipeId;

  /// The canonical pipe name (eager-loaded). `null` if the relation was
  /// not loaded server-side.
  final String? pipeName;

  /// The fully-qualified provider class FQN. `null` when the override has
  /// been cleared but the row retained (the UI keeps a stable row id).
  final String? providerClass;

  /// Provider-specific settings blob.
  final Map<String, dynamic> settings;

  /// Whether this override is active.
  final bool isActive;

  /// In-flight binding stamp — bumped to `now()` on every admin mutation.
  final DateTime? effectiveFrom;

  /// Creation timestamp.
  final DateTime? createdAt;

  /// Last-update timestamp.
  final DateTime? updatedAt;

  static int? _asInt(Object? v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static DateTime? _asDate(Object? v) =>
      v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;
}
