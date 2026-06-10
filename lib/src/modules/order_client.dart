import 'package:ycaas_flutter_sdk/src/client/p2x_client.dart';
import 'package:ycaas_flutter_sdk/src/modules/order_models.dart';

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

  /// `POST /api/order` — create a new [Order] for the current user with
  /// the given [source] (e.g. `nio-subscription`, `phm-lab-booking`),
  /// [amountCents] (smallest currency unit; `999` ≡ `$9.99` for `USD`),
  /// and ISO-4217 [currency] code.
  ///
  /// The server returns the canonical row including its assigned `id`
  /// in `pending` status — call [checkout] next to attach a payment
  /// method and produce a Stripe `PaymentIntent`. The
  /// `IdempotencyInterceptor` attaches a fresh `Idempotency-Key` so a
  /// double-tap "Buy" collapses to a single Order.
  Future<Order> create({
    required String source,
    required int amountCents,
    required String currency,
    Map<String, dynamic>? metadata,
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/order',
        data: <String, dynamic>{
          'source': source,
          'amount_cents': amountCents,
          'currency': currency,
          if (metadata != null) 'metadata': metadata,
        },
      );
      final body = response.data ?? const <String, dynamic>{};
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError('POST /order returned no "data" object.');
      }
      return Order.fromJson(data);
    });
  }

  /// `PUT /api/order/<id>` — update an existing [Order]'s mutable
  /// fields (currently `metadata`). Status transitions go through
  /// [cancel], [checkout], and [confirm] — they are not exposed here.
  ///
  /// Rewritten to `POST /api/order/<id>?_method=PUT` on the wire by the
  /// `MethodOverrideInterceptor`.
  Future<Order> update(int id, {Map<String, dynamic>? metadata}) {
    return _client.request(() async {
      final response = await _client.dio.put<Map<String, dynamic>>(
        '/order/$id',
        data: <String, dynamic>{
          if (metadata != null) 'metadata': metadata,
        },
      );
      final body = response.data ?? const <String, dynamic>{};
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError('PUT /order/$id returned no "data" object.');
      }
      return Order.fromJson(data);
    });
  }

  /// `POST /api/order/cancel-order` — cancel the [Order] identified by
  /// [orderId], optionally recording a human-readable [reason]. The
  /// server transitions the order to `cancelled` and returns the
  /// canonical row.
  ///
  /// Idempotent via the auto-injected `Idempotency-Key` header.
  Future<Order> cancel({required int orderId, String? reason}) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/order/cancel-order',
        data: <String, dynamic>{
          'order_id': orderId,
          if (reason != null) 'reason': reason,
        },
      );
      final body = response.data ?? const <String, dynamic>{};
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError(
          'POST /order/cancel-order returned no "data" object.',
        );
      }
      return Order.fromJson(data);
    });
  }

  /// `POST /api/order/checkout` — kick off payment for [orderId] using
  /// the previously-attached Stripe payment method [paymentMethodId].
  ///
  /// The server creates (or reuses) a Stripe `PaymentIntent` and
  /// returns the result in the [CheckoutResult] envelope. Three paths:
  ///
  ///   1. `status: 'requires_action'` — the app passes
  ///      [CheckoutResult.clientSecret] to the Stripe mobile SDK,
  ///      completes the 3DS / push challenge, then calls [confirm]
  ///      with the resulting `paymentIntentId`.
  ///   2. `status: 'succeeded'` — payment cleared in a single
  ///      round-trip; no follow-up is required (though [confirm] is
  ///      idempotent and safe).
  ///   3. `status: 'failed'` — surface [CheckoutResult.error] and stop.
  ///
  /// Idempotent via the auto-injected `Idempotency-Key` header.
  Future<CheckoutResult> checkout({
    required int orderId,
    required String paymentMethodId,
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/order/checkout',
        data: <String, dynamic>{
          'order_id': orderId,
          'payment_method_id': paymentMethodId,
        },
      );
      final body = response.data ?? const <String, dynamic>{};
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError('POST /order/checkout returned no "data" object.');
      }
      return CheckoutResult.fromJson(data);
    });
  }

  /// `POST /api/order/confirm-order` — confirm payment for [orderId]
  /// once the Stripe mobile SDK has finished the client-side
  /// confirmation flow.
  ///
  /// Called after [checkout] returned `status: 'requires_action'` and
  /// the app handed the resulting [CheckoutResult.clientSecret] to the
  /// Stripe SDK. The [paymentIntentId] is the `PaymentIntent.id`
  /// Stripe returns once it reaches a terminal state.
  ///
  /// Idempotent via the auto-injected `Idempotency-Key` header.
  Future<Order> confirm({
    required int orderId,
    required String paymentIntentId,
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/order/confirm-order',
        data: <String, dynamic>{
          'order_id': orderId,
          'payment_intent_id': paymentIntentId,
        },
      );
      final body = response.data ?? const <String, dynamic>{};
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError(
          'POST /order/confirm-order returned no "data" object.',
        );
      }
      return Order.fromJson(data);
    });
  }
}
