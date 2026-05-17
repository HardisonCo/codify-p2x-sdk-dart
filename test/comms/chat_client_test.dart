// Contract tests for ChatClient.
//
// Covers the 10 endpoints from CommunicationsApiClient:
//
//   GET    /api/chat                          — listRooms
//   POST   /api/chat/room                     — getOrCreateRoom
//   GET    /api/chat/{roomId}                 — getRoom
//   GET    /api/chat/{roomId}/messages        — messages (paginated)
//   POST   /api/chat/send                     — send
//   POST   /api/chat/start                    — start
//   GET    /api/chat/find-user                — findUser
//   DELETE /api/chat/message/{id}             — deleteMessage
//   DELETE /api/chat/{roomId}                 — deleteRoom
//   POST   /api/broadcasting/auth             — authBroadcast
//
// IdempotencyInterceptor auto-injects an Idempotency-Key header on all
// mutating requests; we assert presence on every POST in this suite. We
// also verify ValidationException surfaces on POST /api/chat/send with
// an empty body, and UnauthorizedException on a 401 read.

import 'package:codify_p2x_sdk/src/client/exceptions/unauthorized_exception.dart';
import 'package:codify_p2x_sdk/src/client/exceptions/validation_exception.dart';
import 'package:codify_p2x_sdk/src/client/p2x_client.dart';
import 'package:codify_p2x_sdk/src/client/p2x_client_config.dart';
import 'package:codify_p2x_sdk/src/comms/chat_client.dart';
import 'package:codify_p2x_sdk/src/comms/chat_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

