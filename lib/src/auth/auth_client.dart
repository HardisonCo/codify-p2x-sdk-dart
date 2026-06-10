import 'package:ycaas_flutter_sdk/src/auth/auth_models.dart';
import 'package:ycaas_flutter_sdk/src/client/interceptors/auth_interceptor.dart';
import 'package:ycaas_flutter_sdk/src/client/p2x_client.dart';
import 'package:dio/dio.dart';

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

  /// POST `/auth/sign-up` — register a brand-new P2X user with
  /// email + password.
  ///
  /// Unauthenticated — no Bearer header is sent (the SDK's
  /// `AuthInterceptor` honours the `skip_auth` extra). Idempotent — the
  /// SDK's `IdempotencyInterceptor` adds the `Idempotency-Key` header
  /// automatically, so a retry after a transient network failure
  /// will not double-create the account.
  ///
  /// [referralCode] is forwarded to the server as `referral_code` when
  /// provided.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String name,
    String? referralCode,
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/auth/sign-up',
        data: <String, dynamic>{
          'email': email,
          'password': password,
          'name': name,
          if (referralCode != null) 'referral_code': referralCode,
        },
        options: _unauthenticatedOptions(),
      );
      return _unwrapAuthResponse(response.data);
    });
  }

  /// POST `/auth/password/reset` — request a password-reset link be
  /// emailed to [email].
  ///
  /// Unauthenticated. The response carries no useful data — completes
  /// once the server has accepted the request and (typically) queued
  /// the email send.
  Future<void> resetPassword({required String email}) {
    return _client.request(() async {
      await _client.dio.post<Map<String, dynamic>>(
        '/auth/password/reset',
        data: <String, dynamic>{
          'email': email,
        },
        options: _unauthenticatedOptions(),
      );
    });
  }

  /// POST `/auth/new-password` — complete the password-reset flow with
  /// the [token] from the email link and the new [password] / matching
  /// [passwordConfirmation].
  ///
  /// Unauthenticated.
  Future<void> newPassword({
    required String token,
    required String password,
    required String passwordConfirmation,
  }) {
    return _client.request(() async {
      await _client.dio.post<Map<String, dynamic>>(
        '/auth/new-password',
        data: <String, dynamic>{
          'token': token,
          'password': password,
          'password_confirmation': passwordConfirmation,
        },
        options: _unauthenticatedOptions(),
      );
    });
  }

  /// POST `/auth/finish-social-registration` — finalize signup for a
  /// social-login user (Google / Apple Sign-In). Called after the
  /// client-side OAuth flow yields a [token] and the user has confirmed
  /// the [email] / display [name] they want to register with.
  ///
  /// [provider] is the social provider id — `google`, `apple`, etc.
  ///
  /// Unauthenticated.
  Future<AuthResponse> finishSocialRegistration({
    required String provider,
    required String token,
    required String email,
    required String name,
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/auth/finish-social-registration',
        data: <String, dynamic>{
          'provider': provider,
          'token': token,
          'email': email,
          'name': name,
        },
        options: _unauthenticatedOptions(),
      );
      return _unwrapAuthResponse(response.data);
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

  /// Build a Dio [Options] object that opts the request out of the
  /// SDK's auth header injection via the [AuthInterceptor.skipAuthExtra]
  /// marker.
  Options _unauthenticatedOptions() {
    return Options(
      extra: <String, dynamic>{
        AuthInterceptor.skipAuthExtra: true,
      },
    );
  }
}
