// Contract tests for P2xClient.
//
// These are the canonical invariants the base client must uphold. They mirror
// the TS SDK's `src/__tests__/contract/base-client.contract.test.ts`.
//
// Every test asserts behavior observable from the wire: URL, method, headers,
// body shape, response decoding, error type. Implementation details are not
// asserted — those are free to evolve.

import 'package:ycaas_flutter_sdk/ycaas_flutter_sdk.dart';
import 'package:ycaas_flutter_sdk/src/client/interceptors/auth_interceptor.dart';
import 'package:ycaas_flutter_sdk/src/client/interceptors/error_interceptor.dart';
import 'package:ycaas_flutter_sdk/src/client/interceptors/idempotency_interceptor.dart';
import 'package:ycaas_flutter_sdk/src/client/interceptors/method_override_interceptor.dart';
import 'package:ycaas_flutter_sdk/src/client/interceptors/subproject_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P2xClient — construction', () {
    test('builds with required baseUrl and exposes the underlying Dio', () {
      final client = P2xClient(
        config: const P2xClientConfig(
          baseUrl: 'https://api.project20x.com/api',
        ),
      );

      expect(client.dio, isA<Dio>());
      expect(client.dio.options.baseUrl, 'https://api.project20x.com/api');
    });

    test('registers the full 5-interceptor stack in the documented order', () {
      final client = P2xClient(
        config: const P2xClientConfig(
          baseUrl: 'https://api.project20x.com/api',
        ),
      );

      final stack = client.dio.interceptors
          .where(
            (i) =>
                i is AuthInterceptor ||
                i is SubprojectInterceptor ||
                i is MethodOverrideInterceptor ||
                i is IdempotencyInterceptor ||
                i is ErrorInterceptor,
          )
          .toList();
      expect(stack, hasLength(5));
      expect(stack[0], isA<AuthInterceptor>());
      expect(stack[1], isA<SubprojectInterceptor>());
      expect(stack[2], isA<MethodOverrideInterceptor>());
      expect(stack[3], isA<IdempotencyInterceptor>());
      expect(stack[4], isA<ErrorInterceptor>(),
          reason: 'ErrorInterceptor must be last');
    });

    test('default Content-Type is application/json on every request', () async {
      final client = P2xClient(
        config: const P2xClientConfig(
          baseUrl: 'https://api.project20x.com/api',
        ),
      );
      final adapter = DioAdapter(dio: client.dio);
      adapter.onGet('/me', (req) => req.reply(200, {'data': {}}));

      final response = await client.dio.get<dynamic>('/me');

      expect(response.requestOptions.headers['Content-Type'],
          contains('application/json'));
    });
  });

  group('P2xClient — Authorization header', () {
    test('injects Bearer token from getToken when present', () async {
      String? currentToken = 'tok-abc-123';
      final client = P2xClient(
        config: P2xClientConfig(
          baseUrl: 'https://api.project20x.com/api',
          getToken: () => currentToken,
        ),
      );
      final adapter = DioAdapter(dio: client.dio);
      adapter.onGet('/me', (req) => req.reply(200, {'data': {}}));

      final response = await client.dio.get<dynamic>('/me');

      expect(
        response.requestOptions.headers['Authorization'],
        'Bearer tok-abc-123',
      );
    });

    test('omits Authorization header when getToken returns null', () async {
      final client = P2xClient(
        config: P2xClientConfig(
          baseUrl: 'https://api.project20x.com/api',
          getToken: () => null,
        ),
      );
      final adapter = DioAdapter(dio: client.dio);
      adapter.onGet('/public/load', (req) => req.reply(200, {'data': {}}));

      final response = await client.dio.get<dynamic>('/public/load');

      expect(response.requestOptions.headers.containsKey('Authorization'),
          isFalse);
    });

    test('omits Authorization header when getToken is not configured',
        () async {
      final client = P2xClient(
        config: const P2xClientConfig(
          baseUrl: 'https://api.project20x.com/api',
        ),
      );
      final adapter = DioAdapter(dio: client.dio);
      adapter.onGet('/public/load', (req) => req.reply(200, {'data': {}}));

      final response = await client.dio.get<dynamic>('/public/load');

      expect(response.requestOptions.headers.containsKey('Authorization'),
          isFalse);
    });

    test('re-reads getToken on every request (token rotation works)', () async {
      String? currentToken = 'tok-first';
      final client = P2xClient(
        config: P2xClientConfig(
          baseUrl: 'https://api.project20x.com/api',
          getToken: () => currentToken,
        ),
      );
      final adapter = DioAdapter(dio: client.dio);
      adapter.onGet('/me', (req) => req.reply(200, {'data': {}}));

      final first = await client.dio.get<dynamic>('/me');
      expect(first.requestOptions.headers['Authorization'], 'Bearer tok-first');

      currentToken = 'tok-second';
      final second = await client.dio.get<dynamic>('/me');
      expect(
          second.requestOptions.headers['Authorization'], 'Bearer tok-second');
    });
  });

  group('P2xClient — X-Domain header', () {
    test('injects X-Domain from getDomain when present', () async {
      final client = P2xClient(
        config: P2xClientConfig(
          baseUrl: 'https://api.project20x.com/api',
          getDomain: () => 'nutriscan.codify.ai',
        ),
      );
      final adapter = DioAdapter(dio: client.dio);
      adapter.onGet('/me', (req) => req.reply(200, {'data': {}}));

      final response = await client.dio.get<dynamic>('/me');

      expect(
          response.requestOptions.headers['X-Domain'], 'nutriscan.codify.ai');
    });

    test('omits X-Domain header when getDomain returns null', () async {
      final client = P2xClient(
        config: P2xClientConfig(
          baseUrl: 'https://api.project20x.com/api',
          getDomain: () => null,
        ),
      );
      final adapter = DioAdapter(dio: client.dio);
      adapter.onGet('/public/load', (req) => req.reply(200, {'data': {}}));

      final response = await client.dio.get<dynamic>('/public/load');

      expect(response.requestOptions.headers.containsKey('X-Domain'), isFalse);
    });

    test('omits X-Domain header when getDomain is not configured', () async {
      final client = P2xClient(
        config: const P2xClientConfig(
          baseUrl: 'https://api.project20x.com/api',
        ),
      );
      final adapter = DioAdapter(dio: client.dio);
      adapter.onGet('/public/load', (req) => req.reply(200, {'data': {}}));

      final response = await client.dio.get<dynamic>('/public/load');

      expect(response.requestOptions.headers.containsKey('X-Domain'), isFalse);
    });
  });

  group('P2xClient — request handling', () {
    test('successfully GETs and returns response body', () async {
      final client = P2xClient(
        config: const P2xClientConfig(
          baseUrl: 'https://api.project20x.com/api',
        ),
      );
      final adapter = DioAdapter(dio: client.dio);
      adapter.onGet(
        '/me',
        (req) => req.reply(200, {
          'success': true,
          'message': 'ok',
          'data': {'id': 42, 'name': 'Alice'},
        }),
      );

      final response = await client.dio.get<Map<String, dynamic>>('/me');

      expect(response.statusCode, 200);
      expect(response.data?['data']['id'], 42);
      expect(response.data?['data']['name'], 'Alice');
    });
  });
}
