// Contract tests for NudgeClient expansion (v2 methods).
//
// Covers the four new endpoints added on top of the existing
// list/ack/dismiss surface in nudge_client_test.dart:
//
//   POST   /api/nudges/check-in    — record per-channel delivery
//   GET    /api/nudges/channels    — list configured channels
//   POST   /api/nudges/<id>/snooze — defer a nudge (Duration → seconds)
//   DELETE /api/nudges/<id>        — permanently delete
//
// The original surface stays in nudge_client_test.dart and must keep
// passing — the regression check at the bottom of this file re-asserts
// NudgeClient.list and NudgeClient.ack still work after the additions.

import 'package:codify_p2x_sdk/codify_p2x_sdk.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

final RegExp _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

class _CaptureInterceptor extends Interceptor {
  final List<RequestOptions> captured = <RequestOptions>[];

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    captured.add(options);
    handler.next(options);
  }
}

void main() {
  late P2xClient base;
  late DioAdapter adapter;
  late NudgeClient nudges;
  late _CaptureInterceptor capture;

  Map<String, dynamic> sampleNudge({
    int id = 7,
    String? acknowledgedAt,
    String? dismissedAt,
  }) =>
      <String, dynamic>{
        'id': id,
        'key': 'meal-log-reminder',
        'title': 'Log your lunch',
        'body': "Don't forget to scan your meal.",
        'action': 'screen://meal/log',
        'severity': 'reminder',
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
    capture = _CaptureInterceptor();
    base.dio.interceptors.add(capture);
    adapter = DioAdapter(dio: base.dio);
    nudges = NudgeClient(base);
  });

  group('NudgeClient.checkIn', () {
    test('POSTs /nudges/check-in with nudge_id + channel', () async {
      adapter.onPost(
        '/nudges/check-in',
        (req) => req.reply(200, <String, dynamic>{
          'data': sampleNudge(id: 7),
        }),
        data: <String, dynamic>{
          'nudge_id': 7,
          'channel': 'push',
        },
      );

      final nudge = await nudges.checkIn(nudgeId: 7, channel: 'push');

      expect(nudge, isA<Nudge>());
      expect(nudge.id, 7);
    });

    test('POSTs /nudges/check-in with optional payload', () async {
      adapter.onPost(
        '/nudges/check-in',
        (req) => req.reply(200, <String, dynamic>{
          'data': sampleNudge(id: 7),
        }),
        data: <String, dynamic>{
          'nudge_id': 7,
          'channel': 'sms',
          'payload': <String, dynamic>{
            'rendered_at': '2026-05-01T08:00:00Z',
          },
        },
      );

      await nudges.checkIn(
        nudgeId: 7,
        channel: 'sms',
        payload: <String, dynamic>{
          'rendered_at': '2026-05-01T08:00:00Z',
        },
      );
    });

    test('POST /nudges/check-in auto-injects Idempotency-Key', () async {
      adapter.onPost(
        '/nudges/check-in',
        (req) => req.reply(200, <String, dynamic>{
          'data': sampleNudge(),
        }),
        data: Matchers.any,
      );

      await nudges.checkIn(nudgeId: 7, channel: 'push');

      final key = capture.captured.last.headers['Idempotency-Key'] as String?;
      expect(key, isNotNull);
      expect(_uuidV4.hasMatch(key!), isTrue);
    });
  });

  group('NudgeClient.channels', () {
    test('GETs /nudges/channels and returns the configured list', () async {
      adapter.onGet(
        '/nudges/channels',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'name': 'Default Push',
              'kind': 'push',
              'is_enabled': true,
              'config': <String, dynamic>{'vapid_public_key': 'abc'},
            },
            <String, dynamic>{
              'name': 'NIO SMS',
              'kind': 'sms',
              'is_enabled': false,
              'config': <String, dynamic>{'from_number': '+15555550000'},
            },
          ],
        }),
      );

      final list = await nudges.channels();
      expect(list, hasLength(2));
      expect(list.first.kind, 'push');
      expect(list.first.isEnabled, isTrue);
      expect(list.last.kind, 'sms');
      expect(list.last.isEnabled, isFalse);
    });

    test('returns empty list when no channels configured', () async {
      adapter.onGet(
        '/nudges/channels',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[],
        }),
      );

      final list = await nudges.channels();
      expect(list, isEmpty);
    });
  });

  group('NudgeClient.snooze', () {
    test('POSTs /nudges/<id>/snooze with seconds=<Duration.inSeconds>',
        () async {
      adapter.onPost(
        '/nudges/7/snooze',
        (req) => req.reply(200, <String, dynamic>{
          'data': sampleNudge(id: 7),
        }),
        data: <String, dynamic>{'seconds': 7200},
      );

      final snoozed = await nudges.snooze(
        7,
        duration: const Duration(hours: 2),
      );

      expect(snoozed, isA<Nudge>());
      expect(snoozed.id, 7);
    });

    test('serializes Duration as integer seconds (not ISO duration)', () async {
      adapter.onPost(
        '/nudges/7/snooze',
        (req) => req.reply(200, <String, dynamic>{'data': sampleNudge(id: 7)}),
        data: <String, dynamic>{'seconds': 1800},
      );

      await nudges.snooze(7, duration: const Duration(minutes: 30));

      final last = capture.captured.last;
      final body = last.data;
      expect(body, isA<Map<String, dynamic>>());
      expect((body! as Map<String, dynamic>)['seconds'], 1800);
      expect((body as Map<String, dynamic>)['seconds'], isA<int>());
    });

    test('POST /nudges/<id>/snooze auto-injects Idempotency-Key', () async {
      adapter.onPost(
        '/nudges/7/snooze',
        (req) => req.reply(200, <String, dynamic>{'data': sampleNudge(id: 7)}),
        data: Matchers.any,
      );

      await nudges.snooze(7, duration: const Duration(seconds: 60));

      final key = capture.captured.last.headers['Idempotency-Key'] as String?;
      expect(key, isNotNull);
      expect(_uuidV4.hasMatch(key!), isTrue);
    });
  });

  group('NudgeClient.destroy', () {
    test('DELETEs /nudges/<id>', () async {
      adapter.onDelete(
        '/nudges/7',
        (req) => req.reply(204, ''),
      );

      await nudges.destroy(7);

      final last = capture.captured.last;
      expect(last.method, 'DELETE');
      expect(last.path, '/nudges/7');
    });

    test('DELETE /nudges/<id> auto-injects Idempotency-Key', () async {
      adapter.onDelete(
        '/nudges/7',
        (req) => req.reply(204, ''),
      );

      await nudges.destroy(7);

      final key = capture.captured.last.headers['Idempotency-Key'] as String?;
      expect(key, isNotNull);
      expect(_uuidV4.hasMatch(key!), isTrue);
    });
  });

  // Regression: existing NudgeClient.list + ack surface must keep working
  // after the additive expansion.
  group('NudgeClient existing surface (regression after v2 expansion)', () {
    test('list still GETs /nudges with status=active default', () async {
      adapter.onGet(
        '/nudges',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[sampleNudge()],
        }),
        queryParameters: <String, dynamic>{'status': 'active'},
      );

      final list = await nudges.list();
      expect(list, hasLength(1));
      expect(list.first.id, 7);
    });

    test('ack still POSTs /nudges/<id>/ack', () async {
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

      final acked = await nudges.ack(7);
      expect(acked.acknowledgedAt, DateTime.parse('2026-05-01T09:00:00Z'));
    });
  });
}
