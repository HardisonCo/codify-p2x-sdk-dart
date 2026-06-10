// Contract tests for IdempotencyInterceptor.
//
// Mutating requests (POST/PUT/PATCH/DELETE) get an Idempotency-Key header so
// the P2X backend's idempotency middleware can de-dupe retries within its
// 24-hour Redis TTL window. GETs are skipped (idempotent by definition).

import 'package:ycaas_flutter_sdk/ycaas_flutter_sdk.dart';
import 'package:ycaas_flutter_sdk/src/client/interceptors/idempotency_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

/// Lower-case UUID v4 regex (Idempotency-Key auto-generation contract).
final RegExp _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

void main() {
  late P2xClient client;
  late DioAdapter adapter;

  setUp(() {
    client = P2xClient(
      config: const P2xClientConfig(
        baseUrl: 'https://api.project20x.com/api',
      ),
    );
    client.dio.interceptors
      ..clear()
      ..add(IdempotencyInterceptor());
    adapter = DioAdapter(dio: client.dio);
  });

  group('IdempotencyInterceptor — auto-generation', () {
    test('POST without explicit key gets a fresh UUID v4 Idempotency-Key',
        () async {
      adapter.onPost('/items', (req) => req.reply(201, {'ok': true}));

      final response = await client.dio.post<dynamic>('/items');

      final key = response.requestOptions.headers['Idempotency-Key'] as String?;
      expect(key, isNotNull);
      expect(
        _uuidV4.hasMatch(key!),
        isTrue,
        reason: 'Expected UUID v4 but got "$key"',
      );
    });

    test('PUT gets an auto-generated Idempotency-Key', () async {
      adapter.onPut('/items/1', (req) => req.reply(200, {'ok': true}));

      final response = await client.dio.put<dynamic>('/items/1');

      final key = response.requestOptions.headers['Idempotency-Key'] as String?;
      expect(key, isNotNull);
      expect(_uuidV4.hasMatch(key!), isTrue);
    });

    test('PATCH gets an auto-generated Idempotency-Key', () async {
      adapter.onPatch('/items/1', (req) => req.reply(200, {'ok': true}));

      final response = await client.dio.patch<dynamic>('/items/1');

      final key = response.requestOptions.headers['Idempotency-Key'] as String?;
      expect(key, isNotNull);
      expect(_uuidV4.hasMatch(key!), isTrue);
    });

    test('DELETE gets an auto-generated Idempotency-Key', () async {
      adapter.onDelete('/items/1', (req) => req.reply(204, null));

      final response = await client.dio.delete<dynamic>('/items/1');

      final key = response.requestOptions.headers['Idempotency-Key'] as String?;
      expect(key, isNotNull);
      expect(_uuidV4.hasMatch(key!), isTrue);
    });

    test('two POSTs produce different auto-generated keys', () async {
      adapter
        ..onPost('/items', (req) => req.reply(201, {'ok': true}))
        ..onPost('/items', (req) => req.reply(201, {'ok': true}));

      final first = await client.dio.post<dynamic>('/items');
      final second = await client.dio.post<dynamic>('/items');

      expect(
        first.requestOptions.headers['Idempotency-Key'],
        isNot(equals(second.requestOptions.headers['Idempotency-Key'])),
      );
    });
  });

  group('IdempotencyInterceptor — caller-supplied key', () {
    test('POST with extras["idempotency_key"]="custom-key" uses that key',
        () async {
      adapter.onPost('/items', (req) => req.reply(201, {'ok': true}));

      final response = await client.dio.post<dynamic>(
        '/items',
        options: Options(
          extra: <String, dynamic>{
            IdempotencyInterceptor.idempotencyKeyExtra: 'custom-key',
          },
        ),
      );

      expect(
        response.requestOptions.headers['Idempotency-Key'],
        'custom-key',
      );
    });

    test('POST with explicit Idempotency-Key header passes through unchanged',
        () async {
      adapter.onPost('/items', (req) => req.reply(201, {'ok': true}));

      final response = await client.dio.post<dynamic>(
        '/items',
        options: Options(
          headers: <String, dynamic>{
            'Idempotency-Key': 'preset-key',
          },
        ),
      );

      expect(
        response.requestOptions.headers['Idempotency-Key'],
        'preset-key',
      );
    });
  });

  group('IdempotencyInterceptor — skip behaviour', () {
    test('GET requests do NOT get an Idempotency-Key', () async {
      adapter.onGet(
        '/me',
        (req) => req.reply(200, {'data': <String, dynamic>{}}),
      );

      final response = await client.dio.get<dynamic>('/me');

      expect(
        response.requestOptions.headers.containsKey('Idempotency-Key'),
        isFalse,
      );
    });

    test('extras["skip_idempotency"]=true skips Idempotency-Key even on POST',
        () async {
      adapter.onPost('/items', (req) => req.reply(201, {'ok': true}));

      final response = await client.dio.post<dynamic>(
        '/items',
        options: Options(
          extra: <String, dynamic>{
            IdempotencyInterceptor.skipIdempotencyExtra: true,
          },
        ),
      );

      expect(
        response.requestOptions.headers.containsKey('Idempotency-Key'),
        isFalse,
      );
    });
  });
}
