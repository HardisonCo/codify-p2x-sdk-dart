import 'package:ycaas_flutter_sdk/src/client/p2x_client.dart';
import 'package:ycaas_flutter_sdk/src/modules/items_models.dart';

/// Per-domain client for the **Items** module.
///
/// Items are the cross-subproject catalog unit: NIO meal plans, PHM care
/// kits, MOB exercise templates, etc. This client mirrors the TS SDK's
/// `ItemsModuleApiClient` and covers three resource families:
///
///   * **Items** — `/api/items`: CRUD on the canonical catalog entry.
///   * **Collections** — `/api/collections`: CRUD on named groupings of
///     items.
///   * **User Items** — `/api/user-items`: the per-user save/favorite
///     join row (read-mostly; new saves via [saveUserItem]).
///
/// All writes flow through `_client.request<T>(...)` so the
/// SDK-mandated interceptor stack (auth, X-Domain, method override,
/// idempotency, error normalization) is applied uniformly. PUT calls
/// are transparently rewritten to `POST + ?_method=PUT` by the
/// `MethodOverrideInterceptor`.
class ItemsClient {
  /// Construct with a reference to the shared [P2xClient].
  ItemsClient(this._client);

  final P2xClient _client;

  // ───────────────────────── Items ─────────────────────────

