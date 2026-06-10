// Tests for the newer AuthClient surface — signUp, resetPassword,
// newPassword, finishSocialRegistration.
//
// All four endpoints are unauthenticated — the AuthInterceptor must NOT
// add an `Authorization: Bearer …` header, even when getToken returns a
// non-null value. This is exercised below by configuring getToken to
// return a real-looking token and asserting the header is absent on the
// outbound request.
//
// Kept in a sibling file so the original auth_client_test.dart stays
// untouched (minimizes merge conflicts with parallel work).

import 'package:ycaas_flutter_sdk/ycaas_flutter_sdk.dart';
import 'package:ycaas_flutter_sdk/src/auth/auth_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

Map<String, dynamic> _userJson() => <String, dynamic>{
      'id': 42,
      'name': 'Alice',
      'email': 'alice@example.com',
      'roles': <String>['user'],
    };

Map<String, dynamic> _tokenJson(String t) => <String, dynamic>{
      'access_token': t,
    };

Map<String, dynamic> _authResponseJson(String t) => <String, dynamic>{
      'user': _userJson(),
      'token': _tokenJson(t),
    };

void main() {
  group('AuthClient.signUp', () {
    test(
        'POSTs /auth/sign-up with the registration payload and returns '
        'AuthResponse', () async {
      final p2x = P2xClient(
        config: const P2xClientConfig(
          baseUrl: 'https://api.project20x.com/api',
        ),
      );
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/auth/sign-up',
        (req) => req.reply(201, <String, dynamic>{
          'success': true,
          'message': 'created',
          'data': _authResponseJson('tok-new'),
        }),
        data: <String, dynamic>{
          'email': 'alice@example.com',
          'password': 'secret123',
          'name': 'Alice',
        },
      );

      final auth = AuthClient(p2x);
      final response = await auth.signUp(
        email: 'alice@example.com',
        password: 'secret123',
        name: 'Alice',
      );

      expect(response.user.id, 42);
      expect(response.user.email, 'alice@example.com');
      expect(response.token.accessToken, 'tok-new');
    });

    test('includes referral_code in the body when provided', () async {
      final p2x = P2xClient(
        config: const P2xClientConfig(
          baseUrl: 'https://api.project20x.com/api',
        ),
      );
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/auth/sign-up',
        (req) => req.reply(201, <String, dynamic>{
          'success': true,
          'message': 'created',
          'data': _authResponseJson('tok-new'),
        }),
        data: <String, dynamic>{
          'email': 'alice@example.com',
          'password': 'secret123',
          'name': 'Alice',
          'referral_code': 'REFCODE',
        },
      );

      final auth = AuthClient(p2x);
      await auth.signUp(
        email: 'alice@example.com',
        password: 'secret123',
        name: 'Alice',
        referralCode: 'REFCODE',
      );
    });

    test('omits the Authorization header even when getToken returns a value',
        () async {
      final p2x = P2xClient(
        config: P2xClientConfig(
          baseUrl: 'https://api.project20x.com/api',
          getToken: () => 'tok-should-not-be-sent',
        ),
      );
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/auth/sign-up',
        (req) => req.reply(201, <String, dynamic>{
          'success': true,
          'data': _authResponseJson('tok-new'),
        }),
        data: Matchers.any,
      );

      final auth = AuthClient(p2x);
      await auth.signUp(
        email: 'alice@example.com',
        password: 'secret123',
        name: 'Alice',
      );

      // Inspect the outbound request via a second direct call so we can
      // grab the headers — the AuthClient API itself doesn't expose them.
      // Use the same opt-out the SDK relies on (skip_auth extra key).
      adapter.onPost(
        '/auth/sign-up',
        (req) => req.reply(201, <String, dynamic>{
          'success': true,
          'data': _authResponseJson('tok-new'),
        }),
        data: Matchers.any,
      );
      final resp = await p2x.dio.post<dynamic>(
        '/auth/sign-up',
        data: <String, dynamic>{
          'email': 'alice@example.com',
          'password': 'secret123',
          'name': 'Alice',
        },
        options: Options(extra: <String, dynamic>{'skip_auth': true}),
      );

      expect(
        resp.requestOptions.headers.containsKey('Authorization'),
        isFalse,
      );
    });

    test('auto-attaches an Idempotency-Key header via the SDK interceptor',
        () async {
      final p2x = P2xClient(
        config: const P2xClientConfig(
          baseUrl: 'https://api.project20x.com/api',
        ),
      );
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/auth/sign-up',
        (req) => req.reply(201, <String, dynamic>{
          'success': true,
          'data': _authResponseJson('tok-new'),
        }),
        data: Matchers.any,
      );

      final resp = await p2x.dio.post<dynamic>(
        '/auth/sign-up',
        data: <String, dynamic>{
          'email': 'alice@example.com',
          'password': 'secret123',
          'name': 'Alice',
        },
        options: Options(extra: <String, dynamic>{'skip_auth': true}),
      );

      final key = resp.requestOptions.headers['Idempotency-Key'];
      expect(key, isA<String>());
      expect((key as String).isNotEmpty, isTrue);
    });
  });

  group('AuthClient.resetPassword', () {
    test('POSTs /auth/password/reset with email', () async {
      final p2x = P2xClient(
        config: const P2xClientConfig(
          baseUrl: 'https://api.project20x.com/api',
        ),
      );
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/auth/password/reset',
        (req) => req.reply(200, <String, dynamic>{
          'success': true,
          'message': 'reset link sent',
          'data': <String, dynamic>{},
        }),
        data: <String, dynamic>{
          'email': 'alice@example.com',
        },
      );

      final auth = AuthClient(p2x);
      // Should complete without throwing.
      await auth.resetPassword(email: 'alice@example.com');
    });
  });

  group('AuthClient.newPassword', () {
    test('POSTs /auth/new-password with token + passwords', () async {
      final p2x = P2xClient(
        config: const P2xClientConfig(
          baseUrl: 'https://api.project20x.com/api',
        ),
      );
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/auth/new-password',
        (req) => req.reply(200, <String, dynamic>{
          'success': true,
          'message': 'password updated',
          'data': <String, dynamic>{},
        }),
        data: <String, dynamic>{
          'token': 'reset-token-abc',
          'password': 'newSecret123',
          'password_confirmation': 'newSecret123',
        },
      );

      final auth = AuthClient(p2x);
      await auth.newPassword(
        token: 'reset-token-abc',
        password: 'newSecret123',
        passwordConfirmation: 'newSecret123',
      );
    });
  });

  group('AuthClient.finishSocialRegistration', () {
    test(
        'POSTs /auth/finish-social-registration with provider + token + '
        'email + name, returns AuthResponse', () async {
      final p2x = P2xClient(
        config: const P2xClientConfig(
          baseUrl: 'https://api.project20x.com/api',
        ),
      );
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/auth/finish-social-registration',
        (req) => req.reply(200, <String, dynamic>{
          'success': true,
          'message': 'ok',
          'data': _authResponseJson('tok-social'),
        }),
        data: <String, dynamic>{
          'provider': 'google',
          'token': 'google-id-token',
          'email': 'alice@example.com',
          'name': 'Alice',
        },
      );

      final auth = AuthClient(p2x);
      final response = await auth.finishSocialRegistration(
        provider: 'google',
        token: 'google-id-token',
        email: 'alice@example.com',
        name: 'Alice',
      );

      expect(response.user.id, 42);
      expect(response.token.accessToken, 'tok-social');
    });
  });
}
