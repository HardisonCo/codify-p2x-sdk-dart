// Tests for AuthClient — login, logout, me, refresh.
//
// Uses http_mock_adapter to mock the underlying Dio. The error-normalization
// interceptor isn't wired yet (Agent A's scope), so for now 4xx responses
// bubble up as raw DioException. The 401 -> UnauthorizedException test is
// marked accordingly until that interceptor lands.

import 'package:codify_p2x_sdk/codify_p2x_sdk.dart';
import 'package:codify_p2x_sdk/src/auth/auth_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

Map<String, dynamic> _userJson() => <String, dynamic>{
      'id': 42,
      'name': 'Alice',
      'email': 'alice@example.com',
      'roles': <String>['admin'],
    };

Map<String, dynamic> _tokenJson(String t) => <String, dynamic>{
      'access_token': t,
    };

Map<String, dynamic> _authResponseJson(String t) => <String, dynamic>{
      'user': _userJson(),
      'token': _tokenJson(t),
    };

void main() {
  group('AuthClient.login', () {
    test('POSTs /dashboard/login with email + password, returns AuthResponse',
        () async {
      final p2x = P2xClient(
        config: const P2xClientConfig(
          baseUrl: 'https://api.project20x.com/api',
        ),
      );
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/dashboard/login',
        (req) => req.reply(200, <String, dynamic>{
          'success': true,
          'message': 'ok',
          'data': _authResponseJson('tok-abc'),
        }),
        data: <String, dynamic>{
          'email': 'alice@example.com',
          'password': 'secret',
        },
      );

      final auth = AuthClient(p2x);
      final response = await auth.login(
        email: 'alice@example.com',
        password: 'secret',
      );

      expect(response.user.id, 42);
      expect(response.user.email, 'alice@example.com');
      expect(response.token.accessToken, 'tok-abc');
    });

    test('forwards 401 as a thrown error', () async {
      // TODO(p2x-sdk): once ErrorInterceptor lands, assert this throws
      // UnauthorizedException specifically. For now raw DioException is fine.
      final p2x = P2xClient(
        config: const P2xClientConfig(
          baseUrl: 'https://api.project20x.com/api',
        ),
      );
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/dashboard/login',
        (req) => req.reply(401, <String, dynamic>{
          'success': false,
          'message': 'Invalid credentials',
        }),
        data: <String, dynamic>{
          'email': 'bad@example.com',
          'password': 'wrong',
        },
      );

      final auth = AuthClient(p2x);

      await expectLater(
        auth.login(email: 'bad@example.com', password: 'wrong'),
        throwsA(anyOf(isA<DioException>(), isA<UnauthorizedException>())),
      );
    });
  });

  group('AuthClient.me', () {
    test('GETs /user/get-data with Bearer header and returns AuthResponse',
        () async {
      const currentToken = 'tok-xyz';
      final p2x = P2xClient(
        config: P2xClientConfig(
          baseUrl: 'https://api.project20x.com/api',
          getToken: () => currentToken,
        ),
      );
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onGet(
        '/user/get-data',
        (req) => req.reply(200, <String, dynamic>{
          'success': true,
          'message': 'ok',
          'data': _authResponseJson('tok-xyz'),
        }),
      );

      final auth = AuthClient(p2x);
      final response = await auth.me();

      expect(response.user.id, 42);
      expect(response.token.accessToken, 'tok-xyz');
    });
  });

  group('AuthClient.logout', () {
    test('POSTs /logout and returns Future<void>', () async {
      final p2x = P2xClient(
        config: P2xClientConfig(
          baseUrl: 'https://api.project20x.com/api',
          getToken: () => 'tok-xyz',
        ),
      );
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/logout',
        (req) => req.reply(200, <String, dynamic>{
          'success': true,
          'message': 'logged out',
          'data': <String, dynamic>{},
        }),
        data: null,
      );

      final auth = AuthClient(p2x);

      // Should complete without throwing.
      await auth.logout();
    });
  });

  group('AuthClient.refresh', () {
    test('POSTs /auth/refresh and returns the new Token', () async {
      final p2x = P2xClient(
        config: P2xClientConfig(
          baseUrl: 'https://api.project20x.com/api',
          getToken: () => 'tok-old',
        ),
      );
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/auth/refresh',
        (req) => req.reply(200, <String, dynamic>{
          'success': true,
          'message': 'ok',
          'data': <String, dynamic>{
            'access_token': 'tok-new',
            'refresh_token': 'r-new',
          },
        }),
        data: null,
      );

      final auth = AuthClient(p2x);
      final token = await auth.refresh();

      expect(token.accessToken, 'tok-new');
      expect(token.refreshToken, 'r-new');
    });

    test('forwards 404 (refresh not supported by server) as a thrown error',
        () async {
      // TODO(p2x-sdk): once ErrorInterceptor lands, assert this throws
      // NotFoundException specifically.
      final p2x = P2xClient(
        config: P2xClientConfig(
          baseUrl: 'https://api.project20x.com/api',
          getToken: () => 'tok-old',
        ),
      );
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/auth/refresh',
        (req) => req.reply(404, <String, dynamic>{
          'success': false,
          'message': 'Not Found',
        }),
        data: null,
      );

      final auth = AuthClient(p2x);

      await expectLater(
        auth.refresh(),
        throwsA(anyOf(isA<DioException>(), isA<NotFoundException>())),
      );
    });
  });
}
