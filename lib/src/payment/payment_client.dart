import 'package:ycaas_flutter_sdk/src/client/p2x_client.dart';
import 'package:ycaas_flutter_sdk/src/payment/payment_models.dart';

/// Per-domain client for the **Payment / Stripe** surface.
///
/// Wraps the five endpoints used by the host app to render a user's
/// cards-on-file, attach a new card via Stripe SetupIntent, and list
/// their subscriptions:
///
///   * `GET    /api/payment/payment-method`         — current card on file
///   * `POST   /api/payment/payment-method`         — save a new pm_* id
///   * `DELETE /api/payment/payment-method/{id}`    — detach a card
///   * `GET    /api/payment/setup-payment-method`   — issue SetupIntent
///   * `GET    /api/payment/subscriptions`          — paginated list
///
/// All writes are idempotent — the SDK's idempotency interceptor
/// auto-attaches an `Idempotency-Key` header for POST/DELETE.
class PaymentClient {
  /// Construct against an existing [P2xClient].
  PaymentClient(this._client);

  final P2xClient _client;

  /// `GET /api/payment/payment-method` — return the user's current
  /// payment method on file, or `null` if they have none.
  ///
  /// The server returns the standard Laravel envelope with `data: null`
  /// (or no `data` key at all) when the user has no card attached —
  /// callers do not need to distinguish those two shapes.
  Future<PaymentMethod?> getPaymentMethod() {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/payment/payment-method',
      );
      final body = response.data ?? const <String, dynamic>{};
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        return null;
      }
      return PaymentMethod.fromJson(data);
    });
  }

  /// `POST /api/payment/payment-method` — attach the Stripe payment
  /// method id [paymentMethodId] (a `pm_*` token from Stripe.js /
  /// Stripe SDK) to the user.
  ///
  /// Idempotent — the SDK adds an `Idempotency-Key` header for the
  /// caller. Safe to retry on transient network failure.
  Future<void> savePaymentMethod({required String paymentMethodId}) {
    return _client.request(() async {
      await _client.dio.post<Map<String, dynamic>>(
        '/payment/payment-method',
        data: <String, dynamic>{
          'payment_method_id': paymentMethodId,
        },
      );
    });
  }

  /// `DELETE /api/payment/payment-method/{id}` — detach the payment
  /// method with the given [id] from the user.
  Future<void> deletePaymentMethod(String id) {
    return _client.request(() async {
      await _client.dio.delete<Map<String, dynamic>>(
        '/payment/payment-method/$id',
      );
    });
  }

  /// `GET /api/payment/setup-payment-method` — return a Stripe
  /// SetupIntent the client can pass to `confirmSetup` /
  /// `confirmCardSetup` to attach a new card.
  ///
  /// Despite being a `GET`, the server creates a new SetupIntent on
  /// each call — callers should request one only when they're about
  /// to start the Stripe.js / Stripe SDK flow, not eagerly.
  Future<SetupIntent> setupPaymentMethod() {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/payment/setup-payment-method',
      );
      final body = response.data ?? const <String, dynamic>{};
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError(
          'GET /payment/setup-payment-method returned no "data" object.',
        );
      }
      return SetupIntent.fromJson(data);
    });
  }

  /// `GET /api/payment/subscriptions?page=<page>` — list the user's
  /// Stripe subscriptions, page-by-page.
  ///
  /// Returns the Laravel paginator envelope as
  /// [PaginatedSubscriptions] — `{ data, current_page, last_page,
  /// total }`. The server's default page size is honoured.
  Future<PaginatedSubscriptions> subscriptions({int page = 1}) {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/payment/subscriptions',
        queryParameters: <String, dynamic>{
          'page': page,
        },
      );
      final body = response.data ?? const <String, dynamic>{};
      return PaginatedSubscriptions.fromJson(body);
    });
  }
}
