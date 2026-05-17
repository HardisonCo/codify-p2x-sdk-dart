// Contract tests for MethodOverrideInterceptor.
//
// The interceptor rewrites PUT/PATCH requests to POST with a `_method` query
// parameter, matching the Laravel/Symfony method-override convention used by
// the P2X backend's TS SDK.

import 'package:codify_p2x_sdk/codify_p2x_sdk.dart';
import 'package:codify_p2x_sdk/src/client/interceptors/method_override_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

void main() {
  late P2xClient client;
  late DioAdapter adapter;

  setUp(() {
    client = P2xClient(
      config: const P2xClientConfig(
        baseUrl: 'https://api.project20x.com/api',
      ),
    );
    // Replace any existing interceptors except the one under test for
    // isolation: re-register only the method override interceptor.
    client.dio.interceptors
      ..clear()
      ..add(MethodOverrideInterceptor());
    adapter = DioAdapter(dio: client.dio);
  });

  group('MethodOverrideInterceptor — rewrites PUT/PATCH', () {
    test('PUT becomes POST with _method=PUT in queryParameters', () async {
      adapter.onPost(
        '/items/1',
        (req) => req.reply(200, {'ok': true}),
        queryParameters: {'_method': 'PUT'},
      );

      final response = await client.dio.put<dynamic>('/items/1');

      expect(response.requestOptions.method, 'POST');
      expect(response.requestOptions.queryParameters['_method'], 'PUT');
    });

    test('PATCH becomes POST with _method=PATCH in queryParameters', () async {
      adapter.onPost(
        '/items/1',
        (req) => req.reply(200, {'ok': true}),
        queryParameters: {'_method': 'PATCH'},
      );

      final response = await client.dio.patch<dynamic>('/items/1');

      expect(response.requestOptions.method, 'POST');
      expect(response.requestOptions.queryParameters['_method'], 'PATCH');
    });
  });

  group('MethodOverrideInterceptor — leaves other methods alone', () {
    test('DELETE stays DELETE (no _method query param)', () async {
      adapter.onDelete(
        '/items/1',
        (req) => req.reply(200, {'ok': true}),
      );

      final response = await client.dio.delete<dynamic>('/items/1');

      expect(response.requestOptions.method, 'DELETE');
      expect(
        response.requestOptions.queryParameters.containsKey('_method'),
        isFalse,
      );
    });

    test('GET stays GET (no _method query param)', () async {
      adapter.onGet(
        '/items/1',
        (req) => req.reply(200, {'ok': true}),
      );

      final response = await client.dio.get<dynamic>('/items/1');

      expect(response.requestOptions.method, 'GET');
      expect(
        response.requestOptions.queryParameters.containsKey('_method'),
        isFalse,
      );
    });

    test('POST stays POST (no _method query param)', () async {
      adapter.onPost(
        '/items',
        (req) => req.reply(201, {'ok': true}),
      );

      final response = await client.dio.post<dynamic>('/items');

      expect(response.requestOptions.method, 'POST');
      expect(
        response.requestOptions.queryParameters.containsKey('_method'),
        isFalse,
      );
    });
  });

  group('MethodOverrideInterceptor — opt-out and preservation', () {
    test('extras["skip_method_override"]=true keeps the original PUT method',
        () async {
      adapter.onPut(
        '/items/1',
        (req) => req.reply(200, {'ok': true}),
      );

      final response = await client.dio.put<dynamic>(
        '/items/1',
        options: Options(
          extra: <String, dynamic>{
            MethodOverrideInterceptor.skipMethodOverrideExtra: true,
          },
        ),
      );

      expect(response.requestOptions.method, 'PUT');
      expect(
        response.requestOptions.queryParameters.containsKey('_method'),
        isFalse,
      );
    });

    test('existing query parameters are preserved alongside _method', () async {
      adapter.onPost(
        '/items/1',
        (req) => req.reply(200, {'ok': true}),
        queryParameters: {'_method': 'PUT', 'foo': 'bar', 'page': '2'},
      );

      final response = await client.dio.put<dynamic>(
        '/items/1',
        queryParameters: <String, dynamic>{'foo': 'bar', 'page': '2'},
      );

      expect(response.requestOptions.method, 'POST');
      expect(response.requestOptions.queryParameters['_method'], 'PUT');
      expect(response.requestOptions.queryParameters['foo'], 'bar');
      expect(response.requestOptions.queryParameters['page'], '2');
    });
  });
}
