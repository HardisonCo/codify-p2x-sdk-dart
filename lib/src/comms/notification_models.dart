import 'package:meta/meta.dart';

/// An in-app **notification** row — the server-persisted twin of an FCM
/// push payload.
///
/// IBD uses these for appointment reminders, doctor↔patient message
/// pings, and operator broadcasts. The mobile apps render the FCM push
/// when delivered live, then sync the full history from
/// `GET /api/notification` on app foreground for users who missed the
/// push.
///
/// Named `AppNotification` (not `Notification`) to avoid clashing with
/// Flutter's foundation `Notification` class.
@immutable
class AppNotification {
  /// Construct.
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.payload = const <String, dynamic>{},
    this.readAt,
  });

  /// Decode from a JSON object. Permissive — missing `payload` decodes
  /// to an empty map; missing optional fields fall back to `null`.
  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final rawPayload = json['payload'];
    final payload = rawPayload is Map
        ? Map<String, dynamic>.from(rawPayload)
        : <String, dynamic>{};
    return AppNotification(
      id: json['id'] as int,
      type: json['type'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      payload: payload,
      readAt: json['read_at'] is String
          ? DateTime.parse(json['read_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Primary key.
  final int id;

  /// Stable type identifier — e.g. `appointment.reminder`,
  /// `message.received`, `system`. The SDK doesn't enforce the enum so
  /// new server-side types flow through unchanged.
  final String type;

  /// Display title (already localized server-side).
  final String title;

  /// Display body.
  final String body;

  /// Structured payload — typically deep-link parameters (`room_id`,
  /// `appointment_id`, etc.) the client needs to route the user to the
  /// right screen on tap.
  final Map<String, dynamic> payload;

  /// Read-receipt timestamp. `null` while unread.
  final DateTime? readAt;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Encode to a JSON object. Symmetric with [AppNotification.fromJson].
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'type': type,
      'title': title,
      'body': body,
      'payload': payload,
      if (readAt != null) 'read_at': readAt!.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Return a copy with the given fields replaced.
  AppNotification copyWith({
    int? id,
    String? type,
    String? title,
    String? body,
    Map<String, dynamic>? payload,
    DateTime? readAt,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      payload: payload ?? this.payload,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AppNotification) return false;
    if (id != other.id) return false;
    if (type != other.type) return false;
    if (title != other.title) return false;
    if (body != other.body) return false;
    if (readAt != other.readAt) return false;
    if (createdAt != other.createdAt) return false;
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
      type,
      title,
      body,
      payloadHash,
      readAt,
      createdAt,
    );
  }

  @override
  String toString() => 'AppNotification(id: $id, type: $type, title: $title, '
      'readAt: $readAt)';
}
