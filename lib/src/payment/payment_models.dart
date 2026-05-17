import 'package:meta/meta.dart';

/// A saved Stripe payment method, as returned by
/// `GET /api/payment/payment-method`.
///
/// Identifiers and brand/last4 metadata come straight from Stripe. The
/// server only persists what's needed to render a "card on file" row in
/// the client UI — full card numbers and CVCs never leave Stripe's
/// systems.
@immutable
class PaymentMethod {
  /// Construct.
  const PaymentMethod({
    required this.id,
    required this.brand,
    required this.last4,
    required this.expMonth,
    required this.expYear,
    this.isDefault = false,
  });

  /// Build a [PaymentMethod] from the standard Laravel JSON shape.
  ///
  /// Snake-case keys (`exp_month`, `is_default`) are mapped onto Dart
  /// camelCase. `is_default` defaults to `false` when absent.
  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      id: json['id'] as String,
      brand: json['brand'] as String,
      last4: json['last4'] as String,
      expMonth: (json['exp_month'] as num).toInt(),
      expYear: (json['exp_year'] as num).toInt(),
      isDefault: json['is_default'] == true,
    );
  }

  /// Stripe payment-method id (the `pm_*` token).
  final String id;

  /// Card brand, lower-cased — e.g. `visa`, `mastercard`, `amex`.
  final String brand;

  /// Last four digits of the card.
  final String last4;

  /// Card expiration month (1–12).
  final int expMonth;

  /// Card expiration year (4-digit, e.g. 2030).
  final int expYear;

  /// Whether this is the user's default payment method.
  final bool isDefault;

  /// Encode this payment method back to the standard Laravel JSON shape.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'brand': brand,
      'last4': last4,
      'exp_month': expMonth,
      'exp_year': expYear,
      'is_default': isDefault,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PaymentMethod &&
        other.id == id &&
        other.brand == brand &&
        other.last4 == last4 &&
        other.expMonth == expMonth &&
        other.expYear == expYear &&
        other.isDefault == isDefault;
  }

  @override
  int get hashCode =>
      Object.hash(id, brand, last4, expMonth, expYear, isDefault);

  @override
  String toString() => 'PaymentMethod(id: $id, brand: $brand, '
      'last4: $last4, expMonth: $expMonth, expYear: $expYear, '
      'isDefault: $isDefault)';
}

/// A Stripe SetupIntent — issued by
/// `GET /api/payment/setup-payment-method` so the client can attach a
/// new card via Stripe.js / Stripe SDK without the server ever seeing
/// the PAN.
///
/// The host app passes [clientSecret] to Stripe's `confirmSetup` /
/// `confirmCardSetup` flow.
@immutable
class SetupIntent {
  /// Construct.
  const SetupIntent({
    required this.clientSecret,
    required this.status,
    this.customerId,
  });

  /// Build a [SetupIntent] from JSON.
  factory SetupIntent.fromJson(Map<String, dynamic> json) {
    return SetupIntent(
      clientSecret: json['client_secret'] as String,
      customerId: json['customer_id'] as String?,
      status: json['status'] as String,
    );
  }

  /// Stripe SetupIntent client_secret — used by Stripe.js / Stripe SDK.
  final String clientSecret;

  /// Stripe customer id (`cus_*`) the SetupIntent is attached to. May be
  /// `null` if the server didn't include it.
  final String? customerId;

  /// SetupIntent status — typically `requires_payment_method`,
  /// `requires_confirmation`, `requires_action`, `processing`, or
  /// `succeeded`.
  final String status;

  /// Encode back to JSON.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'client_secret': clientSecret,
      if (customerId != null) 'customer_id': customerId,
      'status': status,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SetupIntent &&
        other.clientSecret == clientSecret &&
        other.customerId == customerId &&
        other.status == status;
  }

  @override
  int get hashCode => Object.hash(clientSecret, customerId, status);

  @override
  String toString() => 'SetupIntent(customerId: $customerId, '
      'status: $status)';
}

