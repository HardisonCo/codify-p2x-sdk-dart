import 'package:ycaas_flutter_sdk/src/client/p2x_client.dart';
import 'package:ycaas_flutter_sdk/src/comms/chat_models.dart';

/// Per-domain client for the **Chat** module.
///
/// Backs IBD's doctor↔patient messaging surface: list/create rooms,
/// page through history, send messages with attachments, and authorise
/// the Pusher/Echo private channel the realtime layer rides on.
///
/// All HTTP work routes through [P2xClient.request] so callers see typed
/// exceptions (e.g. [ValidationException], [UnauthorizedException]) at
/// the call site. POST/DELETE writes pick up an auto-generated
/// `Idempotency-Key` via the SDK's [IdempotencyInterceptor].
class ChatClient {
  /// Construct with a reference to the shared [P2xClient].
  ChatClient(this._client);

  final P2xClient _client;

  /// `GET /api/chat` — list the current user's chat rooms, optionally
  /// filtered by [search] (matched server-side against participant names
  /// and room labels).
  Future<List<ChatRoom>> listRooms({String? search}) {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/chat',
        queryParameters: <String, dynamic>{
          if (search != null) 'search': search,
        },
      );
      final body = response.data ?? const <String, dynamic>{};
      final raw = body['data'];
      if (raw is! List) return const <ChatRoom>[];
      return raw
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => ChatRoom.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    });
  }

  /// `POST /api/chat/room` — fetch the one-to-one room with [recipientId],
  /// creating it on the server if it doesn't yet exist.
  ///
  /// Idempotent by contract: calling this twice with the same
  /// [recipientId] returns the same room. [context] is an optional free-
  /// form hint the server stores against new rooms (e.g.
  /// `'appointment:7'`).
  Future<ChatRoom> getOrCreateRoom({
    required int recipientId,
    String? context,
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/chat/room',
        data: <String, dynamic>{
          'recipient_id': recipientId,
          if (context != null) 'context': context,
        },
      );
      final body = response.data ?? const <String, dynamic>{};
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError('POST /chat/room returned no "data" object.');
      }
      return ChatRoom.fromJson(data);
    });
  }

  /// `GET /api/chat/<roomId>` — fetch a single [ChatRoom] by primary key.
  Future<ChatRoom> getRoom(int roomId) {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/chat/$roomId',
      );
      final body = response.data ?? const <String, dynamic>{};
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError('GET /chat/$roomId returned no "data" object.');
      }
      return ChatRoom.fromJson(data);
    });
  }

  /// `GET /api/chat/<roomId>/messages?page=<n>&per_page=<n>` — page through
  /// the room's message history.
  ///
  /// Server returns the standard Laravel paginator envelope; the response
  /// is modelled by [PaginatedMessages] (`data`, `current_page`,
  /// `last_page`, `total`). Stop paging once `currentPage == lastPage`.
  Future<PaginatedMessages> messages(
    int roomId, {
    int page = 1,
    int perPage = 20,
  }) {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/chat/$roomId/messages',
        queryParameters: <String, dynamic>{
          'page': page,
          'per_page': perPage,
        },
      );
      final body = response.data ?? const <String, dynamic>{};
      return PaginatedMessages.fromJson(body);
    });
  }

  /// `POST /api/chat/send` — post a message into [roomId].
  ///
  /// The server returns the canonical saved row including its assigned
  /// `id` and `created_at`. Empty [body] with no [attachmentUrls] is
  /// rejected with a 422 — the SDK surfaces that as a
  /// `ValidationException` on the `body` field.
  Future<ChatMessage> send({
    required int roomId,
    required String body,
    List<String>? attachmentUrls,
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/chat/send',
        data: <String, dynamic>{
          'room_id': roomId,
          'body': body,
          if (attachmentUrls != null) 'attachment_urls': attachmentUrls,
        },
      );
      final responseBody = response.data ?? const <String, dynamic>{};
      final data = responseBody['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError('POST /chat/send returned no "data" object.');
      }
      return ChatMessage.fromJson(data);
    });
  }

  /// `POST /api/chat/start` — convenience: create (or fetch) a room with
  /// [recipientId] and post [firstMessage] in a single round trip.
  ///
  /// Idempotent at the room level — re-calling with the same
  /// [recipientId] won't create a duplicate room. The first message
  /// itself is deduped by the SDK's auto-generated `Idempotency-Key`.
  Future<ChatRoom> start({
    required int recipientId,
    required String firstMessage,
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/chat/start',
        data: <String, dynamic>{
          'recipient_id': recipientId,
          'first_message': firstMessage,
        },
      );
      final body = response.data ?? const <String, dynamic>{};
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError('POST /chat/start returned no "data" object.');
      }
      return ChatRoom.fromJson(data);
    });
  }

  /// `GET /api/chat/find-user?query=<query>` — search for users the
  /// current account is allowed to start a conversation with.
  ///
  /// Returns lightweight [UserSummary] records — enough to render search
  /// result rows. Use the returned `id` with [getOrCreateRoom] or
  /// [start].
  Future<List<UserSummary>> findUser({required String query}) {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/chat/find-user',
        queryParameters: <String, dynamic>{'query': query},
      );
      final body = response.data ?? const <String, dynamic>{};
      final raw = body['data'];
      if (raw is! List) return const <UserSummary>[];
      return raw
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => UserSummary.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    });
  }

  /// `DELETE /api/chat/message/<id>` — soft-delete a single message.
  ///
  /// Server enforces ownership rules (the message author and operators
  /// can delete; other participants cannot — they'll see a 403).
  Future<void> deleteMessage(int id) {
    return _client.request(() async {
      await _client.dio.delete<dynamic>('/chat/message/$id');
    });
  }

  /// `DELETE /api/chat/<roomId>` — delete a room and all its messages.
  ///
  /// Typically restricted to operators (support kind) or to one-to-one
  /// rooms the caller participates in. Group rooms with > 2 participants
  /// usually require admin-tier permissions; the server enforces the
  /// rule and returns 403 otherwise.
  Future<void> deleteRoom(int roomId) {
    return _client.request(() async {
      await _client.dio.delete<dynamic>('/chat/$roomId');
    });
  }

  /// `POST /api/broadcasting/auth` — sign a private/presence channel
  /// subscription for the Pusher / Laravel Echo websocket client.
  ///
  /// Pass the [channelName] (`private-chat.<roomId>` or
  /// `presence-chat.<roomId>`) and the websocket's transient
  /// [socketId]. The returned [BroadcastAuth.auth] string goes back to
  /// the websocket library verbatim.
  Future<BroadcastAuth> authBroadcast({
    required String channelName,
    required String socketId,
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/broadcasting/auth',
        data: <String, dynamic>{
          'channel_name': channelName,
          'socket_id': socketId,
        },
      );
      final body = response.data ?? const <String, dynamic>{};
      return BroadcastAuth.fromJson(body);
    });
  }
}
