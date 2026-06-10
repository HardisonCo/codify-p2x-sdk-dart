// Tests for the NIO integration model classes (CoinBalance,
// CoinTransaction) — plain @immutable data classes (no freezed).

import 'package:ycaas_flutter_sdk/src/integrations/nio_integrations_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CoinBalance', () {
    test('fromJson handles required fields', () {
      final b = CoinBalance.fromJson(<String, dynamic>{
        'balance': 120,
        'lifetime_earned': 200,
        'lifetime_spent': 80,
        'as_of': '2026-05-01T08:00:00Z',
      });

      expect(b.balance, 120);
      expect(b.lifetimeEarned, 200);
      expect(b.lifetimeSpent, 80);
      expect(b.asOf, DateTime.parse('2026-05-01T08:00:00Z'));
    });

    test('toJson round-trips back to fromJson identity', () {
      final original = CoinBalance(
        balance: 120,
        lifetimeEarned: 200,
        lifetimeSpent: 80,
        asOf: DateTime.parse('2026-05-01T08:00:00Z'),
      );

      final round = CoinBalance.fromJson(original.toJson());
      expect(round, equals(original));
      expect(round.hashCode, equals(original.hashCode));
    });

    test('copyWith with no args returns equal instance', () {
      final b = CoinBalance(
        balance: 120,
        lifetimeEarned: 200,
        lifetimeSpent: 80,
        asOf: DateTime.parse('2026-05-01T08:00:00Z'),
      );
      expect(b.copyWith(), equals(b));
    });

    test('copyWith updates a single field', () {
      final b = CoinBalance(
        balance: 120,
        lifetimeEarned: 200,
        lifetimeSpent: 80,
        asOf: DateTime.parse('2026-05-01T08:00:00Z'),
      );
      final updated = b.copyWith(balance: 130);
      expect(updated.balance, 130);
      expect(updated.lifetimeEarned, b.lifetimeEarned);
      expect(updated, isNot(equals(b)));
    });

    test('two equal instances are == and have equal hashCode', () {
      final a = CoinBalance(
        balance: 1,
        lifetimeEarned: 2,
        lifetimeSpent: 1,
        asOf: DateTime.parse('2026-05-01T08:00:00Z'),
      );
      final b = CoinBalance(
        balance: 1,
        lifetimeEarned: 2,
        lifetimeSpent: 1,
        asOf: DateTime.parse('2026-05-01T08:00:00Z'),
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString includes class name and balance', () {
      final b = CoinBalance(
        balance: 120,
        lifetimeEarned: 200,
        lifetimeSpent: 80,
        asOf: DateTime.parse('2026-05-01T08:00:00Z'),
      );
      final s = b.toString();
      expect(s, contains('CoinBalance'));
      expect(s, contains('120'));
    });
  });

  group('CoinTransaction', () {
    test('fromJson handles required fields', () {
      final tx = CoinTransaction.fromJson(<String, dynamic>{
        'id': 7,
        'type': 'earn',
        'amount': 5,
        'reason': 'scan-streak-bonus',
        'balance_after': 125,
        'created_at': '2026-05-01T08:00:00Z',
      });

      expect(tx.id, 7);
      expect(tx.type, 'earn');
      expect(tx.amount, 5);
      expect(tx.reason, 'scan-streak-bonus');
      expect(tx.balanceAfter, 125);
      expect(tx.createdAt, DateTime.parse('2026-05-01T08:00:00Z'));
      expect(tx.metadata, isEmpty);
    });

    test('fromJson defaults metadata to empty map when missing', () {
      final tx = CoinTransaction.fromJson(<String, dynamic>{
        'id': 7,
        'type': 'spend',
        'amount': 10,
        'reason': 'meal-plan-unlock',
        'balance_after': 115,
        'created_at': '2026-05-01T08:00:00Z',
      });
      expect(tx.metadata, isA<Map<String, dynamic>>());
      expect(tx.metadata, isEmpty);
    });

    test('fromJson reads metadata when present', () {
      final tx = CoinTransaction.fromJson(<String, dynamic>{
        'id': 7,
        'type': 'spend',
        'amount': 10,
        'reason': 'meal-plan-unlock',
        'balance_after': 115,
        'created_at': '2026-05-01T08:00:00Z',
        'metadata': <String, dynamic>{'meal_plan_id': 42},
      });
      expect(tx.metadata['meal_plan_id'], 42);
    });

    test('toJson round-trips back to fromJson identity', () {
      final original = CoinTransaction(
        id: 7,
        type: 'spend',
        amount: 10,
        reason: 'meal-plan-unlock',
        balanceAfter: 115,
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
        metadata: const <String, dynamic>{'meal_plan_id': 42},
      );

      final round = CoinTransaction.fromJson(original.toJson());
      expect(round, equals(original));
      expect(round.hashCode, equals(original.hashCode));
    });

    test('copyWith with no args returns equal instance', () {
      final tx = CoinTransaction(
        id: 7,
        type: 'earn',
        amount: 5,
        reason: 'r',
        balanceAfter: 125,
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );
      expect(tx.copyWith(), equals(tx));
    });

    test('copyWith updates a single field', () {
      final tx = CoinTransaction(
        id: 7,
        type: 'earn',
        amount: 5,
        reason: 'r',
        balanceAfter: 125,
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );
      final updated = tx.copyWith(amount: 10);
      expect(updated.amount, 10);
      expect(updated.id, tx.id);
      expect(updated, isNot(equals(tx)));
    });

    test('two equal instances are == and have equal hashCode', () {
      final a = CoinTransaction(
        id: 1,
        type: 'earn',
        amount: 5,
        reason: 'r',
        balanceAfter: 5,
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );
      final b = CoinTransaction(
        id: 1,
        type: 'earn',
        amount: 5,
        reason: 'r',
        balanceAfter: 5,
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString includes class name, id, type, amount, reason', () {
      final tx = CoinTransaction(
        id: 7,
        type: 'earn',
        amount: 5,
        reason: 'scan-streak-bonus',
        balanceAfter: 125,
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );
      final s = tx.toString();
      expect(s, contains('CoinTransaction'));
      expect(s, contains('7'));
      expect(s, contains('earn'));
      expect(s, contains('5'));
      expect(s, contains('scan-streak-bonus'));
    });
  });
}
