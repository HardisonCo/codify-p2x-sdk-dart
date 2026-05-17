// Tests for FirebaseSwapClient — the NIO Firebase-ID-token -> Sanctum-bearer
// swap endpoint.

import 'package:codify_p2x_sdk/codify_p2x_sdk.dart';
import 'package:codify_p2x_sdk/src/auth/firebase_swap_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

Map<String, dynamic> _authResponseJson(String t) => <String, dynamic>{
      'user': <String, dynamic>{
        'id': 42,
        'name': 'Nio User',
        'email': 'nio@example.com',
        'roles': <String>['user'],
      },
      'token': <String, dynamic>{'access_token': t},
    };

void main() {
  group('FirebaseSwapClient.firebaseLogin', () {
    test(
        'POSTs /v1/integrations/nio/firebase-login with firebase_id_token, '
        'returns AuthResponse', () async {
      final p2x = P2xClient(
        config: const P2xClientConfig(
          baseUrl: 'https://api.project20x.com/api',
        ),
      );
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/v1/integrations/nio/firebase-login',
        (req) => req.reply(200, <String, dynamic>{
          'success': true,
          'message': 'ok',
          'data': _authResponseJson('tok-nio-1'),
        }),
        data: <String, dynamic>{
          'firebase_id_token': 'firebase-jwt-xyz',
        },
      );

      final swap = FirebaseSwapClient(p2x);
      final response = await swap.firebaseLogin(
        firebaseIdToken: 'firebase-jwt-xyz',
      );

      expect(response.user.id, 42);
      expect(response.token.accessToken, 'tok-nio-1');
    });

    test('surfaces 401 (invalid Firebase token) as a thrown error', () async {
      // TODO(p2x-sdk): once ErrorInterceptor lands, assert this throws
      // UnauthorizedException specifically.
      final p2x = P2xClient(
        config: const P2xClientConfig(
          baseUrl: 'https://api.project20x.com/api',
        ),
      );
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/v1/integrations/nio/firebase-login',
        (req) => req.reply(401, <String, dynamic>{
          'success': false,
          'message': 'Invalid Firebase ID token',
        }),
        data: <String, dynamic>{
          'firebase_id_token': 'bad-jwt',
        },
      );

      final swap = FirebaseSwapClient(p2x);

      await expectLater(
        swap.firebaseLogin(firebaseIdToken: 'bad-jwt'),
        throwsA(anyOf(isA<DioException>(), isA<UnauthorizedException>())),
      );
    });
  });
}
