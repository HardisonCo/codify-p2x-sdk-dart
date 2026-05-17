import 'package:codify_p2x_sdk/src/client/exceptions/api_exception.dart';
import 'package:codify_p2x_sdk/src/client/exceptions/forbidden_exception.dart';
import 'package:codify_p2x_sdk/src/client/exceptions/not_found_exception.dart';
import 'package:codify_p2x_sdk/src/client/exceptions/server_exception.dart';
import 'package:codify_p2x_sdk/src/client/exceptions/unauthorized_exception.dart';
import 'package:codify_p2x_sdk/src/client/exceptions/validation_exception.dart';
import 'package:codify_p2x_sdk/src/client/p2x_client_config.dart';
import 'package:dio/dio.dart';

/// Dio interceptor that normalises Dio's generic [DioException] into the
/// SDK's typed exception hierarchy ([UnauthorizedException],
/// [ForbiddenException], [NotFoundException], [ValidationException],
/// [ServerException], or the base [ApiException]) and fires the
/// `onUnauthorized` / `onValidationError` callbacks from [P2xClientConfig].
///
/// This interceptor **must be registered last** in the Dio chain so it
/// sees errors after all upstream interceptors have had their chance.
///
/// Consumer code:
/// ```dart
/// try {
///   await p2x.assessments.storeResponse(...);
/// } on ValidationException catch (e) {
///   // e.errors is Map<String, List<String>>
/// } on UnauthorizedException {
///   // already handled by callback
/// } on ApiException catch (e) {
///   // catch-all for the SDK's exception hierarchy
/// }
/// ```
class ErrorInterceptor extends Interceptor {
  /// Construct.
  ErrorInterceptor(this._config);

  final P2xClientConfig _config;

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) {
    final exception = _toApiException(err);

    if (exception is UnauthorizedException) {
      _config.onUnauthorized?.call();
    } else if (exception is ValidationException) {
      _config.onValidationError?.call(exception.errors);
    }

    // Reject with a new DioException carrying the typed exception. Dio
    // re-throws the `error` field for `throws` to surface, so callers
    // can `catch` the typed exception directly.
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: exception,
        stackTrace: err.stackTrace,
        message: exception.message,
      ),
    );
  }

  /// Map a [DioException] to the appropriate typed [ApiException].
  ApiException _toApiException(DioException err) {
    final response = err.response;
    final status = response?.statusCode ?? 0;
    final body = response?.data;
    final message = _extractMessage(err, body);
    final data = _extractData(body);

    switch (status) {
      case 401:
        return UnauthorizedException(
          message: message,
          data: data,
          originalError: err,
        );
      case 403:
        return ForbiddenException(
          message: message,
          data: data,
          originalError: err,
        );
      case 404:
        return NotFoundException(
          message: message,
          data: data,
          originalError: err,
        );
      case 422:
        return ValidationException(
          message: message,
          errors: _extractValidationErrors(body),
          data: data,
          originalError: err,
        );
      default:
        if (status >= 500 && status < 600) {
          return ServerException(
            status: status,
            message: message,
            data: data,
            originalError: err,
          );
        }
        return ApiException(
          status: status,
          message: message,
          data: data,
          originalError: err,
        );
    }
  }

  /// Best-effort message extraction:
  ///   1. `response.data?['message']` (Laravel's standard envelope key)
  ///   2. `response.statusMessage` (HTTP reason phrase)
  ///   3. `err.message` (Dio's own description, e.g. "Connection refused")
  ///   4. `'Request failed'` as a final fallback.
  String _extractMessage(DioException err, dynamic body) {
    if (body is Map) {
      final maybeMessage = body['message'];
      if (maybeMessage is String && maybeMessage.isNotEmpty) {
        return maybeMessage;
      }
    }
    final statusMessage = err.response?.statusMessage;
    if (statusMessage != null && statusMessage.isNotEmpty) {
      return statusMessage;
    }
    final dioMessage = err.message;
    if (dioMessage != null && dioMessage.isNotEmpty) {
      return dioMessage;
    }
    return 'Request failed';
  }

  /// Pull the `data` block out of a Laravel envelope when present, otherwise
  /// return the raw body so callers retain visibility into the failure.
  dynamic _extractData(dynamic body) {
    if (body is Map && body.containsKey('data')) {
      return body['data'];
    }
    return body;
  }

  /// Parse Laravel's validation `errors` map from either of the two
  /// canonical shapes:
  ///
  ///   * Top-level: `{ "errors": { "field": [...] } }`
  ///   * Nested:    `{ "data": { "errors": { "field": [...] } } }`
  ///
  /// Falls back to an empty map when neither shape is present.
  Map<String, List<String>> _extractValidationErrors(dynamic body) {
    if (body is! Map) {
      return <String, List<String>>{};
    }

    final topLevel = body['errors'];
    if (topLevel is Map) {
      return _coerceErrors(topLevel);
    }

    final nested = body['data'];
    if (nested is Map) {
      final nestedErrors = nested['errors'];
      if (nestedErrors is Map) {
        return _coerceErrors(nestedErrors);
      }
    }

    return <String, List<String>>{};
  }

  /// Coerce a loosely-typed map (`Map<String, dynamic>` etc.) into the
  /// strongly-typed `Map<String, List<String>>` that
  /// [ValidationException.errors] requires.
  Map<String, List<String>> _coerceErrors(Map<dynamic, dynamic> raw) {
    final out = <String, List<String>>{};
    raw.forEach((key, value) {
      if (key is! String) {
        return;
      }
      if (value is List) {
        out[key] = value.map((v) => v?.toString() ?? '').toList();
      } else if (value is String) {
        out[key] = <String>[value];
      } else if (value != null) {
        out[key] = <String>[value.toString()];
      }
    });
    return out;
  }
}
