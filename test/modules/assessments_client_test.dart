// Contract tests for AssessmentsClient.
//
// Asserts URL, HTTP method, body shape, headers, and decoded response
// types for:
//
//   POST /api/response/store
//   GET  /api/responses

import 'package:codify_p2x_sdk/src/client/p2x_client.dart';
import 'package:codify_p2x_sdk/src/client/p2x_client_config.dart';
import 'package:codify_p2x_sdk/src/modules/assessments_client.dart';
import 'package:codify_p2x_sdk/src/modules/assessments_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

void main() {
  late P2xClient base;
  late DioAdapter adapter;
  late AssessmentsClient assessments;

  setUp(() {
    base = P2xClient(
      config: P2xClientConfig(
        baseUrl: 'https://api.project20x.com/api',
        getToken: () => 'tok-abc',
        getDomain: () => 'nutriscan.codify.ai',
      ),
    );
    adapter = DioAdapter(dio: base.dio);
    assessments = AssessmentsClient(base);
  });

  group('AssessmentsClient.storeResponse', () {
    test('POSTs /response/store with payload and returns the saved row',
        () async {
      adapter.onPost(
        '/response/store',
        (req) => req.reply(201, <String, dynamic>{
          'success': true,
          'message': 'stored',
          'data': <String, dynamic>{
            'id': 99,
            'survey_key': 'food-intake-daily',
            'payload': <String, dynamic>{'calories': 1840},
            'user_id': 42,
            'subproject_id': 3,
            'created_at': '2026-05-01T08:00:00Z',
          },
        }),
        data: <String, dynamic>{
          'survey_key': 'food-intake-daily',
          'payload': <String, dynamic>{'calories': 1840},
        },
      );

      final stored = await assessments.storeResponse(
        surveyKey: 'food-intake-daily',
        payload: const <String, dynamic>{'calories': 1840},
      );

      expect(stored, isA<AssessmentResponse>());
      expect(stored.id, 99);
      expect(stored.surveyKey, 'food-intake-daily');
      expect(stored.payload['calories'], 1840);
      expect(stored.userId, 42);
      expect(stored.subprojectId, 3);
    });

    test('Idempotency-Key header is set when caller supplies idempotencyKey',
        () async {
      // Match any POST body — we only care about the outbound header.
      adapter.onPost(
        '/response/store',
        (req) => req.reply(201, <String, dynamic>{
          'data': <String, dynamic>{
            'id': 1,
            'survey_key': 'food-intake-daily',
            'payload': <String, dynamic>{},
          },
        }),
        data: Matchers.any,
      );

      final resp = await base.dio.post<dynamic>(
        '/response/store',
        data: <String, dynamic>{
          'survey_key': 'food-intake-daily',
          'payload': <String, dynamic>{'a': 1},
        },
        options: AssessmentsClient.idempotencyOptionsForTest('scan-uuid-xyz'),
      );

      expect(
        resp.requestOptions.headers['Idempotency-Key'],
        'scan-uuid-xyz',
      );
    });

    // Note: when the caller does not supply an idempotencyKey, Agent A's
    // IdempotencyInterceptor auto-generates one for write methods. That
    // behavior is asserted in the interceptor's own contract suite; we
    // only assert here that an explicit caller-supplied key wins.
  });

  group('AssessmentsClient.list', () {
    test('GETs /responses with default query params', () async {
      adapter.onGet(
        '/responses',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 1,
              'survey_key': 'food-intake-daily',
              'payload': <String, dynamic>{'a': 1},
            },
          ],
          'total': 1,
          'per_page': 50,
          'current_page': 1,
        }),
        queryParameters: <String, dynamic>{
          'limit': 50,
          'page': 1,
        },
      );

      final list = await assessments.list();

      expect(list, isA<AssessmentResponseList>());
      expect(list.data, hasLength(1));
      expect(list.total, 1);
      expect(list.perPage, 50);
      expect(list.currentPage, 1);
    });

    test('GETs /responses filtered by source', () async {
      adapter.onGet(
        '/responses',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 1,
              'survey_key': 'food-intake-daily',
              'payload': <String, dynamic>{},
            },
          ],
          'total': 1,
        }),
        queryParameters: <String, dynamic>{
          'source': 'nio-scan',
          'limit': 10,
          'page': 1,
        },
      );

      final list = await assessments.list(source: 'nio-scan', limit: 10);

      expect(list.data, hasLength(1));
      expect(list.total, 1);
    });
  });
}
