// Contract tests for ApplicationClient.
//
// Covers:
//   GET    /api/applications        — list current user's applications
//   POST   /api/applications        — submit a new application (idempotent)
//   GET    /api/applications/<id>   — fetch one
//   PUT    /api/applications/<id>   — update a draft (idempotent)
//
// PUT rides on POST + ?_method=PUT via MethodOverrideInterceptor.

import 'package:ycaas_flutter_sdk/src/client/exceptions/not_found_exception.dart';
import 'package:ycaas_flutter_sdk/src/client/exceptions/validation_exception.dart';
import 'package:ycaas_flutter_sdk/src/client/p2x_client.dart';
import 'package:ycaas_flutter_sdk/src/client/p2x_client_config.dart';
import 'package:ycaas_flutter_sdk/src/modules/application_client.dart';
import 'package:ycaas_flutter_sdk/src/modules/application_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

/// Matches a v4 UUID — same shape the SDK's IdempotencyInterceptor emits.
final RegExp _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

void main() {
  late P2xClient base;
  late Dio dio;
  late DioAdapter adapter;
  late ApplicationClient apps;

  Map<String, dynamic> sampleApp({
    int id = 11,
    String status = 'draft',
    String type = 'doctor_request',
  }) =>
      <String, dynamic>{
        'id': id,
        'subproject_id': 3,
        'type': type,
        'status': status,
        'payload': <String, dynamic>{
          'license_state': 'NY',
          'specialty': 'gastroenterology',
        },
        'created_at': '2026-05-01T08:00:00Z',
        'updated_at': '2026-05-01T08:00:00Z',
      };

  setUp(() {
    dio = Dio();
    base = P2xClient(
      config: P2xClientConfig(
        baseUrl: 'http://test.local/api',
        getToken: () => 'tk',
      ),
      dio: dio,
    );
    adapter = DioAdapter(dio: base.dio);
    apps = ApplicationClient(base);
  });

  group('ApplicationClient.list', () {
    test('GETs /applications and returns the parsed list', () async {
      adapter.onGet(
        '/applications',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[
            sampleApp(),
            sampleApp(id: 12, status: 'submitted'),
          ],
        }),
      );

      final list = await apps.list();

      expect(list, hasLength(2));
      expect(list.first.id, 11);
      expect(list.first.status, 'draft');
      expect(list.last.id, 12);
      expect(list.last.status, 'submitted');
    });

    test('returns empty list when server returns no rows', () async {
      adapter.onGet(
        '/applications',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[],
        }),
      );

      final list = await apps.list();
      expect(list, isEmpty);
    });
  });

  group('ApplicationClient.create', () {
    test('POSTs /applications with payload and returns the saved row',
        () async {
      adapter.onPost(
        '/applications',
        (req) => req.reply(201, <String, dynamic>{
          'data': sampleApp(status: 'submitted'),
        }),
        data: <String, dynamic>{
          'type': 'doctor_request',
          'payload': <String, dynamic>{
            'license_state': 'NY',
            'specialty': 'gastroenterology',
          },
        },
      );

      final created = await apps.create(
        type: 'doctor_request',
        payload: const <String, dynamic>{
          'license_state': 'NY',
          'specialty': 'gastroenterology',
        },
      );

      expect(created, isA<Application>());
      expect(created.id, 11);
      expect(created.status, 'submitted');
      expect(created.subprojectId, 3);
    });

    test('attaches an Idempotency-Key (v4 UUID) on POST writes', () async {
      String? sentKey;
      adapter.onPost(
        '/applications',
        (req) => req.reply(201, <String, dynamic>{
          'data': sampleApp(),
        }),
        data: Matchers.any,
      );

      // Capture the outbound header via a Dio interceptor.
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            sentKey = options.headers['Idempotency-Key'] as String?;
            handler.next(options);
          },
        ),
      );

      await apps.create(
        type: 'doctor_request',
        payload: const <String, dynamic>{'license_state': 'NY'},
      );

      expect(sentKey, isNotNull);
      expect(
        _uuidV4.hasMatch(sentKey!),
        isTrue,
        reason: 'Expected UUID v4 but got "$sentKey"',
      );
    });

    test('throws ValidationException on 422', () async {
      adapter.onPost(
        '/applications',
        (req) => req.reply(422, <String, dynamic>{
          'message': 'The given data was invalid.',
          'errors': <String, dynamic>{
            'type': <String>['Required.'],
            'payload.license_state': <String>['Required.'],
          },
        }),
        data: Matchers.any,
      );

      Object? caught;
      try {
        await apps.create(
          type: 'doctor_request',
          payload: const <String, dynamic>{},
        );
      } catch (e) {
        caught = e;
      }

      expect(caught, isA<ValidationException>());
      final v = caught! as ValidationException;
      expect(v.errors['type'], <String>['Required.']);
      expect(v.errors['payload.license_state'], <String>['Required.']);
    });
  });

  group('ApplicationClient.show', () {
    test('GETs /applications/<id> and returns one Application', () async {
      adapter.onGet(
        '/applications/11',
        (req) => req.reply(200, <String, dynamic>{
          'data': sampleApp(status: 'approved'),
        }),
      );

      final a = await apps.show(11);

      expect(a, isA<Application>());
      expect(a.id, 11);
      expect(a.status, 'approved');
    });

    test('throws NotFoundException on 404', () async {
      adapter.onGet(
        '/applications/999',
        (req) => req.reply(404, <String, dynamic>{
          'success': false,
          'message': 'Not Found',
        }),
      );

      Object? caught;
      try {
        await apps.show(999);
      } catch (e) {
        caught = e;
      }

      expect(caught, isA<NotFoundException>());
    });
  });

  group('ApplicationClient.update', () {
    test('PUTs /applications/<id> and returns the updated Application',
        () async {
      // MethodOverrideInterceptor rewrites PUT → POST + ?_method=PUT.
      adapter.onPost(
        '/applications/11',
        (req) => req.reply(200, <String, dynamic>{
          'data': sampleApp(status: 'submitted'),
        }),
        data: Matchers.any,
        queryParameters: <String, dynamic>{'_method': 'PUT'},
      );

      final updated = await apps.update(
        11,
        payload: const <String, dynamic>{'license_state': 'NJ'},
        status: 'submitted',
      );

      expect(updated, isA<Application>());
      expect(updated.id, 11);
      expect(updated.status, 'submitted');
    });

    test('attaches an Idempotency-Key (v4 UUID) on PUT writes', () async {
      String? sentKey;
      adapter.onPost(
        '/applications/11',
        (req) => req.reply(200, <String, dynamic>{
          'data': sampleApp(status: 'submitted'),
        }),
        data: Matchers.any,
        queryParameters: <String, dynamic>{'_method': 'PUT'},
      );

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            sentKey = options.headers['Idempotency-Key'] as String?;
            handler.next(options);
          },
        ),
      );

      await apps.update(
        11,
        payload: const <String, dynamic>{'license_state': 'NJ'},
      );

      expect(sentKey, isNotNull);
      expect(_uuidV4.hasMatch(sentKey!), isTrue);
    });
  });
}
