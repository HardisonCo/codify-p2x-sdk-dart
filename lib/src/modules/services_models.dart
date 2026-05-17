import 'package:meta/meta.dart';

import 'package:codify_p2x_sdk/src/modules/schedule_models.dart';

// Re-export Schedule and ScheduleCall — the Services API hands these
// back from /slots and /reserve and we want a single canonical type.
export 'package:codify_p2x_sdk/src/modules/schedule_models.dart'
    show Schedule, ScheduleCall;

/// A bookable **Service** in the P2X services catalog.
///
/// Services describe what a subproject offers (e.g. "30-minute IBD
/// consult", "PHM lab panel — basic"). The catalog is server-owned and
/// the SDK reads it via three endpoints:
///
///   * `GET  /api/services/resolve`     — look up by `subdomain` or `slug`
///   * `GET  /api/services/<id>/slots`  — available [Schedule] windows
///   * `POST /api/services/<id>/reserve` — reserve a slot → [ScheduleCall]
///
/// Pricing is always in **integer minor units** (`priceCents`) to keep
/// rounding out of the wire format.
@immutable
class Service {
  /// Construct.
  const Service({
    required this.id,
    required this.subprojectId,
    required this.slug,
    required this.name,
    required this.description,
    required this.durationMinutes,
    required this.priceCents,
    required this.currency,
    required this.providerId,
    required this.isActive,
    required this.createdAt,
    this.metadata = const <String, dynamic>{},
  });

  /// Decode from a JSON object. Permissive — missing `metadata`
  /// decodes to an empty map.
  factory Service.fromJson(Map<String, dynamic> json) {
    final rawMeta = json['metadata'];
    final metadata = rawMeta is Map
        ? Map<String, dynamic>.from(rawMeta)
        : <String, dynamic>{};
    return Service(
      id: json['id'] as int,
      subprojectId: json['subproject_id'] as int,
      slug: json['slug'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      durationMinutes: json['duration_minutes'] as int,
      priceCents: json['price_cents'] as int,
      currency: json['currency'] as String,
      providerId: json['provider_id'] as int,
      metadata: metadata,
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Primary key.
  final int id;

  /// Subproject this Service belongs to.
  final int subprojectId;

  /// Stable URL-safe identifier — e.g. `ibd-consult-30min`.
  final String slug;

  /// Human-readable name.
  final String name;

  /// Long-form description (markdown allowed).
  final String description;

  /// Service duration in minutes.
  final int durationMinutes;

  /// Price in the smallest minor unit of [currency]
  /// (e.g. `7500` = `$75.00` for `USD`).
  final int priceCents;

  /// Currency code (ISO-4217). Typically `USD`.
  final String currency;

  /// The provider that fulfils the service.
  final int providerId;

  /// Optional structured metadata.
  final Map<String, dynamic> metadata;

  /// Whether the service is currently bookable.
  final bool isActive;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Encode to a JSON object. Symmetric with [Service.fromJson].
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'subproject_id': subprojectId,
      'slug': slug,
      'name': name,
      'description': description,
      'duration_minutes': durationMinutes,
      'price_cents': priceCents,
      'currency': currency,
      'provider_id': providerId,
      'metadata': metadata,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Return a copy with the given fields replaced.
  Service copyWith({
    int? id,
    int? subprojectId,
    String? slug,
    String? name,
    String? description,
    int? durationMinutes,
    int? priceCents,
    String? currency,
    int? providerId,
    Map<String, dynamic>? metadata,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Service(
      id: id ?? this.id,
      subprojectId: subprojectId ?? this.subprojectId,
      slug: slug ?? this.slug,
      name: name ?? this.name,
      description: description ?? this.description,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      priceCents: priceCents ?? this.priceCents,
      currency: currency ?? this.currency,
      providerId: providerId ?? this.providerId,
      metadata: metadata ?? this.metadata,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Service) return false;
    if (id != other.id) return false;
    if (subprojectId != other.subprojectId) return false;
    if (slug != other.slug) return false;
    if (name != other.name) return false;
    if (description != other.description) return false;
    if (durationMinutes != other.durationMinutes) return false;
    if (priceCents != other.priceCents) return false;
    if (currency != other.currency) return false;
    if (providerId != other.providerId) return false;
    if (isActive != other.isActive) return false;
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
      subprojectId,
      slug,
      name,
      description,
      durationMinutes,
      priceCents,
      currency,
      providerId,
      isActive,
      createdAt,
      metaHash,
    );
  }

  @override
  String toString() => 'Service(id: $id, slug: $slug, name: $name, '
      'durationMinutes: $durationMinutes, '
      'priceCents: $priceCents $currency, isActive: $isActive)';
}
