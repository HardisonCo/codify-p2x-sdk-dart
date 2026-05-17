import 'package:codify_p2x_sdk/src/auth/auth_models.dart';
import 'package:codify_p2x_sdk/src/client/p2x_client.dart';

/// Auth-domain client for the standard P2X email/password flow.
///
/// Wraps the dashboard login, logout, session-hydrate (`/user/get-data`),
/// and optional refresh endpoints. The host app holds the resulting bearer
/// (typically via `TokenStorage`) and surfaces it back to [P2xClient] through
/// the `getToken` closure.
class AuthClient {
  /// Construct against an existing [P2xClient].
  AuthClient(this._client);

  final P2xClient _client;

  /// POST `/dashboard/login` — used by the gov-side admin login flow.
  ///
  /// Returns an [AuthResponse] with the Sanctum bearer token and the
  /// authenticated user's profile.
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/dashboard/login',
        data: <String, dynamic>{
          'email': email,
          'password': password,
        },
      );
      return _unwrapAuthResponse(response.data);
    });
  }

  /// POST `/logout` (authenticated) — invalidates the current bearer.
  ///
  /// Returns once the server acknowledges. The host app is responsible for
  /// also clearing local token storage and any in-memory session state.
  Future<void> logout() {
    return _client.request(() async {
      await _client.dio.post<Map<String, dynamic>>('/logout');
    });
  }

  /// GET `/user/get-data` (authenticated) — returns the current user plus
  /// active subproject context.
  ///
  /// Used after login (or app boot, when a persisted token is found) to
  /// rehydrate session state before navigating into protected screens.
  Future<AuthResponse> me() {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/user/get-data',
      );
      return _unwrapAuthResponse(response.data);
    });
  }

  /// POST `/auth/refresh` (authenticated) — optional refresh endpoint.
  ///
  /// Many Sanctum setups don't issue refresh tokens at all; in that case
  /// this method throws (typically a `NotFoundException` once the error
  /// interceptor is wired). Callers should handle that as "refresh not
  /// supported, force re-login on 401".
  Future<Token> refresh() {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/auth/refresh',
      );

      final body = response.data;
      if (body == null) {
        throw StateError('Empty body from /auth/refresh');
      }
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError('Malformed /auth/refresh response — missing "data"');
      }
      return Token.fromJson(data);
    });
  }

  AuthResponse _unwrapAuthResponse(Map<String, dynamic>? body) {
    if (body == null) {
      throw StateError('Empty body from auth endpoint');
    }
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw StateError('Malformed auth response — missing "data" object');
    }
    return AuthResponse.fromJson(data);
  }
}
