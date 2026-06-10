// Tests for the RunActivity + RunLocationPoint model classes — plain
// @immutable data classes (no freezed).

import 'package:ycaas_flutter_sdk/src/modules/activity_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RunLocationPoint', () {
    test('fromJson handles required fields', () {
      final p = RunLocationPoint.fromJson(<String, dynamic>{
        'latitude': 37.7749,
        'longitude': -122.4194,
        'recorded_at': '2026-05-01T08:00:00Z',
      });

      expect(p.latitude, 37.7749);
      expect(p.longitude, -122.4194);
      expect(p.recordedAt, DateTime.parse('2026-05-01T08:00:00Z'));
      expect(p.altitudeMeters, isNull);
      expect(p.accuracyMeters, isNull);
    });

    test('fromJson handles optional altitude + accuracy', () {
      final p = RunLocationPoint.fromJson(<String, dynamic>{
        'latitude': 37.7749,
        'longitude': -122.4194,
        'altitude_meters': 30.5,
        'accuracy_meters': 5.0,
        'recorded_at': '2026-05-01T08:00:00Z',
      });

      expect(p.altitudeMeters, 30.5);
      expect(p.accuracyMeters, 5.0);
    });

    test('fromJson coerces integer lat/lng/altitude to double', () {
      final p = RunLocationPoint.fromJson(<String, dynamic>{
        'latitude': 37,
        'longitude': -122,
        'altitude_meters': 30,
        'accuracy_meters': 5,
        'recorded_at': '2026-05-01T08:00:00Z',
      });

      expect(p.latitude, 37.0);
      expect(p.latitude, isA<double>());
      expect(p.altitudeMeters, 30.0);
      expect(p.accuracyMeters, 5.0);
    });

    test('toJson round-trips back to fromJson identity', () {
      final original = RunLocationPoint(
        latitude: 37.7749,
        longitude: -122.4194,
        altitudeMeters: 30.5,
        accuracyMeters: 5,
        recordedAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );

      final round = RunLocationPoint.fromJson(original.toJson());
      expect(round, equals(original));
      expect(round.hashCode, equals(original.hashCode));
    });

    test('two equal instances are == and have equal hashCode', () {
      final a = RunLocationPoint(
        latitude: 1,
        longitude: 2,
        recordedAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );
      final b = RunLocationPoint(
        latitude: 1,
        longitude: 2,
        recordedAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('copyWith with no args returns equal instance', () {
      final p = RunLocationPoint(
        latitude: 1,
        longitude: 2,
        recordedAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );
      expect(p.copyWith(), equals(p));
    });

    test('toString includes class name and lat/lng', () {
      final p = RunLocationPoint(
        latitude: 37.7749,
        longitude: -122.4194,
        recordedAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );
      final s = p.toString();
      expect(s, contains('RunLocationPoint'));
      expect(s, contains('37.7749'));
      expect(s, contains('-122.4194'));
    });
  });

  group('RunActivity', () {
    test('fromJson handles required fields', () {
      final r = RunActivity.fromJson(<String, dynamic>{
        'distance_meters': 5000.0,
        'duration_seconds': 1800,
        'started_at': '2026-05-01T08:00:00Z',
        'route': <Map<String, dynamic>>[],
      });

      expect(r.distanceMeters, 5000.0);
      expect(r.duration, const Duration(seconds: 1800));
      expect(r.startedAt, DateTime.parse('2026-05-01T08:00:00Z'));
      expect(r.id, isNull);
      expect(r.avgSpeedMps, isNull);
      expect(r.caloriesKcal, isNull);
      expect(r.endedAt, isNull);
      expect(r.source, isNull);
      expect(r.subprojectId, isNull);
      expect(r.route, isEmpty);
    });

    test('fromJson handles all optional fields including route points', () {
      final r = RunActivity.fromJson(<String, dynamic>{
        'id': 7,
        'distance_meters': 5000.0,
        'duration_seconds': 1800,
        'avg_speed_mps': 2.78,
        'calories_kcal': 320,
        'started_at': '2026-05-01T08:00:00Z',
        'ended_at': '2026-05-01T08:30:00Z',
        'source': 'mob',
        'subproject_id': 4,
        'route': <Map<String, dynamic>>[
          <String, dynamic>{
            'latitude': 37.7749,
            'longitude': -122.4194,
            'recorded_at': '2026-05-01T08:00:00Z',
          },
          <String, dynamic>{
            'latitude': 37.7750,
            'longitude': -122.4195,
            'recorded_at': '2026-05-01T08:01:00Z',
          },
        ],
      });

      expect(r.id, 7);
      expect(r.avgSpeedMps, 2.78);
      expect(r.caloriesKcal, 320);
      expect(r.endedAt, DateTime.parse('2026-05-01T08:30:00Z'));
      expect(r.source, 'mob');
      expect(r.subprojectId, 4);
      expect(r.route, hasLength(2));
      expect(r.route.first.latitude, 37.7749);
    });

    test('fromJson coerces integer distance to double', () {
      final r = RunActivity.fromJson(<String, dynamic>{
        'distance_meters': 5000,
        'duration_seconds': 1800,
        'started_at': '2026-05-01T08:00:00Z',
        'route': <Map<String, dynamic>>[],
      });

      expect(r.distanceMeters, 5000.0);
      expect(r.distanceMeters, isA<double>());
    });

    test('toJson encodes duration as int seconds', () {
      final r = RunActivity(
        distanceMeters: 5000,
        duration: const Duration(seconds: 1800),
        startedAt: DateTime.parse('2026-05-01T08:00:00Z'),
        route: const <RunLocationPoint>[],
      );

      final json = r.toJson();
      expect(json['duration_seconds'], 1800);
      expect(json['duration_seconds'], isA<int>());
    });

    test('toJson round-trips back to fromJson identity', () {
      final original = RunActivity(
        id: 7,
        distanceMeters: 5000,
        duration: const Duration(minutes: 30),
        avgSpeedMps: 2.78,
        caloriesKcal: 320,
        startedAt: DateTime.parse('2026-05-01T08:00:00Z'),
        endedAt: DateTime.parse('2026-05-01T08:30:00Z'),
        source: 'mob',
        subprojectId: 4,
        route: <RunLocationPoint>[
          RunLocationPoint(
            latitude: 37.7749,
            longitude: -122.4194,
            recordedAt: DateTime.parse('2026-05-01T08:00:00Z'),
          ),
        ],
      );

      final round = RunActivity.fromJson(original.toJson());
      expect(round, equals(original));
      expect(round.hashCode, equals(original.hashCode));
    });

    test('copyWith with no args returns equal instance', () {
      final r = RunActivity(
        distanceMeters: 5000,
        duration: const Duration(seconds: 1800),
        startedAt: DateTime.parse('2026-05-01T08:00:00Z'),
        route: const <RunLocationPoint>[],
      );
      expect(r.copyWith(), equals(r));
    });

    test('copyWith updates a single field', () {
      final r = RunActivity(
        distanceMeters: 5000,
        duration: const Duration(seconds: 1800),
        startedAt: DateTime.parse('2026-05-01T08:00:00Z'),
        route: const <RunLocationPoint>[],
      );
      final updated = r.copyWith(distanceMeters: 6000);
      expect(updated.distanceMeters, 6000);
      expect(updated.duration, r.duration);
      expect(updated, isNot(equals(r)));
    });

    test('two equal instances are == and have equal hashCode', () {
      final a = RunActivity(
        distanceMeters: 5000,
        duration: const Duration(seconds: 1800),
        startedAt: DateTime.parse('2026-05-01T08:00:00Z'),
        route: const <RunLocationPoint>[],
      );
      final b = RunActivity(
        distanceMeters: 5000,
        duration: const Duration(seconds: 1800),
        startedAt: DateTime.parse('2026-05-01T08:00:00Z'),
        route: const <RunLocationPoint>[],
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString includes class name and distance/duration', () {
      final r = RunActivity(
        distanceMeters: 5000,
        duration: const Duration(seconds: 1800),
        startedAt: DateTime.parse('2026-05-01T08:00:00Z'),
        route: const <RunLocationPoint>[],
      );
      final s = r.toString();
      expect(s, contains('RunActivity'));
      expect(s, contains('5000'));
    });
  });
}
