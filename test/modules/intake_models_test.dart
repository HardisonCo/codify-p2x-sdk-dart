// Tests for the Intake module model classes — Intake, IntakeHandoff,
// IntakeStatus.

import 'package:ycaas_flutter_sdk/src/modules/intake_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Intake', () {
    test('fromJson handles required fields with optionals null', () {
      final i = Intake.fromJson(<String, dynamic>{
        'id': 'intake_123',
        'subproject_id': 'sp_crohnie',
        'answers': <String, dynamic>{},
        'status': 'open',
        'created_at': '2026-05-15T08:00:00Z',
        'updated_at': '2026-05-15T08:00:00Z',
      });

      expect(i.id, 'intake_123');
      expect(i.subprojectId, 'sp_crohnie');
      expect(i.userId, isNull);
      expect(i.audience, isNull);
      expect(i.answers, isEmpty);
      expect(i.voiceUrl, isNull);
      expect(i.voiceDurationSeconds, isNull);
      expect(i.voiceTranscript, isNull);
      expect(i.status, 'open');
    });

    test('fromJson handles all optional fields', () {
      final i = Intake.fromJson(<String, dynamic>{
        'id': 'intake_123',
        'subproject_id': 'sp_crohnie',
        'user_id': 'user_777',
        'audience': 'patient',
        'answers': <String, dynamic>{'q1': 'yes'},
        'voice_url': 'https://cdn.x/intake.m4a',
        'voice_duration_seconds': 95,
        'voice_transcript': 'I have been feeling unwell.',
        'status': 'voice_pending',
        'created_at': '2026-05-15T08:00:00Z',
        'updated_at': '2026-05-16T08:00:00Z',
      });

      expect(i.userId, 'user_777');
      expect(i.audience, 'patient');
      expect(i.answers['q1'], 'yes');
      expect(i.voiceUrl, 'https://cdn.x/intake.m4a');
      expect(i.voiceDurationSeconds, 95);
      expect(i.voiceTranscript, 'I have been feeling unwell.');
      expect(i.status, 'voice_pending');
    });

    test('toJson round-trips back to fromJson identity', () {
      final original = Intake(
        id: 'intake_abc',
        subprojectId: 'sp_crohnie',
        userId: 'user_42',
        audience: 'family_member',
        answers: const <String, dynamic>{'q1': 'yes', 'q2': 3},
        voiceUrl: 'https://cdn.x/intake.m4a',
        voiceDurationSeconds: 95,
        voiceTranscript: 'Hello world.',
        status: 'completed',
        createdAt: DateTime.parse('2026-05-15T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-16T08:00:00Z'),
      );

      final round = Intake.fromJson(original.toJson());

      expect(round, equals(original));
      expect(round.hashCode, equals(original.hashCode));
    });

    test('toJson omits null optionals', () {
      final i = Intake(
        id: 'intake_abc',
        subprojectId: 'sp_crohnie',
        answers: const <String, dynamic>{},
        status: 'open',
        createdAt: DateTime.parse('2026-05-15T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-15T08:00:00Z'),
      );

      final json = i.toJson();
      expect(json.containsKey('user_id'), isFalse);
      expect(json.containsKey('audience'), isFalse);
      expect(json.containsKey('voice_url'), isFalse);
      expect(json.containsKey('voice_duration_seconds'), isFalse);
      expect(json.containsKey('voice_transcript'), isFalse);
    });

    test('copyWith with no args returns equal instance', () {
      final i = Intake(
        id: 'intake_abc',
        subprojectId: 'sp_crohnie',
        answers: const <String, dynamic>{},
        status: 'open',
        createdAt: DateTime.parse('2026-05-15T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-15T08:00:00Z'),
      );
      expect(i.copyWith(), equals(i));
    });

    test('copyWith updates a single field', () {
      final i = Intake(
        id: 'intake_abc',
        subprojectId: 'sp_crohnie',
        answers: const <String, dynamic>{},
        status: 'open',
        createdAt: DateTime.parse('2026-05-15T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-15T08:00:00Z'),
      );
      final done = i.copyWith(status: 'completed');

      expect(done.status, 'completed');
      expect(done.id, i.id);
      expect(done, isNot(equals(i)));
    });

    test('two equal instances are == and have equal hashCode', () {
      final answers = <String, dynamic>{'q1': 'yes'};
      final a = Intake(
        id: 'intake_abc',
        subprojectId: 'sp_crohnie',
        answers: answers,
        status: 'open',
        createdAt: DateTime.parse('2026-05-15T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-15T08:00:00Z'),
      );
      final b = Intake(
        id: 'intake_abc',
        subprojectId: 'sp_crohnie',
        answers: answers,
        status: 'open',
        createdAt: DateTime.parse('2026-05-15T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-15T08:00:00Z'),
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString includes class name, id, status', () {
      final i = Intake(
        id: 'intake_abc',
        subprojectId: 'sp_crohnie',
        answers: const <String, dynamic>{},
        status: 'in_progress',
        createdAt: DateTime.parse('2026-05-15T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-15T08:00:00Z'),
      );

      final str = i.toString();
      expect(str, contains('Intake'));
      expect(str, contains('intake_abc'));
      expect(str, contains('in_progress'));
    });
  });

  group('IntakeHandoff', () {
    test('fromJson handles all fields with no nested intake', () {
      final h = IntakeHandoff.fromJson(<String, dynamic>{
        'token': 'hndf_xyz',
        'expires_at': '2026-05-16T09:00:00Z',
        'target_subproject_domain': 'ibd.codifyhq.com',
        'exchange_url':
            'https://api.project20x.com/api/v1/intake/handoff/hndf_xyz/exchange',
      });

      expect(h.token, 'hndf_xyz');
      expect(h.expiresAt, DateTime.parse('2026-05-16T09:00:00Z'));
      expect(h.targetSubprojectDomain, 'ibd.codifyhq.com');
      expect(h.exchangeUrl, contains('/exchange'));
      expect(h.intake, isNull);
    });

    test('fromJson decodes nested intake when present', () {
      final h = IntakeHandoff.fromJson(<String, dynamic>{
        'token': 'hndf_xyz',
        'expires_at': '2026-05-16T09:00:00Z',
        'target_subproject_domain': 'ibd.codifyhq.com',
        'exchange_url':
            'https://api.project20x.com/api/v1/intake/handoff/hndf_xyz/exchange',
        'intake': <String, dynamic>{
          'id': 'intake_abc',
          'subproject_id': 'sp_ibd',
          'answers': <String, dynamic>{},
          'status': 'handed_off',
          'created_at': '2026-05-15T08:00:00Z',
          'updated_at': '2026-05-15T08:00:00Z',
        },
      });

      expect(h.intake, isNotNull);
      expect(h.intake!.id, 'intake_abc');
      expect(h.intake!.status, 'handed_off');
    });

    test('toJson round-trips through fromJson', () {
      final original = IntakeHandoff(
        token: 'hndf_xyz',
        expiresAt: DateTime.parse('2026-05-16T09:00:00Z'),
        targetSubprojectDomain: 'ibd.codifyhq.com',
        exchangeUrl:
            'https://api.project20x.com/api/v1/intake/handoff/hndf_xyz/exchange',
        intake: Intake(
          id: 'intake_abc',
          subprojectId: 'sp_ibd',
          answers: const <String, dynamic>{},
          status: 'handed_off',
          createdAt: DateTime.parse('2026-05-15T08:00:00Z'),
          updatedAt: DateTime.parse('2026-05-15T08:00:00Z'),
        ),
      );

      final round = IntakeHandoff.fromJson(original.toJson());

      expect(round, equals(original));
      expect(round.hashCode, equals(original.hashCode));
    });

    test('toJson omits null intake', () {
      final h = IntakeHandoff(
        token: 'hndf_xyz',
        expiresAt: DateTime.parse('2026-05-16T09:00:00Z'),
        targetSubprojectDomain: 'ibd.codifyhq.com',
        exchangeUrl: 'https://example.com/exchange',
      );
      expect(h.toJson().containsKey('intake'), isFalse);
    });
  });

  group('IntakeStatus', () {
    test('fromJson handles required fields', () {
      final s = IntakeStatus.fromJson(<String, dynamic>{
        'intake_id': 'intake_abc',
        'status': 'voice_pending',
        'updated_at': '2026-05-16T08:00:00Z',
        'ready_for_handoff': false,
      });

      expect(s.intakeId, 'intake_abc');
      expect(s.status, 'voice_pending');
      expect(s.updatedAt, DateTime.parse('2026-05-16T08:00:00Z'));
      expect(s.readyForHandoff, isFalse);
    });

    test('toJson round-trips through fromJson', () {
      final original = IntakeStatus(
        intakeId: 'intake_abc',
        status: 'completed',
        updatedAt: DateTime.parse('2026-05-16T08:00:00Z'),
        readyForHandoff: true,
      );

      final round = IntakeStatus.fromJson(original.toJson());

      expect(round, equals(original));
      expect(round.hashCode, equals(original.hashCode));
    });

    test('two equal instances are == and have equal hashCode', () {
      final a = IntakeStatus(
        intakeId: 'i_1',
        status: 'open',
        updatedAt: DateTime.parse('2026-05-16T08:00:00Z'),
        readyForHandoff: false,
      );
      final b = IntakeStatus(
        intakeId: 'i_1',
        status: 'open',
        updatedAt: DateTime.parse('2026-05-16T08:00:00Z'),
        readyForHandoff: false,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
