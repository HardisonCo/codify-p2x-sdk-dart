// Tests for the Items module models (Item, Collection, UserItem) —
// plain @immutable data classes (no freezed).

import 'package:ycaas_flutter_sdk/src/modules/items_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Item', () {
    test('fromJson handles required fields', () {
      final item = Item.fromJson(<String, dynamic>{
        'id': 11,
        'subproject_id': 3,
        'type': 'meal',
        'name': 'Greek Yogurt Bowl',
        'description': 'Yogurt, berries, granola.',
        'payload': <String, dynamic>{'calories': 320},
        'created_at': '2026-05-01T08:00:00Z',
        'updated_at': '2026-05-01T08:00:00Z',
      });

      expect(item.id, 11);
      expect(item.subprojectId, 3);
      expect(item.type, 'meal');
      expect(item.name, 'Greek Yogurt Bowl');
      expect(item.description, 'Yogurt, berries, granola.');
      expect(item.imageUrl, isNull);
      expect(item.collectionId, isNull);
      expect(item.payload, <String, dynamic>{'calories': 320});
      expect(item.createdAt, DateTime.parse('2026-05-01T08:00:00Z'));
      expect(item.updatedAt, DateTime.parse('2026-05-01T08:00:00Z'));
    });

    test('fromJson handles optional image_url and collection_id', () {
      final item = Item.fromJson(<String, dynamic>{
        'id': 12,
        'subproject_id': 3,
        'type': 'meal',
        'name': 'Greek Yogurt Bowl',
        'description': 'Yogurt, berries, granola.',
        'image_url': 'https://cdn.example.com/yogurt.jpg',
        'collection_id': 99,
        'payload': <String, dynamic>{'calories': 320},
        'created_at': '2026-05-01T08:00:00Z',
        'updated_at': '2026-05-01T08:00:00Z',
      });

      expect(item.imageUrl, 'https://cdn.example.com/yogurt.jpg');
      expect(item.collectionId, 99);
    });

    test('fromJson treats missing payload as empty map', () {
      final item = Item.fromJson(<String, dynamic>{
        'id': 13,
        'subproject_id': 3,
        'type': 'kit',
        'name': 'Diabetes Kit',
        'description': 'Care kit.',
        'created_at': '2026-05-01T08:00:00Z',
        'updated_at': '2026-05-01T08:00:00Z',
      });

      expect(item.payload, isEmpty);
    });

    test('toJson round-trips through fromJson', () {
      final original = Item(
        id: 21,
        subprojectId: 3,
        type: 'meal',
        name: 'Salmon Salad',
        description: 'Greens, salmon, lemon.',
        imageUrl: 'https://cdn.example.com/salmon.jpg',
        payload: const <String, dynamic>{'calories': 480},
        collectionId: 7,
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-01T08:30:00Z'),
      );

      final roundTripped = Item.fromJson(original.toJson());
      expect(roundTripped, equals(original));
    });

    test('copyWith replaces only specified fields', () {
      final original = Item(
        id: 1,
        subprojectId: 3,
        type: 'meal',
        name: 'Original',
        description: 'd',
        payload: const <String, dynamic>{},
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );

      final copy = original.copyWith(name: 'Updated');

      expect(copy.name, 'Updated');
      expect(copy.id, 1);
      expect(copy.type, 'meal');
    });

    test('equality compares all fields including payload contents', () {
      final a = Item(
        id: 1,
        subprojectId: 3,
        type: 'meal',
        name: 'A',
        description: 'd',
        payload: const <String, dynamic>{'k': 1},
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );
      final b = Item(
        id: 1,
        subprojectId: 3,
        type: 'meal',
        name: 'A',
        description: 'd',
        payload: const <String, dynamic>{'k': 1},
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });
  });

  group('Collection', () {
    test('fromJson handles required fields', () {
      final c = Collection.fromJson(<String, dynamic>{
        'id': 7,
        'subproject_id': 3,
        'type': 'meal',
        'name': 'Mediterranean Meal Plan',
        'description': '7-day plan.',
        'item_count': 21,
        'created_at': '2026-05-01T08:00:00Z',
      });

      expect(c.id, 7);
      expect(c.subprojectId, 3);
      expect(c.type, 'meal');
      expect(c.name, 'Mediterranean Meal Plan');
      expect(c.description, '7-day plan.');
      expect(c.imageUrl, isNull);
      expect(c.itemCount, 21);
      expect(c.createdAt, DateTime.parse('2026-05-01T08:00:00Z'));
    });

    test('fromJson handles optional image_url', () {
      final c = Collection.fromJson(<String, dynamic>{
        'id': 7,
        'subproject_id': 3,
        'type': 'meal',
        'name': 'Plan',
        'description': 'd',
        'image_url': 'https://cdn.example.com/plan.jpg',
        'item_count': 5,
        'created_at': '2026-05-01T08:00:00Z',
      });

      expect(c.imageUrl, 'https://cdn.example.com/plan.jpg');
    });

    test('toJson round-trips through fromJson', () {
      final original = Collection(
        id: 8,
        subprojectId: 3,
        type: 'kit',
        name: 'Care Kits',
        description: 'd',
        imageUrl: 'https://cdn.example.com/kits.jpg',
        itemCount: 4,
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );

      final roundTripped = Collection.fromJson(original.toJson());
      expect(roundTripped, equals(original));
    });

    test('copyWith replaces only specified fields', () {
      final original = Collection(
        id: 1,
        subprojectId: 3,
        type: 'meal',
        name: 'Original',
        description: 'd',
        itemCount: 0,
        createdAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );
      final copy = original.copyWith(itemCount: 5);
      expect(copy.itemCount, 5);
      expect(copy.id, 1);
    });
  });

  group('UserItem', () {
    test('fromJson handles required fields without nested item', () {
      final u = UserItem.fromJson(<String, dynamic>{
        'id': 100,
        'user_id': 42,
        'item_id': 11,
        'metadata': <String, dynamic>{'folder': 'breakfast'},
        'saved_at': '2026-05-01T08:00:00Z',
      });

      expect(u.id, 100);
      expect(u.userId, 42);
      expect(u.itemId, 11);
      expect(u.item, isNull);
      expect(u.metadata, <String, dynamic>{'folder': 'breakfast'});
      expect(u.savedAt, DateTime.parse('2026-05-01T08:00:00Z'));
    });

    test('fromJson hydrates nested item when present', () {
      final u = UserItem.fromJson(<String, dynamic>{
        'id': 100,
        'user_id': 42,
        'item_id': 11,
        'item': <String, dynamic>{
          'id': 11,
          'subproject_id': 3,
          'type': 'meal',
          'name': 'Greek Yogurt Bowl',
          'description': 'd',
          'payload': <String, dynamic>{},
          'created_at': '2026-05-01T08:00:00Z',
          'updated_at': '2026-05-01T08:00:00Z',
        },
        'metadata': <String, dynamic>{},
        'saved_at': '2026-05-01T08:00:00Z',
      });

      expect(u.item, isNotNull);
      expect(u.item!.id, 11);
      expect(u.item!.name, 'Greek Yogurt Bowl');
    });

    test('fromJson treats missing metadata as empty map', () {
      final u = UserItem.fromJson(<String, dynamic>{
        'id': 100,
        'user_id': 42,
        'item_id': 11,
        'saved_at': '2026-05-01T08:00:00Z',
      });

      expect(u.metadata, isEmpty);
    });

    test('toJson round-trips through fromJson', () {
      final original = UserItem(
        id: 1,
        userId: 42,
        itemId: 11,
        metadata: const <String, dynamic>{'note': 'fav'},
        savedAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );

      final roundTripped = UserItem.fromJson(original.toJson());
      expect(roundTripped, equals(original));
    });

    test('copyWith replaces only specified fields', () {
      final original = UserItem(
        id: 1,
        userId: 42,
        itemId: 11,
        savedAt: DateTime.parse('2026-05-01T08:00:00Z'),
      );
      final copy = original.copyWith(
        metadata: const <String, dynamic>{'note': 'updated'},
      );
      expect(copy.metadata['note'], 'updated');
      expect(copy.id, 1);
    });
  });
}
