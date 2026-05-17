// Contract tests for VerificationClient.
//
// Covers:
//   GET    /api/verifications        — list user's verification submissions
//   POST   /api/verifications        — submit a new verification (idempotent)
//   GET    /api/verifications/<id>   — fetch one
//   PUT    /api/verifications/<id>   — update (e.g. resubmit after rejection)
//
// PUT rides on POST + ?_method=PUT via MethodOverrideInterceptor.

import 'package:codify_p2x_sdk/src/client/exceptions/not_found_exception.dart';
import 'package:codify_p2x_sdk/src/client/exceptions/validation_exception.dart';
import 'package:codify_p2x_sdk/src/client/p2x_client.dart';
import 'package:codify_p2x_sdk/src/client/p2x_client_config.dart';
import 'package:codify_p2x_sdk/src/modules/verification_client.dart';
import 'package:codify_p2x_sdk/src/modules/verification_models.dart';
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
  late VerificationClient verifications;

  Map<String, dynamic> sampleVerification({
    int id = 21,
    String status = 'pending',
    String documentType = 'medical_license',
    String? reviewerNotes,
  }) =>
      <String, dynamic>{
        'id': id,
        'subproject_id': 3,
        'document_type': documentType,
        'document_url': 'https://storage.example.com/$documentType-$id.pdf',
        'status': status,
        if (reviewerNotes != null) 'reviewer_notes': reviewerNotes,
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
    verifications = VerificationClient(base);
  });

  group('VerificationClient.list', () {
    test('GETs /verifications and returns the parsed list', () async {
      adapter.onGet(
        '/verifications',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[
            sampleVerification(),
            sampleVerification(
              id: 22,
              status: 'verified',
              documentType: 'dea',
            ),
          ],
        }),
      );

      final list = await verifications.list();

      expect(list, hasLength(2));
      expect(list.first.id, 21);
      expect(list.first.documentType, 'medical_license');
      expect(list.last.id, 22);
      expect(list.last.status, 'verified');
    });

    test('returns empty list when server returns no rows', () async {
      adapter.onGet(
        '/verifications',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[],
        }),
      );

      final list = await verifications.list();
      expect(list, isEmpty);
    });
  });

  group('VerificationClient.create', () {
    test('POSTs /verifications with payload and returns the saved row',
        () async {
      adapter.onPost(
        '/verifications',
        (req) => req.reply(201, <String, dynamic>{
          'data': sampleVerification(),
        }),
        data: <String, dynamic>{
          'document_type': 'medical_license',
          'document_url': 'https://storage.example.com/medical_license-21.pdf',
          'metadata': <String, dynamic>{
            'license_number': 'NY-12345',
            'state': 'NY',
          },
        },
      );

      final created = await verifications.create(
        documentType: 'medical_license',
        documentUrl: 'https://storage.example.com/medical_license-21.pdf',
        metadata: const <String, dynamic>{
          'license_number': 'NY-12345',
          'state': 'NY',
        },
      );

      expect(created, isA<Verification>());
      expect(created.id, 21);
      expect(created.documentType, 'medical_license');
      expect(created.status, 'pending');
    });

    test('attaches an Idempotency-Key (v4 UUID) on POST writes', () async {
      String? sentKey;
      adapter.onPost(
        '/verifications',
        (req) => req.reply(201, <String, dynamic>{
          'data': sampleVerification(),
        }),
        data: Matchers.any,
      );

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            sentKey = options.headers['Idempotency-Key'] as String?;
            handler.next(options);
          },
        ),
      );

      await verifications.create(
        documentType: 'medical_license',
        documentUrl: 'https://storage.example.com/medical_license-21.pdf',
        metadata: const <String, dynamic>{'state': 'NY'},
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
        '/verifications',
        (req) => req.reply(422, <String, dynamic>{
          'message': 'The given data was invalid.',
          'errors': <String, dynamic>{
            'document_type': <String>['Required.'],
            'document_url': <String>['Must be a valid URL.'],
          },
        }),
        data: Matchers.any,
      );

      Object? caught;
      try {
        await verifications.create(
          documentType: '',
          documentUrl: 'not-a-url',
          metadata: const <String, dynamic>{},
        );
      } catch (e) {
        caught = e;
      }

      expect(caught, isA<ValidationException>());
      final v = caught! as ValidationException;
      expect(v.errors['document_type'], <String>['Required.']);
      expect(v.errors['document_url'], <String>['Must be a valid URL.']);
    });
  });

  group('VerificationClient.show', () {
    test('GETs /verifications/<id> and returns one Verification', () async {
      adapter.onGet(
        '/verifications/21',
        (req) => req.reply(200, <String, dynamic>{
          'data': sampleVerification(
            status: 'verified',
          ),
        }),
      );

      final v = await verifications.show(21);

      expect(v, isA<Verification>());
      expect(v.id, 21);
      expect(v.status, 'verified');
    });

    test('throws NotFoundException on 404', () async {
      adapter.onGet(
        '/verifications/999',
        (req) => req.reply(404, <String, dynamic>{
          'success': false,
          'message': 'Not Found',
        }),
      );

      Object? caught;
      try {
        await verifications.show(999);
      } catch (e) {
        caught = e;
      }

      expect(caught, isA<NotFoundException>());
    });
  });

  group('VerificationClient.update', () {
    test('PUTs /verifications/<id> and returns the updated Verification',
        () async {
      adapter.onPost(
        '/verifications/21',
        (req) => req.reply(200, <String, dynamic>{
          'data': sampleVerification(
            status: 'in_review',
          ),
        }),
        data: Matchers.any,
        queryParameters: <String, dynamic>{'_method': 'PUT'},
      );

      final updated = await verifications.update(
        21,
        documentUrl: 'https://storage.example.com/medical_license-21-v2.pdf',
      );

      expect(updated, isA<Verification>());
      expect(updated.id, 21);
      expect(updated.status, 'in_review');
    });

    test('attaches an Idempotency-Key (v4 UUID) on PUT writes', () async {
      String? sentKey;
      adapter.onPost(
        '/verifications/21',
        (req) => req.reply(200, <String, dynamic>{
          'data': sampleVerification(
            status: 'in_review',
          ),
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

      await verifications.update(
        21,
        documentUrl: 'https://storage.example.com/medical_license-21-v2.pdf',
      );

      expect(sentKey, isNotNull);
      expect(_uuidV4.hasMatch(sentKey!), isTrue);
    });
  });
}
