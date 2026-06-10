// Tests for the Order model class — plain @immutable data class
// (no freezed).

import 'package:ycaas_flutter_sdk/src/modules/order_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Order', () {
    test('fromJson handles required fields', () {
      final o = Order.fromJson(<String, dynamic>{
        'id': 17,
        'source': 'nio-subscription',
        'status': 'active',
        'amount': 9.99,
        'currency': 'USD',
        'user_id': 42,
        'subproject_id': 3,
        'created_at': '2026-05-01T08:00:00Z',
        'updated_at': '2026-05-01T08:00:00Z',
      });

      expect(o.id, 17);
      expect(o.source, 'nio-subscription');
      expect(o.status, 'active');
      expect(o.amount, 9.99);
      expect(o.currency, 'USD');
      expect(o.userId, 42);
      expect(o.subprojectId, 3);
      expect(o.tier, isNull);
      expect(o.expiresAt, isNull);
    });

    test('fromJson handles all optional fields (tier + expiresAt)', () {
      final o = Order.fromJson(<String, dynamic>{
        'id': 17,
        'source': 'nio-subscription',
        'status': 'active',
        'amount': 99.99,
        'currency': 'USD',
        'tier': 'yearly',
        'expires_at': '2027-05-01T08:00:00Z',
        'user_id': 42,
        'subproject_id': 3,
        'created_at': '2026-05-01T08:00:00Z',
        'updated_at': '2026-05-01T08:00:00Z',
      });

      expect(o.tier, 'yearly');
      expect(o.expiresAt, DateTime.parse('2027-05-01T08:00:00Z'));
    });

    test('fromJson coerces integer amount to double', () {
      final o = Order.fromJson(<String, dynamic>{
        'id': 1,
        'source': 'phm-lab-booking',
        'status': 'pending',
        'amount': 100,
        'currency': 'USD',
        'user_id': 1,
        'subproject_id': 1,
        'created_at': '2026-05-01T08:00:00Z',
        'updated_at': '2026-05-01T08:00:00Z',
      });

      expect(o.amount, 100.0);
      expect(o.amount, isA<double>());
    });

    test('toJson round-trips back to fromJson identity', () {
      final original = Order(
        id: 17,
        source: 'nio-subscription',
        status: 'active',
        amount: 9.99,
        currency: 'USD',
        tier: 'monthly',
        expiresAt: DateTime.parse('2026-06-01T08:00:00Z'),
        userId: 42,
        subprojectId: 3,
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );

      final round = Order.fromJson(original.toJson());

      expect(round, equals(original));
      expect(round.hashCode, equals(original.hashCode));
    });

    test('copyWith with no args returns equal instance', () {
      final o = Order(
        id: 17,
        source: 'nio-subscription',
        status: 'active',
        amount: 9.99,
        currency: 'USD',
        userId: 42,
        subprojectId: 3,
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );
      expect(o.copyWith(), equals(o));
    });

    test('copyWith updates a single field', () {
      final o = Order(
        id: 17,
        source: 'nio-subscription',
        status: 'active',
        amount: 9.99,
        currency: 'USD',
        userId: 42,
        subprojectId: 3,
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );
      final cancelled = o.copyWith(status: 'cancelled');

      expect(cancelled.status, 'cancelled');
      expect(cancelled.id, o.id);
      expect(cancelled, isNot(equals(o)));
    });

    test('two equal instances are == and have equal hashCode', () {
      final a = Order(
        id: 1,
        source: 's',
        status: 'st',
        amount: 1,
        currency: 'USD',
        userId: 1,
        subprojectId: 1,
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );
      final b = Order(
        id: 1,
        source: 's',
        status: 'st',
        amount: 1,
        currency: 'USD',
        userId: 1,
        subprojectId: 1,
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString includes class name, id, status, source', () {
      final o = Order(
        id: 17,
        source: 'nio-subscription',
        status: 'active',
        amount: 9.99,
        currency: 'USD',
        userId: 42,
        subprojectId: 3,
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );

      final s = o.toString();
      expect(s, contains('Order'));
      expect(s, contains('17'));
      expect(s, contains('active'));
      expect(s, contains('nio-subscription'));
    });
  });
}
