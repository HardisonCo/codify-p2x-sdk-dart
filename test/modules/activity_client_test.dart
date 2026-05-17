// Contract tests for ActivityClient.
//
// Covers:
//   POST /api/activity/runs                    — log a completed run
//   GET  /api/activity/runs                    — list runs
//   POST /api/activity/runs/<id>/locations     — append batch of GPS points

import 'package:codify_p2x_sdk/src/client/p2x_client.dart';
import 'package:codify_p2x_sdk/src/client/p2x_client_config.dart';
import 'package:codify_p2x_sdk/src/modules/activity_client.dart';
import 'package:codify_p2x_sdk/src/modules/activity_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

void main() {
  late P2xClient base;
  late DioAdapter adapter;
  late ActivityClient activity;

  Map<String, dynamic> sampleRun({int id = 1}) => <String, dynamic>{
        'id': id,
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
        ],
      };

  setUp(() {
    base = P2xClient(
      config: P2xClientConfig(
        baseUrl: 'https://api.project20x.com/api',
        getToken: () => 'tok-abc',
        getDomain: () => 'mob.codify.ai',
      ),
    );
    adapter = DioAdapter(dio: base.dio);
    activity = ActivityClient(base);
  });

  group('ActivityClient.logRun', () {
    test('POSTs /activity/runs and returns the persisted RunActivity',
        () async {
      adapter.onPost(
        '/activity/runs',
        (req) => req.reply(201, <String, dynamic>{'data': sampleRun(id: 42)}),
        data: Matchers.any,
      );

      final run = RunActivity(
        distanceMeters: 5000,
        duration: const Duration(seconds: 1800),
        startedAt: DateTime.parse('2026-05-01T08:00:00Z'),
        endedAt: DateTime.parse('2026-05-01T08:30:00Z'),
        route: const <RunLocationPoint>[],
        source: 'mob',
      );

      final saved = await activity.logRun(run);

      expect(saved, isA<RunActivity>());
      expect(saved.id, 42);
      expect(saved.distanceMeters, 5000.0);
      expect(saved.duration, const Duration(seconds: 1800));
      expect(saved.source, 'mob');
    });

    test('forwards Idempotency-Key header when caller supplies one', () async {
      adapter.onPost(
        '/activity/runs',
        (req) => req.reply(201, <String, dynamic>{'data': sampleRun()}),
        data: Matchers.any,
      );

      final resp = await base.dio.post<dynamic>(
        '/activity/runs',
        data: <String, dynamic>{},
        options: ActivityClient.idempotencyOptionsForTest('run-uuid-1'),
      );

      expect(resp.requestOptions.headers['Idempotency-Key'], 'run-uuid-1');
    });
  });

  group('ActivityClient.listRuns', () {
    test('GETs /activity/runs with limit=50 by default (no from/to)', () async {
      adapter.onGet(
        '/activity/runs',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[sampleRun(), sampleRun(id: 2)],
        }),
        queryParameters: <String, dynamic>{'limit': 50},
      );

      final list = await activity.listRuns();

      expect(list, hasLength(2));
      expect(list.first.id, 1);
    });

    test('GETs /activity/runs with from + to + custom limit', () async {
      adapter.onGet(
        '/activity/runs',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[sampleRun()],
        }),
        queryParameters: <String, dynamic>{
          'from': '2026-05-01T00:00:00.000Z',
          'to': '2026-05-31T23:59:59.000Z',
          'limit': 10,
        },
      );

      final list = await activity.listRuns(
        from: DateTime.parse('2026-05-01T00:00:00Z'),
        to: DateTime.parse('2026-05-31T23:59:59Z'),
        limit: 10,
      );

      expect(list, hasLength(1));
    });

    test('returns empty list when server returns no rows', () async {
      adapter.onGet(
        '/activity/runs',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[],
        }),
        queryParameters: <String, dynamic>{'limit': 50},
      );

      final list = await activity.listRuns();
      expect(list, isEmpty);
    });
  });

  group('ActivityClient.appendLocations', () {
    test('POSTs /activity/runs/<id>/locations with the points batch', () async {
      adapter.onPost(
        '/activity/runs/42/locations',
        (req) => req.reply(204, ''),
        data: Matchers.any,
      );

      await activity.appendLocations(
        runId: 42,
        points: <RunLocationPoint>[
          RunLocationPoint(
            latitude: 37.7749,
            longitude: -122.4194,
            recordedAt: DateTime.parse('2026-05-01T08:00:00Z'),
          ),
          RunLocationPoint(
            latitude: 37.7750,
            longitude: -122.4195,
            recordedAt: DateTime.parse('2026-05-01T08:01:00Z'),
          ),
        ],
      );
    });

    test('forwards Idempotency-Key header when caller supplies one', () async {
      adapter.onPost(
        '/activity/runs/42/locations',
        (req) => req.reply(204, ''),
        data: Matchers.any,
      );

      final resp = await base.dio.post<dynamic>(
        '/activity/runs/42/locations',
        data: <String, dynamic>{},
        options: ActivityClient.idempotencyOptionsForTest('locs-uuid-1'),
      );

      expect(resp.requestOptions.headers['Idempotency-Key'], 'locs-uuid-1');
    });
  });
}
