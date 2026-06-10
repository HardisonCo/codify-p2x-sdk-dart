// Tests for the KpiSnapshot model class — plain @immutable data class
// (no freezed).

import 'package:ycaas_flutter_sdk/src/modules/kpi_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('KpiSnapshot', () {
    test('fromJson handles required fields (key, value, unit, recordedAt)', () {
      final s = KpiSnapshot.fromJson(<String, dynamic>{
        'key': 'daily-calories',
        'value': 1840.0,
        'unit': 'kcal',
        'recorded_at': '2026-05-01T08:00:00Z',
      });

      expect(s.key, 'daily-calories');
      expect(s.value, 1840.0);
      expect(s.unit, 'kcal');
      expect(s.recordedAt, DateTime.parse('2026-05-01T08:00:00Z'));
      expect(s.subprojectId, isNull);
    });

    test('fromJson accepts integer value and coerces to double', () {
      final s = KpiSnapshot.fromJson(<String, dynamic>{
        'key': 'steps',
        'value': 10000,
        'unit': 'count',
        'recorded_at': '2026-05-01T08:00:00Z',
      });

      expect(s.value, 10000.0);
      expect(s.value, isA<double>());
    });

    test('fromJson reads optional subprojectId', () {
      final s = KpiSnapshot.fromJson(<String, dynamic>{
        'key': 'weight',
        'value': 75.0,
        'unit': 'kg',
        'recorded_at': '2026-05-01T08:00:00Z',
        'subproject_id': 3,
      });

      expect(s.subprojectId, 3);
    });

    test('toJson round-trips back to fromJson identity', () {
      final original = KpiSnapshot(
        key: 'water-intake',
        value: 500,
        unit: 'ml',
        recordedAt: DateTime.parse('2026-05-01T08:00:00Z'),
        subprojectId: 3,
      );

      final round = KpiSnapshot.fromJson(original.toJson());

      expect(round, equals(original));
      expect(round.hashCode, equals(original.hashCode));
    });

    test('copyWith with no args returns equal instance', () {
      final s = KpiSnapshot(
        key: 'daily-calories',
        value: 1840,
        unit: 'kcal',
        recordedAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );

      expect(s.copyWith(), equals(s));
    });

    test('copyWith updates a single field', () {
      final s = KpiSnapshot(
        key: 'daily-calories',
        value: 1840,
        unit: 'kcal',
        recordedAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );
      final updated = s.copyWith(value: 2000);

      expect(updated.value, 2000);
      expect(updated.key, s.key);
      expect(updated.unit, s.unit);
      expect(updated.recordedAt, s.recordedAt);
      expect(updated, isNot(equals(s)));
    });

    test('two equal instances are == and have equal hashCode', () {
      final a = KpiSnapshot(
        key: 'weight',
        value: 75,
        unit: 'kg',
        recordedAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );
      final b = KpiSnapshot(
        key: 'weight',
        value: 75,
        unit: 'kg',
        recordedAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString includes class name and key fields', () {
      final s = KpiSnapshot(
        key: 'daily-calories',
        value: 1840,
        unit: 'kcal',
        recordedAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );

      final str = s.toString();
      expect(str, contains('KpiSnapshot'));
      expect(str, contains('daily-calories'));
      expect(str, contains('1840'));
      expect(str, contains('kcal'));
    });
  });
}
