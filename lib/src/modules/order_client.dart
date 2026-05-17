import 'package:codify_p2x_sdk/src/client/p2x_client.dart';
import 'package:codify_p2x_sdk/src/modules/order_models.dart';

/// Per-domain client for the **Orders** module.
///
/// In Tier 1 this is read-only — orders are created server-side by the
/// IAP webhook + PHM checkout flow. Mobile clients use this client to
/// read subscription state and order history.
class OrderClient {
  /// Construct with a reference to the shared [P2xClient].
  OrderClient(this._client);

  final P2xClient _client;

  /// `GET /api/orders?source=<source>&status=<status>` — list orders for
  /// the current user, optionally filtered by [source] and/or [status].
  Future<List<Order>> list({String? source, String? status}) {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/orders',
        queryParameters: <String, dynamic>{
          if (source != null) 'source': source,
          if (status != null) 'status': status,
        },
      );
      final body = response.data ?? const <String, dynamic>{};
      final raw = body['data'];
      if (raw is! List) return const <Order>[];
      return raw
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => Order.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    });
  }

  /// `GET /api/orders/<id>` — fetch one Order by primary key.
  Future<Order> get(int id) {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/orders/$id',
      );
      final body = response.data ?? const <String, dynamic>{};
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError('GET /orders/$id returned no "data" object.');
      }
      return Order.fromJson(data);
    });
  }

  /// Convenience: returns the user's currently-active subscription Order
  /// for the given [source] (default `nio-subscription`), or `null` if
  /// none is found.
  Future<Order?> activeSubscription({
    String source = 'nio-subscription',
  }) async {
    final results = await list(source: source, status: 'active');
    if (results.isEmpty) return null;
    return results.first;
  }
}
