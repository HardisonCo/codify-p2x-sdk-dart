// Tests for chat models — plain @immutable data classes (no freezed).
//
// Covers:
//   * ChatRoom    — one-to-one, group, support kinds; optional lastMessageAt
//   * ChatMessage — attachment-url list defaults; readAt optional
//   * PaginatedMessages — Laravel paginator envelope shape
//   * UserSummary — lightweight user record returned by /chat/find-user
//   * BroadcastAuth — Pusher/Echo channel auth payload

import 'package:codify_p2x_sdk/src/comms/chat_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatRoom', () {
    test('fromJson handles required fields', () {
      final r = ChatRoom.fromJson(<String, dynamic>{
        'id': 11,
        'subproject_id': 3,
        'kind': 'one_to_one',
        'participants': <int>[42, 99],
        'created_at': '2026-05-01T08:00:00Z',
      });

      expect(r.id, 11);
      expect(r.subprojectId, 3);
      expect(r.kind, 'one_to_one');
      expect(r.participants, <int>[42, 99]);
      expect(r.name, isNull);
      expect(r.lastMessageAt, isNull);
      expect(r.createdAt, DateTime.parse('2026-05-01T08:00:00Z'));
    });

    test('fromJson handles all optional fields', () {
      final r = ChatRoom.fromJson(<String, dynamic>{
        'id': 11,
        'subproject_id': 3,
        'kind': 'group',
        'name': 'IBD Clinicians',
        'participants': <int>[1, 2, 3],
        'last_message_at': '2026-05-02T09:00:00Z',
        'created_at': '2026-05-01T08:00:00Z',
      });

      expect(r.kind, 'group');
      expect(r.name, 'IBD Clinicians');
      expect(r.lastMessageAt, DateTime.parse('2026-05-02T09:00:00Z'));
    });

    test('fromJson coerces participants from mixed numeric input', () {
      final r = ChatRoom.fromJson(<String, dynamic>{
        'id': 11,
        'subproject_id': 3,
        'kind': 'support',
        'participants': <dynamic>[1, 2, 3],
        'created_at': '2026-05-01T08:00:00Z',
      });

      expect(r.participants, <int>[1, 2, 3]);
      expect(r.kind, 'support');
    });

    test('fromJson defaults participants to empty list when missing', () {
      final r = ChatRoom.fromJson(<String, dynamic>{
        'id': 11,
        'subproject_id': 3,
        'kind': 'one_to_one',
        'created_at': '2026-05-01T08:00:00Z',
      });

      expect(r.participants, isEmpty);
    });

    test('toJson round-trips back to fromJson identity', () {
      final original = ChatRoom(
        id: 11,
        subprojectId: 3,
        kind: 'group',
        name: 'IBD Clinicians',
        participants: const <int>[1, 2, 3],
        lastMessageAt: DateTime.parse('2026-05-02T09:00:00Z'),
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );

      final round = ChatRoom.fromJson(original.toJson());

      expect(round, equals(original));
      expect(round.hashCode, equals(original.hashCode));
    });

    test('copyWith with no args returns equal instance', () {
      final r = ChatRoom(
        id: 11,
        subprojectId: 3,
        kind: 'one_to_one',
        participants: const <int>[1, 2],
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );

      expect(r.copyWith(), equals(r));
    });

    test('two equal instances are == and have equal hashCode', () {
      final a = ChatRoom(
        id: 11,
        subprojectId: 3,
        kind: 'one_to_one',
        participants: const <int>[1, 2],
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );
      final b = ChatRoom(
        id: 11,
        subprojectId: 3,
        kind: 'one_to_one',
        participants: const <int>[1, 2],
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString includes class name, id, kind', () {
      final r = ChatRoom(
        id: 11,
        subprojectId: 3,
        kind: 'group',
        participants: const <int>[1, 2],
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );
      final s = r.toString();

      expect(s, contains('ChatRoom'));
      expect(s, contains('11'));
      expect(s, contains('group'));
    });
  });

  group('ChatMessage', () {
    test('fromJson handles required fields', () {
      final m = ChatMessage.fromJson(<String, dynamic>{
        'id': 501,
        'room_id': 11,
        'sender_id': 42,
        'body': 'Hello, doctor.',
        'created_at': '2026-05-01T08:00:00Z',
      });

      expect(m.id, 501);
      expect(m.roomId, 11);
      expect(m.senderId, 42);
      expect(m.body, 'Hello, doctor.');
      expect(m.attachmentUrls, isEmpty);
      expect(m.readAt, isNull);
      expect(m.createdAt, DateTime.parse('2026-05-01T08:00:00Z'));
    });

    test('fromJson decodes attachment_urls and read_at', () {
      final m = ChatMessage.fromJson(<String, dynamic>{
        'id': 501,
        'room_id': 11,
        'sender_id': 42,
        'body': 'See attached.',
        'attachment_urls': <String>[
          'https://cdn.example.com/a.pdf',
          'https://cdn.example.com/b.png',
        ],
        'read_at': '2026-05-01T09:00:00Z',
        'created_at': '2026-05-01T08:00:00Z',
      });

      expect(m.attachmentUrls, hasLength(2));
      expect(m.attachmentUrls.first, 'https://cdn.example.com/a.pdf');
      expect(m.readAt, DateTime.parse('2026-05-01T09:00:00Z'));
    });

    test('fromJson defaults attachmentUrls to empty list when missing', () {
      final m = ChatMessage.fromJson(<String, dynamic>{
        'id': 1,
        'room_id': 11,
        'sender_id': 42,
        'body': 'hi',
        'created_at': '2026-05-01T08:00:00Z',
      });

      expect(m.attachmentUrls, isA<List<String>>());
      expect(m.attachmentUrls, isEmpty);
    });

    test('toJson round-trips back to fromJson identity', () {
      final original = ChatMessage(
        id: 501,
        roomId: 11,
        senderId: 42,
        body: 'See attached.',
        attachmentUrls: const <String>['https://cdn.example.com/a.pdf'],
        readAt: DateTime.parse('2026-05-01T09:00:00Z'),
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );

      final round = ChatMessage.fromJson(original.toJson());

      expect(round, equals(original));
      expect(round.hashCode, equals(original.hashCode));
    });

    test('copyWith updates a single field', () {
      final m = ChatMessage(
        id: 501,
        roomId: 11,
        senderId: 42,
        body: 'hi',
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );
      final read = m.copyWith(readAt: DateTime.parse('2026-05-01T09:00:00Z'));

      expect(read.readAt, DateTime.parse('2026-05-01T09:00:00Z'));
      expect(read.body, m.body);
      expect(read, isNot(equals(m)));
    });

    test('toString includes class name, id, roomId', () {
      final m = ChatMessage(
        id: 501,
        roomId: 11,
        senderId: 42,
        body: 'hi',
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );

      final s = m.toString();
      expect(s, contains('ChatMessage'));
      expect(s, contains('501'));
      expect(s, contains('11'));
    });
  });

  group('PaginatedMessages', () {
    test('fromJson decodes the Laravel paginator envelope', () {
      final p = PaginatedMessages.fromJson(<String, dynamic>{
        'data': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 501,
            'room_id': 11,
            'sender_id': 42,
            'body': 'first',
            'created_at': '2026-05-01T08:00:00Z',
          },
          <String, dynamic>{
            'id': 502,
            'room_id': 11,
            'sender_id': 99,
            'body': 'second',
            'created_at': '2026-05-01T08:01:00Z',
          },
        ],
        'current_page': 2,
        'last_page': 5,
        'total': 100,
      });

      expect(p.data, hasLength(2));
      expect(p.data.first.id, 501);
      expect(p.data.last.id, 502);
      expect(p.currentPage, 2);
      expect(p.lastPage, 5);
      expect(p.total, 100);
    });

    test('fromJson defaults to safe values when fields missing', () {
      final p = PaginatedMessages.fromJson(<String, dynamic>{
        'data': <Map<String, dynamic>>[],
      });

      expect(p.data, isEmpty);
      expect(p.currentPage, 1);
      expect(p.lastPage, 1);
      expect(p.total, 0);
    });

    test('fromJson handles a single-page envelope', () {
      final p = PaginatedMessages.fromJson(<String, dynamic>{
        'data': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 501,
            'room_id': 11,
            'sender_id': 42,
            'body': 'only',
            'created_at': '2026-05-01T08:00:00Z',
          },
        ],
        'current_page': 1,
        'last_page': 1,
        'total': 1,
      });

      expect(p.data, hasLength(1));
      expect(p.currentPage, 1);
      expect(p.lastPage, 1);
      expect(p.total, 1);
    });

    test('two equal instances are == and have equal hashCode', () {
      final msg = ChatMessage(
        id: 1,
        roomId: 11,
        senderId: 42,
        body: 'hi',
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );
      final a = PaginatedMessages(
        data: <ChatMessage>[msg],
        currentPage: 1,
        lastPage: 1,
        total: 1,
      );
      final b = PaginatedMessages(
        data: <ChatMessage>[msg],
        currentPage: 1,
        lastPage: 1,
        total: 1,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString includes class name and counts', () {
      final p = PaginatedMessages(
        data: const <ChatMessage>[],
        currentPage: 2,
        lastPage: 5,
        total: 100,
      );

      final s = p.toString();
      expect(s, contains('PaginatedMessages'));
      expect(s, contains('2'));
      expect(s, contains('5'));
      expect(s, contains('100'));
    });
  });

  group('UserSummary', () {
    test('fromJson handles required fields', () {
      final u = UserSummary.fromJson(<String, dynamic>{
        'id': 42,
        'name': 'Alice Patient',
      });

      expect(u.id, 42);
      expect(u.name, 'Alice Patient');
      expect(u.photoUrl, isNull);
      expect(u.role, isNull);
    });

    test('fromJson handles all optional fields', () {
      final u = UserSummary.fromJson(<String, dynamic>{
        'id': 42,
        'name': 'Dr Bob',
        'photo_url': 'https://cdn.example.com/dr-bob.jpg',
        'role': 'doctor',
      });

      expect(u.photoUrl, 'https://cdn.example.com/dr-bob.jpg');
      expect(u.role, 'doctor');
    });

    test('toJson round-trips back to fromJson identity', () {
      const original = UserSummary(
        id: 42,
        name: 'Dr Bob',
        photoUrl: 'https://cdn.example.com/dr-bob.jpg',
        role: 'doctor',
      );

      final round = UserSummary.fromJson(original.toJson());

      expect(round, equals(original));
      expect(round.hashCode, equals(original.hashCode));
    });

    test('two equal instances are == and have equal hashCode', () {
      const a = UserSummary(id: 1, name: 'A');
      const b = UserSummary(id: 1, name: 'A');

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString includes class name, id, name', () {
      const u = UserSummary(id: 42, name: 'Alice');
      final s = u.toString();

      expect(s, contains('UserSummary'));
      expect(s, contains('42'));
      expect(s, contains('Alice'));
    });
  });

  group('BroadcastAuth', () {
    test('fromJson handles auth-only payload', () {
      final b = BroadcastAuth.fromJson(<String, dynamic>{
        'auth': 'app-key:signature',
      });

      expect(b.auth, 'app-key:signature');
      expect(b.channelData, isNull);
    });

    test('fromJson handles channel_data', () {
      final b = BroadcastAuth.fromJson(<String, dynamic>{
        'auth': 'app-key:signature',
        'channel_data': <String, dynamic>{
          'user_id': 42,
          'user_info': <String, dynamic>{'name': 'Alice'},
        },
      });

      expect(b.channelData, isNotNull);
      expect(b.channelData!['user_id'], 42);
    });

    test('toJson round-trips back to fromJson identity', () {
      const original = BroadcastAuth(
        auth: 'app-key:signature',
        channelData: <String, dynamic>{'user_id': 42},
      );

      final round = BroadcastAuth.fromJson(original.toJson());

      expect(round, equals(original));
      expect(round.hashCode, equals(original.hashCode));
    });

    test('toString includes class name', () {
      const b = BroadcastAuth(auth: 'app-key:signature');
      expect(b.toString(), contains('BroadcastAuth'));
    });
  });
}
