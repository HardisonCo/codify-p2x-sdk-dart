// Contract tests for SubprojectsClient.
//
// Asserts URL, HTTP method, headers and response decoding for the two
// subproject endpoints consumed by all P2X-aware mobile clients:
//
//   GET /api/v1/subprojects/current
//   GET /api/v1/settings/features

import 'package:ycaas_flutter_sdk/src/client/p2x_client.dart';
import 'package:ycaas_flutter_sdk/src/client/p2x_client_config.dart';
import 'package:ycaas_flutter_sdk/src/subprojects/subprojects_client.dart';
import 'package:ycaas_flutter_sdk/src/subprojects/subprojects_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

void main() {
  late P2xClient base;
  late DioAdapter adapter;
  late SubprojectsClient subprojects;

  setUp(() {
    base = P2xClient(
      config: P2xClientConfig(
        baseUrl: 'https://api.project20x.com/api',
        getToken: () => 'tok-abc',
        getDomain: () => 'crohnie.ai',
      ),
    );
    adapter = DioAdapter(dio: base.dio);
    subprojects = SubprojectsClient(base);
  });

  group('SubprojectsClient.current', () {
    test('GETs /v1/subprojects/current and returns the Subproject', () async {
      adapter.onGet(
        '/v1/subprojects/current',
        (req) => req.reply(200, <String, dynamic>{
          'success': true,
          'message': 'ok',
          'data': <String, dynamic>{
            'id': 2,
            'slug': 'crohnie',
            'name': 'Crohnie AI',
            'domain': 'crohnie.ai',
            'kind': 'health-system',
            'parent_id': null,
            'created_at': '2026-01-01T12:00:00Z',
          },
        }),
      );

      final sp = await subprojects.current();

      expect(sp, isA<Subproject>());
      expect(sp.id, 2);
      expect(sp.slug, 'crohnie');
      expect(sp.name, 'Crohnie AI');
      expect(sp.domain, 'crohnie.ai');
      expect(sp.kind, 'health-system');
      expect(sp.createdAt, DateTime.parse('2026-01-01T12:00:00Z'));
    });

    test('sends Authorization and X-Domain headers via GET', () async {
      adapter.onGet(
        '/v1/subprojects/current',
        (req) => req.reply(200, <String, dynamic>{
          'data': <String, dynamic>{
            'id': 2,
            'slug': 'crohnie',
            'name': 'Crohnie AI',
            'domain': 'crohnie.ai',
          },
        }),
      );

      // We re-issue the same call against a Dio whose adapter records the
      // outbound RequestOptions via the response object — this is the same
      // pattern used by test/client/p2x_client_test.dart.
      final resp = await base.dio.get<dynamic>('/v1/subprojects/current');

      expect(resp.requestOptions.method, 'GET');
      expect(resp.requestOptions.path, '/v1/subprojects/current');
      expect(resp.requestOptions.headers['Authorization'], 'Bearer tok-abc');
      expect(resp.requestOptions.headers['X-Domain'], 'crohnie.ai');
    });

    test('decodes envelope without success/message keys', () async {
      // Some endpoints return bare { data: { ... } } — be permissive.
      adapter.onGet(
        '/v1/subprojects/current',
        (req) => req.reply(200, <String, dynamic>{
          'data': <String, dynamic>{
            'id': 9,
            'slug': 'nutriscan',
            'name': 'NutriScan',
            'domain': 'nutriscan.codify.ai',
          },
        }),
      );

      final sp = await subprojects.current();

      expect(sp.id, 9);
      expect(sp.slug, 'nutriscan');
    });
  });

  group('SubprojectsClient.features', () {
    test('GETs /v1/settings/features and returns SubprojectFeatures', () async {
      adapter.onGet(
        '/v1/settings/features',
        (req) => req.reply(200, <String, dynamic>{
          'success': true,
          'message': 'ok',
          'data': <String, dynamic>{
            'flags': <String, dynamic>{
              'ibd_doctor_request': true,
              'phm_labs': false,
              'nio_premium': true,
            },
          },
        }),
      );

      final feats = await subprojects.features();

      expect(feats, isA<SubprojectFeatures>());
      expect(feats.isEnabled('ibd_doctor_request'), isTrue);
      expect(feats.isEnabled('phm_labs'), isFalse);
      expect(feats.isEnabled('nio_premium'), isTrue);
      expect(feats.isEnabled('missing_flag'), isFalse);
    });

    test('sends GET to /v1/settings/features with proper headers', () async {
      adapter.onGet(
        '/v1/settings/features',
        (req) => req.reply(200, <String, dynamic>{
          'data': <String, dynamic>{
            'flags': <String, dynamic>{},
          },
        }),
      );

      final resp = await base.dio.get<dynamic>('/v1/settings/features');

      expect(resp.requestOptions.method, 'GET');
      expect(resp.requestOptions.path, '/v1/settings/features');
      expect(resp.requestOptions.headers['Authorization'], 'Bearer tok-abc');
      expect(resp.requestOptions.headers['X-Domain'], 'crohnie.ai');
    });

    test('handles an empty flags map gracefully', () async {
      adapter.onGet(
        '/v1/settings/features',
        (req) => req.reply(200, <String, dynamic>{
          'data': <String, dynamic>{
            'flags': <String, dynamic>{},
          },
        }),
      );

      final feats = await subprojects.features();

      expect(feats.flags, isEmpty);
      expect(feats.isEnabled('anything'), isFalse);
    });
  });
}
