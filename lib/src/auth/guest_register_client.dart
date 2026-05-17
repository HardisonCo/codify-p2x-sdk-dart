import 'package:codify_p2x_sdk/src/auth/auth_models.dart';
import 'package:codify_p2x_sdk/src/client/p2x_client.dart';

/// Auth client for the MOB anonymous guest-registration endpoint.
///
/// MOB doesn't ask users to sign up before they explore the app — at first
/// launch the app generates a stable device UUID, calls
/// `/v1/integrations/mob/guest-register`, and uses the returned Sanctum
/// bearer for every subsequent call. Repeating the call with the same
/// `device_uuid` is idempotent and returns the same P2X user.
class GuestRegisterClient {
  /// Construct against an existing [P2xClient].
  GuestRegisterClient(this._client);

  final P2xClient _client;

  /// POST `/v1/integrations/mob/guest-register`.
  ///
  /// Creates (or fetches, if already federated) an anonymous P2X user tied
  /// to [deviceUuid]. The optional [platform] (`ios`, `android`, `web`) and
  /// [appVersion] are attached to the user record for analytics.
  ///
  /// The server enforces idempotency via the `Idempotency-Key` header on
  /// the wire — the (future) IdempotencyInterceptor in the SDK adds that
  /// automatically for writes.
  Future<AuthResponse> guestRegister({
    required String deviceUuid,
    String? platform,
    String? appVersion,
  }) {
    return _client.request(() async {
      final body = <String, dynamic>{
        'device_uuid': deviceUuid,
        if (platform != null) 'platform': platform,
        if (appVersion != null) 'app_version': appVersion,
      };

      final response = await _client.dio.post<Map<String, dynamic>>(
        '/v1/integrations/mob/guest-register',
        data: body,
      );

      final responseBody = response.data;
      if (responseBody == null) {
        throw StateError('Empty body from guest-register');
      }
      final data = responseBody['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError('Malformed guest-register response — missing "data"');
      }
      return AuthResponse.fromJson(data);
    });
  }
}
