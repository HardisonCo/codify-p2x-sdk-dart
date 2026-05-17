import 'package:meta/meta.dart';

/// A P2X **Item** — a single canonical thing a subproject curates and a
/// user may consume, save, or favorite.
///
/// Items are the unit of catalog content across subprojects:
///   * NIO publishes **meals** (`type: 'meal'`) — recipes a user can add
///     to their food log.
///   * PHM publishes **care kits** (`type: 'kit'`) — clinician-curated
///     bundles of lab tests, supplements, or interventions.
///   * MOB publishes **exercises** (`type: 'exercise'`) — workout
///     templates with reps/sets metadata.
///
/// The [type] field is server-driven and free-form; the SDK doesn't
/// enforce an enum so new content types can roll out without an SDK
/// release. The [payload] map carries the type-specific shape (a meal's
/// macro breakdown, a kit's component list, an exercise's set scheme,
/// etc.) and is intentionally opaque to the SDK.
@immutable
class Item {
  /// Construct.
  const Item({
    required this.id,
    required this.subprojectId,
    required this.type,
    required this.name,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
    this.imageUrl,
    this.payload = const <String, dynamic>{},
    this.collectionId,
  });

  /// Decode from a JSON object. Permissive — a missing `payload` decodes
  /// to an empty map, and optional fields fall back to `null`.
  factory Item.fromJson(Map<String, dynamic> json) {
    final rawPayload = json['payload'];
    final payload = rawPayload is Map
        ? Map<String, dynamic>.from(rawPayload)
        : <String, dynamic>{};
    return Item(
      id: json['id'] as int,
      subprojectId: json['subproject_id'] as int,
      type: json['type'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      imageUrl: json['image_url'] as String?,
      payload: payload,
      collectionId: json['collection_id'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Primary key.
  final int id;

  /// The subproject this item belongs to (server-assigned from the
  /// `X-Domain` header at creation time).
  final int subprojectId;

  /// Stable type discriminator — e.g. `meal`, `kit`, `exercise`. Free-form;
  /// the SDK doesn't enforce the enum so new types flow through unchanged.
  final String type;

  /// Display name (already localized server-side).
  final String name;

  /// Display description (already localized server-side).
  final String description;

  /// Optional hero/thumbnail image URL.
  final String? imageUrl;

  /// Type-specific payload. Schema lives on the server; the SDK passes
  /// it through verbatim.
  final Map<String, dynamic> payload;

  /// Optional parent [Collection] this item belongs to.
  final int? collectionId;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Last-modified timestamp.
  final DateTime updatedAt;

  /// Encode to a JSON object. Symmetric with [Item.fromJson].
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'subproject_id': subprojectId,
      'type': type,
      'name': name,
      'description': description,
      if (imageUrl != null) 'image_url': imageUrl,
      'payload': payload,
      if (collectionId != null) 'collection_id': collectionId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Return a copy with the given fields replaced.
  Item copyWith({
    int? id,
    int? subprojectId,
    String? type,
    String? name,
    String? description,
    String? imageUrl,
    Map<String, dynamic>? payload,
    int? collectionId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Item(
      id: id ?? this.id,
      subprojectId: subprojectId ?? this.subprojectId,
      type: type ?? this.type,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      payload: payload ?? this.payload,
      collectionId: collectionId ?? this.collectionId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Item) return false;
    if (id != other.id) return false;
    if (subprojectId != other.subprojectId) return false;
    if (type != other.type) return false;
    if (name != other.name) return false;
    if (description != other.description) return false;
    if (imageUrl != other.imageUrl) return false;
    if (collectionId != other.collectionId) return false;
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
      name,
      description,
      imageUrl,
      payloadHash,
      collectionId,
      createdAt,
      updatedAt,
    );
  }

  @override
  String toString() => 'Item(id: $id, type: $type, name: $name, '
      'subprojectId: $subprojectId, collectionId: $collectionId)';
}

/// A P2X **Collection** — a named grouping of [Item]s a subproject
/// curates (e.g. NIO "Mediterranean Meal Plan", PHM "Diabetes Care Kit").
///
/// Collections are owned per-subproject; the `X-Domain` header at
/// creation time pins [subprojectId]. The server keeps [itemCount] up to
/// date as items are added or removed.
@immutable
class Collection {
  /// Construct.
  const Collection({
    required this.id,
    required this.subprojectId,
    required this.type,
    required this.name,
    required this.description,
    required this.itemCount,
    required this.createdAt,
    this.imageUrl,
  });

  /// Decode from a JSON object. Permissive — optional fields fall back
  /// to `null` or `0`.
  factory Collection.fromJson(Map<String, dynamic> json) {
    final rawCount = json['item_count'];
    final itemCount =
        rawCount is int ? rawCount : (rawCount is num ? rawCount.toInt() : 0);
    return Collection(
      id: json['id'] as int,
      subprojectId: json['subproject_id'] as int,
      type: json['type'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      imageUrl: json['image_url'] as String?,
      itemCount: itemCount,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Primary key.
  final int id;

  /// The subproject this collection belongs to.
  final int subprojectId;

  /// Type discriminator — typically matches the [Item.type] of the items
  /// it contains (`meal`, `kit`, `exercise`).
  final String type;

  /// Display name.
  final String name;

  /// Display description.
  final String description;

  /// Optional hero/thumbnail image URL.
  final String? imageUrl;

  /// Server-maintained count of items currently in the collection.
  final int itemCount;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Encode to a JSON object. Symmetric with [Collection.fromJson].
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'subproject_id': subprojectId,
      'type': type,
      'name': name,
      'description': description,
      if (imageUrl != null) 'image_url': imageUrl,
      'item_count': itemCount,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Return a copy with the given fields replaced.
  Collection copyWith({
    int? id,
    int? subprojectId,
    String? type,
    String? name,
    String? description,
    String? imageUrl,
    int? itemCount,
    DateTime? createdAt,
  }) {
    return Collection(
      id: id ?? this.id,
      subprojectId: subprojectId ?? this.subprojectId,
      type: type ?? this.type,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      itemCount: itemCount ?? this.itemCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Collection &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          subprojectId == other.subprojectId &&
          type == other.type &&
          name == other.name &&
          description == other.description &&
          imageUrl == other.imageUrl &&
          itemCount == other.itemCount &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(
        id,
        subprojectId,
        type,
        name,
        description,
        imageUrl,
        itemCount,
        createdAt,
      );

  @override
  String toString() => 'Collection(id: $id, type: $type, name: $name, '
      'itemCount: $itemCount, subprojectId: $subprojectId)';
}

/// A **UserItem** — the join row that says "user X saved/favorited
/// item Y". Used by NIO ("my saved meals"), PHM ("my saved kits"), and
/// MOB ("my saved exercises").
///
/// The server returns the join row alongside an optional fully-hydrated
/// nested [item] for list views that want to render without a second
/// request. Free-form [metadata] lets callers attach per-user context
/// (e.g. `{"folder": "breakfast"}`, `{"reminder_at": "08:00"}`).
@immutable
class UserItem {
  /// Construct.
  const UserItem({
    required this.id,
    required this.userId,
    required this.itemId,
    required this.savedAt,
    this.item,
    this.metadata = const <String, dynamic>{},
  });

  /// Decode from a JSON object. Permissive — missing optional fields
  /// fall back to `null`, and a missing `metadata` decodes to an empty
  /// map.
  factory UserItem.fromJson(Map<String, dynamic> json) {
    final rawMetadata = json['metadata'];
    final metadata = rawMetadata is Map
        ? Map<String, dynamic>.from(rawMetadata)
        : <String, dynamic>{};
    final rawItem = json['item'];
    return UserItem(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      itemId: json['item_id'] as int,
      item: rawItem is Map
          ? Item.fromJson(Map<String, dynamic>.from(rawItem))
          : null,
      metadata: metadata,
      savedAt: DateTime.parse(json['saved_at'] as String),
    );
  }

  /// Primary key of the join row.
  final int id;

  /// The user who saved the item.
  final int userId;

  /// The item that was saved.
  final int itemId;

  /// The nested [Item], when the server eager-loaded it. `null` on
  /// endpoints that return the join row only.
  final Item? item;

  /// Free-form per-user metadata attached to the save (folder name,
  /// reminder time, notes, etc.).
  final Map<String, dynamic> metadata;

  /// When the user saved the item.
  final DateTime savedAt;

  /// Encode to a JSON object. Symmetric with [UserItem.fromJson].
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'user_id': userId,
      'item_id': itemId,
      if (item != null) 'item': item!.toJson(),
      'metadata': metadata,
      'saved_at': savedAt.toIso8601String(),
    };
  }

  /// Return a copy with the given fields replaced.
  UserItem copyWith({
    int? id,
    int? userId,
    int? itemId,
    Item? item,
    Map<String, dynamic>? metadata,
    DateTime? savedAt,
  }) {
    return UserItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      itemId: itemId ?? this.itemId,
      item: item ?? this.item,
      metadata: metadata ?? this.metadata,
      savedAt: savedAt ?? this.savedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! UserItem) return false;
    if (id != other.id) return false;
    if (userId != other.userId) return false;
    if (itemId != other.itemId) return false;
    if (item != other.item) return false;
    if (savedAt != other.savedAt) return false;
    if (metadata.length != other.metadata.length) return false;
    for (final entry in metadata.entries) {
      if (!other.metadata.containsKey(entry.key)) return false;
      if (other.metadata[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    var metadataHash = 0;
    for (final entry in metadata.entries) {
      metadataHash ^= Object.hash(entry.key, entry.value);
    }
    return Object.hash(
      id,
      userId,
      itemId,
      item,
      metadataHash,
      savedAt,
    );
  }

  @override
  String toString() => 'UserItem(id: $id, userId: $userId, '
      'itemId: $itemId, savedAt: $savedAt)';
}
