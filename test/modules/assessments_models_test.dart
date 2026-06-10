// Tests for AssessmentResponse + AssessmentResponseList model classes —
// plain @immutable data classes (no freezed).

import 'package:ycaas_flutter_sdk/src/modules/assessments_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AssessmentResponse', () {
    test('fromJson handles required fields (surveyKey, payload)', () {
      final r = AssessmentResponse.fromJson(<String, dynamic>{
        'survey_key': 'food-intake-daily',
        'payload': <String, dynamic>{
          'calories': 1840,
          'protein_g': 120,
        },
      });

      expect(r.id, isNull);
      expect(r.surveyKey, 'food-intake-daily');
      expect(r.payload['calories'], 1840);
      expect(r.payload['protein_g'], 120);
      expect(r.userId, isNull);
      expect(r.subprojectId, isNull);
      expect(r.createdAt, isNull);
    });

    test('fromJson handles all optional fields', () {
      final r = AssessmentResponse.fromJson(<String, dynamic>{
        'id': 17,
        'survey_key': 'food-intake-daily',
        'payload': <String, dynamic>{'foo': 'bar'},
        'user_id': 42,
        'subproject_id': 3,
        'created_at': '2026-05-01T08:00:00Z',
      });

      expect(r.id, 17);
      expect(r.userId, 42);
      expect(r.subprojectId, 3);
      expect(r.createdAt, DateTime.parse('2026-05-01T08:00:00Z'));
    });

    test('fromJson defaults payload to empty when absent', () {
      final r = AssessmentResponse.fromJson(<String, dynamic>{
        'survey_key': 'food-intake-daily',
      });
      expect(r.payload, isEmpty);
    });

    test('toJson round-trips back to fromJson identity', () {
      final original = AssessmentResponse(
        id: 17,
        surveyKey: 'food-intake-daily',
        payload: const <String, dynamic>{'calories': 1840},
        userId: 42,
        subprojectId: 3,
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );

      final round = AssessmentResponse.fromJson(original.toJson());

      expect(round, equals(original));
      expect(round.hashCode, equals(original.hashCode));
    });

    test('copyWith with no args returns equal instance', () {
      const r = AssessmentResponse(
        surveyKey: 'food-intake-daily',
        payload: <String, dynamic>{'a': 1},
      );

      expect(r.copyWith(), equals(r));
    });

    test('copyWith updates a single field', () {
      const r = AssessmentResponse(
        surveyKey: 'food-intake-daily',
        payload: <String, dynamic>{'a': 1},
      );
      final updated = r.copyWith(id: 99);

      expect(updated.id, 99);
      expect(updated.surveyKey, r.surveyKey);
      expect(updated, isNot(equals(r)));
    });

    test('two equal instances are == and have equal hashCode', () {
      const a = AssessmentResponse(
        surveyKey: 'food-intake-daily',
        payload: <String, dynamic>{'x': 1},
      );
      const b = AssessmentResponse(
        surveyKey: 'food-intake-daily',
        payload: <String, dynamic>{'x': 1},
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString includes class name and surveyKey', () {
      const r = AssessmentResponse(
        surveyKey: 'food-intake-daily',
        payload: <String, dynamic>{},
      );

      final s = r.toString();
      expect(s, contains('AssessmentResponse'));
      expect(s, contains('food-intake-daily'));
    });
  });

  group('AssessmentResponseList', () {
    test('fromJson handles a Laravel-paginator-shaped payload', () {
      final list = AssessmentResponseList.fromJson(<String, dynamic>{
        'data': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'survey_key': 'food-intake-daily',
            'payload': <String, dynamic>{'a': 1},
          },
          <String, dynamic>{
            'id': 2,
            'survey_key': 'food-intake-daily',
            'payload': <String, dynamic>{'b': 2},
          },
        ],
        'total': 27,
        'per_page': 50,
        'current_page': 1,
      });

      expect(list.data, hasLength(2));
      expect(list.data.first.id, 1);
      expect(list.data.last.id, 2);
      expect(list.total, 27);
      expect(list.perPage, 50);
      expect(list.currentPage, 1);
    });

    test('fromJson handles minimal payload (just data array)', () {
      final list = AssessmentResponseList.fromJson(<String, dynamic>{
        'data': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'survey_key': 'food-intake-daily',
            'payload': <String, dynamic>{},
          },
        ],
      });

      expect(list.data, hasLength(1));
      expect(list.total, 1); // fallback to data.length when total absent
      expect(list.perPage, isNull);
      expect(list.currentPage, isNull);
    });

    test('fromJson handles fully empty payload', () {
      final list = AssessmentResponseList.fromJson(<String, dynamic>{});
      expect(list.data, isEmpty);
      expect(list.total, 0);
    });

    test('two equal instances are == and have equal hashCode', () {
      const a = AssessmentResponseList(
        data: <AssessmentResponse>[
          AssessmentResponse(
            id: 1,
            surveyKey: 'k',
            payload: <String, dynamic>{},
          ),
        ],
        total: 1,
        perPage: 50,
        currentPage: 1,
      );
      const b = AssessmentResponseList(
        data: <AssessmentResponse>[
          AssessmentResponse(
            id: 1,
            surveyKey: 'k',
            payload: <String, dynamic>{},
          ),
        ],
        total: 1,
        perPage: 50,
        currentPage: 1,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString includes class name and total', () {
      const list = AssessmentResponseList(
        data: <AssessmentResponse>[],
        total: 0,
      );
      expect(list.toString(), contains('AssessmentResponseList'));
      expect(list.toString(), contains('total: 0'));
    });
  });
}
