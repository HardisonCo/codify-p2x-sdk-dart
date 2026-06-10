// Contract tests for ServicesClient.
//
// Mirrors the TS ServicesModuleApiClient:
//   GET  /api/services/resolve            — look up by subdomain or slug
//   GET  /api/services/<id>/slots         — available Schedule slots
//   POST /api/services/<id>/reserve       — reserve a slot → ScheduleCall

import 'package:ycaas_flutter_sdk/src/client/exceptions/not_found_exception.dart';
import 'package:ycaas_flutter_sdk/src/client/exceptions/validation_exception.dart';
import 'package:ycaas_flutter_sdk/src/client/p2x_client.dart';
import 'package:ycaas_flutter_sdk/src/client/p2x_client_config.dart';
import 'package:ycaas_flutter_sdk/src/modules/services_client.dart';
import 'package:ycaas_flutter_sdk/src/modules/services_models.dart';
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
  late ServicesClient client;

  Map<String, dynamic> sampleService({
    int id = 5,
    String slug = 'ibd-consult-30min',
  }) =>
      <String, dynamic>{
        'id': id,
        'subproject_id': 3,
        'slug': slug,
        'name': '30-minute IBD consult',
        'description': 'One-on-one telehealth visit.',
        'duration_minutes': 30,
        'price_cents': 7500,
        'currency': 'USD',
        'provider_id': 42,
        'metadata': <String, dynamic>{},
        'is_active': true,
        'created_at': '2026-05-01T08:00:00Z',
      };

  Map<String, dynamic> sampleSchedule({int id = 11}) => <String, dynamic>{
        'id': id,
        'subproject_id': 3,
        'provider_id': 42,
        'starts_at': '2026-05-20T09:00:00Z',
        'ends_at': '2026-05-20T09:30:00Z',
        'status': 'open',
        'capacity': 1,
        'metadata': <String, dynamic>{},
        'created_at': '2026-05-01T08:00:00Z',
        'updated_at': '2026-05-01T08:00:00Z',
      };

  Map<String, dynamic> sampleCall({int id = 7}) => <String, dynamic>{
        'id': id,
        'schedule_id': 11,
        'patient_id': 99,
        'provider_id': 42,
        'status': 'pending',
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
    client = ServicesClient(base);
  });

  group('ServicesClient.resolve', () {
    test('GETs /services/resolve with subdomain query param', () async {
      adapter.onGet(
        '/services/resolve',
        (req) => req.reply(200, <String, dynamic>{
          'data': sampleService(),
        }),
        queryParameters: <String, dynamic>{'subdomain': 'crohnie.ai'},
      );

      final s = await client.resolve(subdomain: 'crohnie.ai');

      expect(s, isA<Service>());
      expect(s.id, 5);
      expect(s.slug, 'ibd-consult-30min');
    });

    test('GETs /services/resolve with slug query param', () async {
      adapter.onGet(
        '/services/resolve',
        (req) => req.reply(200, <String, dynamic>{
          'data': sampleService(slug: 'phm-lab-basic'),
        }),
        queryParameters: <String, dynamic>{'slug': 'phm-lab-basic'},
      );

      final s = await client.resolve(slug: 'phm-lab-basic');
      expect(s.slug, 'phm-lab-basic');
    });

    test('GETs /services/resolve with both subdomain and slug', () async {
      adapter.onGet(
        '/services/resolve',
        (req) => req.reply(200, <String, dynamic>{
          'data': sampleService(),
        }),
        queryParameters: <String, dynamic>{
          'subdomain': 'crohnie.ai',
          'slug': 'ibd-consult-30min',
        },
      );

      final s = await client.resolve(
        subdomain: 'crohnie.ai',
        slug: 'ibd-consult-30min',
      );
      expect(s.id, 5);
    });

    test('throws NotFoundException on 404', () async {
      adapter.onGet(
        '/services/resolve',
        (req) => req.reply(404, <String, dynamic>{'message': 'Not found.'}),
        queryParameters: <String, dynamic>{'slug': 'nope'},
      );

      expect(
        () => client.resolve(slug: 'nope'),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  group('ServicesClient.slots', () {
    test('GETs /services/<id>/slots with no query params by default', () async {
      adapter.onGet(
        '/services/5/slots',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[
            sampleSchedule(),
            sampleSchedule(id: 12),
          ],
        }),
      );

      final list = await client.slots(5);

      expect(list, hasLength(2));
      expect(list.first, isA<Schedule>());
      expect(list.first.id, 11);
    });

    test('GETs /services/<id>/slots with from + to range', () async {
      adapter.onGet(
        '/services/5/slots',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[sampleSchedule()],
        }),
        queryParameters: <String, dynamic>{
          'from': '2026-05-20T00:00:00.000Z',
          'to': '2026-05-21T00:00:00.000Z',
        },
      );

      final list = await client.slots(
        5,
        from: DateTime.parse('2026-05-20T00:00:00Z'),
        to: DateTime.parse('2026-05-21T00:00:00Z'),
      );

      expect(list, hasLength(1));
    });

    test('throws NotFoundException on 404', () async {
      adapter.onGet(
        '/services/999/slots',
        (req) => req.reply(404, <String, dynamic>{'message': 'Not found.'}),
      );

      expect(
        () => client.slots(999),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('returns empty list when server returns no rows', () async {
      adapter.onGet(
        '/services/5/slots',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[],
        }),
      );

      final list = await client.slots(5);
      expect(list, isEmpty);
    });
  });

  group('ServicesClient.reserve', () {
    test('POSTs /services/<id>/reserve with schedule_id and returns the call',
        () async {
      adapter.onPost(
        '/services/5/reserve',
        (req) => req.reply(201, <String, dynamic>{
          'data': sampleCall(),
        }),
        data: Matchers.any,
      );

      final call = await client.reserve(5, scheduleId: 11);

      expect(call, isA<ScheduleCall>());
      expect(call.id, 7);
      expect(call.scheduleId, 11);
    });

    test('POSTs /services/<id>/reserve forwards optional metadata', () async {
      adapter.onPost(
        '/services/5/reserve',
        (req) => req.reply(201, <String, dynamic>{
          'data': sampleCall(),
        }),
        data: Matchers.any,
      );

      final call = await client.reserve(
        5,
        scheduleId: 11,
        metadata: const <String, dynamic>{'referral_id': 99},
      );

      expect(call.scheduleId, 11);
    });

    test('auto-attaches a UUID v4 Idempotency-Key on POST', () async {
      adapter.onPost(
        '/services/5/reserve',
        (req) => req.reply(201, <String, dynamic>{
          'data': sampleCall(),
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

      await client.reserve(5, scheduleId: 11);

      expect(capturedKey, isNotNull);
      expect(_uuidV4.hasMatch(capturedKey!), isTrue);
    });

    test('throws ValidationException on 422', () async {
      adapter.onPost(
        '/services/5/reserve',
        (req) => req.reply(422, <String, dynamic>{
          'message': 'The given data was invalid.',
          'errors': <String, dynamic>{
            'schedule_id': <String>['Already booked.'],
          },
        }),
        data: Matchers.any,
      );

      expect(
        () => client.reserve(5, scheduleId: 11),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}
