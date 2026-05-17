// Tests for the AppNotification model — plain @immutable data class
// (no freezed). Named AppNotification to avoid clashing with Flutter's
// foundation Notification class.

import 'package:codify_p2x_sdk/src/comms/notification_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppNotification', () {
    test('fromJson handles required fields', () {
      final n = AppNotification.fromJson(<String, dynamic>{
        'id': 7,
        'type': 'appointment.reminder',
        'title': 'Your appointment is tomorrow',
        'body': 'Dr Bob — 10:00 am',
        'created_at': '2026-05-01T08:00:00Z',
      });

      expect(n.id, 7);
      expect(n.type, 'appointment.reminder');
      expect(n.title, 'Your appointment is tomorrow');
      expect(n.body, 'Dr Bob — 10:00 am');
      expect(n.payload, isEmpty);
      expect(n.readAt, isNull);
      expect(n.createdAt, DateTime.parse('2026-05-01T08:00:00Z'));
    });

    test('fromJson handles all optional fields', () {
      final n = AppNotification.fromJson(<String, dynamic>{
        'id': 7,
        'type': 'message.received',
        'title': 'New message from Dr Bob',
        'body': 'Tap to open',
        'payload': <String, dynamic>{'room_id': 11, 'message_id': 501},
        'read_at': '2026-05-01T09:00:00Z',
        'created_at': '2026-05-01T08:00:00Z',
      });

      expect(n.payload['room_id'], 11);
      expect(n.payload['message_id'], 501);
      expect(n.readAt, DateTime.parse('2026-05-01T09:00:00Z'));
    });

    test('fromJson defaults payload to empty map when missing', () {
      final n = AppNotification.fromJson(<String, dynamic>{
        'id': 1,
        'type': 'system',
        'title': 't',
        'body': 'b',
        'created_at': '2026-05-01T08:00:00Z',
      });

      expect(n.payload, isA<Map<String, dynamic>>());
      expect(n.payload, isEmpty);
    });

    test('toJson round-trips back to fromJson identity', () {
      final original = AppNotification(
        id: 7,
        type: 'message.received',
        title: 'New message',
        body: 'Tap to open',
        payload: const <String, dynamic>{'room_id': 11},
        readAt: DateTime.parse('2026-05-01T09:00:00Z'),
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );

      final round = AppNotification.fromJson(original.toJson());

      expect(round, equals(original));
      expect(round.hashCode, equals(original.hashCode));
    });

    test('copyWith with no args returns equal instance', () {
      final n = AppNotification(
        id: 7,
        type: 'system',
        title: 't',
        body: 'b',
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );

      expect(n.copyWith(), equals(n));
    });

    test('copyWith updates a single field', () {
      final n = AppNotification(
        id: 7,
        type: 'system',
        title: 't',
        body: 'b',
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );
      final read = n.copyWith(readAt: DateTime.parse('2026-05-01T09:00:00Z'));

      expect(read.readAt, DateTime.parse('2026-05-01T09:00:00Z'));
      expect(read.id, n.id);
      expect(read, isNot(equals(n)));
    });

    test('two equal instances are == and have equal hashCode', () {
      final a = AppNotification(
        id: 1,
        type: 't',
        title: 'title',
        body: 'body',
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );
      final b = AppNotification(
        id: 1,
        type: 't',
        title: 'title',
        body: 'body',
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString includes class name, id, type', () {
      final n = AppNotification(
        id: 7,
        type: 'message.received',
        title: 't',
        body: 'b',
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );

      final s = n.toString();
      expect(s, contains('AppNotification'));
      expect(s, contains('7'));
      expect(s, contains('message.received'));
    });
  });
}
