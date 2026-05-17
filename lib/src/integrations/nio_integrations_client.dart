import 'package:dio/dio.dart';
import 'package:meta/meta.dart';

import 'package:codify_p2x_sdk/src/client/p2x_client.dart';
import 'package:codify_p2x_sdk/src/integrations/nio_integrations_models.dart';

/// Per-subproject client for **NIO**-specific integration endpoints.
///
/// All endpoints in this client live under `/api/v1/integrations/nio/`.
/// In Tier 1 the surface covers the NIO coin economy: read the current
/// balance, spend coins on premium unlocks, and (for completeness)
/// grant coins from server-side trusted callers.
class NioIntegrationsClient {
  /// Construct with a reference to the shared [P2xClient].
  NioIntegrationsClient(this._client);

  final P2xClient _client;

  /// Header name for the idempotency key the SDK sends on writes.
  static const String _idempotencyHeader = 'Idempotency-Key';

  /// `GET /api/v1/integrations/nio/coins/balance` — fetch the current
  /// user's coin balance snapshot.
  Future<CoinBalance> balance() {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/v1/integrations/nio/coins/balance',
      );
      final body = response.data ?? const <String, dynamic>{};
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError(
          'GET /v1/integrations/nio/coins/balance returned no "data" object.',
        );
      }
      return CoinBalance.fromJson(data);
    });
  }

  /// `POST /api/v1/integrations/nio/coins/spend` — spend [amount] coins
  /// for [reason].
  ///
  /// The server is authoritative. On insufficient balance the SDK
  /// surfaces a `ValidationException` (mapped from a 422 by the error
  /// interceptor).
  ///
  /// [metadata] is an optional bag of structured data the server stores
  /// against the resulting ledger row. [idempotencyKey] dedupes
  /// double-submits (e.g. if the user double-taps the unlock button).
  Future<CoinTransaction> spend({
    required int amount,
    required String reason,
    Map<String, dynamic>? metadata,
    String? idempotencyKey,
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/v1/integrations/nio/coins/spend',
        data: <String, dynamic>{
          'amount': amount,
          'reason': reason,
          if (metadata != null) 'metadata': metadata,
        },
        options: _buildOptions(idempotencyKey: idempotencyKey),
      );
      final body = response.data ?? const <String, dynamic>{};
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError(
          'POST /v1/integrations/nio/coins/spend returned no "data" object.',
        );
      }
      return CoinTransaction.fromJson(data);
    });
  }

  /// `POST /api/v1/integrations/nio/coins/grant` — grant [amount] coins
  /// for [reason].
  ///
  /// NIO ops uses this endpoint; clients usually do not, but the SDK
  /// exposes it for completeness. Pass a server-trusted [reason] like
  /// `ad-watched` that the server validates against its own ad-watch
  /// log before persisting the ledger row.
  ///
  /// [metadata] is an optional bag of structured data. [idempotencyKey]
  /// dedupes double-submits.
  Future<CoinTransaction> grant({
    required int amount,
    required String reason,
    Map<String, dynamic>? metadata,
    String? idempotencyKey,
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/v1/integrations/nio/coins/grant',
        data: <String, dynamic>{
          'amount': amount,
          'reason': reason,
          if (metadata != null) 'metadata': metadata,
        },
        options: _buildOptions(idempotencyKey: idempotencyKey),
      );
      final body = response.data ?? const <String, dynamic>{};
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError(
          'POST /v1/integrations/nio/coins/grant returned no "data" object.',
        );
      }
      return CoinTransaction.fromJson(data);
    });
  }

  Options? _buildOptions({String? idempotencyKey}) {
    if (idempotencyKey == null || idempotencyKey.isEmpty) return null;
    return Options(
      headers: <String, dynamic>{_idempotencyHeader: idempotencyKey},
    );
  }

  /// Test seam: the [Options] object the client uses internally for a
  /// given [idempotencyKey]. Test-only.
  @visibleForTesting
  static Options idempotencyOptionsForTest(String idempotencyKey) {
    return Options(
      headers: <String, dynamic>{_idempotencyHeader: idempotencyKey},
    );
  }
}
