import 'package:ycaas_flutter_sdk/src/auth/auth_models.dart';
import 'package:ycaas_flutter_sdk/src/client/p2x_client.dart';

/// Auth client for the NIO Firebase-token swap endpoint.
///
/// NIO authenticates users on-device with Firebase Auth, then exchanges the
/// short-lived Firebase ID token for a long-lived Sanctum bearer that the
/// P2X API understands. The first call for a given Firebase UID also
/// federates the user — creating the P2X-side record and linking it via
/// `external_user_links`.
///
/// This is intentionally a separate client from `AuthClient` because the
/// endpoint sits under `/api/v1/integrations/nio/` and follows the
/// Idempotency-Key contract for federated writes.
class FirebaseSwapClient {
  /// Construct against an existing [P2xClient].
  FirebaseSwapClient(this._client);

  final P2xClient _client;

  /// POST `/v1/integrations/nio/firebase-login`.
  ///
  /// Verifies the [firebaseIdToken] server-side via the Firebase Admin SDK,
  /// then returns an [AuthResponse] with the matching P2X user and a fresh
  /// Sanctum bearer. Used by NIO at app boot.
  Future<AuthResponse> firebaseLogin({required String firebaseIdToken}) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/v1/integrations/nio/firebase-login',
        data: <String, dynamic>{
          'firebase_id_token': firebaseIdToken,
        },
      );

      final body = response.data;
      if (body == null) {
        throw StateError('Empty body from firebase-login');
      }
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError('Malformed firebase-login response — missing "data"');
      }
      return AuthResponse.fromJson(data);
    });
  }
}
