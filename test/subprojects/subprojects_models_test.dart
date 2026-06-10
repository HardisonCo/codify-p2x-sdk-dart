// Tests for the Subprojects module model classes — Subproject and
// SubprojectFeatures. Plain @immutable data classes (no freezed).
//
// Covers JSON round-trips, optional-field permissiveness, copyWith,
// value-equality, and toString.

import 'package:ycaas_flutter_sdk/src/subprojects/subprojects_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Subproject', () {
    test('fromJson handles required fields (id, slug, name, domain)', () {
      final sp = Subproject.fromJson(<String, dynamic>{
        'id': 2,
        'slug': 'crohnie',
        'name': 'Crohnie AI',
        'domain': 'crohnie.ai',
      });

      expect(sp.id, 2);
      expect(sp.slug, 'crohnie');
      expect(sp.name, 'Crohnie AI');
      expect(sp.domain, 'crohnie.ai');
      expect(sp.kind, isNull);
      expect(sp.parentId, isNull);
      expect(sp.createdAt, isNull);
    });

    test('fromJson handles all optional fields', () {
      final sp = Subproject.fromJson(<String, dynamic>{
        'id': 5,
        'slug': 'doh-ny',
        'name': 'DOH NY',
        'domain': 'doh.ny.gov',
        'kind': 'agency',
        'parent_id': 1,
        'created_at': '2026-01-01T12:00:00Z',
      });

      expect(sp.kind, 'agency');
      expect(sp.parentId, 1);
      expect(sp.createdAt, DateTime.parse('2026-01-01T12:00:00Z'));
    });

    test('toJson round-trips back to fromJson identity', () {
      final original = Subproject(
        id: 5,
        slug: 'doh-ny',
        name: 'DOH NY',
        domain: 'doh.ny.gov',
        kind: 'agency',
        parentId: 1,
        createdAt: DateTime.parse('2026-01-01T12:00:00Z'),
      );

      final round = Subproject.fromJson(original.toJson());

      expect(round, equals(original));
      expect(round.hashCode, equals(original.hashCode));
    });

    test('copyWith with no args returns equal instance', () {
      const sp = Subproject(
        id: 2,
        slug: 'crohnie',
        name: 'Crohnie AI',
        domain: 'crohnie.ai',
      );

      expect(sp.copyWith(), equals(sp));
    });

    test('copyWith updates a single field', () {
      const sp = Subproject(
        id: 2,
        slug: 'crohnie',
        name: 'Crohnie AI',
        domain: 'crohnie.ai',
      );
      final updated = sp.copyWith(name: 'Crohnie Health');

      expect(updated.name, 'Crohnie Health');
      expect(updated.id, sp.id);
      expect(updated.slug, sp.slug);
      expect(updated.domain, sp.domain);
      expect(updated, isNot(equals(sp)));
    });

    test('two equal instances are == and have equal hashCode', () {
      const a = Subproject(
        id: 2,
        slug: 'crohnie',
        name: 'Crohnie AI',
        domain: 'crohnie.ai',
      );
      const b = Subproject(
        id: 2,
        slug: 'crohnie',
        name: 'Crohnie AI',
        domain: 'crohnie.ai',
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString includes class name and key fields', () {
      const sp = Subproject(
        id: 2,
        slug: 'crohnie',
        name: 'Crohnie AI',
        domain: 'crohnie.ai',
      );

      final s = sp.toString();
      expect(s, contains('Subproject'));
      expect(s, contains('crohnie'));
      expect(s, contains('Crohnie AI'));
      expect(s, contains('crohnie.ai'));
    });
  });

  group('SubprojectFeatures', () {
    test('fromJson reads the flags map', () {
      final feats = SubprojectFeatures.fromJson(<String, dynamic>{
        'flags': <String, dynamic>{
          'ibd_doctor_request': true,
          'phm_labs': false,
        },
      });

      expect(feats.flags, <String, bool>{
        'ibd_doctor_request': true,
        'phm_labs': false,
      });
    });

    test('fromJson handles missing flags as empty map', () {
      final feats = SubprojectFeatures.fromJson(<String, dynamic>{});
      expect(feats.flags, isEmpty);
    });

    test('isEnabled returns the flag value when present', () {
      const feats = SubprojectFeatures(
        flags: <String, bool>{'ibd_doctor_request': true, 'phm_labs': false},
      );

      expect(feats.isEnabled('ibd_doctor_request'), isTrue);
      expect(feats.isEnabled('phm_labs'), isFalse);
    });

    test('isEnabled defaults to false for missing keys', () {
      const feats = SubprojectFeatures(flags: <String, bool>{});
      expect(feats.isEnabled('unknown_feature'), isFalse);
    });

    test('toJson round-trips', () {
      const original = SubprojectFeatures(
        flags: <String, bool>{'a': true, 'b': false},
      );

      final round = SubprojectFeatures.fromJson(original.toJson());

      expect(round, equals(original));
      expect(round.hashCode, equals(original.hashCode));
    });

    test('two equal instances are == and have equal hashCode', () {
      const a = SubprojectFeatures(
        flags: <String, bool>{'a': true, 'b': false},
      );
      const b = SubprojectFeatures(
        flags: <String, bool>{'a': true, 'b': false},
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString includes class name', () {
      const feats = SubprojectFeatures(flags: <String, bool>{'a': true});
      expect(feats.toString(), contains('SubprojectFeatures'));
    });
  });
}
