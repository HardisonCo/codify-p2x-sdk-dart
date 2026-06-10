import 'package:meta/meta.dart';

/// A YCaaS deal — the persistent unit driven through the
/// **analyze → codify → setup → execute → verify** lifecycle.
///
/// Most of the long-tail fields (solutions, stakeholders, financing,
/// pipeline_steps, outcome reports) vary by deal template and are stashed on
/// [extras] verbatim. The fields lifted to first-class are the ones the SDK
/// will hold-load-bearing across the wizard flow.
@immutable
class Deal {
  /// Construct.
  const Deal({
    required this.id,
    required this.state,
    this.problem,
    this.outcomeClass,
    this.outcomeScore,
    this.extras = const <String, dynamic>{},
  });

  /// Decode from the inner `data` block of the Laravel envelope.
  factory Deal.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? json['deal_id']) as Object?;
    final extras = <String, dynamic>{
      for (final MapEntry<String, dynamic> e in json.entries)
        if (e.key != 'id' &&
            e.key != 'deal_id' &&
            e.key != 'state' &&
            e.key != 'problem' &&
            e.key != 'outcome_class' &&
            e.key != 'outcome_score')
          e.key: e.value,
    };
    return Deal(
      id: id is num ? id.toInt() : int.parse(id.toString()),
      state: (json['state'] ?? '') as String,
      problem: json['problem'] as String?,
      outcomeClass: json['outcome_class'] as String?,
      outcomeScore: json['outcome_score'] == null
          ? null
          : (json['outcome_score'] as num).toDouble(),
      extras: extras,
    );
  }

  /// FK into the `deals` table.
  final int id;

  /// Lifecycle state — `analyzing`, `codified`, `setup`, `executing`,
  /// `completed`, `verified`, …
  final String state;

  /// The user-supplied problem statement that seeded the deal.
  final String? problem;

  /// Set after verification — e.g. `success`, `failure`, `partial`.
  final String? outcomeClass;

  /// Numeric 0..1 score set after verification.
  final double? outcomeScore;

  /// All other top-level fields from the response body (solutions,
  /// stakeholders, financing, expertise, pipeline_steps, outcome_report, …).
  final Map<String, dynamic> extras;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Deal &&
        other.id == id &&
        other.state == state &&
        other.problem == problem;
  }

  @override
  int get hashCode => Object.hash(id, state, problem);

  @override
  String toString() => 'Deal(id: $id, state: $state)';
}