void main() {
  late P2xClient base;
  late DioAdapter adapter;
  late ChatClient chat;

  Map<String, dynamic> sampleRoom({
    int id = 11,
    String kind = 'one_to_one',
    String? name,
    List<int> participants = const <int>[42, 99],
    String? lastMessageAt,
  }) =>
      <String, dynamic>{
        'id': id,
        'subproject_id': 3,
        'kind': kind,
        if (name != null) 'name': name,
        'participants': participants,
        if (lastMessageAt != null) 'last_message_at': lastMessageAt,
        'created_at': '2026-05-01T08:00:00Z',
      };

  Map<String, dynamic> sampleMessage({
    int id = 501,
    int roomId = 11,
    int senderId = 42,
    String body = 'hi',
    List<String>? attachmentUrls,
    String? readAt,
  }) =>
      <String, dynamic>{
        'id': id,
        'room_id': roomId,
        'sender_id': senderId,
        'body': body,
        if (attachmentUrls != null) 'attachment_urls': attachmentUrls,
        if (readAt != null) 'read_at': readAt,
        'created_at': '2026-05-01T08:00:00Z',
      };

  setUp(() {
    base = P2xClient(
      config: P2xClientConfig(
        baseUrl: 'https://api.project20x.com/api',
        getToken: () => 'tok-abc',
        getDomain: () => 'crohnie.ai',
      ),
    );
    adapter = DioAdapter(dio: base.dio);
    chat = ChatClient(base);
  });

  group('ChatClient.listRooms', () {
    test('GETs /chat and returns the decoded ChatRoom list', () async {
      adapter.onGet(
        '/chat',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[
            sampleRoom(),
            sampleRoom(id: 12, kind: 'group', name: 'IBD Clinicians'),
          ],
        }),
      );

      final list = await chat.listRooms();

      expect(list, hasLength(2));
      expect(list.first.id, 11);
      expect(list.last.kind, 'group');
      expect(list.last.name, 'IBD Clinicians');
    });

    test('GETs /chat with search query when provided', () async {
      adapter.onGet(
        '/chat',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[sampleRoom()],
        }),
        queryParameters: <String, dynamic>{'search': 'bob'},
      );

      final list = await chat.listRooms(search: 'bob');
      expect(list, hasLength(1));
    });

    test('returns empty list when server returns no rows', () async {
      adapter.onGet(
        '/chat',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[],
        }),
      );

      final list = await chat.listRooms();
      expect(list, isEmpty);
    });

    test('401 surfaces as UnauthorizedException', () async {
      adapter.onGet(
        '/chat',
        (req) => req.reply(401, <String, dynamic>{
          'success': false,
          'message': 'Unauthenticated',
        }),
      );

      await expectLater(
        chat.listRooms(),
        throwsA(isA<UnauthorizedException>()),
      );
    });
  });

  group('ChatClient.getOrCreateRoom', () {
    test('POSTs /chat/room and returns the (new or existing) ChatRoom',
        () async {
      adapter.onPost(
        '/chat/room',
        (req) => req.reply(200, <String, dynamic>{
          'data': sampleRoom(),
        }),
        data: <String, dynamic>{'recipient_id': 99},
      );

      final room = await chat.getOrCreateRoom(recipientId: 99);

      expect(room, isA<ChatRoom>());
      expect(room.id, 11);
      expect(room.participants, contains(99));
    });

    test('forwards context when provided', () async {
      adapter.onPost(
        '/chat/room',
        (req) => req.reply(200, <String, dynamic>{
          'data': sampleRoom(),
        }),
        data: <String, dynamic>{
          'recipient_id': 99,
          'context': 'appointment:7',
        },
      );

      final room = await chat.getOrCreateRoom(
        recipientId: 99,
        context: 'appointment:7',
      );
      expect(room.id, 11);
    });

    test('Idempotency-Key header is auto-attached', () async {
      adapter.onPost(
        '/chat/room',
        (req) => req.reply(200, <String, dynamic>{
          'data': sampleRoom(),
        }),
        data: Matchers.any,
      );

      final resp = await base.dio.post<dynamic>(
        '/chat/room',
        data: <String, dynamic>{'recipient_id': 99},
      );

      expect(
        resp.requestOptions.headers['Idempotency-Key'],
        isA<String>(),
      );
      expect(
        (resp.requestOptions.headers['Idempotency-Key'] as String).isNotEmpty,
        isTrue,
      );
    });
  });

  group('ChatClient.getRoom', () {
    test('GETs /chat/<roomId> and returns the ChatRoom', () async {
      adapter.onGet(
        '/chat/11',
        (req) => req.reply(200, <String, dynamic>{
          'data': sampleRoom(),
        }),
      );

      final room = await chat.getRoom(11);

      expect(room.id, 11);
      expect(room.subprojectId, 3);
    });
  });

  group('ChatClient.messages', () {
    test('GETs /chat/<roomId>/messages with default pagination', () async {
      adapter.onGet(
        '/chat/11/messages',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[
            sampleMessage(),
            sampleMessage(id: 502, body: 'second'),
          ],
          'current_page': 1,
          'last_page': 1,
          'total': 2,
        }),
        queryParameters: <String, dynamic>{
          'page': 1,
          'per_page': 20,
        },
      );

      final page = await chat.messages(11);

      expect(page, isA<PaginatedMessages>());
      expect(page.data, hasLength(2));
      expect(page.currentPage, 1);
      expect(page.lastPage, 1);
      expect(page.total, 2);
    });

    test('GETs /chat/<roomId>/messages with custom pagination', () async {
      adapter.onGet(
        '/chat/11/messages',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[sampleMessage()],
          'current_page': 3,
          'last_page': 7,
          'total': 140,
        }),
        queryParameters: <String, dynamic>{
          'page': 3,
          'per_page': 50,
        },
      );

      final page = await chat.messages(11, page: 3, perPage: 50);
      expect(page.currentPage, 3);
      expect(page.lastPage, 7);
      expect(page.total, 140);
      expect(page.data, hasLength(1));
    });

    test('decodes Laravel paginator envelope with attachment_urls', () async {
      adapter.onGet(
        '/chat/11/messages',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[
            sampleMessage(
              attachmentUrls: <String>['https://cdn.example.com/a.pdf'],
              readAt: '2026-05-01T09:00:00Z',
            ),
          ],
          'current_page': 1,
          'last_page': 1,
          'total': 1,
        }),
        queryParameters: <String, dynamic>{
          'page': 1,
          'per_page': 20,
        },
      );

      final page = await chat.messages(11);
      expect(page.data.first.attachmentUrls, hasLength(1));
      expect(page.data.first.readAt, DateTime.parse('2026-05-01T09:00:00Z'));
    });
  });

  group('ChatClient.send', () {
    test('POSTs /chat/send and returns the saved ChatMessage', () async {
      adapter.onPost(
        '/chat/send',
        (req) => req.reply(201, <String, dynamic>{
          'data': sampleMessage(body: 'Hello, doctor.'),
        }),
        data: <String, dynamic>{
          'room_id': 11,
          'body': 'Hello, doctor.',
        },
      );

      final msg = await chat.send(roomId: 11, body: 'Hello, doctor.');

      expect(msg, isA<ChatMessage>());
      expect(msg.id, 501);
      expect(msg.body, 'Hello, doctor.');
    });

    test('forwards attachment_urls when provided', () async {
      adapter.onPost(
        '/chat/send',
        (req) => req.reply(201, <String, dynamic>{
          'data': sampleMessage(
            attachmentUrls: <String>['https://cdn.example.com/a.pdf'],
          ),
        }),
        data: <String, dynamic>{
          'room_id': 11,
          'body': 'See attached.',
          'attachment_urls': <String>['https://cdn.example.com/a.pdf'],
        },
      );

      final msg = await chat.send(
        roomId: 11,
        body: 'See attached.',
        attachmentUrls: const <String>['https://cdn.example.com/a.pdf'],
      );
      expect(msg.attachmentUrls, hasLength(1));
    });

    test('422 surfaces as ValidationException with field errors', () async {
      adapter.onPost(
        '/chat/send',
        (req) => req.reply(422, <String, dynamic>{
          'success': false,
          'message': 'The body field is required.',
          'errors': <String, dynamic>{
            'body': <String>['The body field is required.'],
          },
        }),
        data: Matchers.any,
      );

      try {
        await chat.send(roomId: 11, body: '');
        fail('Expected ValidationException');
      } on ValidationException catch (e) {
        expect(e.errors, contains('body'));
        expect(e.errors['body'], isNotEmpty);
      }
    });

    test('Idempotency-Key header is auto-attached', () async {
      adapter.onPost(
        '/chat/send',
        (req) => req.reply(201, <String, dynamic>{
          'data': sampleMessage(),
        }),
        data: Matchers.any,
      );

      final resp = await base.dio.post<dynamic>(
        '/chat/send',
        data: <String, dynamic>{'room_id': 11, 'body': 'hi'},
      );

      expect(
        resp.requestOptions.headers['Idempotency-Key'],
        isA<String>(),
      );
    });
  });

  group('ChatClient.start', () {
    test('POSTs /chat/start and returns the room with first message', () async {
      adapter.onPost(
        '/chat/start',
        (req) => req.reply(201, <String, dynamic>{
          'data': sampleRoom(lastMessageAt: '2026-05-01T08:00:00Z'),
        }),
        data: <String, dynamic>{
          'recipient_id': 99,
          'first_message': 'Hello, doctor.',
        },
      );

      final room = await chat.start(
        recipientId: 99,
        firstMessage: 'Hello, doctor.',
      );
      expect(room.id, 11);
      expect(room.lastMessageAt, isNotNull);
    });

    test('Idempotency-Key header is auto-attached', () async {
      adapter.onPost(
        '/chat/start',
        (req) => req.reply(201, <String, dynamic>{
          'data': sampleRoom(),
        }),
        data: Matchers.any,
      );

      final resp = await base.dio.post<dynamic>(
        '/chat/start',
        data: <String, dynamic>{
          'recipient_id': 99,
          'first_message': 'hi',
        },
      );

      expect(
        resp.requestOptions.headers['Idempotency-Key'],
        isA<String>(),
      );
    });
  });

  group('ChatClient.findUser', () {
    test('GETs /chat/find-user with query param and decodes summaries',
        () async {
      adapter.onGet(
        '/chat/find-user',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 42,
              'name': 'Alice Patient',
              'role': 'patient',
            },
            <String, dynamic>{
              'id': 99,
              'name': 'Dr Bob',
              'photo_url': 'https://cdn.example.com/dr-bob.jpg',
              'role': 'doctor',
            },
          ],
        }),
        queryParameters: <String, dynamic>{'query': 'bob'},
      );

      final list = await chat.findUser(query: 'bob');

      expect(list, hasLength(2));
      expect(list.first.name, 'Alice Patient');
      expect(list.last.role, 'doctor');
      expect(list.last.photoUrl, 'https://cdn.example.com/dr-bob.jpg');
    });

    test('returns empty list when nobody matches', () async {
      adapter.onGet(
        '/chat/find-user',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[],
        }),
        queryParameters: <String, dynamic>{'query': 'nope'},
      );

      final list = await chat.findUser(query: 'nope');
      expect(list, isEmpty);
    });
  });

  group('ChatClient.deleteMessage', () {
    test('DELETEs /chat/message/<id> and completes', () async {
      adapter.onDelete(
        '/chat/message/501',
        (req) => req.reply(204, null),
      );

      await chat.deleteMessage(501);
    });

    test('DELETE carries an auto-generated Idempotency-Key', () async {
      adapter.onDelete(
        '/chat/message/501',
        (req) => req.reply(204, null),
      );

      final resp = await base.dio.delete<dynamic>('/chat/message/501');
      expect(
        resp.requestOptions.headers['Idempotency-Key'],
        isA<String>(),
      );
    });
  });

  group('ChatClient.deleteRoom', () {
    test('DELETEs /chat/<roomId> and completes', () async {
      adapter.onDelete(
        '/chat/11',
        (req) => req.reply(204, null),
      );

      await chat.deleteRoom(11);
    });
  });

  group('ChatClient.authBroadcast', () {
    test('POSTs /broadcasting/auth and returns BroadcastAuth', () async {
      adapter.onPost(
        '/broadcasting/auth',
        (req) => req.reply(200, <String, dynamic>{
          'auth': 'app-key:signature',
        }),
        data: <String, dynamic>{
          'channel_name': 'private-chat.11',
          'socket_id': '12345.6789',
        },
      );

      final auth = await chat.authBroadcast(
        channelName: 'private-chat.11',
        socketId: '12345.6789',
      );

      expect(auth, isA<BroadcastAuth>());
      expect(auth.auth, 'app-key:signature');
      expect(auth.channelData, isNull);
    });

    test('decodes presence channel_data when present', () async {
      adapter.onPost(
        '/broadcasting/auth',
        (req) => req.reply(200, <String, dynamic>{
          'auth': 'app-key:signature',
          'channel_data': <String, dynamic>{
            'user_id': 42,
            'user_info': <String, dynamic>{'name': 'Alice'},
          },
        }),
        data: Matchers.any,
      );

      final auth = await chat.authBroadcast(
        channelName: 'presence-chat.11',
        socketId: '12345.6789',
      );

      expect(auth.channelData, isNotNull);
      expect(auth.channelData!['user_id'], 42);
    });

    test('Idempotency-Key header is auto-attached', () async {
      adapter.onPost(
        '/broadcasting/auth',
        (req) => req.reply(200, <String, dynamic>{
          'auth': 'app-key:signature',
        }),
        data: Matchers.any,
      );

      final resp = await base.dio.post<dynamic>(
        '/broadcasting/auth',
        data: <String, dynamic>{
          'channel_name': 'private-chat.11',
          'socket_id': '12345.6789',
        },
      );

      expect(
        resp.requestOptions.headers['Idempotency-Key'],
        isA<String>(),
      );
    });
  });

  // Sanity: avoid unused-import warning for Dio in the test file. We use
  // it implicitly via base.dio above, but reference here for clarity.
  test('Dio adapter is wired', () {
    expect(base.dio, isA<Dio>());
  });
}
