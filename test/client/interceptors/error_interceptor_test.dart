// Contract tests for ErrorInterceptor.
//
// Normalises Dio errors into the SDK's typed exception hierarchy
// (UnauthorizedException, ForbiddenException, NotFoundException,
// ValidationException, ServerException, ApiException) and fires the
// onUnauthorized / onValidationError callbacks from P2xClientConfig.
//
// Dio always re-wraps the final thrown object in a DioException
// (see `assureDioException` in dio_mixin.dart). The ErrorInterceptor
// preserves the typed SDK exception on `DioException.error`, so callers
// always unwrap via `(e as DioException).error as ApiException` (or
// equivalent) — the pattern documented in the SDK README and CLAUDE.md.

import 'package:ycaas_flutter_sdk/ycaas_flutter_sdk.dart';
import 'package:ycaas_flutter_sdk/src/client/interceptors/error_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

/// Build a client wired ONLY with the ErrorInterceptor, so tests can pivot
/// on this interceptor's behaviour in isolation. The [config] provides the
/// callbacks under test.
({P2xClient client, DioAdapter adapter}) _buildClient(P2xClientConfig config) {
  final client = P2xClient(config: config);
  client.dio.interceptors
    ..clear()
    ..add(ErrorInterceptor(config));
  final adapter = DioAdapter(dio: client.dio);
  return (client: client, adapter: adapter);
}

/// Unwrap Dio's outer envelope to get at the typed SDK exception that the
/// ErrorInterceptor has stashed on `DioException.error`.
ApiException _unwrap(Object thrown) {
  if (thrown is ApiException) {
    return thrown;
  }
  if (thrown is DioException) {
    final inner = thrown.error;
    if (inner is ApiException) {
      return inner;
    }
  }
  fail('Expected ApiException (possibly wrapped in DioException), got '
      '${thrown.runtimeType}: $thrown');
}

