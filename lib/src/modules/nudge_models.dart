import 'package:meta/meta.dart';

/// A server-driven **Nudge** — a short, contextual prompt the server asks
/// the client to render.
///
/// Nudges are used by NIO for reminders (e.g. "log your lunch"), coin-earning
/// prompts ("watch an ad to earn 5 coins"), and streak celebrations. The
/// server owns the trigger logic; the client just renders the active set and
/// reports back when the user acknowledges or dismisses one — see
/// `NudgeClient.ack` and `NudgeClient.dismiss`.
@immutable
class Nudge {
  /// Construct.
  const Nudge({
    required this.id,
    required this.key,
    required this.title,
    required this.body,
    required this.severity,
    required this.createdAt,
    this.action,
    this.acknowledgedAt,
    this.dismissedAt,
    this.payload = const <String, dynamic>{},
  });

  /// Decode from a JSON object. Permissive — missing optional fields fall
  /// back to `null`, and a missing `payload` decodes to an empty map.
  factory Nudge.fromJson(Map<String, dynamic> json) {
    final rawPayload = json['payload'];
    final payload = rawPayload is Map
        ? Map<String, dynamic>.from(rawPayload)
        : <String, dynamic>{};
    return Nudge(
      id: json['id'] as int,
      key: json['key'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      action: json['action'] as String?,
      severity: json['severity'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      acknowledgedAt: json['acknowledged_at'] is String
          ? DateTime.parse(json['acknowledged_at'] as String)
          : null,
      dismissedAt: json['dismissed_at'] is String
          ? DateTime.parse(json['dismissed_at'] as String)
          : null,
      payload: payload,
    );
  }

  /// Primary key.
  final int id;

  /// Stable string identifier the client can map to UI
  /// (e.g. `meal-log-reminder`, `coin-earn`, `daily-streak`).
  final String key;

  /// Display title (already localized server-side).
  final String title;

  /// Display body.
  final String body;

  /// Optional deep-link or screen route hint
  /// (e.g. `screen://meal/log`). `null` when the nudge is informational
  /// only and has no actionable target.
  final String? action;

  /// One of `info`, `reminder`, `celebration`. Drives UI styling — the
  /// SDK doesn't enforce the enum so new server-side severities flow
  /// through unchanged.
  final String severity;

  /// When the nudge was created server-side.
  final DateTime createdAt;

  /// `null` while active; set after the user acknowledges the nudge.
  final DateTime? acknowledgedAt;

  /// Optional dismissal timestamp distinct from acknowledgement. Some
  /// UIs treat "dismiss" as "don't show, but don't count as
  /// acknowledged" — this column is how the server tells the two apart.
  final DateTime? dismissedAt;

  /// Optional payload — extra structured data the client may need to
  /// render or act on the nudge (deep-link params, reward amount,
  /// streak length, etc.).
  final Map<String, dynamic> payload;

  /// Encode to a JSON object. Symmetric with [Nudge.fromJson].
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'key': key,
      'title': title,
      'body': body,
      if (action != null) 'action': action,
      'severity': severity,
      'created_at': createdAt.toIso8601String(),
      if (acknowledgedAt != null)
        'acknowledged_at': acknowledgedAt!.toIso8601String(),
      if (dismissedAt != null) 'dismissed_at': dismissedAt!.toIso8601String(),
      'payload': payload,
    };
  }

  /// Return a copy with the given fields replaced.
  Nudge copyWith({
    int? id,
    String? key,
    String? title,
    String? body,
    String? action,
    String? severity,
    DateTime? createdAt,
    DateTime? acknowledgedAt,
    DateTime? dismissedAt,
    Map<String, dynamic>? payload,
  }) {
    return Nudge(
      id: id ?? this.id,
      key: key ?? this.key,
      title: title ?? this.title,
      body: body ?? this.body,
      action: action ?? this.action,
      severity: severity ?? this.severity,
      createdAt: createdAt ?? this.createdAt,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      dismissedAt: dismissedAt ?? this.dismissedAt,
      payload: payload ?? this.payload,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Nudge) return false;
    if (id != other.id) return false;
    if (key != other.key) return false;
    if (title != other.title) return false;
    if (body != other.body) return false;
    if (action != other.action) return false;
    if (severity != other.severity) return false;
    if (createdAt != other.createdAt) return false;
    if (acknowledgedAt != other.acknowledgedAt) return false;
    if (dismissedAt != other.dismissedAt) return false;
    if (payload.length != other.payload.length) return false;
    for (final entry in payload.entries) {
      if (!other.payload.containsKey(entry.key)) return false;
      if (other.payload[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    var payloadHash = 0;
    for (final entry in payload.entries) {
      payloadHash ^= Object.hash(entry.key, entry.value);
    }
    return Object.hash(
      id,
      key,
      title,
      body,
      action,
      severity,
      createdAt,
      acknowledgedAt,
      dismissedAt,
      payloadHash,
    );
  }

  @override
  String toString() => 'Nudge(id: $id, key: $key, severity: $severity, '
      'title: $title, acknowledgedAt: $acknowledgedAt, '
      'dismissedAt: $dismissedAt)';
}
