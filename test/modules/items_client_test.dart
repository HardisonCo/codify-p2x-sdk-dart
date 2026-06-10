// Contract tests for ItemsClient.
//
// Covers all 12 endpoints in three resource families:
//
//   Items:
//     GET    /api/items                          — list
//     POST   /api/items                          — create (idempotent)
//     GET    /api/items/<id>                     — get
//     PUT    /api/items/<id>                     — update (POST + _method=PUT)
//     DELETE /api/items/<id>                     — destroy
//
//   Collections:
//     GET    /api/collections                    — list
//     POST   /api/collections                    — create (idempotent)
//     GET    /api/collections/<id>               — get
//     PUT    /api/collections/<id>               — update
//     DELETE /api/collections/<id>               — destroy
//
//   User items:
//     GET  /api/user-items                       — list user-saved items
//     POST /api/user-items                       — save (idempotent)

import 'package:ycaas_flutter_sdk/ycaas_flutter_sdk.dart';
import 'package:ycaas_flutter_sdk/src/modules/items_client.dart';
import 'package:ycaas_flutter_sdk/src/modules/items_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

/// Lower-case UUID v4 regex (Idempotency-Key auto-generation contract).
final RegExp _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

/// Capture interceptor — records the outbound request headers and method
/// after the SDK interceptor stack has run. Installed in the test setup
/// (after the production interceptors) so assertions can verify the
/// auto-injected `Idempotency-Key` header on real client method calls.
class _CaptureInterceptor extends Interceptor {
  final List<RequestOptions> captured = <RequestOptions>[];

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    captured.add(options);
    handler.next(options);
  }
}

