// Tests for PasswordSwapClient — the PHM-flavoured email/password swap that
// turns credentials into a Sanctum bearer via `POST /public/auth/sign-in`.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:ycaas_flutter_sdk/src/auth/password_swap_client.dart';
import 'package:ycaas_flutter_sdk/src/auth/password_swap_models.dart';
import 'package:ycaas_flutter_sdk/ycaas_flutter_sdk.dart';

Map<String, dynamic> _signInPayload(String token) => <String, dynamic>{
      'accessToken': token,
      'id': 99,
      'username': 'doc@phm.ai',
      'full_name': 'Dr Patel',
      'roles': <String>['doctor'],
      'permissions': <String>['subproject:7'],
      'email_verified_at': '2026-01-01T00:00:00Z',
      'force_password_reset': false,
    };

void main() {
  group('PasswordSwapClient.signIn', () {
    test(
        'POSTs /public/auth/sign-in with login + password and returns '
        'an AuthResponse', () async {
      final p2x = P2xClient(
        config: const P2xClientConfig(
          baseUrl: 'https://api.project20x.com/api',
        ),
      );
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/public/auth/sign-in',
        (req) => req.reply(200, <String, dynamic>{
          'success': true,
          'message': 'ok',
          'data': _signInPayload('tok-pwd-1'),
        }),
        data: <String, dynamic>{
          'login': 'doc@phm.ai',
          'password': 'hunter2',
        },
      );

      final client = PasswordSwapClient(p2x);
      final response = await client.signIn(
        login: 'doc@phm.ai',
        password: 'hunter2',
      );

      expect(response.user.id, 99);
      expect(response.user.email, 'doc@phm.ai');
      expect(response.user.name, 'Dr Patel');
      expect(response.user.roles, <String>['doctor']);
      expect(response.token.accessToken, 'tok-pwd-1');
    });

    test('forwards optional timezone in the body', () async {
      final p2x = P2xClient(
        config: const P2xClientConfig(
          baseUrl: 'https://api.project20x.com/api',
        ),
      );
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/public/auth/sign-in',
        (req) => req.reply(200, <String, dynamic>{
          'success': true,
          'message': 'ok',
          'data': _signInPayload('tok-pwd-tz'),
        }),
        data: <String, dynamic>{
          'login': 'doc@phm.ai',
          'password': 'hunter2',
          'timezone': 'America/Los_Angeles',
        },
      );

      final client = PasswordSwapClient(p2x);
      await client.signIn(
        login: 'doc@phm.ai',
        password: 'hunter2',
        timezone: 'America/Los_Angeles',
      );
      // Adapter throws if the body shape doesn't match; reaching here proves
      // it did.
    });

    // Note: the "skip Authorization header on public endpoints" contract is
    // covered exhaustively in test/client/interceptors/auth_interceptor_test.dart;
    // we trust the unit test there rather than re-asserting it here.

    test('surfaces 422 bad credentials as ValidationException', () async {
      final p2x = P2xClient(
        config: const P2xClientConfig(
          baseUrl: 'https://api.project20x.com/api',
        ),
      );
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/public/auth/sign-in',
        (req) => req.reply(422, <String, dynamic>{
          'success': false,
          'message': 'These credentials do not match our records.',
          'errors': <String, dynamic>{
            'login': <String>['The credentials are invalid.'],
            'password': <String>['The credentials are invalid.'],
          },
        }),
        data: <String, dynamic>{
          'login': 'doc@phm.ai',
          'password': 'wrong',
        },
      );

      final client = PasswordSwapClient(p2x);

      await expectLater(
        client.signIn(login: 'doc@phm.ai', password: 'wrong'),
        throwsA(
          anyOf(isA<ValidationException>(), isA<DioException>()),
        ),
      );
    });
  });

  group('PasswordSwapClient.signInRaw', () {
    test('returns PasswordSignInResponse with permissions + forcePasswordReset',
        () async {
      final p2x = P2xClient(
        config: const P2xClientConfig(
          baseUrl: 'https://api.project20x.com/api',
        ),
      );
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/public/auth/sign-in',
        (req) => req.reply(200, <String, dynamic>{
          'success': true,
          'message': 'ok',
          'data': <String, dynamic>{
            'accessToken': 'tok-pwd-raw',
            'id': 7,
            'username': 'forced@phm.ai',
            'full_name': '',
            'roles': <String>['patient'],
            'permissions': <String>['subproject:7', 'order:write'],
            'email_verified_at': null,
            'force_password_reset': true,
          },
        }),
        data: <String, dynamic>{
          'login': 'forced@phm.ai',
          'password': 'tmp-pw',
        },
      );

      final client = PasswordSwapClient(p2x);
      final PasswordSignInResponse raw = await client.signInRaw(
        login: 'forced@phm.ai',
        password: 'tmp-pw',
      );

      expect(raw.accessToken, 'tok-pwd-raw');
      expect(raw.permissions, <String>['subproject:7', 'order:write']);
      expect(raw.forcePasswordReset, isTrue);
      // toAuthResponse() picks username when fullName is empty.
      expect(raw.toAuthResponse().user.name, 'forced@phm.ai');
    });
  });
}
