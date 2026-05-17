// Contract tests for OrderClient.
//
// Covers:
//   GET /api/orders          — list, optionally filtered
//   GET /api/orders/<id>     — get one
//   activeSubscription helper

import 'package:codify_p2x_sdk/src/client/p2x_client.dart';
import 'package:codify_p2x_sdk/src/client/p2x_client_config.dart';
import 'package:codify_p2x_sdk/src/modules/order_client.dart';
import 'package:codify_p2x_sdk/src/modules/order_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

void main() {
  late P2xClient base;
  late DioAdapter adapter;
  late OrderClient orders;

  Map<String, dynamic> sampleOrder({
    int id = 1,
    String source = 'nio-subscription',
    String status = 'active',
  }) =>
      <String, dynamic>{
        'id': id,
        'source': source,
        'status': status,
        'amount': 9.99,
        'currency': 'USD',
        'tier': 'monthly',
        'expires_at': '2026-06-01T08:00:00Z',
        'user_id': 42,
        'subproject_id': 3,
        'created_at': '2026-05-01T08:00:00Z',
        'updated_at': '2026-05-01T08:00:00Z',
      };

  setUp(() {
    base = P2xClient(
      config: P2xClientConfig(
        baseUrl: 'https://api.project20x.com/api',
        getToken: () => 'tok-abc',
        getDomain: () => 'nutriscan.codify.ai',
      ),
    );
    adapter = DioAdapter(dio: base.dio);
    orders = OrderClient(base);
  });

  group('OrderClient.list', () {
    test('GETs /orders with no query params by default', () async {
      adapter.onGet(
        '/orders',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[
            sampleOrder(),
            sampleOrder(id: 2, status: 'cancelled'),
          ],
        }),
      );

      final list = await orders.list();

      expect(list, hasLength(2));
      expect(list.first.id, 1);
      expect(list.last.status, 'cancelled');
    });

    test('GETs /orders filtered by source and status', () async {
      adapter.onGet(
        '/orders',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[
            sampleOrder(),
          ],
        }),
        queryParameters: <String, dynamic>{
          'source': 'nio-subscription',
          'status': 'active',
        },
      );

      final list = await orders.list(
        source: 'nio-subscription',
        status: 'active',
      );

      expect(list, hasLength(1));
      expect(list.first.source, 'nio-subscription');
      expect(list.first.status, 'active');
    });

    test('GETs /orders returns empty list when none', () async {
      adapter.onGet(
        '/orders',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[],
        }),
      );

      final list = await orders.list();
      expect(list, isEmpty);
    });
  });

  group('OrderClient.get', () {
    test('GETs /orders/<id> and returns one Order', () async {
      adapter.onGet(
        '/orders/17',
        (req) => req.reply(200, <String, dynamic>{
          'data': sampleOrder(id: 17),
        }),
      );

      final o = await orders.get(17);

      expect(o, isA<Order>());
      expect(o.id, 17);
      expect(o.source, 'nio-subscription');
      expect(o.status, 'active');
    });
  });

  group('OrderClient.activeSubscription', () {
    test('returns the first active nio-subscription Order when one exists',
        () async {
      adapter.onGet(
        '/orders',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[
            sampleOrder(id: 9),
          ],
        }),
        queryParameters: <String, dynamic>{
          'source': 'nio-subscription',
          'status': 'active',
        },
      );

      final sub = await orders.activeSubscription();

      expect(sub, isNotNull);
      expect(sub!.id, 9);
      expect(sub.source, 'nio-subscription');
      expect(sub.status, 'active');
    });

    test('returns null when no active subscription exists', () async {
      adapter.onGet(
        '/orders',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[],
        }),
        queryParameters: <String, dynamic>{
          'source': 'nio-subscription',
          'status': 'active',
        },
      );

      final sub = await orders.activeSubscription();
      expect(sub, isNull);
    });

    test('accepts a custom source argument', () async {
      adapter.onGet(
        '/orders',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[
            sampleOrder(id: 5, source: 'phm-lab-booking'),
          ],
        }),
        queryParameters: <String, dynamic>{
          'source': 'phm-lab-booking',
          'status': 'active',
        },
      );

      final sub = await orders.activeSubscription(source: 'phm-lab-booking');
      expect(sub, isNotNull);
      expect(sub!.source, 'phm-lab-booking');
    });
  });
}
