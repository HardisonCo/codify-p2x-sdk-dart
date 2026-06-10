// Tests for PaymentMethod, SetupIntent, Subscription, and the
// Laravel-paginator-shaped PaginatedSubscriptions envelope.
//
// These are plain @immutable data classes (no freezed) — see the auth
// and modules sibling tests for the same shape.

import 'package:ycaas_flutter_sdk/src/payment/payment_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PaymentMethod', () {
    test('fromJson handles full Stripe pm_* row', () {
      final pm = PaymentMethod.fromJson(<String, dynamic>{
        'id': 'pm_1NXYZ',
        'brand': 'visa',
        'last4': '4242',
        'exp_month': 12,
        'exp_year': 2030,
        'is_default': true,
      });

      expect(pm.id, 'pm_1NXYZ');
      expect(pm.brand, 'visa');
      expect(pm.last4, '4242');
      expect(pm.expMonth, 12);
      expect(pm.expYear, 2030);
      expect(pm.isDefault, isTrue);
    });

    test('fromJson defaults isDefault to false when absent', () {
      final pm = PaymentMethod.fromJson(<String, dynamic>{
        'id': 'pm_1',
        'brand': 'mastercard',
        'last4': '1234',
        'exp_month': 1,
        'exp_year': 2027,
      });

      expect(pm.isDefault, isFalse);
    });

    test('toJson round-trips back to fromJson identity', () {
      const original = PaymentMethod(
        id: 'pm_1NXYZ',
        brand: 'visa',
        last4: '4242',
        expMonth: 12,
        expYear: 2030,
        isDefault: true,
      );

      final round = PaymentMethod.fromJson(original.toJson());
      expect(round, original);
    });

    test('value equality and hashCode behave', () {
      const a = PaymentMethod(
        id: 'pm_1',
        brand: 'visa',
        last4: '4242',
        expMonth: 12,
        expYear: 2030,
      );
      const b = PaymentMethod(
        id: 'pm_1',
        brand: 'visa',
        last4: '4242',
        expMonth: 12,
        expYear: 2030,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('SetupIntent', () {
    test('fromJson handles all fields', () {
      final s = SetupIntent.fromJson(<String, dynamic>{
        'client_secret': 'seti_1_secret_abc',
        'customer_id': 'cus_123',
        'status': 'requires_payment_method',
      });

      expect(s.clientSecret, 'seti_1_secret_abc');
      expect(s.customerId, 'cus_123');
      expect(s.status, 'requires_payment_method');
    });

    test('fromJson tolerates missing customer_id', () {
      final s = SetupIntent.fromJson(<String, dynamic>{
        'client_secret': 'seti_1_secret_abc',
        'status': 'requires_payment_method',
      });

      expect(s.clientSecret, 'seti_1_secret_abc');
      expect(s.customerId, isNull);
    });

    test('toJson round-trips', () {
      const original = SetupIntent(
        clientSecret: 'seti_1_secret_abc',
        customerId: 'cus_123',
        status: 'requires_payment_method',
      );
      final round = SetupIntent.fromJson(original.toJson());
      expect(round, original);
    });
  });

  group('Subscription', () {
    test('fromJson handles the canonical row shape', () {
      final s = Subscription.fromJson(<String, dynamic>{
        'id': 'sub_123',
        'status': 'active',
        'current_period_end': '2026-12-01T00:00:00Z',
        'price_id': 'price_abc',
        'product_name': 'Pro Plan',
        'amount_cents': 1999,
        'currency': 'usd',
      });

      expect(s.id, 'sub_123');
      expect(s.status, 'active');
      expect(s.currentPeriodEnd, DateTime.parse('2026-12-01T00:00:00Z'));
      expect(s.priceId, 'price_abc');
      expect(s.productName, 'Pro Plan');
      expect(s.amountCents, 1999);
      expect(s.currency, 'usd');
    });

    test('toJson round-trips back to fromJson identity', () {
      final original = Subscription(
        id: 'sub_123',
        status: 'active',
        currentPeriodEnd: DateTime.parse('2026-12-01T00:00:00Z'),
        priceId: 'price_abc',
        productName: 'Pro Plan',
        amountCents: 1999,
        currency: 'usd',
      );

      final round = Subscription.fromJson(original.toJson());
      expect(round, original);
    });
  });

  group('PaginatedSubscriptions', () {
    test(
        'parses Laravel paginator envelope {data, current_page, last_page, '
        'total}', () {
      final p = PaginatedSubscriptions.fromJson(<String, dynamic>{
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
          <String, dynamic>{
            'id': 'sub_2',
            'status': 'canceled',
            'current_period_end': '2025-12-01T00:00:00Z',
            'price_id': 'price_b',
            'product_name': 'Basic',
            'amount_cents': 999,
            'currency': 'usd',
          },
        ],
        'current_page': 1,
        'last_page': 3,
        'total': 27,
      });

      expect(p.data, hasLength(2));
      expect(p.data.first.id, 'sub_1');
      expect(p.data.last.status, 'canceled');
      expect(p.currentPage, 1);
      expect(p.lastPage, 3);
      expect(p.total, 27);
    });

    test('handles an empty page gracefully', () {
      final p = PaginatedSubscriptions.fromJson(<String, dynamic>{
        'data': <dynamic>[],
        'current_page': 1,
        'last_page': 1,
        'total': 0,
      });

      expect(p.data, isEmpty);
      expect(p.currentPage, 1);
      expect(p.lastPage, 1);
      expect(p.total, 0);
    });
  });
}
