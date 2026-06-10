import 'package:meta/meta.dart';

/// Response of `POST /wizard/start` — the entry-point to the YCaaS Five-Step
/// Wizard. The server creates a fresh deal (and its driving protocol) and
/// returns enough state for the client to navigate into the wizard.
///
/// The wizard surface is **state-machine-shaped** and the long-tail fields
/// vary by step / template — they're stashed on [extras] verbatim so the
/// host app can read them without each new field requiring an SDK release.
@immutable
class WizardStartResponse {
  /// Construct.
  const WizardStartResponse({
    required this.dealId,
    required this.state,
    this.protocolId,
    this.extras = const <String, dynamic>{},
  });

  /// Decode from the inner `data` block of the Laravel envelope.
  factory WizardStartResponse.fromJson(Map<String, dynamic> json) {
    final dealId = (json['deal_id'] ?? json['dealId']) as Object?;
    final protocolId = (json['protocol_id'] ?? json['protocolId']) as Object?;
    final extras = <String, dynamic>{
      for (final MapEntry<String, dynamic> e in json.entries)
        if (e.key != 'deal_id' &&
            e.key != 'dealId' &&
            e.key != 'state' &&
            e.key != 'protocol_id' &&
            e.key != 'protocolId')
          e.key: e.value,
    };
    return WizardStartResponse(
      dealId: dealId is num ? dealId.toInt() : int.parse(dealId.toString()),
      state: (json['state'] ?? '') as String,
      protocolId: protocolId == null
          ? null
          : (protocolId is num
              ? protocolId.toInt()
              : int.tryParse(protocolId.toString())),
      extras: extras,
    );
  }

  /// FK into the `deals` table — used by `DealsClient` to advance the deal.
  final int dealId;

  /// Current wizard / deal state (e.g. `analyzing`, `codified`, `executing`).
  final String state;

  /// Optional FK into the `protocols` table — many wizard methods take the
  /// protocol ID as a path param.
  final int? protocolId;

  /// All other top-level fields from the response body. Passthrough so the
  /// SDK doesn't need a release whenever the server adds a field.
  final Map<String, dynamic> extras;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WizardStartResponse &&
        other.dealId == dealId &&
        other.state == state &&
        other.protocolId == protocolId;
  }

  @override
  int get hashCode => Object.hash(dealId, state, protocolId);

  @override
  String toString() =>
      'WizardStartResponse(dealId: $dealId, state: $state, '
      'protocolId: $protocolId)';
}
