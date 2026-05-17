// Contract tests for ScheduleClient.
//
// Two resources, mirroring the TS ScheduleApiClient:
//   GET/POST/GET-by-id/PUT/DELETE  /api/schedule
//   GET/POST/GET-by-id/PUT/DELETE  /api/schedule-call
//
// PUT requests transit the wire as POST + ?_method=PUT (Laravel
// method-override convention enforced by MethodOverrideInterceptor).

import 'package:codify_p2x_sdk/src/client/exceptions/not_found_exception.dart';
import 'package:codify_p2x_sdk/src/client/exceptions/validation_exception.dart';
import 'package:codify_p2x_sdk/src/client/p2x_client.dart';
import 'package:codify_p2x_sdk/src/client/p2x_client_config.dart';
import 'package:codify_p2x_sdk/src/modules/schedule_client.dart';
import 'package:codify_p2x_sdk/src/modules/schedule_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

/// Lower-case UUID v4 regex (Idempotency-Key auto-generation contract).
final RegExp _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

void main() {
  late P2xClient base;
  late DioAdapter adapter;
  late ScheduleClient client;

  Map<String, dynamic> sampleSchedule({
    int id = 11,
    String status = 'open',
  }) =>
      <String, dynamic>{
        'id': id,
        'subproject_id': 3,
        'provider_id': 42,
        'starts_at': '2026-05-20T09:00:00Z',
        'ends_at': '2026-05-20T09:30:00Z',
        'status': status,
        'capacity': 1,
        'metadata': <String, dynamic>{'room': 'A'},
        'created_at': '2026-05-01T08:00:00Z',
        'updated_at': '2026-05-01T08:00:00Z',
      };

  Map<String, dynamic> sampleCall({
    int id = 7,
    String status = 'pending',
  }) =>
      <String, dynamic>{
        'id': id,
        'schedule_id': 11,
        'patient_id': 99,
        'provider_id': 42,
        'status': status,
        'livekit_room': 'room-abc',
        'metadata': <String, dynamic>{},
        'created_at': '2026-05-20T08:55:00Z',
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
    client = ScheduleClient(base);
  });

  // ─── /api/schedule ─────────────────────────────────────────────────────
  group('ScheduleClient.list', () {
    test('GETs /schedule and decodes the list', () async {
      adapter.onGet(
        '/schedule',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[
            sampleSchedule(),
            sampleSchedule(id: 12, status: 'booked'),
          ],
        }),
      );

      final list = await client.list();

      expect(list, hasLength(2));
      expect(list.first.id, 11);
      expect(list.last.status, 'booked');
    });

    test('returns empty list when server returns no rows', () async {
      adapter.onGet(
        '/schedule',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[],
        }),
      );

      final list = await client.list();
      expect(list, isEmpty);
    });
  });

  group('ScheduleClient.create', () {
    test('POSTs /schedule with body and returns the saved Schedule', () async {
      adapter.onPost(
        '/schedule',
        (req) => req.reply(201, <String, dynamic>{
          'data': sampleSchedule(id: 100),
        }),
        data: Matchers.any,
      );

      final saved = await client.create(
        providerId: 42,
        startsAt: DateTime.parse('2026-05-20T09:00:00Z'),
        endsAt: DateTime.parse('2026-05-20T09:30:00Z'),
        capacity: 2,
        metadata: const <String, dynamic>{'room': 'A'},
      );

      expect(saved, isA<Schedule>());
      expect(saved.id, 100);
      expect(saved.providerId, 42);
    });

    test('auto-attaches a UUID v4 Idempotency-Key on POST', () async {
      adapter.onPost(
        '/schedule',
        (req) => req.reply(201, <String, dynamic>{
          'data': sampleSchedule(id: 101),
        }),
        data: Matchers.any,
      );

      String? capturedKey;
      base.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedKey = options.headers['Idempotency-Key'] as String?;
            handler.next(options);
          },
        ),
      );

      await client.create(
        providerId: 42,
        startsAt: DateTime.parse('2026-05-20T09:00:00Z'),
        endsAt: DateTime.parse('2026-05-20T09:30:00Z'),
      );

      expect(capturedKey, isNotNull);
      expect(_uuidV4.hasMatch(capturedKey!), isTrue);
    });

    test('throws ValidationException on 422', () async {
      adapter.onPost(
        '/schedule',
        (req) => req.reply(422, <String, dynamic>{
          'message': 'The given data was invalid.',
          'errors': <String, dynamic>{
            'starts_at': <String>['Required.'],
          },
        }),
        data: Matchers.any,
      );

      expect(
        () => client.create(
          providerId: 42,
          startsAt: DateTime.parse('2026-05-20T09:00:00Z'),
          endsAt: DateTime.parse('2026-05-20T09:30:00Z'),
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('ScheduleClient.get', () {
    test('GETs /schedule/<id> and returns one Schedule', () async {
      adapter.onGet(
        '/schedule/11',
        (req) => req.reply(200, <String, dynamic>{
          'data': sampleSchedule(),
        }),
      );

      final got = await client.get(11);
      expect(got.id, 11);
      expect(got.status, 'open');
    });

    test('throws NotFoundException on 404', () async {
      adapter.onGet(
        '/schedule/999',
        (req) => req.reply(404, <String, dynamic>{'message': 'Not found.'}),
      );

      expect(
        () => client.get(999),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  group('ScheduleClient.update', () {
    test(
      'PUTs /schedule/<id> (over the wire as POST + ?_method=PUT) and '
      'returns the updated Schedule',
      () async {
        // PUT is rewritten to POST + ?_method=PUT by MethodOverrideInterceptor.
        adapter.onPost(
          '/schedule/11',
          (req) => req.reply(200, <String, dynamic>{
            'data': sampleSchedule(status: 'reserved'),
          }),
          data: Matchers.any,
          queryParameters: <String, dynamic>{'_method': 'PUT'},
        );

        final updated = await client.update(11, status: 'reserved');

        expect(updated, isA<Schedule>());
        expect(updated.status, 'reserved');
      },
    );

    test('throws ValidationException on 422', () async {
      adapter.onPost(
        '/schedule/11',
        (req) => req.reply(422, <String, dynamic>{
          'message': 'The given data was invalid.',
          'errors': <String, dynamic>{
            'status': <String>['Invalid status.'],
          },
        }),
        data: Matchers.any,
        queryParameters: <String, dynamic>{'_method': 'PUT'},
      );

      expect(
        () => client.update(11, status: 'bogus'),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('ScheduleClient.destroy', () {
    test('DELETEs /schedule/<id> and resolves to void', () async {
      adapter.onDelete(
        '/schedule/11',
        (req) => req.reply(204, null),
      );

      await client.destroy(11);
    });
  });

  // ─── /api/schedule-call ────────────────────────────────────────────────
  group('ScheduleClient.listCalls', () {
    test('GETs /schedule-call and decodes the list', () async {
      adapter.onGet(
        '/schedule-call',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[
            sampleCall(),
            sampleCall(id: 8, status: 'connected'),
          ],
        }),
      );

      final list = await client.listCalls();
      expect(list, hasLength(2));
      expect(list.last.status, 'connected');
    });
  });

  group('ScheduleClient.createCall', () {
    test('POSTs /schedule-call with body and returns the saved ScheduleCall',
        () async {
      adapter.onPost(
        '/schedule-call',
        (req) => req.reply(201, <String, dynamic>{
          'data': sampleCall(id: 50),
        }),
        data: Matchers.any,
      );

      final saved = await client.createCall(
        scheduleId: 11,
        patientId: 99,
        providerId: 42,
      );

      expect(saved, isA<ScheduleCall>());
      expect(saved.id, 50);
    });

    test('auto-attaches a UUID v4 Idempotency-Key on POST', () async {
      adapter.onPost(
        '/schedule-call',
        (req) => req.reply(201, <String, dynamic>{
          'data': sampleCall(id: 51),
        }),
        data: Matchers.any,
      );

      String? capturedKey;
      base.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedKey = options.headers['Idempotency-Key'] as String?;
            handler.next(options);
          },
        ),
      );

      await client.createCall(
        scheduleId: 11,
        patientId: 99,
        providerId: 42,
      );

      expect(capturedKey, isNotNull);
      expect(_uuidV4.hasMatch(capturedKey!), isTrue);
    });

    test('throws ValidationException on 422', () async {
      adapter.onPost(
        '/schedule-call',
        (req) => req.reply(422, <String, dynamic>{
          'message': 'The given data was invalid.',
          'errors': <String, dynamic>{
            'schedule_id': <String>['Required.'],
          },
        }),
        data: Matchers.any,
      );

      expect(
        () => client.createCall(
          scheduleId: 11,
          patientId: 99,
          providerId: 42,
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('ScheduleClient.getCall', () {
    test('GETs /schedule-call/<id> and returns one ScheduleCall', () async {
      adapter.onGet(
        '/schedule-call/7',
        (req) => req.reply(200, <String, dynamic>{
          'data': sampleCall(),
        }),
      );

      final got = await client.getCall(7);
      expect(got.id, 7);
      expect(got.status, 'pending');
    });

    test('throws NotFoundException on 404', () async {
      adapter.onGet(
        '/schedule-call/999',
        (req) => req.reply(404, <String, dynamic>{'message': 'Not found.'}),
      );

      expect(
        () => client.getCall(999),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  group('ScheduleClient.updateCall', () {
    test('PUTs /schedule-call/<id> via POST + ?_method=PUT', () async {
      adapter.onPost(
        '/schedule-call/7',
        (req) => req.reply(200, <String, dynamic>{
          'data': sampleCall(status: 'ended'),
        }),
        data: Matchers.any,
        queryParameters: <String, dynamic>{'_method': 'PUT'},
      );

      final updated = await client.updateCall(7, status: 'ended');

      expect(updated, isA<ScheduleCall>());
      expect(updated.status, 'ended');
    });

    test('throws ValidationException on 422', () async {
      adapter.onPost(
        '/schedule-call/7',
        (req) => req.reply(422, <String, dynamic>{
          'message': 'The given data was invalid.',
          'errors': <String, dynamic>{
            'status': <String>['Invalid status.'],
          },
        }),
        data: Matchers.any,
        queryParameters: <String, dynamic>{'_method': 'PUT'},
      );

      expect(
        () => client.updateCall(7, status: 'bogus'),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('ScheduleClient.destroyCall', () {
    test('DELETEs /schedule-call/<id> and resolves to void', () async {
      adapter.onDelete(
        '/schedule-call/7',
        (req) => req.reply(204, null),
      );

      await client.destroyCall(7);
    });
  });
}
