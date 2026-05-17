import 'package:meta/meta.dart';

/// The standard Laravel response envelope that every P2X endpoint returns.
///
/// Shape:
/// ```json
/// {
///   "success": true,
///   "message": "Operation completed",
///   "data": <payload>,
///   "meta": { "timestamp": "...", "apiVersion": "..." }
/// }
/// ```
///
/// Mirrors the TS SDK's `ApiResponse<T>` interface.
///
/// Per-domain clients typically return `T` directly (unwrapping the envelope
/// internally) — this type is exposed for callers that need access to the
/// `meta` block or the raw `message`.
@immutable
class ApiResponse<T> {
  /// Construct.
  const ApiResponse({
    required this.success,
    required this.message,
    required this.data,
    this.meta,
  });

  /// `true` for 2xx responses. The SDK normalizes non-2xx into thrown
  /// exceptions, so consumers see `success: true` whenever the call
  /// returns normally.
  final bool success;

  /// Human-readable message from the server. May be empty.
  final String message;

  /// The typed payload. Empty `Map`/`List`/etc. when the endpoint returns
  /// no body — not `null`.
  final T data;

  /// Optional metadata: timestamp, apiVersion, pagination cursors, etc.
  final ApiMeta? meta;
}

/// Metadata block from an [ApiResponse]. May include pagination and
/// API-version information depending on the endpoint.
@immutable
class ApiMeta {
  /// Construct.
  const ApiMeta({
    this.timestamp,
    this.apiVersion,
    this.extra = const <String, dynamic>{},
  });

  /// Server-emitted ISO-8601 timestamp.
  final String? timestamp;

  /// Server-emitted API version string (e.g. `"v1"`).
  final String? apiVersion;

  /// Any additional metadata fields the endpoint includes (pagination
  /// cursors, total counts, etc.). Kept loose to avoid coupling every
  /// caller to specific extras.
  final Map<String, dynamic> extra;
}
