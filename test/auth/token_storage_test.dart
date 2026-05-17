// Tests for TokenStorage. Uses mocktail to mock FlutterSecureStorage so
// the tests don't touch the platform keychain.

import 'package:codify_p2x_sdk/src/auth/auth_models.dart';
import 'package:codify_p2x_sdk/src/auth/token_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late _MockSecureStorage storage;
  late TokenStorage tokenStorage;

  setUp(() {
    storage = _MockSecureStorage();
    tokenStorage = TokenStorage(storage: storage);

    // Default stubs — individual tests override as needed.
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => storage.delete(key: any(named: 'key')),
    ).thenAnswer((_) async {});
  });

  group('TokenStorage.writeToken', () {
    test('writes accessToken under codify_p2x_access_token', () async {
      await tokenStorage.writeToken(const Token(accessToken: 'abc'));

      verify(
        () => storage.write(
          key: 'codify_p2x_access_token',
          value: 'abc',
        ),
      ).called(1);
    });

    test('writes refreshToken under codify_p2x_refresh_token when present',
        () async {
      await tokenStorage.writeToken(
        const Token(accessToken: 'abc', refreshToken: 'r-1'),
      );

      verify(
        () => storage.write(
          key: 'codify_p2x_refresh_token',
          value: 'r-1',
        ),
      ).called(1);
    });

    test(
        'writes expiresAt under codify_p2x_token_expires_at as ISO-8601 string '
        'when present', () async {
      final at = DateTime.parse('2026-12-31T00:00:00Z');
      await tokenStorage.writeToken(
        Token(accessToken: 'abc', expiresAt: at),
      );

      verify(
        () => storage.write(
          key: 'codify_p2x_token_expires_at',
          value: at.toIso8601String(),
        ),
      ).called(1);
    });

    test('clears refreshToken slot when token has no refresh token', () async {
      await tokenStorage.writeToken(const Token(accessToken: 'abc'));

      verify(
        () => storage.delete(key: 'codify_p2x_refresh_token'),
      ).called(1);
    });

    test('clears expiresAt slot when token has no expiry', () async {
      await tokenStorage.writeToken(const Token(accessToken: 'abc'));

      verify(
        () => storage.delete(key: 'codify_p2x_token_expires_at'),
      ).called(1);
    });
  });

  group('TokenStorage.readToken', () {
    test('returns null when accessToken key is absent', () async {
      when(() => storage.read(key: 'codify_p2x_access_token'))
          .thenAnswer((_) async => null);
      when(() => storage.read(key: 'codify_p2x_refresh_token'))
          .thenAnswer((_) async => null);
      when(() => storage.read(key: 'codify_p2x_token_expires_at'))
          .thenAnswer((_) async => null);

      final token = await tokenStorage.readToken();

      expect(token, isNull);
    });

    test('reconstructs Token with all fields present', () async {
      final at = DateTime.parse('2026-12-31T00:00:00Z');
      when(() => storage.read(key: 'codify_p2x_access_token'))
          .thenAnswer((_) async => 'abc');
      when(() => storage.read(key: 'codify_p2x_refresh_token'))
          .thenAnswer((_) async => 'r-1');
      when(() => storage.read(key: 'codify_p2x_token_expires_at'))
          .thenAnswer((_) async => at.toIso8601String());

      final token = await tokenStorage.readToken();

      expect(token, isNotNull);
      expect(token!.accessToken, 'abc');
      expect(token.refreshToken, 'r-1');
      expect(token.expiresAt, at);
    });

    test('handles partial state — access present, refresh absent', () async {
      when(() => storage.read(key: 'codify_p2x_access_token'))
          .thenAnswer((_) async => 'abc');
      when(() => storage.read(key: 'codify_p2x_refresh_token'))
          .thenAnswer((_) async => null);
      when(() => storage.read(key: 'codify_p2x_token_expires_at'))
          .thenAnswer((_) async => null);

      final token = await tokenStorage.readToken();

      expect(token, isNotNull);
      expect(token!.accessToken, 'abc');
      expect(token.refreshToken, isNull);
      expect(token.expiresAt, isNull);
    });
  });

  group('TokenStorage.clearToken', () {
    test('deletes all three keys', () async {
      await tokenStorage.clearToken();

      verify(() => storage.delete(key: 'codify_p2x_access_token')).called(1);
      verify(() => storage.delete(key: 'codify_p2x_refresh_token')).called(1);
      verify(
        () => storage.delete(key: 'codify_p2x_token_expires_at'),
      ).called(1);
    });
  });

  group('TokenStorage.hasToken', () {
    test('returns true when accessToken is non-null and non-empty', () async {
      when(() => storage.read(key: 'codify_p2x_access_token'))
          .thenAnswer((_) async => 'abc');

      expect(await tokenStorage.hasToken(), isTrue);
    });

    test('returns false when accessToken is null', () async {
      when(() => storage.read(key: 'codify_p2x_access_token'))
          .thenAnswer((_) async => null);

      expect(await tokenStorage.hasToken(), isFalse);
    });

    test('returns false when accessToken is empty string', () async {
      when(() => storage.read(key: 'codify_p2x_access_token'))
          .thenAnswer((_) async => '');

      expect(await tokenStorage.hasToken(), isFalse);
    });
  });
}