void main() {
  group('ErrorInterceptor — status code → typed exception', () {
    test('401 throws UnauthorizedException and fires onUnauthorized once',
        () async {
      var unauthorizedCalls = 0;
      final harness = _buildClient(
        P2xClientConfig(
          baseUrl: 'https://api.project20x.com/api',
          onUnauthorized: () => unauthorizedCalls++,
        ),
      );
      harness.adapter.onGet(
        '/me',
        (req) => req.reply(401, {'message': 'Unauthenticated.'}),
      );

      Object? caught;
      try {
        await harness.client.dio.get<dynamic>('/me');
      } catch (e) {
        caught = e;
      }
      expect(_unwrap(caught!), isA<UnauthorizedException>());
      expect(unauthorizedCalls, 1);
    });

    test('403 throws ForbiddenException', () async {
      final harness = _buildClient(
        const P2xClientConfig(baseUrl: 'https://api.project20x.com/api'),
      );
      harness.adapter.onGet(
        '/admin',
        (req) => req.reply(403, {'message': 'Forbidden.'}),
      );

      Object? caught;
      try {
        await harness.client.dio.get<dynamic>('/admin');
      } catch (e) {
        caught = e;
      }
      expect(_unwrap(caught!), isA<ForbiddenException>());
    });

    test('404 throws NotFoundException', () async {
      final harness = _buildClient(
        const P2xClientConfig(baseUrl: 'https://api.project20x.com/api'),
      );
      harness.adapter.onGet(
        '/items/999',
        (req) => req.reply(404, {'message': 'Not found.'}),
      );

      Object? caught;
      try {
        await harness.client.dio.get<dynamic>('/items/999');
      } catch (e) {
        caught = e;
      }
      expect(_unwrap(caught!), isA<NotFoundException>());
    });

    test('500 throws ServerException', () async {
      final harness = _buildClient(
        const P2xClientConfig(baseUrl: 'https://api.project20x.com/api'),
      );
      harness.adapter.onGet(
        '/boom',
        (req) => req.reply(500, {'message': 'Server error.'}),
      );

      Object? caught;
      try {
        await harness.client.dio.get<dynamic>('/boom');
      } catch (e) {
        caught = e;
      }
      final unwrapped = _unwrap(caught!);
      expect(unwrapped, isA<ServerException>());
      expect(unwrapped.status, 500);
    });

    test('503 throws ServerException', () async {
      final harness = _buildClient(
        const P2xClientConfig(baseUrl: 'https://api.project20x.com/api'),
      );
      harness.adapter.onGet(
        '/maintenance',
        (req) => req.reply(503, {'message': 'Service unavailable.'}),
      );

      Object? caught;
      try {
        await harness.client.dio.get<dynamic>('/maintenance');
      } catch (e) {
        caught = e;
      }
      final unwrapped = _unwrap(caught!);
      expect(unwrapped, isA<ServerException>());
      expect(unwrapped.status, 503);
    });

    test('418 throws base ApiException (no specialised subtype)', () async {
      final harness = _buildClient(
        const P2xClientConfig(baseUrl: 'https://api.project20x.com/api'),
      );
      harness.adapter.onGet(
        '/teapot',
        (req) => req.reply(418, {'message': "I'm a teapot."}),
      );

      Object? caught;
      try {
        await harness.client.dio.get<dynamic>('/teapot');
      } catch (e) {
        caught = e;
      }
      final unwrapped = _unwrap(caught!);
      expect(unwrapped, isA<ApiException>());
      expect(unwrapped, isNot(isA<UnauthorizedException>()));
      expect(unwrapped, isNot(isA<ForbiddenException>()));
      expect(unwrapped, isNot(isA<NotFoundException>()));
      expect(unwrapped, isNot(isA<ValidationException>()));
      expect(unwrapped, isNot(isA<ServerException>()));
      expect(unwrapped.status, 418);
    });
  });

  group('ErrorInterceptor — 422 ValidationException', () {
    test(
        'top-level {errors: ...} shape parses fields and fires '
        'onValidationError', () async {
      Map<String, List<String>>? captured;
      final harness = _buildClient(
        P2xClientConfig(
          baseUrl: 'https://api.project20x.com/api',
          onValidationError: (errors) => captured = errors,
        ),
      );
      harness.adapter.onPost(
        '/items',
        (req) => req.reply(422, {
          'message': 'The given data was invalid.',
          'errors': {
            'email': ['Required.', 'Invalid format.'],
            'phone': ['Required.'],
          },
        }),
      );

      Object? caught;
      try {
        await harness.client.dio.post<dynamic>('/items');
      } catch (e) {
        caught = e;
      }
      final unwrapped = _unwrap(caught!);
      expect(unwrapped, isA<ValidationException>());
      final v = unwrapped as ValidationException;
      expect(v.errors, {
        'email': ['Required.', 'Invalid format.'],
        'phone': ['Required.'],
      });
      expect(captured, isNotNull);
      expect(captured!['email'], ['Required.', 'Invalid format.']);
      expect(captured!['phone'], ['Required.']);
    });

    test('nested {data: {errors: ...}} shape also parses', () async {
      final harness = _buildClient(
        const P2xClientConfig(baseUrl: 'https://api.project20x.com/api'),
      );
      harness.adapter.onPost(
        '/items',
        (req) => req.reply(422, {
          'message': 'Validation failed.',
          'data': {
            'errors': {
              'name': ['Required.'],
            },
          },
        }),
      );

      Object? caught;
      try {
        await harness.client.dio.post<dynamic>('/items');
      } catch (e) {
        caught = e;
      }
      final unwrapped = _unwrap(caught!);
      expect(unwrapped, isA<ValidationException>());
      expect((unwrapped as ValidationException).errors, {
        'name': ['Required.'],
      });
    });

    test('422 with no errors field yields ValidationException with empty map',
        () async {
      final harness = _buildClient(
        const P2xClientConfig(baseUrl: 'https://api.project20x.com/api'),
      );
      harness.adapter.onPost(
        '/items',
        (req) => req.reply(422, {'message': 'Unprocessable.'}),
      );

      Object? caught;
      try {
        await harness.client.dio.post<dynamic>('/items');
      } catch (e) {
        caught = e;
      }
      final unwrapped = _unwrap(caught!);
      expect(unwrapped, isA<ValidationException>());
      expect(
        (unwrapped as ValidationException).errors,
        <String, List<String>>{},
      );
    });
  });

  group('ErrorInterceptor — network and edge cases', () {
    test('connection error (no response) throws ApiException with status 0',
        () async {
      final harness = _buildClient(
        const P2xClientConfig(baseUrl: 'https://api.project20x.com/api'),
      );
      harness.adapter.onGet(
        '/offline',
        (req) => req.throws(
          0,
          DioException.connectionError(
            requestOptions: RequestOptions(path: '/offline'),
            reason: 'No internet',
          ),
        ),
      );

      Object? caught;
      try {
        await harness.client.dio.get<dynamic>('/offline');
      } catch (e) {
        caught = e;
      }
      final unwrapped = _unwrap(caught!);
      expect(unwrapped, isA<ApiException>());
      expect(unwrapped.status, 0);
    });

    test('multiple 401s each fire onUnauthorized once per request', () async {
      var calls = 0;
      final harness = _buildClient(
        P2xClientConfig(
          baseUrl: 'https://api.project20x.com/api',
          onUnauthorized: () => calls++,
        ),
      );
      harness.adapter
        ..onGet('/a', (req) => req.reply(401, {'message': 'no'}))
        ..onGet('/b', (req) => req.reply(401, {'message': 'no'}));

      try {
        await harness.client.dio.get<dynamic>('/a');
      } catch (_) {/* expected */}
      try {
        await harness.client.dio.get<dynamic>('/b');
      } catch (_) {/* expected */}
      expect(calls, 2);
    });

    test('exception carries server message when available', () async {
      final harness = _buildClient(
        const P2xClientConfig(baseUrl: 'https://api.project20x.com/api'),
      );
      harness.adapter.onGet(
        '/forbidden',
        (req) => req.reply(403, {'message': 'You shall not pass.'}),
      );

      Object? caught;
      try {
        await harness.client.dio.get<dynamic>('/forbidden');
      } catch (e) {
        caught = e;
      }
      final unwrapped = _unwrap(caught!);
      expect(unwrapped, isA<ForbiddenException>());
      expect(unwrapped.message, 'You shall not pass.');
    });
  });
}
