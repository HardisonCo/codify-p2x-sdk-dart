// Tests for the Schedule and ScheduleCall model classes — plain
// @immutable data classes (no freezed).

import 'package:codify_p2x_sdk/src/modules/schedule_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Schedule', () {
    test('fromJson handles required fields', () {
      final s = Schedule.fromJson(<String, dynamic>{
        'id': 11,
        'subproject_id': 3,
        'provider_id': 42,
        'starts_at': '2026-05-20T09:00:00Z',
        'ends_at': '2026-05-20T09:30:00Z',
        'status': 'open',
        'capacity': 1,
        'created_at': '2026-05-01T08:00:00Z',
        'updated_at': '2026-05-01T08:00:00Z',
      });

      expect(s.id, 11);
      expect(s.subprojectId, 3);
      expect(s.providerId, 42);
      expect(s.startsAt, DateTime.parse('2026-05-20T09:00:00Z'));
      expect(s.endsAt, DateTime.parse('2026-05-20T09:30:00Z'));
      expect(s.status, 'open');
      expect(s.capacity, 1);
      expect(s.metadata, isEmpty);
    });

    test('fromJson decodes metadata when present', () {
      final s = Schedule.fromJson(<String, dynamic>{
        'id': 11,
        'subproject_id': 3,
        'provider_id': 42,
        'starts_at': '2026-05-20T09:00:00Z',
        'ends_at': '2026-05-20T09:30:00Z',
        'status': 'reserved',
        'capacity': 1,
        'metadata': <String, dynamic>{'room': 'A', 'notes': 'urgent'},
        'created_at': '2026-05-01T08:00:00Z',
        'updated_at': '2026-05-01T08:00:00Z',
      });

      expect(s.status, 'reserved');
      expect(s.metadata['room'], 'A');
      expect(s.metadata['notes'], 'urgent');
    });

    test('fromJson defaults metadata to empty map when missing', () {
      final s = Schedule.fromJson(<String, dynamic>{
        'id': 1,
        'subproject_id': 3,
        'provider_id': 42,
        'starts_at': '2026-05-20T09:00:00Z',
        'ends_at': '2026-05-20T09:30:00Z',
        'status': 'open',
        'capacity': 2,
        'created_at': '2026-05-01T08:00:00Z',
        'updated_at': '2026-05-01T08:00:00Z',
      });

      expect(s.metadata, isA<Map<String, dynamic>>());
      expect(s.metadata, isEmpty);
    });

    test('toJson round-trips back to fromJson identity', () {
      final original = Schedule(
        id: 11,
        subprojectId: 3,
        providerId: 42,
        startsAt: DateTime.parse('2026-05-20T09:00:00Z'),
        endsAt: DateTime.parse('2026-05-20T09:30:00Z'),
        status: 'booked',
        capacity: 1,
        metadata: const <String, dynamic>{'room': 'B'},
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );

      final round = Schedule.fromJson(original.toJson());

      expect(round, equals(original));
      expect(round.hashCode, equals(original.hashCode));
    });

    test('copyWith with no args returns equal instance', () {
      final s = Schedule(
        id: 11,
        subprojectId: 3,
        providerId: 42,
        startsAt: DateTime.parse('2026-05-20T09:00:00Z'),
        endsAt: DateTime.parse('2026-05-20T09:30:00Z'),
        status: 'open',
        capacity: 1,
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );
      expect(s.copyWith(), equals(s));
    });

    test('copyWith updates a single field', () {
      final s = Schedule(
        id: 11,
        subprojectId: 3,
        providerId: 42,
        startsAt: DateTime.parse('2026-05-20T09:00:00Z'),
        endsAt: DateTime.parse('2026-05-20T09:30:00Z'),
        status: 'open',
        capacity: 1,
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );
      final booked = s.copyWith(status: 'booked');

      expect(booked.status, 'booked');
      expect(booked.id, s.id);
      expect(booked, isNot(equals(s)));
    });

    test('two equal instances are == and have equal hashCode', () {
      final a = Schedule(
        id: 1,
        subprojectId: 1,
        providerId: 1,
        startsAt: DateTime.parse('2026-05-20T09:00:00Z'),
        endsAt: DateTime.parse('2026-05-20T09:30:00Z'),
        status: 'open',
        capacity: 1,
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );
      final b = Schedule(
        id: 1,
        subprojectId: 1,
        providerId: 1,
        startsAt: DateTime.parse('2026-05-20T09:00:00Z'),
        endsAt: DateTime.parse('2026-05-20T09:30:00Z'),
        status: 'open',
        capacity: 1,
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString includes class name, id, status', () {
      final s = Schedule(
        id: 11,
        subprojectId: 3,
        providerId: 42,
        startsAt: DateTime.parse('2026-05-20T09:00:00Z'),
        endsAt: DateTime.parse('2026-05-20T09:30:00Z'),
        status: 'open',
        capacity: 1,
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );

      final str = s.toString();
      expect(str, contains('Schedule'));
      expect(str, contains('11'));
      expect(str, contains('open'));
    });
  });

  group('ScheduleCall', () {
    test('fromJson handles required fields with optionals null', () {
      final c = ScheduleCall.fromJson(<String, dynamic>{
        'id': 7,
        'schedule_id': 11,
        'patient_id': 99,
        'provider_id': 42,
        'status': 'pending',
        'created_at': '2026-05-20T08:55:00Z',
      });

      expect(c.id, 7);
      expect(c.scheduleId, 11);
      expect(c.patientId, 99);
      expect(c.providerId, 42);
      expect(c.status, 'pending');
      expect(c.startedAt, isNull);
      expect(c.endedAt, isNull);
      expect(c.livekitRoom, isNull);
      expect(c.metadata, isEmpty);
    });

    test('fromJson handles all optional fields', () {
      final c = ScheduleCall.fromJson(<String, dynamic>{
        'id': 7,
        'schedule_id': 11,
        'patient_id': 99,
        'provider_id': 42,
        'status': 'connected',
        'started_at': '2026-05-20T09:00:00Z',
        'ended_at': '2026-05-20T09:25:00Z',
        'livekit_room': 'room-abc',
        'metadata': <String, dynamic>{'recording_url': 'https://x'},
        'created_at': '2026-05-20T08:55:00Z',
      });

      expect(c.startedAt, DateTime.parse('2026-05-20T09:00:00Z'));
      expect(c.endedAt, DateTime.parse('2026-05-20T09:25:00Z'));
      expect(c.livekitRoom, 'room-abc');
      expect(c.metadata['recording_url'], 'https://x');
    });

    test('toJson round-trips back to fromJson identity', () {
      final original = ScheduleCall(
        id: 7,
        scheduleId: 11,
        patientId: 99,
        providerId: 42,
        status: 'connected',
        startedAt: DateTime.parse('2026-05-20T09:00:00Z'),
        endedAt: DateTime.parse('2026-05-20T09:25:00Z'),
        livekitRoom: 'room-abc',
        metadata: const <String, dynamic>{'recording_url': 'https://x'},
        createdAt: DateTime.parse('2026-05-20T08:55:00Z'),
      );

      final round = ScheduleCall.fromJson(original.toJson());

      expect(round, equals(original));
      expect(round.hashCode, equals(original.hashCode));
    });

    test('copyWith with no args returns equal instance', () {
      final c = ScheduleCall(
        id: 7,
        scheduleId: 11,
        patientId: 99,
        providerId: 42,
        status: 'pending',
        createdAt: DateTime.parse('2026-05-20T08:55:00Z'),
      );
      expect(c.copyWith(), equals(c));
    });

    test('copyWith updates a single field', () {
      final c = ScheduleCall(
        id: 7,
        scheduleId: 11,
        patientId: 99,
        providerId: 42,
        status: 'pending',
        createdAt: DateTime.parse('2026-05-20T08:55:00Z'),
      );
      final ended = c.copyWith(
        status: 'ended',
        endedAt: DateTime.parse('2026-05-20T09:25:00Z'),
      );

      expect(ended.status, 'ended');
      expect(ended.endedAt, DateTime.parse('2026-05-20T09:25:00Z'));
      expect(ended.id, c.id);
      expect(ended, isNot(equals(c)));
    });

    test('two equal instances are == and have equal hashCode', () {
      final a = ScheduleCall(
        id: 1,
        scheduleId: 1,
        patientId: 1,
        providerId: 1,
        status: 'pending',
        createdAt: DateTime.parse('2026-05-20T08:55:00Z'),
      );
      final b = ScheduleCall(
        id: 1,
        scheduleId: 1,
        patientId: 1,
        providerId: 1,
        status: 'pending',
        createdAt: DateTime.parse('2026-05-20T08:55:00Z'),
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString includes class name, id, status', () {
      final c = ScheduleCall(
        id: 7,
        scheduleId: 11,
        patientId: 99,
        providerId: 42,
        status: 'connected',
        createdAt: DateTime.parse('2026-05-20T08:55:00Z'),
      );

      final str = c.toString();
      expect(str, contains('ScheduleCall'));
      expect(str, contains('7'));
      expect(str, contains('connected'));
    });
  });
}
