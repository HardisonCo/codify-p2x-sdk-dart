// Contract tests for PaymentClient — Stripe payment methods + setup
// intent + Laravel-paginated subscriptions surface.
//
// Asserts URL, HTTP method, body shape, headers (Idempotency-Key), and
// decoded response types for:
//
//   GET    /api/payment/payment-method
//   POST   /api/payment/payment-method
//   DELETE /api/payment/payment-method/{id}
//   GET    /api/payment/setup-payment-method
//   GET    /api/payment/subscriptions

import 'package:codify_p2x_sdk/src/client/p2x_client.dart';
import 'package:codify_p2x_sdk/src/client/p2x_client_config.dart';
import 'package:codify_p2x_sdk/src/payment/payment_client.dart';
import 'package:codify_p2x_sdk/src/payment/payment_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

void main() {
  late P2xClient base;
  late DioAdapter adapter;
  late PaymentClient payment;

  setUp(() {
    base = P2xClient(
      config: P2xClientConfig(
        baseUrl: 'https://api.project20x.com/api',
        getToken: () => 'tok-abc',
        getDomain: () => 'crohnie.ai',
      ),
    );
    adapter = DioAdapter(dio: base.dio);
    payment = PaymentClient(base);
  });

  group('PaymentClient.getPaymentMethod', () {
    test('GETs /payment/payment-method and decodes the row', () async {
      adapter.onGet(
        '/payment/payment-method',
        (req) => req.reply(200, <String, dynamic>{
          'success': true,
          'message': 'ok',
          'data': <String, dynamic>{
            'id': 'pm_1NXYZ',
            'brand': 'visa',
            'last4': '4242',
            'exp_month': 12,
            'exp_year': 2030,
            'is_default': true,
          },
        }),
      );

      final pm = await payment.getPaymentMethod();

      expect(pm, isA<PaymentMethod>());
      expect(pm!.id, 'pm_1NXYZ');
      expect(pm.brand, 'visa');
      expect(pm.last4, '4242');
      expect(pm.expMonth, 12);
      expect(pm.expYear, 2030);
      expect(pm.isDefault, isTrue);
    });

    test(
        'returns null when the user has no payment method on file '
        '(data is null)', () async {
      adapter.onGet(
        '/payment/payment-method',
        (req) => req.reply(200, <String, dynamic>{
          'success': true,
          'message': 'no payment method',
          'data': null,
        }),
      );

      final pm = await payment.getPaymentMethod();

      expect(pm, isNull);
    });

    test('returns null when "data" key is absent entirely', () async {
      adapter.onGet(
        '/payment/payment-method',
        (req) => req.reply(200, <String, dynamic>{
          'success': true,
          'message': 'no payment method',
        }),
      );

      final pm = await payment.getPaymentMethod();

      expect(pm, isNull);
    });
  });

  group('PaymentClient.savePaymentMethod', () {
    test('POSTs /payment/payment-method with paymentMethodId in the body',
        () async {
      adapter.onPost(
        '/payment/payment-method',
        (req) => req.reply(200, <String, dynamic>{
          'success': true,
          'message': 'saved',
          'data': <String, dynamic>{},
        }),
        data: <String, dynamic>{
          'payment_method_id': 'pm_1NXYZ',
        },
      );

      // Should complete without throwing.
      await payment.savePaymentMethod(paymentMethodId: 'pm_1NXYZ');
    });

    test('auto-attaches an Idempotency-Key header via the SDK interceptor',
        () async {
      adapter.onPost(
        '/payment/payment-method',
        (req) => req.reply(200, <String, dynamic>{
          'success': true,
          'data': <String, dynamic>{},
        }),
        data: Matchers.any,
      );

      final resp = await base.dio.post<dynamic>(
        '/payment/payment-method',
        data: <String, dynamic>{'payment_method_id': 'pm_1NXYZ'},
      );

      final key = resp.requestOptions.headers['Idempotency-Key'];
      expect(key, isA<String>());
      expect((key as String).isNotEmpty, isTrue);
    });
  });

  group('PaymentClient.deletePaymentMethod', () {
    test('DELETEs /payment/payment-method/{id}', () async {
      adapter.onDelete(
        '/payment/payment-method/pm_1NXYZ',
        (req) => req.reply(200, <String, dynamic>{
          'success': true,
          'message': 'deleted',
          'data': <String, dynamic>{},
        }),
      );

      await payment.deletePaymentMethod('pm_1NXYZ');
    });
  });

  group('PaymentClient.setupPaymentMethod', () {
    test('GETs /payment/setup-payment-method and decodes the SetupIntent',
        () async {
      adapter.onGet(
        '/payment/setup-payment-method',
        (req) => req.reply(200, <String, dynamic>{
          'success': true,
          'message': 'ok',
          'data': <String, dynamic>{
            'client_secret': 'seti_1_secret_abc',
            'customer_id': 'cus_123',
            'status': 'requires_payment_method',
          },
        }),
      );

      final intent = await payment.setupPaymentMethod();

      expect(intent, isA<SetupIntent>());
      expect(intent.clientSecret, 'seti_1_secret_abc');
      expect(intent.customerId, 'cus_123');
      expect(intent.status, 'requires_payment_method');
    });
  });

  group('PaymentClient.subscriptions', () {
    test(
        'GETs /payment/subscriptions?page=1 by default and decodes the '
        'paginator', () async {
      adapter.onGet(
        '/payment/subscriptions',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'sub_1',
              'status': 'active',
              'current_period_end': '2026-12-01T00:00:00Z',
              'price_id': 'price_a',
              'product_name': 'Pro',
              'amount_cents': 1999,
              'currency': 'usd',
            },
          ],
          'current_page': 1,
          'last_page': 1,
          'total': 1,
        }),
        queryParameters: <String, dynamic>{
          'page': 1,
        },
      );

      final page = await payment.subscriptions();

      expect(page, isA<PaginatedSubscriptions>());
      expect(page.data, hasLength(1));
      expect(page.data.first.id, 'sub_1');
      expect(page.data.first.amountCents, 1999);
      expect(page.currentPage, 1);
      expect(page.lastPage, 1);
      expect(page.total, 1);
    });

    test('GETs /payment/subscriptions?page=3 when caller supplies a page',
        () async {
      adapter.onGet(
        '/payment/subscriptions',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[],
          'current_page': 3,
          'last_page': 3,
          'total': 25,
        }),
        queryParameters: <String, dynamic>{
          'page': 3,
        },
      );

      final page = await payment.subscriptions(page: 3);

      expect(page.data, isEmpty);
      expect(page.currentPage, 3);
      expect(page.lastPage, 3);
      expect(page.total, 25);
    });
  });
}
