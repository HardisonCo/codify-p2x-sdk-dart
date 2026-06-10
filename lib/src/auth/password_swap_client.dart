import 'package:dio/dio.dart';

import '../client/interceptors/auth_interceptor.dart';
import '../client/p2x_client.dart';
import 'auth_models.dart';
import 'password_swap_models.dart';

/// Auth client for the standard email/password sign-in endpoint —
/// `POST /public/auth/sign-in`.
///
/// Used by consumer apps that don't have a Firebase Auth dependency (PHM
/// patient + doctor) and instead authenticate directly against P2X with
/// email + password. Mirrors [FirebaseSwapClient]'s contract: returns an
/// [AuthResponse] suitable for the host app's existing post-login plumbing.
///
/// The endpoint returns **422** (not 401) on bad credentials to prevent
/// email enumeration. Callers should catch [ValidationException] and treat
/// it as "invalid credentials" — the `errors` map will contain entries for
/// `login` and/or `password`. There is no separate "user not found" signal.
class PasswordSwapClient {
  /// Construct against an existing [P2xClient].
  PasswordSwapClient(this._client);

  final P2xClient _client;

  /// POST `/public/auth/sign-in` — exchange email/phone + password for a
  /// Sanctum bearer.
  ///
  /// [login] is the user's email or E.164 phone. [password] is the plaintext
  /// secret. [timezone] is the IANA timezone string the server records on
  /// the user's session (e.g. `America/Los_Angeles`); omitted when the host
  /// app doesn't have it yet.
  ///
  /// Returns the SDK-standard [AuthResponse] for parity with the other
  /// `*SwapClient`s. Use [signInRaw] if the host app needs `permissions[]`
  /// or `forcePasswordReset` — those fields are dropped on adaptation.
  Future<AuthResponse> signIn({
    required String login,
    required String password,
    String? timezone,
  }) async {
    final raw = await signInRaw(
      login: login,
      password: password,
      timezone: timezone,
    );
    return raw.toAuthResponse();
  }

  /// As [signIn] but returns the raw flat response so callers can read
  /// [PasswordSignInResponse.permissions] and
  /// [PasswordSignInResponse.forcePasswordReset]. Most apps want the
  /// envelope-shaped [signIn] instead.
  Future<PasswordSignInResponse> signInRaw({
    required String login,
    required String password,
    String? timezone,
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/public/auth/sign-in',
        data: <String, dynamic>{
          'login': login,
          'password': password,
          if (timezone != null) 'timezone': timezone,
        },
        options: _unauthenticatedOptions(),
      );

      final body = response.data;
      if (body == null) {
        throw StateError('Empty body from /public/auth/sign-in');
      }
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError('Malformed sign-in response — missing "data"');
      }
      return PasswordSignInResponse.fromJson(data);
    });
  }

  Options _unauthenticatedOptions() {
    return Options(
      extra: <String, dynamic>{
        AuthInterceptor.skipAuthExtra: true,
      },
    );
  }
}
