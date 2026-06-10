// Round-trip tests for PasswordSignInResponse — confirm JSON decoding handles
// both camelCase and snake_case variants, and that toAuthResponse() builds a
// well-shaped AuthResponse.

import 'package:flutter_test/flutter_test.dart';
import 'package:ycaas_flutter_sdk/src/auth/password_swap_models.dart';

void main() {
  group('PasswordSignInResponse.fromJson', () {
    test('decodes the canonical camelCase shape', () {
      final r = PasswordSignInResponse.fromJson(<String, dynamic>{
        'accessToken': 'tok-1',
        'id': 1,
        'username': 'a@b.com',
        'full_name': 'Alpha',
        'roles': <String>['user'],
        'permissions': <String>['subproject:1'],
        'email_verified_at': '2026-02-01T00:00:00Z',
        'force_password_reset': false,
      });
      expect(r.accessToken, 'tok-1');
      expect(r.id, 1);
      expect(r.username, 'a@b.com');
      expect(r.fullName, 'Alpha');
      expect(r.roles, <String>['user']);
      expect(r.permissions, <String>['subproject:1']);
      expect(r.emailVerifiedAt?.year, 2026);
      expect(r.forcePasswordReset, isFalse);
    });

    test('decodes the snake_case access_token fallback', () {
      final r = PasswordSignInResponse.fromJson(<String, dynamic>{
        'access_token': 'tok-snake',
        'id': 2,
        'username': 'snake@b.com',
        'full_name': 'Snake',
        'roles': <String>[],
        'permissions': <String>[],
      });
      expect(r.accessToken, 'tok-snake');
      expect(r.emailVerifiedAt, isNull);
      expect(r.forcePasswordReset, isFalse);
    });

    test('tolerates empty full_name and missing permissions', () {
      final r = PasswordSignInResponse.fromJson(<String, dynamic>{
        'accessToken': 'tok-empty',
        'id': 3,
        'username': 'empty@b.com',
        'full_name': '',
        'roles': <String>['x'],
      });
      expect(r.fullName, '');
      expect(r.permissions, isEmpty);
    });
  });

  group('PasswordSignInResponse.toAuthResponse', () {
    test('falls back to username when fullName is empty', () {
      final r = PasswordSignInResponse(
        accessToken: 't',
        id: 4,
        username: 'fallback@b.com',
        fullName: '',
        roles: const <String>['user'],
        permissions: const <String>[],
      );
      final a = r.toAuthResponse();
      expect(a.user.name, 'fallback@b.com');
      expect(a.user.email, 'fallback@b.com');
    });

    test('uses fullName when present', () {
      final r = PasswordSignInResponse(
        accessToken: 't',
        id: 5,
        username: 'present@b.com',
        fullName: 'Present Person',
        roles: const <String>['admin'],
        permissions: const <String>[],
      );
      expect(r.toAuthResponse().user.name, 'Present Person');
    });
  });

  test('toJson + fromJson round-trips (canonical fields)', () {
    final original = PasswordSignInResponse(
      accessToken: 't-rt',
      id: 6,
      username: 'rt@b.com',
      fullName: 'RT',
      roles: const <String>['user'],
      permissions: const <String>['subproject:1'],
      emailVerifiedAt: DateTime.utc(2026, 3, 4),
      forcePasswordReset: true,
    );
    final json = original.toJson();
    final round = PasswordSignInResponse.fromJson(json);
    expect(round, original);
  });
}
