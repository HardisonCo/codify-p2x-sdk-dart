// Tests for the Service model class — plain @immutable data class.

import 'package:ycaas_flutter_sdk/src/modules/services_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Service', () {
    test('fromJson handles required fields', () {
      final s = Service.fromJson(<String, dynamic>{
        'id': 5,
        'subproject_id': 3,
        'slug': 'ibd-consult-30min',
        'name': '30-minute IBD consult',
        'description': 'One-on-one telehealth visit.',
        'duration_minutes': 30,
        'price_cents': 7500,
        'currency': 'USD',
        'provider_id': 42,
        'is_active': true,
        'created_at': '2026-05-01T08:00:00Z',
      });

      expect(s.id, 5);
      expect(s.subprojectId, 3);
      expect(s.slug, 'ibd-consult-30min');
      expect(s.name, '30-minute IBD consult');
      expect(s.description, 'One-on-one telehealth visit.');
      expect(s.durationMinutes, 30);
      expect(s.priceCents, 7500);
      expect(s.currency, 'USD');
      expect(s.providerId, 42);
      expect(s.isActive, isTrue);
      expect(s.metadata, isEmpty);
    });

    test('fromJson decodes metadata when present', () {
      final s = Service.fromJson(<String, dynamic>{
        'id': 5,
        'subproject_id': 3,
        'slug': 'ibd-consult-30min',
        'name': '30-minute IBD consult',
        'description': '...',
        'duration_minutes': 30,
        'price_cents': 7500,
        'currency': 'USD',
        'provider_id': 42,
        'is_active': true,
        'metadata': <String, dynamic>{'category': 'gastro', 'tags': 'urgent'},
        'created_at': '2026-05-01T08:00:00Z',
      });

      expect(s.metadata['category'], 'gastro');
      expect(s.metadata['tags'], 'urgent');
    });

    test('fromJson defaults metadata to empty map when missing', () {
      final s = Service.fromJson(<String, dynamic>{
        'id': 1,
        'subproject_id': 3,
        'slug': 's',
        'name': 'n',
        'description': 'd',
        'duration_minutes': 15,
        'price_cents': 0,
        'currency': 'USD',
        'provider_id': 1,
        'is_active': false,
        'created_at': '2026-05-01T08:00:00Z',
      });

      expect(s.metadata, isA<Map<String, dynamic>>());
      expect(s.metadata, isEmpty);
      expect(s.isActive, isFalse);
    });

    test('toJson round-trips back to fromJson identity', () {
      final original = Service(
        id: 5,
        subprojectId: 3,
        slug: 'ibd-consult-30min',
        name: '30-minute IBD consult',
        description: 'One-on-one.',
        durationMinutes: 30,
        priceCents: 7500,
        currency: 'USD',
        providerId: 42,
        metadata: const <String, dynamic>{'category': 'gastro'},
        isActive: true,
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );

      final round = Service.fromJson(original.toJson());

      expect(round, equals(original));
      expect(round.hashCode, equals(original.hashCode));
    });

    test('copyWith with no args returns equal instance', () {
      final s = Service(
        id: 5,
        subprojectId: 3,
        slug: 'ibd-consult-30min',
        name: '30-minute IBD consult',
        description: '...',
        durationMinutes: 30,
        priceCents: 7500,
        currency: 'USD',
        providerId: 42,
        isActive: true,
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );
      expect(s.copyWith(), equals(s));
    });

    test('copyWith updates a single field', () {
      final s = Service(
        id: 5,
        subprojectId: 3,
        slug: 'ibd-consult-30min',
        name: '30-minute IBD consult',
        description: '...',
        durationMinutes: 30,
        priceCents: 7500,
        currency: 'USD',
        providerId: 42,
        isActive: true,
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );
      final inactive = s.copyWith(isActive: false);

      expect(inactive.isActive, isFalse);
      expect(inactive.id, s.id);
      expect(inactive, isNot(equals(s)));
    });

    test('two equal instances are == and have equal hashCode', () {
      final a = Service(
        id: 5,
        subprojectId: 3,
        slug: 'x',
        name: 'n',
        description: 'd',
        durationMinutes: 30,
        priceCents: 7500,
        currency: 'USD',
        providerId: 42,
        isActive: true,
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );
      final b = Service(
        id: 5,
        subprojectId: 3,
        slug: 'x',
        name: 'n',
        description: 'd',
        durationMinutes: 30,
        priceCents: 7500,
        currency: 'USD',
        providerId: 42,
        isActive: true,
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString includes class name, id, slug', () {
      final s = Service(
        id: 5,
        subprojectId: 3,
        slug: 'ibd-consult-30min',
        name: 'n',
        description: 'd',
        durationMinutes: 30,
        priceCents: 7500,
        currency: 'USD',
        providerId: 42,
        isActive: true,
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );

      final str = s.toString();
      expect(str, contains('Service'));
      expect(str, contains('5'));
      expect(str, contains('ibd-consult-30min'));
    });
  });

  group('services_models re-exports', () {
    test('Schedule is importable from services_models.dart', () {
      // Resolved purely through services_models — confirms the
      // `export ... show Schedule` re-export works.
      final s = Schedule.fromJson(<String, dynamic>{
        'id': 1,
        'subproject_id': 1,
        'provider_id': 1,
        'starts_at': '2026-05-20T09:00:00Z',
        'ends_at': '2026-05-20T09:30:00Z',
        'status': 'open',
        'capacity': 1,
        'created_at': '2026-05-01T08:00:00Z',
        'updated_at': '2026-05-01T08:00:00Z',
      });
      expect(s, isA<Schedule>());
    });

    test('ScheduleCall is importable from services_models.dart', () {
      final c = ScheduleCall.fromJson(<String, dynamic>{
        'id': 1,
        'schedule_id': 1,
        'patient_id': 1,
        'provider_id': 1,
        'status': 'pending',
        'created_at': '2026-05-20T08:55:00Z',
      });
      expect(c, isA<ScheduleCall>());
    });
  });
}
