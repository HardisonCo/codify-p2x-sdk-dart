// Tests for the auth model classes — User, Token, Subproject, AuthResponse.
//
// These are plain @immutable data classes (no freezed for this round). The
// tests assert JSON round-trips, copyWith semantics, value-equality, and
// safe toString (no token leakage).

import 'package:ycaas_flutter_sdk/src/auth/auth_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('User', () {
    test('fromJson handles required fields (id, name, email, roles)', () {
      final user = User.fromJson(<String, dynamic>{
        'id': 42,
        'name': 'Alice',
        'email': 'alice@example.com',
        'roles': <String>['admin'],
      });

      expect(user.id, 42);
      expect(user.name, 'Alice');
      expect(user.email, 'alice@example.com');
      expect(user.roles, <String>['admin']);
      expect(user.phone, isNull);
      expect(user.subprojectId, isNull);
      expect(user.subprojectDomain, isNull);
      expect(user.createdAt, isNull);
      expect(user.updatedAt, isNull);
      expect(user.emailVerifiedAt, isNull);
      expect(user.phoneVerifiedAt, isNull);
    });

    test('fromJson handles all optional fields', () {
      final user = User.fromJson(<String, dynamic>{
        'id': 7,
        'name': 'Bob',
        'email': 'bob@example.com',
        'phone': '+15551234567',
        'roles': <String>['doctor', 'admin'],
        'subproject_id': 3,
        'subproject_domain': 'crohnie.ai',
        'created_at': '2026-01-01T12:00:00Z',
        'updated_at': '2026-02-01T13:00:00Z',
        'email_verified_at': '2026-01-02T00:00:00Z',
        'phone_verified_at': '2026-01-03T00:00:00Z',
      });

      expect(user.id, 7);
      expect(user.phone, '+15551234567');
      expect(user.roles, <String>['doctor', 'admin']);
      expect(user.subprojectId, 3);
      expect(user.subprojectDomain, 'crohnie.ai');
      expect(user.createdAt, DateTime.parse('2026-01-01T12:00:00Z'));
      expect(user.updatedAt, DateTime.parse('2026-02-01T13:00:00Z'));
      expect(user.emailVerifiedAt, DateTime.parse('2026-01-02T00:00:00Z'));
      expect(user.phoneVerifiedAt, DateTime.parse('2026-01-03T00:00:00Z'));
    });

    test('fromJson defaults roles to empty list when absent', () {
      final user = User.fromJson(<String, dynamic>{
        'id': 1,
        'name': 'X',
        'email': 'x@y.z',
      });
      expect(user.roles, <String>[]);
    });

    test('toJson round-trips back to fromJson identity', () {
      final original = User(
        id: 11,
        name: 'Carol',
        email: 'carol@example.com',
        phone: '+15550001111',
        roles: const <String>['patient'],
        subprojectId: 9,
        subprojectDomain: 'crohnie.ai',
        createdAt: DateTime.parse('2026-03-04T05:06:07Z'),
        updatedAt: DateTime.parse('2026-03-04T05:06:08Z'),
        emailVerifiedAt: DateTime.parse('2026-03-04T05:06:09Z'),
        phoneVerifiedAt: DateTime.parse('2026-03-04T05:06:10Z'),
      );

      final round = User.fromJson(original.toJson());

      expect(round, equals(original));
      expect(round.hashCode, equals(original.hashCode));
    });

    test('copyWith with no args returns equal instance', () {
      const user = User(
        id: 1,
        name: 'A',
        email: 'a@b.c',
        roles: <String>['admin'],
      );

      expect(user.copyWith(), equals(user));
    });

    test('copyWith with one arg returns instance differing only by that field',
        () {
      const user = User(
        id: 1,
        name: 'A',
        email: 'a@b.c',
        roles: <String>['admin'],
      );
      final updated = user.copyWith(name: 'B');

      expect(updated.name, 'B');
      expect(updated.id, user.id);
      expect(updated.email, user.email);
      expect(updated.roles, user.roles);
      expect(updated, isNot(equals(user)));
    });

    test('two equal instances are == and have equal hashCode', () {
      const a = User(
        id: 1,
        name: 'A',
        email: 'a@b.c',
        roles: <String>['admin'],
      );
      const b = User(
        id: 1,
        name: 'A',
        email: 'a@b.c',
        roles: <String>['admin'],
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString includes class name and key fields', () {
      const user = User(
        id: 42,
        name: 'Alice',
        email: 'alice@example.com',
        roles: <String>['admin'],
      );

      final s = user.toString();
      expect(s, contains('User'));
      expect(s, contains('42'));
      expect(s, contains('Alice'));
      expect(s, contains('alice@example.com'));
    });
  });

  group('Token', () {
    test('fromJson handles all fields', () {
      final token = Token.fromJson(<String, dynamic>{
        'access_token': 'abc123',
        'refresh_token': 'r-xyz',
        'expires_at': '2026-05-01T00:00:00Z',
        'token_type': 'Bearer',
      });

      expect(token.accessToken, 'abc123');
      expect(token.refreshToken, 'r-xyz');
      expect(token.expiresAt, DateTime.parse('2026-05-01T00:00:00Z'));
      expect(token.tokenType, 'Bearer');
    });

    test('fromJson handles missing refreshToken and expiresAt', () {
      final token = Token.fromJson(<String, dynamic>{
        'access_token': 'abc123',
      });

      expect(token.accessToken, 'abc123');
      expect(token.refreshToken, isNull);
      expect(token.expiresAt, isNull);
      expect(token.tokenType, 'Bearer'); // default
    });

    test('toJson round-trips back to fromJson identity', () {
      final original = Token(
        accessToken: 'tok',
        refreshToken: 'r',
        expiresAt: DateTime.parse('2026-12-31T23:59:59Z'),
      );

      final round = Token.fromJson(original.toJson());

      expect(round, equals(original));
      expect(round.hashCode, equals(original.hashCode));
    });

    test('copyWith with no args returns equal instance', () {
      const token = Token(accessToken: 'x');
      expect(token.copyWith(), equals(token));
    });

    test('copyWith updates a single field', () {
      const token = Token(accessToken: 'x');
      final updated = token.copyWith(refreshToken: 'r');
      expect(updated.refreshToken, 'r');
      expect(updated.accessToken, 'x');
      expect(updated, isNot(equals(token)));
    });

    test('equality and hashCode', () {
      const a = Token(accessToken: 'x');
      const b = Token(accessToken: 'x');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString does NOT leak full access token', () {
      const token = Token(accessToken: 'super-secret-bearer-token-value-12345');
      final s = token.toString();
      expect(s, contains('Token'));
      // Should not include the raw token value.
      expect(s, isNot(contains('super-secret-bearer-token-value-12345')));
    });
  });

  group('Subproject', () {
    test('fromJson handles required + optional fields', () {
      final sp = Subproject.fromJson(<String, dynamic>{
        'id': 2,
        'slug': 'crohnie',
        'name': 'Crohnie AI',
        'domain': 'crohnie.ai',
        'kind': 'health-system',
      });

      expect(sp.id, 2);
      expect(sp.slug, 'crohnie');
      expect(sp.name, 'Crohnie AI');
      expect(sp.domain, 'crohnie.ai');
      expect(sp.kind, 'health-system');
    });

    test('fromJson handles missing kind', () {
      final sp = Subproject.fromJson(<String, dynamic>{
        'id': 2,
        'slug': 'crohnie',
        'name': 'Crohnie AI',
        'domain': 'crohnie.ai',
      });

      expect(sp.kind, isNull);
    });

    test('toJson round-trips', () {
      const original = Subproject(
        id: 2,
        slug: 'crohnie',
        name: 'Crohnie AI',
        domain: 'crohnie.ai',
        kind: 'health-system',
      );
      final round = Subproject.fromJson(original.toJson());
      expect(round, equals(original));
      expect(round.hashCode, equals(original.hashCode));
    });

    test('copyWith with no args returns equal instance', () {
      const sp = Subproject(
        id: 2,
        slug: 'crohnie',
        name: 'Crohnie AI',
        domain: 'crohnie.ai',
      );
      expect(sp.copyWith(), equals(sp));
    });

    test('toString includes class name', () {
      const sp = Subproject(
        id: 2,
        slug: 'crohnie',
        name: 'Crohnie AI',
        domain: 'crohnie.ai',
      );
      expect(sp.toString(), contains('Subproject'));
      expect(sp.toString(), contains('crohnie'));
    });
  });

  group('AuthResponse', () {
    test('fromJson nests User and Token + optional Subproject', () {
      final auth = AuthResponse.fromJson(<String, dynamic>{
        'user': <String, dynamic>{
          'id': 1,
          'name': 'Alice',
          'email': 'a@b.c',
          'roles': <String>['admin'],
        },
        'token': <String, dynamic>{
          'access_token': 'tok',
        },
        'subproject': <String, dynamic>{
          'id': 2,
          'slug': 'crohnie',
          'name': 'Crohnie AI',
          'domain': 'crohnie.ai',
        },
      });

      expect(auth.user.id, 1);
      expect(auth.user.email, 'a@b.c');
      expect(auth.token.accessToken, 'tok');
      expect(auth.subproject, isNotNull);
      expect(auth.subproject!.slug, 'crohnie');
    });

    test('fromJson handles missing subproject', () {
      final auth = AuthResponse.fromJson(<String, dynamic>{
        'user': <String, dynamic>{
          'id': 1,
          'name': 'Alice',
          'email': 'a@b.c',
          'roles': <String>['admin'],
        },
        'token': <String, dynamic>{
          'access_token': 'tok',
        },
      });

      expect(auth.subproject, isNull);
    });

    test('toJson round-trips', () {
      const original = AuthResponse(
        user: User(
          id: 1,
          name: 'Alice',
          email: 'a@b.c',
          roles: <String>['admin'],
        ),
        token: Token(accessToken: 'tok'),
        subproject: Subproject(
          id: 2,
          slug: 'crohnie',
          name: 'Crohnie AI',
          domain: 'crohnie.ai',
        ),
      );

      final round = AuthResponse.fromJson(original.toJson());
      expect(round, equals(original));
      expect(round.hashCode, equals(original.hashCode));
    });

    test('copyWith with no args returns equal instance', () {
      const auth = AuthResponse(
        user: User(
          id: 1,
          name: 'Alice',
          email: 'a@b.c',
          roles: <String>['admin'],
        ),
        token: Token(accessToken: 'tok'),
      );
      expect(auth.copyWith(), equals(auth));
    });

    test('toString includes class name and does not leak token', () {
      const auth = AuthResponse(
        user: User(
          id: 1,
          name: 'Alice',
          email: 'a@b.c',
          roles: <String>['admin'],
        ),
        token: Token(accessToken: 'super-secret-bearer-token-value-12345'),
      );

      final s = auth.toString();
      expect(s, contains('AuthResponse'));
      expect(s, isNot(contains('super-secret-bearer-token-value-12345')));
    });
  });
}
