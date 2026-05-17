// Tests for GuestRegisterClient — the MOB anonymous device-UUID -> Sanctum
// bearer endpoint.

import 'package:codify_p2x_sdk/codify_p2x_sdk.dart';
import 'package:codify_p2x_sdk/src/auth/guest_register_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

Map<String, dynamic> _authResponseJson(String t, {int userId = 99}) =>
    <String, dynamic>{
      'user': <String, dynamic>{
        'id': userId,
        'name': 'Guest $userId',
        'email': 'guest-$userId@mob.local',
        'roles': <String>['guest'],
      },
      'token': <String, dynamic>{'access_token': t},
    };

void main() {
  group('GuestRegisterClient.guestRegister', () {
    test(
        'POSTs /v1/integrations/mob/guest-register with device_uuid, returns '
        'AuthResponse on 201', () async {
      final p2x = P2xClient(
        config: const P2xClientConfig(
          baseUrl: 'https://api.project20x.com/api',
        ),
      );
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/v1/integrations/mob/guest-register',
        (req) => req.reply(201, <String, dynamic>{
          'success': true,
          'message': 'created',
          'data': _authResponseJson('tok-mob-1'),
        }),
        data: <String, dynamic>{
          'device_uuid': 'device-uuid-1',
        },
      );

      final client = GuestRegisterClient(p2x);
      final response = await client.guestRegister(
        deviceUuid: 'device-uuid-1',
      );

      expect(response.user.id, 99);
      expect(response.token.accessToken, 'tok-mob-1');
    });

    test('also handles 200 OK (idempotent re-register)', () async {
      final p2x = P2xClient(
        config: const P2xClientConfig(
          baseUrl: 'https://api.project20x.com/api',
        ),
      );
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/v1/integrations/mob/guest-register',
        (req) => req.reply(200, <String, dynamic>{
          'success': true,
          'message': 'ok',
          'data': _authResponseJson('tok-mob-1'),
        }),
        data: <String, dynamic>{
          'device_uuid': 'device-uuid-1',
        },
      );

      final client = GuestRegisterClient(p2x);
      final response = await client.guestRegister(
        deviceUuid: 'device-uuid-1',
      );

      expect(response.user.id, 99);
      expect(response.token.accessToken, 'tok-mob-1');
    });

    test('includes platform and app_version when provided', () async {
      final p2x = P2xClient(
        config: const P2xClientConfig(
          baseUrl: 'https://api.project20x.com/api',
        ),
      );
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/v1/integrations/mob/guest-register',
        (req) => req.reply(201, <String, dynamic>{
          'success': true,
          'message': 'created',
          'data': _authResponseJson('tok-mob-2'),
        }),
        data: <String, dynamic>{
          'device_uuid': 'device-uuid-2',
          'platform': 'ios',
          'app_version': '1.2.3',
        },
      );

      final client = GuestRegisterClient(p2x);
      final response = await client.guestRegister(
        deviceUuid: 'device-uuid-2',
        platform: 'ios',
        appVersion: '1.2.3',
      );

      expect(response.token.accessToken, 'tok-mob-2');
    });

    test('omits platform / app_version from the body when null', () async {
      final p2x = P2xClient(
        config: const P2xClientConfig(
          baseUrl: 'https://api.project20x.com/api',
        ),
      );
      final adapter = DioAdapter(dio: p2x.dio);

      // The mock matches the exact body shape — if guestRegister sent
      // {platform: null, app_version: null} this would not match.
      adapter.onPost(
        '/v1/integrations/mob/guest-register',
        (req) => req.reply(201, <String, dynamic>{
          'success': true,
          'message': 'created',
          'data': _authResponseJson('tok-mob-3'),
        }),
        data: <String, dynamic>{
          'device_uuid': 'device-uuid-3',
        },
      );

      final client = GuestRegisterClient(p2x);
      final response = await client.guestRegister(deviceUuid: 'device-uuid-3');

      expect(response.token.accessToken, 'tok-mob-3');
    });

    test(
        'same device_uuid called twice resolves to the same user_id '
        '(server-side idempotency via Idempotency-Key)', () async {
      // We mock the server side to return the same user both times for the
      // same device_uuid. The actual idempotency contract is enforced by
      // the (future) IdempotencyInterceptor + the server's Redis cache.
      final p2x = P2xClient(
        config: const P2xClientConfig(
          baseUrl: 'https://api.project20x.com/api',
        ),
      );
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/v1/integrations/mob/guest-register',
        (req) => req.reply(201, <String, dynamic>{
          'success': true,
          'message': 'created',
          'data': _authResponseJson('tok-stable', userId: 123),
        }),
        data: <String, dynamic>{
          'device_uuid': 'stable-uuid',
        },
      );

      final client = GuestRegisterClient(p2x);
      final first = await client.guestRegister(deviceUuid: 'stable-uuid');
      final second = await client.guestRegister(deviceUuid: 'stable-uuid');

      expect(first.user.id, second.user.id);
      expect(first.user.id, 123);
    });
  });
}
