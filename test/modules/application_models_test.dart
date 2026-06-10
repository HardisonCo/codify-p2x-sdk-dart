// Tests for the Application model class — plain @immutable data class
// (no freezed).

import 'package:ycaas_flutter_sdk/src/modules/application_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Application', () {
    test('fromJson handles required fields', () {
      final a = Application.fromJson(const <String, dynamic>{
        'id': 11,
        'subproject_id': 3,
        'type': 'doctor_request',
        'status': 'draft',
        'created_at': '2026-05-01T08:00:00Z',
        'updated_at': '2026-05-01T08:00:00Z',
      });

      expect(a.id, 11);
      expect(a.subprojectId, 3);
      expect(a.type, 'doctor_request');
      expect(a.status, 'draft');
      expect(a.createdAt, DateTime.parse('2026-05-01T08:00:00Z'));
      expect(a.updatedAt, DateTime.parse('2026-05-01T08:00:00Z'));
      expect(a.payload, isEmpty);
    });

    test('fromJson handles a populated payload', () {
      final a = Application.fromJson(const <String, dynamic>{
        'id': 11,
        'subproject_id': 3,
        'type': 'doctor_request',
        'status': 'submitted',
        'payload': <String, dynamic>{
          'license_state': 'NY',
          'specialty': 'gastroenterology',
        },
        'created_at': '2026-05-01T08:00:00Z',
        'updated_at': '2026-05-01T08:00:00Z',
      });

      expect(a.status, 'submitted');
      expect(a.payload['license_state'], 'NY');
      expect(a.payload['specialty'], 'gastroenterology');
    });

    test('fromJson defaults payload to empty map when missing', () {
      final a = Application.fromJson(const <String, dynamic>{
        'id': 11,
        'subproject_id': 3,
        'type': 'doctor_request',
        'status': 'draft',
        'created_at': '2026-05-01T08:00:00Z',
        'updated_at': '2026-05-01T08:00:00Z',
      });

      expect(a.payload, isA<Map<String, dynamic>>());
      expect(a.payload, isEmpty);
    });

    test('toJson round-trips back to fromJson identity', () {
      final original = Application(
        id: 11,
        subprojectId: 3,
        type: 'doctor_request',
        status: 'submitted',
        payload: const <String, dynamic>{
          'license_state': 'NY',
          'specialty': 'gastroenterology',
        },
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-02T08:00:00Z'),
      );

      final round = Application.fromJson(original.toJson());

      expect(round, equals(original));
      expect(round.hashCode, equals(original.hashCode));
    });

    test('copyWith with no args returns equal instance', () {
      final a = Application(
        id: 11,
        subprojectId: 3,
        type: 'doctor_request',
        status: 'draft',
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );

      expect(a.copyWith(), equals(a));
    });

    test('copyWith updates a single field', () {
      final a = Application(
        id: 11,
        subprojectId: 3,
        type: 'doctor_request',
        status: 'draft',
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );
      final submitted = a.copyWith(status: 'submitted');

      expect(submitted.status, 'submitted');
      expect(submitted.id, a.id);
      expect(submitted, isNot(equals(a)));
    });

    test('two equal instances are == and have equal hashCode', () {
      final created = DateTime.parse('2026-05-01T08:00:00Z');
      final updated = DateTime.parse('2026-05-01T08:00:00Z');
      final a = Application(
        id: 1,
        subprojectId: 3,
        type: 'doctor_request',
        status: 'draft',
        createdAt: created,
        updatedAt: updated,
      );
      final b = Application(
        id: 1,
        subprojectId: 3,
        type: 'doctor_request',
        status: 'draft',
        createdAt: created,
        updatedAt: updated,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString includes class name, id, type, status', () {
      final a = Application(
        id: 11,
        subprojectId: 3,
        type: 'doctor_request',
        status: 'submitted',
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );

      final s = a.toString();
      expect(s, contains('Application'));
      expect(s, contains('11'));
      expect(s, contains('doctor_request'));
      expect(s, contains('submitted'));
    });
  });
}
