// JSON-decode tests for the Workflow admin pipe-config model
// (Modules/Workflow — SubprojectPipeConfigResource).

import 'package:flutter_test/flutter_test.dart';
import 'package:ycaas_flutter_sdk/src/modules/workflow_models.dart';

void main() {
  group('SubprojectPipeConfig.fromJson', () {
    test('decodes the full resource shape', () {
      final c = SubprojectPipeConfig.fromJson(<String, dynamic>{
        'id': 12,
        'subproject_id': 7,
        'canonical_pipe_id': 3,
        'pipe_name': 'LocateResource',
        'provider_class': 'Modules\\Workflow\\Pipes\\LocateResourcePipe',
        'settings': <String, dynamic>{'mode': 'fast'},
        'is_active': true,
        'effective_from': '2026-06-01T08:00:00+00:00',
        'created_at': '2026-06-01T08:00:00+00:00',
        'updated_at': '2026-06-02T08:00:00+00:00',
      });

      expect(c.id, 12);
      expect(c.subprojectId, 7);
      expect(c.canonicalPipeId, 3);
      expect(c.pipeName, 'LocateResource');
      expect(c.providerClass, 'Modules\\Workflow\\Pipes\\LocateResourcePipe');
      expect(c.settings['mode'], 'fast');
      expect(c.isActive, isTrue);
      expect(c.effectiveFrom, DateTime.parse('2026-06-01T08:00:00+00:00'));
      expect(c.createdAt, isA<DateTime>());
      expect(c.updatedAt, isA<DateTime>());
    });

    test('tolerates a null pipe_name and cleared provider_class', () {
      final c = SubprojectPipeConfig.fromJson(<String, dynamic>{
        'id': 1,
        'subproject_id': 7,
        'canonical_pipe_id': 3,
        'pipe_name': null,
        'provider_class': null,
        'settings': null,
        'is_active': false,
      });

      expect(c.pipeName, isNull);
      expect(c.providerClass, isNull);
      expect(c.settings, isEmpty);
      expect(c.isActive, isFalse);
      expect(c.effectiveFrom, isNull);
    });

    test('is_active defaults to true when absent', () {
      final c = SubprojectPipeConfig.fromJson(<String, dynamic>{
        'id': 1,
        'subproject_id': 7,
        'canonical_pipe_id': 3,
      });
      expect(c.isActive, isTrue);
    });

    test('coerces string-numeric ids', () {
      final c = SubprojectPipeConfig.fromJson(<String, dynamic>{
        'id': '9',
        'subproject_id': '7',
        'canonical_pipe_id': '3',
      });
      expect(c.id, 9);
      expect(c.subprojectId, 7);
      expect(c.canonicalPipeId, 3);
    });
  });
}