  /// `GET /api/items?type=<type>&collection=<collection>` — list items
  /// for the current subproject, optionally filtered by [type]
  /// (e.g. `meal`, `kit`, `exercise`) and/or [collection] id.
  Future<List<Item>> list({String? type, String? collection}) {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/items',
        queryParameters: <String, dynamic>{
          if (type != null) 'type': type,
          if (collection != null) 'collection': collection,
        },
      );
      final body = response.data ?? const <String, dynamic>{};
      final raw = body['data'];
      if (raw is! List) return const <Item>[];
      return raw
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => Item.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    });
  }

  /// `POST /api/items` — create a new [Item].
  ///
  /// The server returns the canonical row including its assigned `id`,
  /// `subproject_id`, `created_at`, and `updated_at`. The
  /// `IdempotencyInterceptor` attaches a fresh `Idempotency-Key` so
  /// double-submits collapse to a single row server-side.
  Future<Item> create({
    required String type,
    required String name,
    required String description,
    String? imageUrl,
    Map<String, dynamic>? payload,
    int? collectionId,
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/items',
        data: <String, dynamic>{
          'type': type,
          'name': name,
          'description': description,
          if (imageUrl != null) 'image_url': imageUrl,
          if (payload != null) 'payload': payload,
          if (collectionId != null) 'collection_id': collectionId,
        },
      );
      final body = response.data ?? const <String, dynamic>{};
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError('POST /items returned no "data" object.');
      }
      return Item.fromJson(data);
    });
  }

  /// `GET /api/items/<id>` — fetch one [Item] by primary key.
  Future<Item> get(int id) {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/items/$id',
      );
      final body = response.data ?? const <String, dynamic>{};
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError('GET /items/$id returned no "data" object.');
      }
      return Item.fromJson(data);
    });
  }

  /// `PUT /api/items/<id>` — update an existing [Item]. Only the fields
  /// supplied are sent; the server merges them into the existing row.
  ///
  /// The `MethodOverrideInterceptor` transparently rewrites this to
  /// `POST /api/items/<id>?_method=PUT` on the wire so legacy
  /// load-balancers that strip PUT/PATCH don't break the request.
  Future<Item> update(
    int id, {
    String? type,
    String? name,
    String? description,
    String? imageUrl,
    Map<String, dynamic>? payload,
    int? collectionId,
  }) {
    return _client.request(() async {
      final response = await _client.dio.put<Map<String, dynamic>>(
        '/items/$id',
        data: <String, dynamic>{
          if (type != null) 'type': type,
          if (name != null) 'name': name,
          if (description != null) 'description': description,
          if (imageUrl != null) 'image_url': imageUrl,
          if (payload != null) 'payload': payload,
          if (collectionId != null) 'collection_id': collectionId,
        },
      );
      final body = response.data ?? const <String, dynamic>{};
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError('PUT /items/$id returned no "data" object.');
      }
      return Item.fromJson(data);
    });
  }

  /// `DELETE /api/items/<id>` — permanently delete an [Item].
  Future<void> destroy(int id) {
    return _client.request(() async {
      await _client.dio.delete<dynamic>('/items/$id');
    });
  }

  // ──────────────────────── Collections ────────────────────────

  /// `GET /api/collections?type=<type>` — list collections for the
  /// current subproject, optionally filtered by [type].
  Future<List<Collection>> listCollections({String? type}) {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/collections',
        queryParameters: <String, dynamic>{
          if (type != null) 'type': type,
        },
      );
      final body = response.data ?? const <String, dynamic>{};
      final raw = body['data'];
      if (raw is! List) return const <Collection>[];
      return raw
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => Collection.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    });
  }

  /// `POST /api/collections` — create a new [Collection]. Idempotent via
  /// the auto-injected `Idempotency-Key` header.
  Future<Collection> createCollection({
    required String type,
    required String name,
    required String description,
    String? imageUrl,
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/collections',
        data: <String, dynamic>{
          'type': type,
          'name': name,
          'description': description,
          if (imageUrl != null) 'image_url': imageUrl,
        },
      );
      final body = response.data ?? const <String, dynamic>{};
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError('POST /collections returned no "data" object.');
      }
      return Collection.fromJson(data);
    });
  }

  /// `GET /api/collections/<id>` — fetch one [Collection] by primary key.
  Future<Collection> getCollection(int id) {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/collections/$id',
      );
      final body = response.data ?? const <String, dynamic>{};
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError('GET /collections/$id returned no "data" object.');
      }
      return Collection.fromJson(data);
    });
  }

  /// `PUT /api/collections/<id>` — update an existing [Collection].
  ///
  /// Rewritten to `POST /api/collections/<id>?_method=PUT` on the wire
  /// by the `MethodOverrideInterceptor`.
  Future<Collection> updateCollection(
    int id, {
    String? type,
    String? name,
    String? description,
    String? imageUrl,
  }) {
    return _client.request(() async {
      final response = await _client.dio.put<Map<String, dynamic>>(
        '/collections/$id',
        data: <String, dynamic>{
          if (type != null) 'type': type,
          if (name != null) 'name': name,
          if (description != null) 'description': description,
          if (imageUrl != null) 'image_url': imageUrl,
        },
      );
      final body = response.data ?? const <String, dynamic>{};
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError('PUT /collections/$id returned no "data" object.');
      }
      return Collection.fromJson(data);
    });
  }

  /// `DELETE /api/collections/<id>` — permanently delete a [Collection].
  Future<void> destroyCollection(int id) {
    return _client.request(() async {
      await _client.dio.delete<dynamic>('/collections/$id');
    });
  }

  // ──────────────────────── User Items ────────────────────────

  /// `GET /api/user-items?type=<type>` — list the current user's saved
  /// items, optionally filtered by the underlying [Item.type].
  Future<List<UserItem>> userItems({String? type}) {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/user-items',
        queryParameters: <String, dynamic>{
          if (type != null) 'type': type,
        },
      );
      final body = response.data ?? const <String, dynamic>{};
      final raw = body['data'];
      if (raw is! List) return const <UserItem>[];
      return raw
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => UserItem.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    });
  }

  /// `POST /api/user-items` — save/favorite an [Item] for the current
  /// user, optionally annotating the save with free-form [metadata]
  /// (e.g. `{"folder": "breakfast"}`). Idempotent via the auto-injected
  /// `Idempotency-Key` header.
  Future<UserItem> saveUserItem({
    required int itemId,
    Map<String, dynamic>? metadata,
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/user-items',
        data: <String, dynamic>{
          'item_id': itemId,
          if (metadata != null) 'metadata': metadata,
        },
      );
      final body = response.data ?? const <String, dynamic>{};
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError('POST /user-items returned no "data" object.');
      }
      return UserItem.fromJson(data);
    });
  }
}
