import 'package:ycaas_flutter_sdk/src/client/exceptions/api_exception.dart';
import 'package:ycaas_flutter_sdk/src/client/interceptors/auth_interceptor.dart';
import 'package:ycaas_flutter_sdk/src/client/interceptors/error_interceptor.dart';
import 'package:ycaas_flutter_sdk/src/client/interceptors/idempotency_interceptor.dart';
import 'package:ycaas_flutter_sdk/src/client/interceptors/method_override_interceptor.dart';
import 'package:ycaas_flutter_sdk/src/client/interceptors/subproject_interceptor.dart';
import 'package:ycaas_flutter_sdk/src/client/p2x_client_config.dart';
import 'package:dio/dio.dart';

/// The base HTTP client for the P2X SDK. Wraps a Dio instance with the
/// SDK-mandated interceptor stack (auth, subproject, method override,
/// idempotency, error normalization).
///
/// Per-domain clients (auth, assessments, kpi, etc.) hold a reference to a
/// [P2xClient] and delegate HTTP work to it. The host app typically
/// instantiates **one** P2xClient and reuses it.
///
/// Mirrors the TS SDK's `BaseApiClient` in `P2X/sdk/src/api-client.ts`.
///
/// ```dart
/// final p2x = P2xClient(
///   config: P2xClientConfig(
///     baseUrl: 'https://api.project20x.com/api',
///     getToken: () => tokenStorage.read(),
///     getDomain: () => 'nutriscan.codify.ai',
///   ),
/// );
/// ```
class P2xClient {
  /// Construct with the given [config] and an optional pre-built [dio]
  /// instance (mainly for tests — production callers should omit it).
  P2xClient({required P2xClientConfig config, Dio? dio})
      : _config = config,
        dio = dio ?? Dio() {
    _wireDio();
  }

  final P2xClientConfig _config;

  /// The underlying Dio instance.
  ///
  /// Exposed so per-domain clients in this SDK (`AuthClient`,
  /// `AssessmentsClient`, etc.) can issue HTTP requests with the full
  /// SDK interceptor stack applied. Tests use it via `http_mock_adapter`.
  ///
  /// **App code should not call `dio.get/post/etc.` directly** — use the
  /// per-domain client methods (`p2x.auth.login(...)`,
  /// `p2x.assessments.storeResponse(...)`, etc.) instead. Direct dio use
  /// bypasses the typed-exception unwrap that `request<T>` performs.
  final Dio dio;

  /// The active configuration. Read-only — to change auth or domain
  /// behaviour, swap the values returned by your `getToken` / `getDomain`
  /// closures rather than reconstructing the client.
  P2xClientConfig get config => _config;

  /// Run a Dio call and unwrap [ErrorInterceptor]-attached typed exceptions.
  ///
  /// Dio always re-wraps thrown errors in a `DioException` before bubbling
  /// to callers, so [ErrorInterceptor] stores the typed [ApiException] on
  /// `DioException.error` instead of throwing it directly. Per-domain clients
  /// route their HTTP work through this helper so consumers see the typed
  /// exception at the call site:
  ///
  /// ```dart
  /// try {
  ///   await p2x.auth.login(email: ..., password: ...);
  /// } on UnauthorizedException catch (e) {
  ///   // works — instead of unwrapping DioException.error manually
  /// } on ValidationException catch (e) {
  ///   // e.errors is Map<String, List<String>>
  /// }
  /// ```
  ///
  /// Callers that need to handle Dio-level concerns (cancellation,
  /// connection errors with no HTTP response, etc.) should catch
  /// [DioException] before [ApiException]. The helper rethrows the original
  /// [DioException] unchanged if [ErrorInterceptor] couldn't attach a typed
  /// exception (network errors, etc.).
  Future<T> request<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      final attached = e.error;
      if (attached is ApiException) {
        throw attached;
      }
      rethrow;
    }
  }

  void _wireDio() {
    dio.options.baseUrl = _config.baseUrl;
    dio.options.connectTimeout = _config.connectTimeout;
    dio.options.receiveTimeout = _config.receiveTimeout;
    dio.options.sendTimeout = _config.sendTimeout;
    dio.options.headers = <String, dynamic>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ..._config.extraHeaders,
    };

    // Interceptor order matters:
    //   1. Auth — adds Authorization header
    //   2. Subproject — adds X-Domain header
    //   3. MethodOverride — translates PUT/PATCH to POST + _method
    //   4. Idempotency — adds Idempotency-Key for writes
    //   5. Error — normalizes 4xx/5xx into typed ApiExceptions
    //
    // ErrorInterceptor MUST be registered last so the typed exception
    // mapping sees errors after upstream interceptors have had their chance
    // (e.g. to retry, refresh tokens, etc. in future).
    dio.interceptors
      ..add(AuthInterceptor(_config))
      ..add(SubprojectInterceptor(_config))
      ..add(MethodOverrideInterceptor())
      ..add(IdempotencyInterceptor())
      ..add(ErrorInterceptor(_config));
  }
}
