// Tests for the Verification model class — plain @immutable data class
// (no freezed).

import 'package:ycaas_flutter_sdk/src/modules/verification_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Verification', () {
    test('fromJson handles required fields', () {
      final v = Verification.fromJson(const <String, dynamic>{
        'id': 21,
        'subproject_id': 3,
        'document_type': 'medical_license',
        'document_url': 'https://storage.example.com/license-21.pdf',
        'status': 'pending',
        'created_at': '2026-05-01T08:00:00Z',
        'updated_at': '2026-05-01T08:00:00Z',
      });

      expect(v.id, 21);
      expect(v.subprojectId, 3);
      expect(v.documentType, 'medical_license');
      expect(v.documentUrl, 'https://storage.example.com/license-21.pdf');
      expect(v.status, 'pending');
      expect(v.reviewerNotes, isNull);
      expect(v.createdAt, DateTime.parse('2026-05-01T08:00:00Z'));
      expect(v.updatedAt, DateTime.parse('2026-05-01T08:00:00Z'));
    });

    test('fromJson handles all optional fields', () {
      final v = Verification.fromJson(const <String, dynamic>{
        'id': 21,
        'subproject_id': 3,
        'document_type': 'dea',
        'document_url': 'https://storage.example.com/dea-21.pdf',
        'status': 'rejected',
        'reviewer_notes': 'Image is illegible — please reupload.',
        'created_at': '2026-05-01T08:00:00Z',
        'updated_at': '2026-05-02T08:00:00Z',
      });

      expect(v.status, 'rejected');
      expect(v.reviewerNotes, 'Image is illegible — please reupload.');
    });

    test('toJson omits reviewerNotes when null', () {
      final v = Verification(
        id: 21,
        subprojectId: 3,
        documentType: 'medical_license',
        documentUrl: 'https://storage.example.com/license-21.pdf',
        status: 'pending',
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );

      final json = v.toJson();
      expect(json.containsKey('reviewer_notes'), isFalse);
    });

    test('toJson round-trips back to fromJson identity', () {
      final original = Verification(
        id: 21,
        subprojectId: 3,
        documentType: 'malpractice_insurance',
        documentUrl: 'https://storage.example.com/mal-21.pdf',
        status: 'in_review',
        reviewerNotes: 'Awaiting third-party check.',
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-02T08:00:00Z'),
      );

      final round = Verification.fromJson(original.toJson());

      expect(round, equals(original));
      expect(round.hashCode, equals(original.hashCode));
    });

    test('copyWith with no args returns equal instance', () {
      final v = Verification(
        id: 21,
        subprojectId: 3,
        documentType: 'medical_license',
        documentUrl: 'https://storage.example.com/license-21.pdf',
        status: 'pending',
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );

      expect(v.copyWith(), equals(v));
    });

    test('copyWith updates a single field', () {
      final v = Verification(
        id: 21,
        subprojectId: 3,
        documentType: 'medical_license',
        documentUrl: 'https://storage.example.com/license-21.pdf',
        status: 'pending',
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );
      final verified = v.copyWith(status: 'verified');

      expect(verified.status, 'verified');
      expect(verified.id, v.id);
      expect(verified, isNot(equals(v)));
    });

    test('two equal instances are == and have equal hashCode', () {
      final created = DateTime.parse('2026-05-01T08:00:00Z');
      final updated = DateTime.parse('2026-05-01T08:00:00Z');
      final a = Verification(
        id: 1,
        subprojectId: 3,
        documentType: 'medical_license',
        documentUrl: 'https://x/y.pdf',
        status: 'pending',
        createdAt: created,
        updatedAt: updated,
      );
      final b = Verification(
        id: 1,
        subprojectId: 3,
        documentType: 'medical_license',
        documentUrl: 'https://x/y.pdf',
        status: 'pending',
        createdAt: created,
        updatedAt: updated,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString includes class name, id, documentType, status', () {
      final v = Verification(
        id: 21,
        subprojectId: 3,
        documentType: 'medical_license',
        documentUrl: 'https://storage.example.com/license-21.pdf',
        status: 'in_review',
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );

      final s = v.toString();
      expect(s, contains('Verification'));
      expect(s, contains('21'));
      expect(s, contains('medical_license'));
      expect(s, contains('in_review'));
    });
  });
}
