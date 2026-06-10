import 'package:ycaas_flutter_sdk/src/auth/auth_models.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the Sanctum bearer token (and optional refresh token + expiry)
/// to platform-secure storage — iOS Keychain, Android
/// EncryptedSharedPreferences, macOS Keychain, etc.
///
/// The SDK doesn't wire this into `P2xClientConfig.getToken` for you — host
/// apps decide when to read/write. A typical pattern:
///
/// ```dart
/// final tokenStorage = TokenStorage();
/// final p2x = P2xClient(
///   config: P2xClientConfig(
///     baseUrl: '...',
///     getToken: () => _cachedToken?.accessToken,
///   ),
/// );
///
/// // On boot:
/// _cachedToken = await tokenStorage.readToken();
///
/// // After login:
/// await tokenStorage.writeToken(authResponse.token);
/// _cachedToken = authResponse.token;
/// ```
///
/// Pass a custom [FlutterSecureStorage] via the constructor for tests or
/// to override platform options (e.g. iOS Keychain access groups).
class TokenStorage {
  /// Construct.
  ///
  /// In production omit [storage] and a default [FlutterSecureStorage] is
  /// used. In tests inject a mock.
  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  /// Storage key for the access token.
  static const String _accessTokenKey = 'codify_p2x_access_token';

  /// Storage key for the optional refresh token.
  static const String _refreshTokenKey = 'codify_p2x_refresh_token';

  /// Storage key for the optional ISO-8601 expiry.
  static const String _expiresAtKey = 'codify_p2x_token_expires_at';

  /// Persist the given [token]. Optional fields that are `null` clear any
  /// previously stored value at the corresponding key (so swapping a
  /// long-expiry token for a no-expiry one won't leave stale state).
  Future<void> writeToken(Token token) async {
    await _storage.write(key: _accessTokenKey, value: token.accessToken);

    if (token.refreshToken != null) {
      await _storage.write(key: _refreshTokenKey, value: token.refreshToken);
    } else {
      await _storage.delete(key: _refreshTokenKey);
    }

    if (token.expiresAt != null) {
      await _storage.write(
        key: _expiresAtKey,
        value: token.expiresAt!.toIso8601String(),
      );
    } else {
      await _storage.delete(key: _expiresAtKey);
    }
  }

  /// Read the persisted token, or `null` if no access token is present.
  ///
  /// If the access token is present but other fields are missing the
  /// returned [Token] will have `null` for those fields (e.g. a fresh login
  /// before a refresh token has ever been issued).
  Future<Token?> readToken() async {
    final accessToken = await _storage.read(key: _accessTokenKey);
    if (accessToken == null || accessToken.isEmpty) return null;

    final refreshToken = await _storage.read(key: _refreshTokenKey);
    final expiresAtRaw = await _storage.read(key: _expiresAtKey);
    final expiresAt = (expiresAtRaw != null && expiresAtRaw.isNotEmpty)
        ? DateTime.tryParse(expiresAtRaw)
        : null;

    return Token(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
    );
  }

  /// Delete the persisted token (all three keys). Call on logout.
  Future<void> clearToken() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _expiresAtKey);
  }

  /// Returns `true` only when a non-empty access token is on disk.
  Future<bool> hasToken() async {
    final accessToken = await _storage.read(key: _accessTokenKey);
    return accessToken != null && accessToken.isNotEmpty;
  }
}
