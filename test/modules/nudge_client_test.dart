// Contract tests for NudgeClient.
//
// Covers:
//   GET  /api/nudges?status=<status>   — list active (or filtered) nudges
//   POST /api/nudges/<id>/ack          — acknowledge a nudge
//   POST /api/nudges/<id>/dismiss      — dismiss a nudge

import 'package:codify_p2x_sdk/src/client/p2x_client.dart';
import 'package:codify_p2x_sdk/src/client/p2x_client_config.dart';
import 'package:codify_p2x_sdk/src/modules/nudge_client.dart';
import 'package:codify_p2x_sdk/src/modules/nudge_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

void main() {
  late P2xClient base;
  late DioAdapter adapter;
  late NudgeClient nudges;

  Map<String, dynamic> sampleNudge({
    int id = 1,
    String key = 'meal-log-reminder',
    String severity = 'reminder',
    String? acknowledgedAt,
    String? dismissedAt,
  }) =>
      <String, dynamic>{
        'id': id,
        'key': key,
        'title': 'Log your lunch',
        'body': "Don't forget to scan your meal.",
        'action': 'screen://meal/log',
        'severity': severity,
        'created_at': '2026-05-01T08:00:00Z',
        if (acknowledgedAt != null) 'acknowledged_at': acknowledgedAt,
        if (dismissedAt != null) 'dismissed_at': dismissedAt,
        'payload': <String, dynamic>{'subprojectId': 3},
      };

  setUp(() {
    base = P2xClient(
      config: P2xClientConfig(
        baseUrl: 'https://api.project20x.com/api',
        getToken: () => 'tok-abc',
        getDomain: () => 'nutriscan.codify.ai',
      ),
    );
    adapter = DioAdapter(dio: base.dio);
    nudges = NudgeClient(base);
  });

  group('NudgeClient.list', () {
    test('GETs /nudges with status=active by default', () async {
      adapter.onGet(
        '/nudges',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[
            sampleNudge(),
            sampleNudge(
              id: 2,
              key: 'streak-celebration',
              severity: 'celebration',
            ),
          ],
        }),
        queryParameters: <String, dynamic>{'status': 'active'},
      );

      final list = await nudges.list();

      expect(list, hasLength(2));
      expect(list.first.id, 1);
      expect(list.first.severity, 'reminder');
      expect(list.last.severity, 'celebration');
    });

    test('GETs /nudges with no query params when status is null', () async {
      adapter.onGet(
        '/nudges',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[
            sampleNudge(),
            sampleNudge(
              id: 2,
              acknowledgedAt: '2026-05-01T09:00:00Z',
            ),
          ],
        }),
      );

      final list = await nudges.list(status: null);

      expect(list, hasLength(2));
      expect(list.last.acknowledgedAt, isNotNull);
    });

    test('GETs /nudges with custom status filter', () async {
      adapter.onGet(
        '/nudges',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[
            sampleNudge(id: 5, acknowledgedAt: '2026-05-01T09:00:00Z'),
          ],
        }),
        queryParameters: <String, dynamic>{'status': 'acknowledged'},
      );

      final list = await nudges.list(status: 'acknowledged');

      expect(list, hasLength(1));
      expect(list.first.acknowledgedAt, isNotNull);
    });

    test('returns empty list when server returns no rows', () async {
      adapter.onGet(
        '/nudges',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[],
        }),
        queryParameters: <String, dynamic>{'status': 'active'},
      );

      final list = await nudges.list();
      expect(list, isEmpty);
    });
  });

  group('NudgeClient.ack', () {
    test('POSTs /nudges/<id>/ack and returns the updated Nudge', () async {
      adapter.onPost(
        '/nudges/7/ack',
        (req) => req.reply(200, <String, dynamic>{
          'data': sampleNudge(
            id: 7,
            acknowledgedAt: '2026-05-01T09:00:00Z',
          ),
        }),
        data: Matchers.any,
      );

      final ack = await nudges.ack(7);

      expect(ack, isA<Nudge>());
      expect(ack.id, 7);
      expect(ack.acknowledgedAt, DateTime.parse('2026-05-01T09:00:00Z'));
    });

    test('forwards Idempotency-Key header when caller supplies one', () async {
      adapter.onPost(
        '/nudges/7/ack',
        (req) => req.reply(200, <String, dynamic>{
          'data': sampleNudge(
            id: 7,
            acknowledgedAt: '2026-05-01T09:00:00Z',
          ),
        }),
        data: Matchers.any,
      );

      final resp = await base.dio.post<dynamic>(
        '/nudges/7/ack',
        options: NudgeClient.idempotencyOptionsForTest('ack-uuid-1'),
      );

      expect(resp.requestOptions.headers['Idempotency-Key'], 'ack-uuid-1');
    });
  });

  group('NudgeClient.dismiss', () {
    test('POSTs /nudges/<id>/dismiss and returns the updated Nudge', () async {
      adapter.onPost(
        '/nudges/7/dismiss',
        (req) => req.reply(200, <String, dynamic>{
          'data': sampleNudge(
            id: 7,
            dismissedAt: '2026-05-01T09:30:00Z',
          ),
        }),
        data: Matchers.any,
      );

      final dismissed = await nudges.dismiss(7);

      expect(dismissed, isA<Nudge>());
      expect(dismissed.id, 7);
      expect(dismissed.dismissedAt, DateTime.parse('2026-05-01T09:30:00Z'));
      expect(dismissed.acknowledgedAt, isNull);
    });

    test('forwards Idempotency-Key header when caller supplies one', () async {
      adapter.onPost(
        '/nudges/7/dismiss',
        (req) => req.reply(200, <String, dynamic>{
          'data': sampleNudge(
            id: 7,
            dismissedAt: '2026-05-01T09:30:00Z',
          ),
        }),
        data: Matchers.any,
      );

      final resp = await base.dio.post<dynamic>(
        '/nudges/7/dismiss',
        options: NudgeClient.idempotencyOptionsForTest('dismiss-uuid-1'),
      );

      expect(resp.requestOptions.headers['Idempotency-Key'], 'dismiss-uuid-1');
    });
  });
}
