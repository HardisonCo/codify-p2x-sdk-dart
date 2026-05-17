import 'package:meta/meta.dart';

/// A snapshot of the current user's **coin balance** in the NIO economy.
///
/// Returned by `GET /api/v1/integrations/nio/coins/balance`. Coins are
/// the internal NIO loyalty currency — earned via scan streaks, ad
/// watches, and other gamified actions; spent on premium meal-plan
/// unlocks. The server is authoritative; the client should never
/// compute a balance locally.
@immutable
class CoinBalance {
  /// Construct.
  const CoinBalance({
    required this.balance,
    required this.lifetimeEarned,
    required this.lifetimeSpent,
    required this.asOf,
  });

  /// Decode from a JSON object.
  factory CoinBalance.fromJson(Map<String, dynamic> json) {
    return CoinBalance(
      balance: json['balance'] as int,
      lifetimeEarned: json['lifetime_earned'] as int,
      lifetimeSpent: json['lifetime_spent'] as int,
      asOf: DateTime.parse(json['as_of'] as String),
    );
  }

  /// Current spendable balance.
  final int balance;

  /// Lifetime cumulative coins earned by this user. Never decreases.
  final int lifetimeEarned;

  /// Lifetime cumulative coins spent by this user. Never decreases.
  final int lifetimeSpent;

  /// Server-side `as-of` timestamp for this snapshot.
  final DateTime asOf;

  /// Encode to a JSON object. Symmetric with [CoinBalance.fromJson].
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'balance': balance,
      'lifetime_earned': lifetimeEarned,
      'lifetime_spent': lifetimeSpent,
      'as_of': asOf.toIso8601String(),
    };
  }

  /// Return a copy with the given fields replaced.
  CoinBalance copyWith({
    int? balance,
    int? lifetimeEarned,
    int? lifetimeSpent,
    DateTime? asOf,
  }) {
    return CoinBalance(
      balance: balance ?? this.balance,
      lifetimeEarned: lifetimeEarned ?? this.lifetimeEarned,
      lifetimeSpent: lifetimeSpent ?? this.lifetimeSpent,
      asOf: asOf ?? this.asOf,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoinBalance &&
          runtimeType == other.runtimeType &&
          balance == other.balance &&
          lifetimeEarned == other.lifetimeEarned &&
          lifetimeSpent == other.lifetimeSpent &&
          asOf == other.asOf;

  @override
  int get hashCode => Object.hash(balance, lifetimeEarned, lifetimeSpent, asOf);

  @override
  String toString() => 'CoinBalance(balance: $balance, '
      'lifetimeEarned: $lifetimeEarned, lifetimeSpent: $lifetimeSpent, '
      'asOf: $asOf)';
}

/// A single ledger entry in the NIO coin economy.
///
/// Each row records a single mutation of the user's balance (earn,
/// spend, refund, or grant). Returned by the `spend` / `grant`
/// endpoints in `NioIntegrationsClient`.
@immutable
class CoinTransaction {
  /// Construct.
  const CoinTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.reason,
    required this.balanceAfter,
    required this.createdAt,
    this.metadata = const <String, dynamic>{},
  });

  /// Decode from a JSON object. Permissive — a missing `metadata`
  /// field decodes to an empty map.
  factory CoinTransaction.fromJson(Map<String, dynamic> json) {
    final rawMetadata = json['metadata'];
    final metadata = rawMetadata is Map
        ? Map<String, dynamic>.from(rawMetadata)
        : <String, dynamic>{};
    return CoinTransaction(
      id: json['id'] as int,
      type: json['type'] as String,
      amount: json['amount'] as int,
      reason: json['reason'] as String,
      balanceAfter: json['balance_after'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      metadata: metadata,
    );
  }

  /// Primary key.
  final int id;

  /// Transaction type — one of `earn`, `spend`, `refund`, `grant`.
  /// The sign of [amount] is implied by [type] (amount is always a
  /// positive integer; the server never sends negatives).
  final String type;

  /// Coin delta in absolute value. Positive integer.
  final int amount;

  /// Stable reason code (e.g. `scan-streak-bonus`, `meal-plan-unlock`,
  /// `ad-watched`). The server validates these against its own
  /// allow-list — sending an unknown reason yields a `ValidationException`.
  final String reason;

  /// Spendable balance after this transaction was applied.
  final int balanceAfter;

  /// When the transaction was recorded.
  final DateTime createdAt;

  /// Optional structured metadata — server-defined, free-form.
  final Map<String, dynamic> metadata;

  /// Encode to a JSON object. Symmetric with [CoinTransaction.fromJson].
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'type': type,
      'amount': amount,
      'reason': reason,
      'balance_after': balanceAfter,
      'created_at': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  /// Return a copy with the given fields replaced.
  CoinTransaction copyWith({
    int? id,
    String? type,
    int? amount,
    String? reason,
    int? balanceAfter,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) {
    return CoinTransaction(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      reason: reason ?? this.reason,
      balanceAfter: balanceAfter ?? this.balanceAfter,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CoinTransaction) return false;
    if (id != other.id) return false;
    if (type != other.type) return false;
    if (amount != other.amount) return false;
    if (reason != other.reason) return false;
    if (balanceAfter != other.balanceAfter) return false;
    if (createdAt != other.createdAt) return false;
    if (metadata.length != other.metadata.length) return false;
    for (final entry in metadata.entries) {
      if (!other.metadata.containsKey(entry.key)) return false;
      if (other.metadata[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    var metaHash = 0;
    for (final entry in metadata.entries) {
      metaHash ^= Object.hash(entry.key, entry.value);
    }
    return Object.hash(
      id,
      type,
      amount,
      reason,
      balanceAfter,
      createdAt,
      metaHash,
    );
  }

  @override
  String toString() => 'CoinTransaction(id: $id, type: $type, amount: $amount, '
      'reason: $reason, balanceAfter: $balanceAfter, '
      'createdAt: $createdAt)';
}