void main() {
  late P2xClient base;
  late DioAdapter adapter;
  late ItemsClient items;
  late _CaptureInterceptor capture;

  Map<String, dynamic> sampleItem({
    int id = 11,
    String type = 'meal',
    String name = 'Greek Yogurt Bowl',
    int? collectionId,
  }) =>
      <String, dynamic>{
        'id': id,
        'subproject_id': 3,
        'type': type,
        'name': name,
        'description': 'Yogurt, berries, granola.',
        'image_url': 'https://cdn.example.com/yogurt.jpg',
        'payload': <String, dynamic>{'calories': 320},
        if (collectionId != null) 'collection_id': collectionId,
        'created_at': '2026-05-01T08:00:00Z',
        'updated_at': '2026-05-01T08:00:00Z',
      };

  Map<String, dynamic> sampleCollection({int id = 7}) => <String, dynamic>{
        'id': id,
        'subproject_id': 3,
        'type': 'meal',
        'name': 'Mediterranean Meal Plan',
        'description': '7-day plan.',
        'image_url': 'https://cdn.example.com/plan.jpg',
        'item_count': 21,
        'created_at': '2026-05-01T08:00:00Z',
      };

  Map<String, dynamic> sampleUserItem({int id = 100, int itemId = 11}) =>
      <String, dynamic>{
        'id': id,
        'user_id': 42,
        'item_id': itemId,
        'metadata': <String, dynamic>{'folder': 'breakfast'},
        'saved_at': '2026-05-01T08:00:00Z',
      };

  setUp(() {
    base = P2xClient(
      config: P2xClientConfig(
        baseUrl: 'https://api.project20x.com/api',
        getToken: () => 'tok-abc',
        getDomain: () => 'nutriscan.codify.ai',
      ),
    );
    capture = _CaptureInterceptor();
    // Append capture after the production stack so it sees the headers
    // after idempotency/method-override have run.
    base.dio.interceptors.add(capture);
    adapter = DioAdapter(dio: base.dio);
    items = ItemsClient(base);
  });

  // ──────────────────────── Items ────────────────────────

  group('ItemsClient.list', () {
    test('GETs /items with no query params by default', () async {
      adapter.onGet(
        '/items',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[
            sampleItem(),
            sampleItem(id: 12, name: 'Salmon Salad'),
          ],
        }),
      );

      final list = await items.list();

      expect(list, hasLength(2));
      expect(list.first.id, 11);
      expect(list.last.name, 'Salmon Salad');
    });

    test('GETs /items filtered by type and collection', () async {
      adapter.onGet(
        '/items',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[sampleItem(collectionId: 7)],
        }),
        queryParameters: <String, dynamic>{
          'type': 'meal',
          'collection': '7',
        },
      );

      final list = await items.list(type: 'meal', collection: '7');

      expect(list, hasLength(1));
      expect(list.first.collectionId, 7);
    });

    test('returns empty list when server returns no rows', () async {
      adapter.onGet(
        '/items',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[],
        }),
      );

      final list = await items.list();
      expect(list, isEmpty);
    });
  });

  group('ItemsClient.create', () {
    test('POSTs /items and returns the persisted Item', () async {
      adapter.onPost(
        '/items',
        (req) => req.reply(201, <String, dynamic>{'data': sampleItem(id: 42)}),
        data: <String, dynamic>{
          'type': 'meal',
          'name': 'Greek Yogurt Bowl',
          'description': 'Yogurt, berries, granola.',
          'payload': <String, dynamic>{'calories': 320},
        },
      );

      final created = await items.create(
        type: 'meal',
        name: 'Greek Yogurt Bowl',
        description: 'Yogurt, berries, granola.',
        payload: <String, dynamic>{'calories': 320},
      );

      expect(created, isA<Item>());
      expect(created.id, 42);
      expect(created.type, 'meal');
    });

    test('POST /items auto-injects an Idempotency-Key (UUID v4)', () async {
      adapter.onPost(
        '/items',
        (req) => req.reply(201, <String, dynamic>{'data': sampleItem()}),
        data: Matchers.any,
      );

      await items.create(
        type: 'meal',
        name: 'Greek Yogurt Bowl',
        description: 'Yogurt, berries, granola.',
      );

      final last = capture.captured.last;
      expect(last.method, 'POST');
      final key = last.headers['Idempotency-Key'] as String?;
      expect(key, isNotNull);
      expect(
        _uuidV4.hasMatch(key!),
        isTrue,
        reason: 'Expected UUID v4 but got "$key"',
      );
    });

    test('POST /items throws ValidationException on missing name', () async {
      adapter.onPost(
        '/items',
        (req) => req.reply(422, <String, dynamic>{
          'message': 'The given data was invalid.',
          'errors': <String, dynamic>{
            'name': <String>['The name field is required.'],
          },
        }),
        data: Matchers.any,
      );

      Object? caught;
      try {
        await items.create(
          type: 'meal',
          name: '',
          description: 'd',
        );
      } catch (e) {
        caught = e;
      }
      expect(caught, isA<ValidationException>());
      expect(
        (caught! as ValidationException).errors['name'],
        <String>['The name field is required.'],
      );
    });
  });

  group('ItemsClient.get', () {
    test('GETs /items/<id> and returns one Item', () async {
      adapter.onGet(
        '/items/17',
        (req) => req.reply(200, <String, dynamic>{
          'data': sampleItem(id: 17),
        }),
      );

      final item = await items.get(17);

      expect(item, isA<Item>());
      expect(item.id, 17);
    });
  });

  group('ItemsClient.update', () {
    test('PUTs /items/<id> (rewritten to POST + _method=PUT)', () async {
      adapter.onPost(
        '/items/17',
        (req) => req.reply(200, <String, dynamic>{
          'data': sampleItem(id: 17, name: 'Updated Bowl'),
        }),
        data: Matchers.any,
        queryParameters: <String, dynamic>{'_method': 'PUT'},
      );

      final updated = await items.update(17, name: 'Updated Bowl');

      expect(updated.name, 'Updated Bowl');

      final last = capture.captured.last;
      // MethodOverrideInterceptor rewrites PUT → POST + _method=PUT.
      expect(last.method, 'POST');
      expect(last.queryParameters['_method'], 'PUT');
    });
  });

  group('ItemsClient.destroy', () {
    test('DELETEs /items/<id>', () async {
      adapter.onDelete(
        '/items/17',
        (req) => req.reply(204, ''),
      );

      await items.destroy(17);

      final last = capture.captured.last;
      expect(last.method, 'DELETE');
      expect(last.path, '/items/17');
    });
  });

  // ──────────────────────── Collections ────────────────────────

  group('ItemsClient.listCollections', () {
    test('GETs /collections with no query params by default', () async {
      adapter.onGet(
        '/collections',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[
            sampleCollection(),
            sampleCollection(id: 8),
          ],
        }),
      );

      final list = await items.listCollections();
      expect(list, hasLength(2));
      expect(list.first.id, 7);
    });

    test('GETs /collections filtered by type', () async {
      adapter.onGet(
        '/collections',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[sampleCollection()],
        }),
        queryParameters: <String, dynamic>{'type': 'meal'},
      );

      final list = await items.listCollections(type: 'meal');
      expect(list, hasLength(1));
    });
  });

  group('ItemsClient.createCollection', () {
    test('POSTs /collections and returns the persisted Collection', () async {
      adapter.onPost(
        '/collections',
        (req) => req.reply(201, <String, dynamic>{
          'data': sampleCollection(id: 42),
        }),
        data: <String, dynamic>{
          'type': 'meal',
          'name': 'Mediterranean Meal Plan',
          'description': '7-day plan.',
        },
      );

      final created = await items.createCollection(
        type: 'meal',
        name: 'Mediterranean Meal Plan',
        description: '7-day plan.',
      );
      expect(created.id, 42);
    });

    test('POST /collections auto-injects an Idempotency-Key', () async {
      adapter.onPost(
        '/collections',
        (req) => req.reply(201, <String, dynamic>{
          'data': sampleCollection(),
        }),
        data: Matchers.any,
      );

      await items.createCollection(
        type: 'meal',
        name: 'x',
        description: 'd',
      );

      final key = capture.captured.last.headers['Idempotency-Key'] as String?;
      expect(key, isNotNull);
      expect(_uuidV4.hasMatch(key!), isTrue);
    });
  });

  group('ItemsClient.getCollection', () {
    test('GETs /collections/<id>', () async {
      adapter.onGet(
        '/collections/7',
        (req) => req.reply(200, <String, dynamic>{
          'data': sampleCollection(),
        }),
      );

      final c = await items.getCollection(7);
      expect(c.id, 7);
    });
  });

  group('ItemsClient.updateCollection', () {
    test('PUTs /collections/<id> (rewritten)', () async {
      adapter.onPost(
        '/collections/7',
        (req) => req.reply(200, <String, dynamic>{
          'data': sampleCollection(),
        }),
        data: Matchers.any,
        queryParameters: <String, dynamic>{'_method': 'PUT'},
      );

      await items.updateCollection(7, name: 'New name');

      final last = capture.captured.last;
      expect(last.method, 'POST');
      expect(last.queryParameters['_method'], 'PUT');
    });
  });

  group('ItemsClient.destroyCollection', () {
    test('DELETEs /collections/<id>', () async {
      adapter.onDelete(
        '/collections/7',
        (req) => req.reply(204, ''),
      );

      await items.destroyCollection(7);
      expect(capture.captured.last.method, 'DELETE');
    });
  });

  // ──────────────────────── User Items ────────────────────────

  group('ItemsClient.userItems', () {
    test('GETs /user-items with no query params by default', () async {
      adapter.onGet(
        '/user-items',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[
            sampleUserItem(),
            sampleUserItem(id: 101, itemId: 12),
          ],
        }),
      );

      final list = await items.userItems();
      expect(list, hasLength(2));
      expect(list.first.id, 100);
    });

    test('GETs /user-items filtered by type', () async {
      adapter.onGet(
        '/user-items',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[sampleUserItem()],
        }),
        queryParameters: <String, dynamic>{'type': 'meal'},
      );

      final list = await items.userItems(type: 'meal');
      expect(list, hasLength(1));
    });
  });

  group('ItemsClient.saveUserItem', () {
    test('POSTs /user-items and returns the persisted UserItem', () async {
      adapter.onPost(
        '/user-items',
        (req) => req.reply(201, <String, dynamic>{
          'data': sampleUserItem(),
        }),
        data: <String, dynamic>{
          'item_id': 11,
          'metadata': <String, dynamic>{'folder': 'breakfast'},
        },
      );

      final saved = await items.saveUserItem(
        itemId: 11,
        metadata: <String, dynamic>{'folder': 'breakfast'},
      );

      expect(saved, isA<UserItem>());
      expect(saved.itemId, 11);
    });

    test('POST /user-items auto-injects an Idempotency-Key', () async {
      adapter.onPost(
        '/user-items',
        (req) => req.reply(201, <String, dynamic>{
          'data': sampleUserItem(),
        }),
        data: Matchers.any,
      );

      await items.saveUserItem(itemId: 11);

      final key = capture.captured.last.headers['Idempotency-Key'] as String?;
      expect(key, isNotNull);
      expect(_uuidV4.hasMatch(key!), isTrue);
    });

    test('POSTs /user-items without metadata when not supplied', () async {
      adapter.onPost(
        '/user-items',
        (req) => req.reply(201, <String, dynamic>{
          'data': sampleUserItem(),
        }),
        data: <String, dynamic>{'item_id': 11},
      );

      final saved = await items.saveUserItem(itemId: 11);
      expect(saved.id, 100);
    });
  });
}
