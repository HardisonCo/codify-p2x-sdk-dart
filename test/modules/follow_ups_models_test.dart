// Tests for the FollowUp model class — plain @immutable data class.

import 'package:codify_p2x_sdk/src/modules/follow_ups_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FollowUp', () {
    test('fromJson handles required fields with optionals null', () {
      final f = FollowUp.fromJson(<String, dynamic>{
        'id': 21,
        'patient_id': 99,
        'provider_id': 42,
        'due_at': '2026-05-25T08:00:00Z',
        'status': 'pending',
        'created_at': '2026-05-20T08:00:00Z',
        'updated_at': '2026-05-20T08:00:00Z',
      });

      expect(f.id, 21);
      expect(f.patientId, 99);
      expect(f.providerId, 42);
      expect(f.dueAt, DateTime.parse('2026-05-25T08:00:00Z'));
      expect(f.status, 'pending');
      expect(f.notes, isNull);
      expect(f.voiceUrl, isNull);
      expect(f.voiceDurationSeconds, isNull);
    });

    test('fromJson handles all optional fields', () {
      final f = FollowUp.fromJson(<String, dynamic>{
        'id': 21,
        'patient_id': 99,
        'provider_id': 42,
        'due_at': '2026-05-25T08:00:00Z',
        'status': 'completed',
        'notes': 'Patient feels much better.',
        'voice_url': 'https://cdn.x/voice.m4a',
        'voice_duration_seconds': 42,
        'created_at': '2026-05-20T08:00:00Z',
        'updated_at': '2026-05-26T08:00:00Z',
      });

      expect(f.notes, 'Patient feels much better.');
      expect(f.voiceUrl, 'https://cdn.x/voice.m4a');
      expect(f.voiceDurationSeconds, 42);
      expect(f.status, 'completed');
    });

    test('toJson round-trips back to fromJson identity', () {
      final original = FollowUp(
        id: 21,
        patientId: 99,
        providerId: 42,
        dueAt: DateTime.parse('2026-05-25T08:00:00Z'),
        status: 'completed',
        notes: 'All good.',
        voiceUrl: 'https://cdn.x/voice.m4a',
        voiceDurationSeconds: 42,
        createdAt: DateTime.parse('2026-05-20T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-26T08:00:00Z'),
      );

      final round = FollowUp.fromJson(original.toJson());

      expect(round, equals(original));
      expect(round.hashCode, equals(original.hashCode));
    });

    test('toJson omits null optionals', () {
      final f = FollowUp(
        id: 21,
        patientId: 99,
        providerId: 42,
        dueAt: DateTime.parse('2026-05-25T08:00:00Z'),
        status: 'pending',
        createdAt: DateTime.parse('2026-05-20T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-20T08:00:00Z'),
      );

      final json = f.toJson();
      expect(json.containsKey('notes'), isFalse);
      expect(json.containsKey('voice_url'), isFalse);
      expect(json.containsKey('voice_duration_seconds'), isFalse);
    });

    test('copyWith with no args returns equal instance', () {
      final f = FollowUp(
        id: 21,
        patientId: 99,
        providerId: 42,
        dueAt: DateTime.parse('2026-05-25T08:00:00Z'),
        status: 'pending',
        createdAt: DateTime.parse('2026-05-20T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-20T08:00:00Z'),
      );
      expect(f.copyWith(), equals(f));
    });

    test('copyWith updates a single field', () {
      final f = FollowUp(
        id: 21,
        patientId: 99,
        providerId: 42,
        dueAt: DateTime.parse('2026-05-25T08:00:00Z'),
        status: 'pending',
        createdAt: DateTime.parse('2026-05-20T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-20T08:00:00Z'),
      );
      final done = f.copyWith(status: 'completed');

      expect(done.status, 'completed');
      expect(done.id, f.id);
      expect(done, isNot(equals(f)));
    });

    test('two equal instances are == and have equal hashCode', () {
      final a = FollowUp(
        id: 1,
        patientId: 1,
        providerId: 1,
        dueAt: DateTime.parse('2026-05-25T08:00:00Z'),
        status: 'pending',
        createdAt: DateTime.parse('2026-05-20T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-20T08:00:00Z'),
      );
      final b = FollowUp(
        id: 1,
        patientId: 1,
        providerId: 1,
        dueAt: DateTime.parse('2026-05-25T08:00:00Z'),
        status: 'pending',
        createdAt: DateTime.parse('2026-05-20T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-20T08:00:00Z'),
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString includes class name, id, status', () {
      final f = FollowUp(
        id: 21,
        patientId: 99,
        providerId: 42,
        dueAt: DateTime.parse('2026-05-25T08:00:00Z'),
        status: 'in_progress',
        createdAt: DateTime.parse('2026-05-20T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-20T08:00:00Z'),
      );

      final str = f.toString();
      expect(str, contains('FollowUp'));
      expect(str, contains('21'));
      expect(str, contains('in_progress'));
    });
  });
}
