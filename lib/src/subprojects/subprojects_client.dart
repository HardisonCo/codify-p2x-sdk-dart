import 'package:ycaas_flutter_sdk/src/client/p2x_client.dart';
import 'package:ycaas_flutter_sdk/src/subprojects/subprojects_models.dart';

/// Per-domain client for the `subprojects` and `settings` modules.
///
/// The two endpoints exposed here let a client app resolve **which**
/// subproject it's running under (via the `X-Domain` header) and **what**
/// it's allowed to do (feature flags). Both are typically called once at
/// boot and cached.
///
/// ```dart
/// final subprojects = SubprojectsClient(p2x);
/// final me = await subprojects.current();
/// final feats = await subprojects.features();
/// if (feats.isEnabled('nio_premium')) {
///   // show premium UI
/// }
/// ```
class SubprojectsClient {
  /// Construct with a reference to the shared [P2xClient]. The client uses
  /// [P2xClient.dio] for HTTP work and inherits the SDK interceptor stack.
  SubprojectsClient(this._client);

  final P2xClient _client;

  /// `GET /api/v1/subprojects/current` — resolves the active subproject
  /// based on the `X-Domain` header injected by the SDK.
  ///
  /// Throws an `ApiException` (via the SDK error interceptor) if the
  /// server returns a non-2xx — typically 404 when the `X-Domain` value
  /// doesn't match any registered subproject.
  Future<Subproject> current() {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/v1/subprojects/current',
      );
      final body = response.data ?? const <String, dynamic>{};
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError(
          'GET /v1/subprojects/current returned no "data" object.',
        );
      }
      return Subproject.fromJson(data);
    });
  }

  /// `GET /api/v1/settings/features` — returns the per-subproject
  /// feature flag map. Consumed by the `gov` middleware for capability
  /// gating; clients use it for UI gating.
  Future<SubprojectFeatures> features() {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/v1/settings/features',
      );
      final body = response.data ?? const <String, dynamic>{};
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        return const SubprojectFeatures(flags: <String, bool>{});
      }
      return SubprojectFeatures.fromJson(data);
    });
  }
}
