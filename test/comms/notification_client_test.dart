// Contract tests for NotificationClient.
//
// Covers:
//   GET    /api/notification             — list (optional limit)
//   GET    /api/notification/unread      — unread
//   DELETE /api/notification/<id>        — delete
//   POST   /api/notification/start-task  — startTask
//
// IdempotencyInterceptor auto-injects an Idempotency-Key header on every
// mutating request; we assert presence on the POST in this suite.

import 'package:ycaas_flutter_sdk/src/client/exceptions/unauthorized_exception.dart';
import 'package:ycaas_flutter_sdk/src/client/p2x_client.dart';
import 'package:ycaas_flutter_sdk/src/client/p2x_client_config.dart';
import 'package:ycaas_flutter_sdk/src/comms/notification_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

void main() {
  late P2xClient base;
  late DioAdapter adapter;
  late NotificationClient notifications;

  Map<String, dynamic> sampleNotification({
    int id = 7,
    String type = 'appointment.reminder',
    String? readAt,
  }) =>
      <String, dynamic>{
        'id': id,
        'type': type,
        'title': 'Your appointment is tomorrow',
        'body': 'Dr Bob — 10:00 am',
        'payload': <String, dynamic>{'appointment_id': 7},
        if (readAt != null) 'read_at': readAt,
        'created_at': '2026-05-01T08:00:00Z',
      };

  setUp(() {
    base = P2xClient(
      config: P2xClientConfig(
        baseUrl: 'https://api.project20x.com/api',
        getToken: () => 'tok-abc',
        getDomain: () => 'crohnie.ai',
      ),
    );
    adapter = DioAdapter(dio: base.dio);
    notifications = NotificationClient(base);
  });

  group('NotificationClient.list', () {
    test('GETs /notification and returns the decoded list', () async {
      adapter.onGet(
        '/notification',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[
            sampleNotification(),
            sampleNotification(
              id: 8,
              type: 'message.received',
              readAt: '2026-05-01T09:00:00Z',
            ),
          ],
        }),
      );

      final list = await notifications.list();

      expect(list, hasLength(2));
      expect(list.first.id, 7);
      expect(list.last.type, 'message.received');
      expect(list.last.readAt, isNotNull);
    });

    test('GETs /notification with limit query when provided', () async {
      adapter.onGet(
        '/notification',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[sampleNotification()],
        }),
        queryParameters: <String, dynamic>{'limit': 10},
      );

      final list = await notifications.list(limit: 10);
      expect(list, hasLength(1));
    });

    test('returns empty list when server returns no rows', () async {
      adapter.onGet(
        '/notification',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[],
        }),
      );

      final list = await notifications.list();
      expect(list, isEmpty);
    });

    test('401 surfaces as UnauthorizedException', () async {
      adapter.onGet(
        '/notification',
        (req) => req.reply(401, <String, dynamic>{
          'success': false,
          'message': 'Unauthenticated',
        }),
      );

      await expectLater(
        notifications.list(),
        throwsA(isA<UnauthorizedException>()),
      );
    });
  });

  group('NotificationClient.unread', () {
    test('GETs /notification/unread and returns only unread rows', () async {
      adapter.onGet(
        '/notification/unread',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[
            sampleNotification(),
          ],
        }),
      );

      final list = await notifications.unread();
      expect(list, hasLength(1));
      expect(list.first.readAt, isNull);
    });

    test('returns empty list when no unread notifications', () async {
      adapter.onGet(
        '/notification/unread',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[],
        }),
      );

      final list = await notifications.unread();
      expect(list, isEmpty);
    });
  });

  group('NotificationClient.delete', () {
    test('DELETEs /notification/<id> and completes', () async {
      adapter.onDelete(
        '/notification/7',
        (req) => req.reply(204, null),
      );

      await notifications.delete(7);
    });

    test('DELETE carries an auto-generated Idempotency-Key', () async {
      adapter.onDelete(
        '/notification/7',
        (req) => req.reply(204, null),
      );

      final resp = await base.dio.delete<dynamic>('/notification/7');
      expect(
        resp.requestOptions.headers['Idempotency-Key'],
        isA<String>(),
      );
    });
  });

  group('NotificationClient.startTask', () {
    test('POSTs /notification/start-task with task_key only', () async {
      adapter.onPost(
        '/notification/start-task',
        (req) => req.reply(202, <String, dynamic>{
          'success': true,
          'message': 'queued',
        }),
        data: <String, dynamic>{'task_key': 'flush-appointment-reminders'},
      );

      await notifications.startTask(taskKey: 'flush-appointment-reminders');
    });

    test('POSTs /notification/start-task with task_key + payload', () async {
      adapter.onPost(
        '/notification/start-task',
        (req) => req.reply(202, <String, dynamic>{
          'success': true,
          'message': 'queued',
        }),
        data: <String, dynamic>{
          'task_key': 'flush-appointment-reminders',
          'payload': <String, dynamic>{'doctor_id': 99},
        },
      );

      await notifications.startTask(
        taskKey: 'flush-appointment-reminders',
        payload: const <String, dynamic>{'doctor_id': 99},
      );
    });

    test('Idempotency-Key header is auto-attached', () async {
      adapter.onPost(
        '/notification/start-task',
        (req) => req.reply(202, <String, dynamic>{
          'success': true,
          'message': 'queued',
        }),
        data: Matchers.any,
      );

      final resp = await base.dio.post<dynamic>(
        '/notification/start-task',
        data: <String, dynamic>{'task_key': 'flush'},
      );

      expect(
        resp.requestOptions.headers['Idempotency-Key'],
        isA<String>(),
      );
    });
  });
}
