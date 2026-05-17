import 'package:meta/meta.dart';

/// A P2X **Order** — the canonical record of a paid (or pending) thing
/// the user bought through the platform.
///
/// Sources include `nio-subscription` (NIO premium tier, monthly/yearly),
/// `phm-lab-booking` (PHM-ordered lab work), `ibd-doctor-visit` (IBD
/// telehealth fee), and others. Reading subscription state for the
/// current user is the most common Tier-1 use of this client.
@immutable
class Order {
  /// Construct.
  const Order({
    required this.id,
    required this.source,
    required this.status,
    required this.amount,
    required this.currency,
    required this.userId,
    required this.subprojectId,
    required this.createdAt,
    required this.updatedAt,
    this.tier,
    this.expiresAt,
  });

  /// Decode from a JSON object. Permissive — integer `amount` is coerced
  /// to `double`, optional fields fall back to `null`.
  factory Order.fromJson(Map<String, dynamic> json) {
    final rawAmount = json['amount'];
    final amount = rawAmount is num
        ? rawAmount.toDouble()
        : double.parse(rawAmount.toString());
    return Order(
      id: json['id'] as int,
      source: json['source'] as String,
      status: json['status'] as String,
      amount: amount,
      currency: json['currency'] as String,
      tier: json['tier'] as String?,
      expiresAt: json['expires_at'] is String
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      userId: json['user_id'] as int,
      subprojectId: json['subproject_id'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Primary key.
  final int id;

  /// Stable source identifier — e.g. `nio-subscription`,
  /// `phm-lab-booking`, `ibd-doctor-visit`.
  final String source;

  /// One of `pending`, `active`, `cancelled`, `expired`. Server-driven —
  /// the SDK doesn't enforce the enum, so a new server-side status will
  /// flow through unchanged.
  final String status;

  /// Order amount in the smallest decimal unit of [currency]
  /// (e.g. `9.99` for `USD`).
  final double amount;

  /// Currency code (ISO-4217). Typically `USD`.
  final String currency;

  /// Subscription tier — typically `monthly` or `yearly`. Optional and
  /// only set on subscription-style sources.
  final String? tier;

  /// When the order expires (subscription-only). `null` for one-shot
  /// orders.
  final DateTime? expiresAt;

  /// The user this order belongs to.
  final int userId;

  /// The subproject this order belongs to (server-assigned from the
  /// `X-Domain` header at creation time).
  final int subprojectId;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Last-modified timestamp.
  final DateTime updatedAt;

  /// Encode to a JSON object. Symmetric with [Order.fromJson].
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'source': source,
      'status': status,
      'amount': amount,
      'currency': currency,
      if (tier != null) 'tier': tier,
      if (expiresAt != null) 'expires_at': expiresAt!.toIso8601String(),
      'user_id': userId,
      'subproject_id': subprojectId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Return a copy with the given fields replaced.
  Order copyWith({
    int? id,
    String? source,
    String? status,
    double? amount,
    String? currency,
    String? tier,
    DateTime? expiresAt,
    int? userId,
    int? subprojectId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Order(
      id: id ?? this.id,
      source: source ?? this.source,
      status: status ?? this.status,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      tier: tier ?? this.tier,
      expiresAt: expiresAt ?? this.expiresAt,
      userId: userId ?? this.userId,
      subprojectId: subprojectId ?? this.subprojectId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Order &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          source == other.source &&
          status == other.status &&
          amount == other.amount &&
          currency == other.currency &&
          tier == other.tier &&
          expiresAt == other.expiresAt &&
          userId == other.userId &&
          subprojectId == other.subprojectId &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        source,
        status,
        amount,
        currency,
        tier,
        expiresAt,
        userId,
        subprojectId,
        createdAt,
        updatedAt,
      );

  @override
  String toString() => 'Order(id: $id, source: $source, status: $status, '
      'amount: $amount $currency, tier: $tier, '
      'expiresAt: $expiresAt, userId: $userId, '
      'subprojectId: $subprojectId)';
}
