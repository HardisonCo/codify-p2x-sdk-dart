// Contract tests for OrderClient expansion (v2 methods).
//
// Covers the five new endpoints added on top of the existing read-only
// surface in order_client_test.dart:
//
//   POST /api/order                  — create
//   PUT  /api/order/<id>             — update (POST + _method=PUT)
//   POST /api/order/cancel-order     — cancel
//   POST /api/order/checkout         — checkout (Stripe envelope)
//   POST /api/order/confirm-order    — confirm after Stripe client-side
//
// The existing OrderClient.list tests live in order_client_test.dart and
// MUST keep passing — the regression check at the bottom of this file
// re-asserts that surface.

import 'package:codify_p2x_sdk/codify_p2x_sdk.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

final RegExp _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

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
  late OrderClient orders;
  late _CaptureInterceptor capture;

  Map<String, dynamic> sampleOrder({
    int id = 1,
    String source = 'nio-subscription',
    String status = 'pending',
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
    capture = _CaptureInterceptor();
    base.dio.interceptors.add(capture);
    adapter = DioAdapter(dio: base.dio);
    orders = OrderClient(base);
  });

  group('OrderClient.create', () {
    test('POSTs /order with source + amount_cents + currency', () async {
      adapter.onPost(
        '/order',
        (req) => req.reply(201, <String, dynamic>{'data': sampleOrder(id: 42)}),
        data: <String, dynamic>{
          'source': 'nio-subscription',
          'amount_cents': 999,
          'currency': 'USD',
        },
      );

      final created = await orders.create(
        source: 'nio-subscription',
        amountCents: 999,
        currency: 'USD',
      );

      expect(created, isA<Order>());
      expect(created.id, 42);
      expect(created.source, 'nio-subscription');
    });

    test('POSTs /order with optional metadata when supplied', () async {
      adapter.onPost(
        '/order',
        (req) => req.reply(201, <String, dynamic>{'data': sampleOrder()}),
        data: <String, dynamic>{
          'source': 'phm-lab-booking',
          'amount_cents': 12500,
          'currency': 'USD',
          'metadata': <String, dynamic>{'lab_test_id': 7},
        },
      );

      await orders.create(
        source: 'phm-lab-booking',
        amountCents: 12500,
        currency: 'USD',
        metadata: <String, dynamic>{'lab_test_id': 7},
      );
    });

    test('POST /order auto-injects an Idempotency-Key (UUID v4)', () async {
      adapter.onPost(
        '/order',
        (req) => req.reply(201, <String, dynamic>{'data': sampleOrder()}),
        data: Matchers.any,
      );

      await orders.create(
        source: 'nio-subscription',
        amountCents: 999,
        currency: 'USD',
      );

      final key = capture.captured.last.headers['Idempotency-Key'] as String?;
      expect(key, isNotNull);
      expect(
        _uuidV4.hasMatch(key!),
        isTrue,
        reason: 'Expected UUID v4 but got "$key"',
      );
    });

    test('POST /order throws ValidationException on missing source', () async {
      adapter.onPost(
        '/order',
        (req) => req.reply(422, <String, dynamic>{
          'message': 'The given data was invalid.',
          'errors': <String, dynamic>{
            'source': <String>['The source field is required.'],
          },
        }),
        data: Matchers.any,
      );

      Object? caught;
      try {
        await orders.create(
          source: '',
          amountCents: 999,
          currency: 'USD',
        );
      } catch (e) {
        caught = e;
      }
      expect(caught, isA<ValidationException>());
      expect(
        (caught! as ValidationException).errors['source'],
        <String>['The source field is required.'],
      );
    });
  });

  group('OrderClient.update', () {
    test('PUTs /order/<id> (rewritten to POST + _method=PUT)', () async {
      adapter.onPost(
        '/order/17',
        (req) => req.reply(200, <String, dynamic>{
          'data': sampleOrder(id: 17),
        }),
        data: Matchers.any,
        queryParameters: <String, dynamic>{'_method': 'PUT'},
      );

      final updated = await orders.update(
        17,
        metadata: <String, dynamic>{'note': 'gift'},
      );

      expect(updated.id, 17);

      final last = capture.captured.last;
      expect(last.method, 'POST');
      expect(last.queryParameters['_method'], 'PUT');
    });
  });

  group('OrderClient.cancel', () {
    test('POSTs /order/cancel-order with order_id + reason', () async {
      adapter.onPost(
        '/order/cancel-order',
        (req) => req.reply(200, <String, dynamic>{
          'data': sampleOrder(id: 17, status: 'cancelled'),
        }),
        data: <String, dynamic>{
          'order_id': 17,
          'reason': 'changed mind',
        },
      );

      final cancelled = await orders.cancel(
        orderId: 17,
        reason: 'changed mind',
      );

      expect(cancelled.id, 17);
      expect(cancelled.status, 'cancelled');
    });

    test('POSTs /order/cancel-order without reason when not supplied',
        () async {
      adapter.onPost(
        '/order/cancel-order',
        (req) => req.reply(200, <String, dynamic>{
          'data': sampleOrder(id: 17, status: 'cancelled'),
        }),
        data: <String, dynamic>{'order_id': 17},
      );

      final cancelled = await orders.cancel(orderId: 17);
      expect(cancelled.status, 'cancelled');
    });

    test('POST /order/cancel-order auto-injects Idempotency-Key', () async {
      adapter.onPost(
        '/order/cancel-order',
        (req) => req.reply(200, <String, dynamic>{
          'data': sampleOrder(status: 'cancelled'),
        }),
        data: Matchers.any,
      );

      await orders.cancel(orderId: 17);

      final key = capture.captured.last.headers['Idempotency-Key'] as String?;
      expect(key, isNotNull);
      expect(_uuidV4.hasMatch(key!), isTrue);
    });
  });

  group('OrderClient.checkout', () {
    test('POSTs /order/checkout and returns requires_action result', () async {
      adapter.onPost(
        '/order/checkout',
        (req) => req.reply(200, <String, dynamic>{
          'data': <String, dynamic>{
            'order_id': 17,
            'status': 'requires_action',
            'client_secret': 'pi_abc_secret_xyz',
            'payment_intent_id': 'pi_abc',
          },
        }),
        data: <String, dynamic>{
          'order_id': 17,
          'payment_method_id': 'pm_card_visa',
        },
      );

      final result = await orders.checkout(
        orderId: 17,
        paymentMethodId: 'pm_card_visa',
      );

      expect(result, isA<CheckoutResult>());
      expect(result.orderId, 17);
      expect(result.status, 'requires_action');
      expect(result.clientSecret, 'pi_abc_secret_xyz');
      expect(result.paymentIntentId, 'pi_abc');
      expect(result.error, isNull);
    });

    test('POSTs /order/checkout and returns succeeded result', () async {
      adapter.onPost(
        '/order/checkout',
        (req) => req.reply(200, <String, dynamic>{
          'data': <String, dynamic>{
            'order_id': 17,
            'status': 'succeeded',
            'payment_intent_id': 'pi_abc',
          },
        }),
        data: Matchers.any,
      );

      final result = await orders.checkout(
        orderId: 17,
        paymentMethodId: 'pm_card_visa',
      );

      expect(result.status, 'succeeded');
      expect(result.paymentIntentId, 'pi_abc');
      expect(result.clientSecret, isNull);
    });

    test('POSTs /order/checkout and returns failed result with error',
        () async {
      adapter.onPost(
        '/order/checkout',
        (req) => req.reply(200, <String, dynamic>{
          'data': <String, dynamic>{
            'order_id': 17,
            'status': 'failed',
            'error': 'Your card was declined.',
          },
        }),
        data: Matchers.any,
      );

      final result = await orders.checkout(
        orderId: 17,
        paymentMethodId: 'pm_card_visa',
      );

      expect(result.status, 'failed');
      expect(result.error, 'Your card was declined.');
    });

    test('POST /order/checkout auto-injects Idempotency-Key', () async {
      adapter.onPost(
        '/order/checkout',
        (req) => req.reply(200, <String, dynamic>{
          'data': <String, dynamic>{
            'order_id': 17,
            'status': 'succeeded',
          },
        }),
        data: Matchers.any,
      );

      await orders.checkout(orderId: 17, paymentMethodId: 'pm_card_visa');

      final key = capture.captured.last.headers['Idempotency-Key'] as String?;
      expect(key, isNotNull);
      expect(_uuidV4.hasMatch(key!), isTrue);
    });
  });

  group('OrderClient.confirm', () {
    test('POSTs /order/confirm-order with order_id + payment_intent_id',
        () async {
      adapter.onPost(
        '/order/confirm-order',
        (req) => req.reply(200, <String, dynamic>{
          'data': sampleOrder(id: 17, status: 'active'),
        }),
        data: <String, dynamic>{
          'order_id': 17,
          'payment_intent_id': 'pi_abc',
        },
      );

      final confirmed = await orders.confirm(
        orderId: 17,
        paymentIntentId: 'pi_abc',
      );

      expect(confirmed.id, 17);
      expect(confirmed.status, 'active');
    });

    test('POST /order/confirm-order auto-injects Idempotency-Key', () async {
      adapter.onPost(
        '/order/confirm-order',
        (req) => req.reply(200, <String, dynamic>{
          'data': sampleOrder(id: 17, status: 'active'),
        }),
        data: Matchers.any,
      );

      await orders.confirm(orderId: 17, paymentIntentId: 'pi_abc');

      final key = capture.captured.last.headers['Idempotency-Key'] as String?;
      expect(key, isNotNull);
      expect(_uuidV4.hasMatch(key!), isTrue);
    });
  });

  // Regression: existing OrderClient.list surface must keep working
  // after the additive expansion.
  group('OrderClient.list (regression after v2 expansion)', () {
    test('GETs /orders still returns the parsed list', () async {
      adapter.onGet(
        '/orders',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[
            sampleOrder(status: 'active'),
            sampleOrder(id: 2, status: 'cancelled'),
          ],
        }),
      );

      final list = await orders.list();
      expect(list, hasLength(2));
      expect(list.first.status, 'active');
      expect(list.last.status, 'cancelled');
    });
  });
}
