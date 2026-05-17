import 'package:meta/meta.dart';

/// A chat **room** — the durable container for a conversation between two
/// or more users.
///
/// IBD uses rooms for direct doctor↔patient chats (`kind: 'one_to_one'`),
/// multi-clinician group threads (`kind: 'group'`), and operator support
/// channels (`kind: 'support'`). Server owns membership; the SDK exposes
/// the participant id list verbatim so the client can render names from
/// its own user cache.
@immutable
class ChatRoom {
  /// Construct.
  const ChatRoom({
    required this.id,
    required this.subprojectId,
    required this.kind,
    required this.participants,
    required this.createdAt,
    this.name,
    this.lastMessageAt,
  });

  /// Decode from a JSON object. Permissive — missing `participants` decodes
  /// to an empty list; missing optional fields fall back to `null`.
  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    final rawParticipants = json['participants'];
    final participants = <int>[];
    if (rawParticipants is List) {
      for (final id in rawParticipants) {
        if (id is int) {
          participants.add(id);
        } else if (id is num) {
          participants.add(id.toInt());
        } else if (id is String) {
          final parsed = int.tryParse(id);
          if (parsed != null) participants.add(parsed);
        }
      }
    }
    return ChatRoom(
      id: json['id'] as int,
      subprojectId: json['subproject_id'] as int,
      kind: json['kind'] as String,
      name: json['name'] as String?,
      participants: participants,
      lastMessageAt: json['last_message_at'] is String
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Primary key.
  final int id;

  /// Subproject the room belongs to. Server-assigned from the `X-Domain`
  /// header at creation time.
  final int subprojectId;

  /// One of `one_to_one`, `group`, `support`. Drives UI affordances —
  /// the SDK doesn't enforce the enum so new server-side kinds flow
  /// through unchanged.
  final String kind;

  /// Display name. `null` for `one_to_one` rooms (which the UI typically
  /// labels with the other participant's name).
  final String? name;

  /// Participant user ids. Order is server-assigned.
  final List<int> participants;

  /// When the most recent message landed, when known. `null` for rooms
  /// that have no messages yet.
  final DateTime? lastMessageAt;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Encode to a JSON object. Symmetric with [ChatRoom.fromJson].
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'subproject_id': subprojectId,
      'kind': kind,
      if (name != null) 'name': name,
      'participants': participants,
      if (lastMessageAt != null)
        'last_message_at': lastMessageAt!.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Return a copy with the given fields replaced.
  ChatRoom copyWith({
    int? id,
    int? subprojectId,
    String? kind,
    String? name,
    List<int>? participants,
    DateTime? lastMessageAt,
    DateTime? createdAt,
  }) {
    return ChatRoom(
      id: id ?? this.id,
      subprojectId: subprojectId ?? this.subprojectId,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      participants: participants ?? this.participants,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ChatRoom) return false;
    if (id != other.id) return false;
    if (subprojectId != other.subprojectId) return false;
    if (kind != other.kind) return false;
    if (name != other.name) return false;
    if (lastMessageAt != other.lastMessageAt) return false;
    if (createdAt != other.createdAt) return false;
    if (participants.length != other.participants.length) return false;
    for (var i = 0; i < participants.length; i++) {
      if (participants[i] != other.participants[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    var partHash = 0;
    for (final p in participants) {
      partHash ^= p.hashCode;
    }
    return Object.hash(
      id,
      subprojectId,
      kind,
      name,
      partHash,
      lastMessageAt,
      createdAt,
    );
  }

  @override
  String toString() => 'ChatRoom(id: $id, kind: $kind, name: $name, '
      'participants: $participants, lastMessageAt: $lastMessageAt)';
}

/// A single chat **message** posted into a [ChatRoom].
///
/// Attachments are server-validated URLs (already uploaded via the host
/// app's media pipeline). The SDK passes them through verbatim. `readAt`
/// is the recipient-side read receipt timestamp; `null` while the message
/// is still unread.
@immutable
class ChatMessage {
  /// Construct.
  const ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.attachmentUrls = const <String>[],
    this.readAt,
  });

  /// Decode from a JSON object. Permissive — missing `attachment_urls`
  /// decodes to an empty list.
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final rawAttachments = json['attachment_urls'];
    final attachments = <String>[];
    if (rawAttachments is List) {
      for (final url in rawAttachments) {
        if (url is String) attachments.add(url);
      }
    }
    return ChatMessage(
      id: json['id'] as int,
      roomId: json['room_id'] as int,
      senderId: json['sender_id'] as int,
      body: json['body'] as String,
      attachmentUrls: attachments,
      readAt: json['read_at'] is String
          ? DateTime.parse(json['read_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Primary key.
  final int id;

  /// The room this message belongs to.
  final int roomId;

  /// User id of the sender.
  final int senderId;

  /// Message body. May be empty if the message carries only attachments
  /// — but `POST /api/chat/send` rejects empty body + empty attachments
  /// at the server.
  final String body;

  /// Attachment URLs. Always present; empty list if the message is text-
  /// only.
  final List<String> attachmentUrls;

  /// Recipient-side read receipt timestamp. `null` while unread.
  final DateTime? readAt;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Encode to a JSON object. Symmetric with [ChatMessage.fromJson].
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'room_id': roomId,
      'sender_id': senderId,
      'body': body,
      'attachment_urls': attachmentUrls,
      if (readAt != null) 'read_at': readAt!.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Return a copy with the given fields replaced.
  ChatMessage copyWith({
    int? id,
    int? roomId,
    int? senderId,
    String? body,
    List<String>? attachmentUrls,
    DateTime? readAt,
    DateTime? createdAt,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      senderId: senderId ?? this.senderId,
      body: body ?? this.body,
      attachmentUrls: attachmentUrls ?? this.attachmentUrls,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ChatMessage) return false;
    if (id != other.id) return false;
    if (roomId != other.roomId) return false;
    if (senderId != other.senderId) return false;
    if (body != other.body) return false;
    if (readAt != other.readAt) return false;
    if (createdAt != other.createdAt) return false;
    if (attachmentUrls.length != other.attachmentUrls.length) return false;
    for (var i = 0; i < attachmentUrls.length; i++) {
      if (attachmentUrls[i] != other.attachmentUrls[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    var urlHash = 0;
    for (final u in attachmentUrls) {
      urlHash ^= u.hashCode;
    }
    return Object.hash(id, roomId, senderId, body, urlHash, readAt, createdAt);
  }

  @override
  String toString() => 'ChatMessage(id: $id, roomId: $roomId, '
      'senderId: $senderId, body: $body, readAt: $readAt)';
}

/// A paginated page of [ChatMessage] rows, modelling Laravel's default
/// paginator envelope:
/// `{ data: [...], current_page: N, last_page: N, total: N }`.
///
/// Use [currentPage] / [lastPage] to drive infinite-scroll fetch logic;
/// stop once `currentPage == lastPage`.
@immutable
class PaginatedMessages {
  /// Construct.
  const PaginatedMessages({
    required this.data,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  /// Decode from a JSON object. Permissive — missing `data` decodes to
  /// an empty list; missing `current_page` / `last_page` default to `1`
  /// and missing `total` defaults to the row count.
  factory PaginatedMessages.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final messages = <ChatMessage>[];
    if (rawData is List) {
      for (final row in rawData) {
        if (row is Map) {
          messages.add(
            ChatMessage.fromJson(Map<String, dynamic>.from(row)),
          );
        }
      }
    }
    return PaginatedMessages(
      data: messages,
      currentPage:
          json['current_page'] is int ? json['current_page'] as int : 1,
      lastPage: json['last_page'] is int ? json['last_page'] as int : 1,
      total: json['total'] is int ? json['total'] as int : messages.length,
    );
  }

  /// The page of messages, ordered server-side (typically oldest-first
  /// within a page, newest page first).
  final List<ChatMessage> data;

  /// 1-indexed current page.
  final int currentPage;

  /// 1-indexed last page. When `currentPage == lastPage` there are no
  /// further pages to fetch.
  final int lastPage;

  /// Total message count across all pages.
  final int total;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PaginatedMessages) return false;
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
    for (final m in data) {
      dataHash ^= m.hashCode;
    }
    return Object.hash(dataHash, currentPage, lastPage, total);
  }

  @override
  String toString() => 'PaginatedMessages(currentPage: $currentPage, '
      'lastPage: $lastPage, total: $total, count: ${data.length})';
}

/// A lightweight user record returned by `GET /api/chat/find-user` — just
/// enough to render a search result row and start a conversation.
///
/// Use the user [id] as the `recipientId` argument to
/// `ChatClient.start` / `ChatClient.getOrCreateRoom`.
@immutable
class UserSummary {
  /// Construct.
  const UserSummary({
    required this.id,
    required this.name,
    this.photoUrl,
    this.role,
  });

  /// Decode from a JSON object.
  factory UserSummary.fromJson(Map<String, dynamic> json) {
    return UserSummary(
      id: json['id'] as int,
      name: json['name'] as String,
      photoUrl: json['photo_url'] as String?,
      role: json['role'] as String?,
    );
  }

  /// Primary key.
  final int id;

  /// Display name.
  final String name;

  /// Avatar URL, when known.
  final String? photoUrl;

  /// Role identifier — typically `doctor`, `patient`, `admin`. Drives
  /// UI affordances; the SDK doesn't enforce the enum.
  final String? role;

  /// Encode to a JSON object. Symmetric with [UserSummary.fromJson].
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      if (photoUrl != null) 'photo_url': photoUrl,
      if (role != null) 'role': role,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserSummary &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          photoUrl == other.photoUrl &&
          role == other.role;

  @override
  int get hashCode => Object.hash(id, name, photoUrl, role);

  @override
  String toString() => 'UserSummary(id: $id, name: $name, role: $role)';
}

/// The response payload from `POST /api/broadcasting/auth` — the standard
/// Pusher / Laravel Echo private-channel auth envelope.
///
/// `auth` is the signed string the websocket client passes back to the
/// Pusher / Echo server to subscribe. `channelData` is non-null only for
/// presence channels.
@immutable
class BroadcastAuth {
  /// Construct.
  const BroadcastAuth({
    required this.auth,
    this.channelData,
  });

  /// Decode from a JSON object.
  factory BroadcastAuth.fromJson(Map<String, dynamic> json) {
    final raw = json['channel_data'];
    final channelData = raw is Map ? Map<String, dynamic>.from(raw) : null;
    return BroadcastAuth(
      auth: json['auth'] as String,
      channelData: channelData,
    );
  }

  /// Signed auth string — opaque to the SDK, passed through to the
  /// websocket client unchanged.
  final String auth;

  /// Presence-channel member info, when applicable. `null` for plain
  /// private channels.
  final Map<String, dynamic>? channelData;

  /// Encode to a JSON object. Symmetric with [BroadcastAuth.fromJson].
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'auth': auth,
      if (channelData != null) 'channel_data': channelData,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! BroadcastAuth) return false;
    if (auth != other.auth) return false;
    final a = channelData;
    final b = other.channelData;
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key)) return false;
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    var dataHash = 0;
    final data = channelData;
    if (data != null) {
      for (final entry in data.entries) {
        dataHash ^= Object.hash(entry.key, entry.value);
      }
    }
    return Object.hash(auth, dataHash);
  }

  @override
  String toString() => 'BroadcastAuth(auth: $auth, '
      'channelData: $channelData)';
}