/// A Stripe subscription row, as returned in pages by
/// `GET /api/payment/subscriptions`.
///
/// Status mirrors Stripe's lifecycle — typical values are `active`,
/// `trialing`, `past_due`, and `canceled`.
@immutable
class Subscription {
  /// Construct.
  const Subscription({
    required this.id,
    required this.status,
    required this.currentPeriodEnd,
    required this.priceId,
    required this.productName,
    required this.amountCents,
    required this.currency,
  });

  /// Build a [Subscription] from JSON.
  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'] as String,
      status: json['status'] as String,
      currentPeriodEnd: DateTime.parse(json['current_period_end'] as String),
      priceId: json['price_id'] as String,
      productName: json['product_name'] as String,
      amountCents: (json['amount_cents'] as num).toInt(),
      currency: json['currency'] as String,
    );
  }

  /// Stripe subscription id (`sub_*`).
  final String id;

  /// Stripe subscription status — `active`, `trialing`, `past_due`,
  /// `canceled`, etc.
  final String status;

  /// End of the current billing period.
  final DateTime currentPeriodEnd;

  /// Stripe price id (`price_*`) the subscription is on.
  final String priceId;

  /// Human-readable product name for UI display (e.g. `Pro Plan`).
  final String productName;

  /// Amount in the smallest currency unit (cents for USD).
  final int amountCents;

  /// ISO-4217 currency code in Stripe's lowercase form (`usd`, `eur`).
  final String currency;

  /// Encode back to JSON.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'status': status,
      'current_period_end': currentPeriodEnd.toIso8601String(),
      'price_id': priceId,
      'product_name': productName,
      'amount_cents': amountCents,
      'currency': currency,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Subscription &&
        other.id == id &&
        other.status == status &&
        other.currentPeriodEnd == currentPeriodEnd &&
        other.priceId == priceId &&
        other.productName == productName &&
        other.amountCents == amountCents &&
        other.currency == currency;
  }

  @override
  int get hashCode => Object.hash(
        id,
        status,
        currentPeriodEnd,
        priceId,
        productName,
        amountCents,
        currency,
      );

  @override
  String toString() => 'Subscription(id: $id, status: $status, '
      'priceId: $priceId, productName: $productName, '
      'amountCents: $amountCents, currency: $currency, '
      'currentPeriodEnd: $currentPeriodEnd)';
}

/// A paginated page of [Subscription] rows — Laravel's default
/// paginator envelope, with `{ data, current_page, last_page, total }`.
///
/// The paginator emits `per_page`, `from`, and `to` fields too, but
/// they're not needed by the SDK's surface and intentionally dropped
/// here to keep the model lean. Re-add them if a caller needs them.
@immutable
class PaginatedSubscriptions {
  /// Construct.
  const PaginatedSubscriptions({
    required this.data,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  /// Decode from the Laravel paginator JSON envelope.
  factory PaginatedSubscriptions.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final items = <Subscription>[];
    if (rawData is List) {
      for (final row in rawData) {
        if (row is Map) {
          items.add(Subscription.fromJson(Map<String, dynamic>.from(row)));
        }
      }
    }
    return PaginatedSubscriptions(
      data: items,
      currentPage: (json['current_page'] as num?)?.toInt() ?? 1,
      lastPage: (json['last_page'] as num?)?.toInt() ?? 1,
      total: (json['total'] as num?)?.toInt() ?? items.length,
    );
  }

  /// The page of rows.
  final List<Subscription> data;

  /// 1-indexed current page.
  final int currentPage;

  /// 1-indexed last page (`currentPage == lastPage` ⇒ no next page).
  final int lastPage;

  /// Total row count across all pages.
  final int total;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PaginatedSubscriptions) return false;
    if (currentPage != other.currentPage) return false;
    if (lastPage != other.lastPage) return false;
    if (total != other.total) return false;
    if (data.length != other.data.length) return false;
    for (var i = 0; i < data.length; i++) {
      if (data[i] != other.data[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    var dataHash = 0;
    for (final r in data) {
      dataHash ^= r.hashCode;
    }
    return Object.hash(dataHash, currentPage, lastPage, total);
  }

  @override
  String toString() => 'PaginatedSubscriptions(currentPage: $currentPage, '
      'lastPage: $lastPage, total: $total, count: ${data.length})';
}
