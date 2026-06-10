// Tests for the Nudge model class — plain @immutable data class
// (no freezed).

import 'package:ycaas_flutter_sdk/src/modules/nudge_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Nudge', () {
    test('fromJson handles required fields', () {
      final n = Nudge.fromJson(<String, dynamic>{
        'id': 7,
        'key': 'meal-log-reminder',
        'title': 'Log your lunch',
        'body': "Don't forget to scan your meal.",
        'severity': 'reminder',
        'created_at': '2026-05-01T08:00:00Z',
      });

      expect(n.id, 7);
      expect(n.key, 'meal-log-reminder');
      expect(n.title, 'Log your lunch');
      expect(n.body, "Don't forget to scan your meal.");
      expect(n.severity, 'reminder');
      expect(n.createdAt, DateTime.parse('2026-05-01T08:00:00Z'));
      expect(n.action, isNull);
      expect(n.acknowledgedAt, isNull);
      expect(n.dismissedAt, isNull);
      expect(n.payload, isEmpty);
    });

    test('fromJson handles all optional fields', () {
      final n = Nudge.fromJson(<String, dynamic>{
        'id': 7,
        'key': 'coin-earn',
        'title': 'You earned 5 coins',
        'body': 'Tap to claim.',
        'action': 'screen://coins/claim',
        'severity': 'celebration',
        'created_at': '2026-05-01T08:00:00Z',
        'acknowledged_at': '2026-05-01T09:00:00Z',
        'dismissed_at': '2026-05-01T09:30:00Z',
        'payload': <String, dynamic>{'reward': 5, 'currency': 'coin'},
      });

      expect(n.action, 'screen://coins/claim');
      expect(n.acknowledgedAt, DateTime.parse('2026-05-01T09:00:00Z'));
      expect(n.dismissedAt, DateTime.parse('2026-05-01T09:30:00Z'));
      expect(n.payload['reward'], 5);
      expect(n.payload['currency'], 'coin');
    });

    test('fromJson defaults payload to empty map when missing', () {
      final n = Nudge.fromJson(<String, dynamic>{
        'id': 1,
        'key': 'streak',
        'title': 'Streak',
        'body': 'Keep it up',
        'severity': 'info',
        'created_at': '2026-05-01T08:00:00Z',
      });

      expect(n.payload, isA<Map<String, dynamic>>());
      expect(n.payload, isEmpty);
    });

    test('toJson round-trips back to fromJson identity', () {
      final original = Nudge(
        id: 7,
        key: 'meal-log-reminder',
        title: 'Log your lunch',
        body: "Don't forget to scan your meal.",
        action: 'screen://meal/log',
        severity: 'reminder',
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
        acknowledgedAt: DateTime.parse('2026-05-01T09:00:00Z'),
        dismissedAt: DateTime.parse('2026-05-01T09:30:00Z'),
        payload: const <String, dynamic>{'reward': 5},
      );

      final round = Nudge.fromJson(original.toJson());

      expect(round, equals(original));
      expect(round.hashCode, equals(original.hashCode));
    });

    test('copyWith with no args returns equal instance', () {
      final n = Nudge(
        id: 7,
        key: 'meal-log-reminder',
        title: 'Log your lunch',
        body: "Don't forget to scan your meal.",
        severity: 'reminder',
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );

      expect(n.copyWith(), equals(n));
    });

    test('copyWith updates a single field', () {
      final n = Nudge(
        id: 7,
        key: 'meal-log-reminder',
        title: 'Log your lunch',
        body: "Don't forget to scan your meal.",
        severity: 'reminder',
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );
      final acked = n.copyWith(
        acknowledgedAt: DateTime.parse('2026-05-01T09:00:00Z'),
      );

      expect(acked.acknowledgedAt, DateTime.parse('2026-05-01T09:00:00Z'));
      expect(acked.id, n.id);
      expect(acked, isNot(equals(n)));
    });

    test('two equal instances are == and have equal hashCode', () {
      final a = Nudge(
        id: 1,
        key: 'k',
        title: 't',
        body: 'b',
        severity: 'info',
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );
      final b = Nudge(
        id: 1,
        key: 'k',
        title: 't',
        body: 'b',
        severity: 'info',
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString includes class name, id, key, severity', () {
      final n = Nudge(
        id: 7,
        key: 'meal-log-reminder',
        title: 'Log your lunch',
        body: 'b',
        severity: 'reminder',
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );

      final s = n.toString();
      expect(s, contains('Nudge'));
      expect(s, contains('7'));
      expect(s, contains('meal-log-reminder'));
      expect(s, contains('reminder'));
    });
  });
}
