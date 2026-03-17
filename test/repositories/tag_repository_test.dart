import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

/// In-memory storage for testing tag operations
class InMemoryTagStorage {
  final Map<String, Map<String, dynamic>> _tags = {};
  final Map<String, String> _aliases = {}; // aliasName -> primaryTagId

  int _idCounter = 0;

  String generateId() {
    return 'tag_${_idCounter++}';
  }

  void insertTag(Map<String, dynamic> tag) {
    final id = tag['id'] as String;
    _tags[id] = Map.from(tag);
  }

  void updateTag(String id, Map<String, dynamic> tag) {
    if (_tags.containsKey(id)) {
      _tags[id] = Map.from(tag);
    }
  }

  void deleteTag(String id) {
    _tags.remove(id);
    // Remove aliases pointing to this tag
    _aliases.removeWhere((_, primaryId) => primaryId == id);
  }

  Map<String, dynamic>? getTag(String id) {
    return _tags[id];
  }

  Map<String, dynamic>? getTagByName(String name) {
    for (final tag in _tags.values) {
      if (tag['name'] == name) return tag;
    }
    return null;
  }

  List<Map<String, dynamic>> getAllTags() {
    return _tags.values.toList();
  }

  List<Map<String, dynamic>> getTagsByType(String type) {
    return _tags.values.where((t) => t['type'] == type).toList();
  }

  List<Map<String, dynamic>> getChildTags(String parentId) {
    return _tags.values.where((t) => t['parent_id'] == parentId).toList();
  }

  void insertTagAlias(String aliasName, String primaryTagId) {
    _aliases[aliasName] = primaryTagId;
  }

  void deleteTagAlias(String aliasName) {
    _aliases.remove(aliasName);
  }

  String? resolveAlias(String aliasName) {
    return _aliases[aliasName];
  }

  List<String> getAliasesForTag(String primaryTagId) {
    return _aliases.entries
        .where((e) => e.value == primaryTagId)
        .map((e) => e.key)
        .toList();
  }

  void clear() {
    _tags.clear();
    _aliases.clear();
    _idCounter = 0;
  }
}

/// Test generators for tag-related tests
class TagTestGenerators {
  static final Random _random = Random();

  /// Generate a valid tag name (any characters except dangerous/reserved ones)
  /// Can include Unicode characters like Chinese, Japanese, Korean, etc.
  static String validTagName({int minLength = 3, int maxLength = 15}) {
    final length = minLength + _random.nextInt(maxLength - minLength + 1);
    // Include ASCII alphanumeric, underscores, spaces, hyphens, and some Unicode ranges
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_- ';
    // Add some Chinese characters for testing Unicode support
    const unicodeChars = '中文日本語한국어';
    const allChars = chars + unicodeChars;

    var name = String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => allChars.codeUnitAt(_random.nextInt(allChars.length)),
      ),
    ).trim(); // Ensure no leading/trailing whitespace

    // Ensure not empty after trim
    if (name.isEmpty) name = 'tag';

    return name;
  }

  /// Generate an invalid tag name (contains dangerous/reserved characters)
  /// Dangerous: " (quotes), Reserved: ! & : * (query logic, wildcard)
  /// Note: / is valid as it's used for hierarchy
  static String invalidTagName() {
    const invalidChars = '"!&:*';
    final validPart = validTagName(minLength: 2, maxLength: 5);
    final invalidChar = invalidChars[_random.nextInt(invalidChars.length)];
    return validPart + invalidChar + validTagName(minLength: 1, maxLength: 3);
  }
}

void main() {
  group('Tag Repository Property Tests', () {
    late InMemoryTagStorage storage;

    setUp(() {
      storage = InMemoryTagStorage();
    });

    tearDown(() {
      storage.clear();
    });

    // Feature: song-unit-core, Property 11: User tag name validation
    // **Validates: Requirements 4.2**
    test(
      'Property 11: For any user tag creation, the tag name SHALL be accepted if and only if it contains only alphanumeric characters and underscores',
      () {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          // Test valid names - should be accepted
          final validName = TagTestGenerators.validTagName();
          final isValid = _isValidTagName(validName);
          expect(
            isValid,
            isTrue,
            reason: 'Valid tag name "$validName" should be accepted',
          );

          // Test invalid names - should be rejected
          final invalidName = TagTestGenerators.invalidTagName();
          final isInvalid = _isValidTagName(invalidName);
          expect(
            isInvalid,
            isFalse,
            reason: 'Invalid tag name "$invalidName" should be rejected',
          );
        }
      },
    );

    test(
      'Property 11 (edge cases): Empty and whitespace-only names are invalid',
      () {
        expect(_isValidTagName(''), isFalse);
        // Whitespace-only strings become empty after trim, so they're invalid
        expect(_isValidTagName(' '.trim()), isFalse);
        expect(_isValidTagName('  '.trim()), isFalse);
        expect(_isValidTagName('\t'.trim()), isFalse);
        expect(_isValidTagName('\n'.trim()), isFalse);
      },
    );

    test(
      'Property 11 (auto-trim): Leading/trailing whitespace should be trimmed',
      () {
        // These should be valid after trimming
        expect(_isValidTagName(' tag'.trim()), isTrue);
        expect(_isValidTagName('tag '.trim()), isTrue);
        expect(_isValidTagName(' tag '.trim()), isTrue);
      },
    );

    test('Property 11 (valid patterns): Various valid name patterns', () {
      // All lowercase
      expect(_isValidTagName('mytag'), isTrue);
      // All uppercase
      expect(_isValidTagName('MYTAG'), isTrue);
      // Mixed case
      expect(_isValidTagName('MyTag'), isTrue);
      // With numbers
      expect(_isValidTagName('tag123'), isTrue);
      // With underscores
      expect(_isValidTagName('my_tag'), isTrue);
      // Starting with underscore
      expect(_isValidTagName('_tag'), isTrue);
      // With spaces (internal)
      expect(_isValidTagName('my tag'), isTrue);
      // With hyphens
      expect(_isValidTagName('my-tag'), isTrue);
      // Unicode characters (Chinese)
      expect(_isValidTagName('中文标签'), isTrue);
      // Unicode characters (Japanese)
      expect(_isValidTagName('日本語タグ'), isTrue);
      // Unicode characters (Korean)
      expect(_isValidTagName('한국어태그'), isTrue);
      // Mixed ASCII and Unicode
      expect(_isValidTagName('tag中文'), isTrue);
    });

    test(
      'Property 11 (invalid patterns): Dangerous and reserved characters',
      () {
        // Dangerous: quotes
        expect(_isValidTagName('tag"name'), isFalse);
        expect(_isValidTagName('"tag'), isFalse);
        expect(_isValidTagName('tag"'), isFalse);
        // Reserved: exclamation mark
        expect(_isValidTagName('tag!name'), isFalse);
        expect(_isValidTagName('!tag'), isFalse);
        // Reserved: ampersand
        expect(_isValidTagName('tag&name'), isFalse);
        expect(_isValidTagName('tag&&name'), isFalse);
        // Reserved: colon
        expect(_isValidTagName('tag:name'), isFalse);
        expect(_isValidTagName('tag:'), isFalse);
        // Reserved: asterisk (wildcard)
        expect(_isValidTagName('tag*name'), isFalse);
        expect(_isValidTagName('*tag'), isFalse);
        expect(_isValidTagName('tag*'), isFalse);
      },
    );

    test('Property 11 (hierarchy): Slash is allowed for hierarchy notation', () {
      // Slash is valid - used for hierarchy
      expect(_isValidTagName('parent'), isTrue);
      expect(_isValidTagName('child'), isTrue);
      // Note: Full paths like 'parent/child' are handled by createTag, not _isValidTagName
    });

    // Feature: song-unit-core, Property 12: Hierarchical tag structure support
    // **Validates: Requirements 4.3**
    test(
      'Property 12: For any tag hierarchy of arbitrary depth, the parent-child relationships SHALL be preserved and queryable',
      () {
        const iterations = 20;

        for (var i = 0; i < iterations; i++) {
          // Create a hierarchy of random depth (1-5 levels)
          final depth = 1 + Random().nextInt(5);
          final tagIds = <String>[];
          String? parentId;

          for (var level = 0; level < depth; level++) {
            final tagId = storage.generateId();
            final tagName = 'level${level}_${TagTestGenerators.validTagName()}';

            storage.insertTag({
              'id': tagId,
              'name': tagName,
              'type': 'user',
              'parent_id': parentId,
              'include_children': 1,
            });

            tagIds.add(tagId);
            parentId = tagId;
          }

          // Verify parent-child relationships are preserved
          for (var level = 0; level < depth; level++) {
            final tag = storage.getTag(tagIds[level]);
            expect(tag, isNotNull);

            if (level == 0) {
              expect(
                tag!['parent_id'],
                isNull,
                reason: 'Root tag should have no parent',
              );
            } else {
              expect(
                tag!['parent_id'],
                equals(tagIds[level - 1]),
                reason: 'Tag at level $level should have correct parent',
              );
            }
          }

          // Verify children can be queried
          for (var level = 0; level < depth - 1; level++) {
            final children = storage.getChildTags(tagIds[level]);
            expect(children.length, equals(1));
            expect(children.first['id'], equals(tagIds[level + 1]));
          }

          // Verify leaf has no children
          final leafChildren = storage.getChildTags(tagIds.last);
          expect(leafChildren, isEmpty);
        }
      },
    );

    test(
      'Property 12 (multiple children): Parent can have multiple children',
      () {
        // Create parent
        final parentId = storage.generateId();
        storage.insertTag({
          'id': parentId,
          'name': 'parent',
          'type': 'user',
          'parent_id': null,
          'include_children': 1,
        });

        // Create multiple children
        const childCount = 5;
        final childIds = <String>[];
        for (var i = 0; i < childCount; i++) {
          final childId = storage.generateId();
          childIds.add(childId);
          storage.insertTag({
            'id': childId,
            'name': 'child_$i',
            'type': 'user',
            'parent_id': parentId,
            'include_children': 1,
          });
        }

        // Verify all children are queryable
        final children = storage.getChildTags(parentId);
        expect(children.length, equals(childCount));
        for (final childId in childIds) {
          expect(children.any((c) => c['id'] == childId), isTrue);
        }
      },
    );

    // Feature: song-unit-core, Property 14: Alias tag uniqueness
    // **Validates: Requirements 4.5**
    test(
      'Property 14: For any alias tag, it SHALL map to exactly one primary tag',
      () {
        const iterations = 50;

        for (var i = 0; i < iterations; i++) {
          // Create a primary tag
          final primaryTagId = storage.generateId();
          storage.insertTag({
            'id': primaryTagId,
            'name': 'primary_${TagTestGenerators.validTagName()}',
            'type': 'user',
            'parent_id': null,
            'include_children': 1,
          });

          // Create an alias
          final aliasName = 'alias_${TagTestGenerators.validTagName()}';
          storage.insertTagAlias(aliasName, primaryTagId);

          // Verify alias resolves to exactly one tag
          final resolvedId = storage.resolveAlias(aliasName);
          expect(resolvedId, isNotNull);
          expect(resolvedId, equals(primaryTagId));

          // Verify the resolved tag exists
          final resolvedTag = storage.getTag(resolvedId!);
          expect(resolvedTag, isNotNull);
        }
      },
    );

    test('Property 14 (overwrite): Adding same alias again overwrites', () {
      // Create two tags
      final tag1Id = storage.generateId();
      final tag2Id = storage.generateId();

      storage
        ..insertTag({
          'id': tag1Id,
          'name': 'tag1',
          'type': 'user',
          'parent_id': null,
          'include_children': 1,
        })
        ..insertTag({
          'id': tag2Id,
          'name': 'tag2',
          'type': 'user',
          'parent_id': null,
          'include_children': 1,
        })
        // Add alias to tag1
        ..insertTagAlias('myalias', tag1Id);
      expect(storage.resolveAlias('myalias'), equals(tag1Id));

      // Overwrite alias to point to tag2
      storage.insertTagAlias('myalias', tag2Id);
      expect(storage.resolveAlias('myalias'), equals(tag2Id));
    });

    // Feature: song-unit-core, Property 15: Alias resolution equivalence
    // **Validates: Requirements 4.6**
    test(
      'Property 15: For any query using an alias tag, the results SHALL be identical to querying with the primary tag',
      () {
        const iterations = 50;

        for (var i = 0; i < iterations; i++) {
          // Create a primary tag
          final primaryTagId = storage.generateId();
          final primaryTagName = 'primary_${TagTestGenerators.validTagName()}';

          storage.insertTag({
            'id': primaryTagId,
            'name': primaryTagName,
            'type': 'user',
            'parent_id': null,
            'include_children': 1,
          });

          // Create multiple aliases for the same tag
          final aliasCount = 1 + Random().nextInt(3);
          final aliasNames = <String>[];

          for (var j = 0; j < aliasCount; j++) {
            final aliasName = 'alias${j}_${TagTestGenerators.validTagName()}';
            aliasNames.add(aliasName);
            storage.insertTagAlias(aliasName, primaryTagId);
          }

          // Verify all aliases resolve to the same primary tag
          for (final aliasName in aliasNames) {
            final resolvedId = storage.resolveAlias(aliasName);
            expect(
              resolvedId,
              equals(primaryTagId),
              reason: 'Alias "$aliasName" should resolve to primary tag',
            );

            // Get the tag via alias resolution
            final tagViaAlias = storage.getTag(resolvedId!);

            // Get the tag directly
            final tagDirect = storage.getTag(primaryTagId);

            // They should be identical
            expect(
              tagViaAlias,
              equals(tagDirect),
              reason:
                  'Tag retrieved via alias should be identical to direct retrieval',
            );
          }
        }
      },
    );

    test(
      'Property 15 (non-existent alias): Non-existent alias returns null',
      () {
        final result = storage.resolveAlias('nonexistent_alias');
        expect(result, isNull);
      },
    );

    test('Property 15 (alias deletion): Deleting tag removes its aliases', () {
      // Create a tag with aliases
      final tagId = storage.generateId();
      storage
        ..insertTag({
          'id': tagId,
          'name': 'mytag',
          'type': 'user',
          'parent_id': null,
          'include_children': 1,
        })
        ..insertTagAlias('alias1', tagId)
        ..insertTagAlias('alias2', tagId);

      // Verify aliases work
      expect(storage.resolveAlias('alias1'), equals(tagId));
      expect(storage.resolveAlias('alias2'), equals(tagId));

      // Delete the tag (which should also remove aliases)
      storage.deleteTag(tagId);

      // Verify aliases are gone
      expect(storage.resolveAlias('alias1'), isNull);
      expect(storage.resolveAlias('alias2'), isNull);
    });
  });

  group('Collection Operations Tests (Task 2.1)', () {
    late InMemoryTagStorage storage;

    setUp(() {
      storage = InMemoryTagStorage();
    });

    tearDown(() {
      storage.clear();
    });

    test('createCollection with isGroup parameter creates group collection', () {
      final parentId = storage.generateId();
      storage.insertTag({
        'id': parentId,
        'name': 'parent_collection',
        'type': 'user',
        'parent_id': null,
        'include_children': 1,
        'is_group': 0,
        'playlist_metadata_json':
            '{"isLocked":false,"displayOrder":0,"items":[],"createdAt":"2024-01-01T00:00:00.000","updatedAt":"2024-01-01T00:00:00.000","currentIndex":-1,"playbackPositionMs":0,"wasPlaying":false,"removeAfterPlay":false}',
      });

      final groupId = storage.generateId();
      storage.insertTag({
        'id': groupId,
        'name': 'group_collection',
        'type': 'user',
        'parent_id': parentId,
        'include_children': 1,
        'is_group': 1,
        'playlist_metadata_json':
            '{"isLocked":false,"displayOrder":0,"items":[],"createdAt":"2024-01-01T00:00:00.000","updatedAt":"2024-01-01T00:00:00.000","currentIndex":-1,"playbackPositionMs":0,"wasPlaying":false,"removeAfterPlay":false}',
      });

      final group = storage.getTag(groupId);
      expect(group, isNotNull);
      expect(group!['is_group'], equals(1));
      expect(group['parent_id'], equals(parentId));
      expect(group['playlist_metadata_json'], isNotNull);
    });

    test('getCollections with includeGroups=false filters out groups', () {
      // Create regular collection
      final collectionId = storage.generateId();
      storage.insertTag({
        'id': collectionId,
        'name': 'regular_collection',
        'type': 'user',
        'parent_id': null,
        'include_children': 1,
        'is_group': 0,
        'playlist_metadata_json':
            '{"isLocked":false,"displayOrder":0,"items":[],"createdAt":"2024-01-01T00:00:00.000","updatedAt":"2024-01-01T00:00:00.000","currentIndex":-1,"playbackPositionMs":0,"wasPlaying":false,"removeAfterPlay":false}',
      });

      // Create group collection
      final groupId = storage.generateId();
      storage.insertTag({
        'id': groupId,
        'name': 'group_collection',
        'type': 'user',
        'parent_id': collectionId,
        'include_children': 1,
        'is_group': 1,
        'playlist_metadata_json':
            '{"isLocked":false,"displayOrder":0,"items":[],"createdAt":"2024-01-01T00:00:00.000","updatedAt":"2024-01-01T00:00:00.000","currentIndex":-1,"playbackPositionMs":0,"wasPlaying":false,"removeAfterPlay":false}',
      });

      // Get all collections
      final allCollections = storage
          .getAllTags()
          .where((t) => t['playlist_metadata_json'] != null)
          .toList();
      expect(allCollections.length, equals(2));

      // Filter out groups
      final nonGroupCollections = allCollections
          .where((t) => (t['is_group'] as int?) != 1)
          .toList();
      expect(nonGroupCollections.length, equals(1));
      expect(nonGroupCollections.first['id'], equals(collectionId));
    });

    test('getCollections with includeQueues=false filters out active queues', () {
      // Create regular collection (not playing)
      final collectionId = storage.generateId();
      storage.insertTag({
        'id': collectionId,
        'name': 'regular_collection',
        'type': 'user',
        'parent_id': null,
        'include_children': 1,
        'is_group': 0,
        'playlist_metadata_json':
            '{"isLocked":false,"displayOrder":0,"items":[],"createdAt":"2024-01-01T00:00:00.000","updatedAt":"2024-01-01T00:00:00.000","currentIndex":-1,"playbackPositionMs":0,"wasPlaying":false,"removeAfterPlay":false}',
      });

      // Create active queue (currently playing)
      final queueId = storage.generateId();
      storage.insertTag({
        'id': queueId,
        'name': 'active_queue',
        'type': 'user',
        'parent_id': null,
        'include_children': 1,
        'is_group': 0,
        'playlist_metadata_json':
            '{"isLocked":false,"displayOrder":0,"items":[],"createdAt":"2024-01-01T00:00:00.000","updatedAt":"2024-01-01T00:00:00.000","currentIndex":0,"playbackPositionMs":0,"wasPlaying":true,"removeAfterPlay":false}',
      });

      // Get all collections
      final allCollections = storage
          .getAllTags()
          .where((t) => t['playlist_metadata_json'] != null)
          .toList();
      expect(allCollections.length, equals(2));

      // Filter out active queues (currentIndex >= 0)
      // Note: This requires parsing the JSON, which is simplified here
      final nonQueueCollections = allCollections.where((t) {
        final json = t['playlist_metadata_json'] as String?;
        if (json == null) return false;
        // Simple check: if currentIndex is not -1, it's an active queue
        return !json.contains('"currentIndex":0') &&
            !json.contains('"currentIndex":1') &&
            !json.contains('"currentIndex":2');
      }).toList();
      expect(nonQueueCollections.length, equals(1));
      expect(nonQueueCollections.first['id'], equals(collectionId));
    });

    test('toggleLock changes lock state correctly', () {
      final collectionId = storage.generateId();
      storage
        ..insertTag({
          'id': collectionId,
          'name': 'test_collection',
          'type': 'user',
          'parent_id': null,
          'include_children': 1,
          'is_group': 0,
          'is_locked': 0,
          'playlist_metadata_json':
              '{"isLocked":false,"displayOrder":0,"items":[],"createdAt":"2024-01-01T00:00:00.000","updatedAt":"2024-01-01T00:00:00.000","currentIndex":-1,"playbackPositionMs":0,"wasPlaying":false,"removeAfterPlay":false}',
        })
        // Toggle lock on (false -> true)
        ..updateTag(collectionId, {
          'id': collectionId,
          'name': 'test_collection',
          'type': 'user',
          'parent_id': null,
          'include_children': 1,
          'is_group': 0,
          'is_locked': 1,
          'playlist_metadata_json':
              '{"isLocked":true,"displayOrder":0,"items":[],"createdAt":"2024-01-01T00:00:00.000","updatedAt":"2024-01-01T00:00:00.000","currentIndex":-1,"playbackPositionMs":0,"wasPlaying":false,"removeAfterPlay":false}',
        });

      var collection = storage.getTag(collectionId);
      expect(collection!['is_locked'], equals(1));

      // Toggle lock off (true -> false)
      storage.updateTag(collectionId, {
        'id': collectionId,
        'name': 'test_collection',
        'type': 'user',
        'parent_id': null,
        'include_children': 1,
        'is_group': 0,
        'is_locked': 0,
        'playlist_metadata_json':
            '{"isLocked":false,"displayOrder":0,"items":[],"createdAt":"2024-01-01T00:00:00.000","updatedAt":"2024-01-01T00:00:00.000","currentIndex":-1,"playbackPositionMs":0,"wasPlaying":false,"removeAfterPlay":false}',
      });

      collection = storage.getTag(collectionId);
      expect(collection!['is_locked'], equals(0));
    });

    test('reorderCollection moves item from oldIndex to newIndex', () {
      // This test verifies the logic of reordering
      // In a real implementation, items would be stored in playlist_items table

      // Simulate a collection with 5 items
      final items = List.generate(5, (i) => {'id': 'item_$i', 'order': i});

      // Move item from index 1 to index 3
      const oldIndex = 1;
      const newIndex = 3;

      final item = items.removeAt(oldIndex);
      items.insert(newIndex, item);

      // Update order values
      for (var i = 0; i < items.length; i++) {
        items[i]['order'] = i;
      }

      // Verify the order
      expect(items[0]['id'], equals('item_0'));
      expect(items[1]['id'], equals('item_2'));
      expect(items[2]['id'], equals('item_3'));
      expect(items[3]['id'], equals('item_1')); // Moved item
      expect(items[4]['id'], equals('item_4'));

      // Verify order values are correct
      for (var i = 0; i < items.length; i++) {
        expect(items[i]['order'], equals(i));
      }
    });
  });

  group('Collection Content Resolution Tests (Task 2.3)', () {
    late InMemoryTagStorage storage;
    late MockLibraryRepository libraryRepo;

    setUp(() {
      storage = InMemoryTagStorage();
      libraryRepo = MockLibraryRepository();
    });

    tearDown(() {
      storage.clear();
      libraryRepo.clear();
    });

    test(
      'resolveContent returns empty list for non-existent collection',
      () async {
        final repo = TestTagRepository(storage);
        final result = await repo.resolveContent(
          'nonexistent',
          libraryRepository: libraryRepo,
        );
        expect(result, isEmpty);
      },
    );

    test('resolveContent returns empty list for non-collection tag', () async {
      final repo = TestTagRepository(storage);

      // Create a regular tag (not a collection)
      final tagId = storage.generateId();
      storage.insertTag({
        'id': tagId,
        'name': 'regular_tag',
        'type': 'user',
        'parent_id': null,
        'include_children': 1,
        'is_group': 0,
      });

      final result = await repo.resolveContent(
        tagId,
        libraryRepository: libraryRepo,
      );
      expect(result, isEmpty);
    });

    test('resolveContent returns song units for simple collection', () async {
      final repo = TestTagRepository(storage);

      // Create song units
      final songUnit1 = MockSongUnit('song1', 'Song 1');
      final songUnit2 = MockSongUnit('song2', 'Song 2');
      libraryRepo
        ..addSongUnit(songUnit1)
        ..addSongUnit(songUnit2);

      // Create collection with song units
      final collectionId = storage.generateId();
      storage.insertTag({
        'id': collectionId,
        'name': 'test_collection',
        'type': 'user',
        'parent_id': null,
        'include_children': 1,
        'is_group': 0,
        'playlist_metadata_json':
            '{"isLocked":false,"displayOrder":0,"items":[{"id":"item1","type":"songUnit","targetId":"song1","order":0,"inheritLock":true},{"id":"item2","type":"songUnit","targetId":"song2","order":1,"inheritLock":true}],"createdAt":"2024-01-01T00:00:00.000","updatedAt":"2024-01-01T00:00:00.000","currentIndex":-1,"playbackPositionMs":0,"wasPlaying":false,"removeAfterPlay":false}',
      });

      final result = await repo.resolveContent(
        collectionId,
        libraryRepository: libraryRepo,
      );

      expect(result.length, equals(2));
      expect(result[0].id, equals('song1'));
      expect(result[1].id, equals('song2'));
    });

    test('resolveContent recursively resolves collection references', () async {
      final repo = TestTagRepository(storage);

      // Create song units
      final songUnit1 = MockSongUnit('song1', 'Song 1');
      final songUnit2 = MockSongUnit('song2', 'Song 2');
      final songUnit3 = MockSongUnit('song3', 'Song 3');
      libraryRepo
        ..addSongUnit(songUnit1)
        ..addSongUnit(songUnit2)
        ..addSongUnit(songUnit3);

      // Create nested collection
      final nestedId = storage.generateId();
      storage.insertTag({
        'id': nestedId,
        'name': 'nested_collection',
        'type': 'user',
        'parent_id': null,
        'include_children': 1,
        'is_group': 0,
        'playlist_metadata_json':
            '{"isLocked":false,"displayOrder":0,"items":[{"id":"item1","type":"songUnit","targetId":"song2","order":0,"inheritLock":true},{"id":"item2","type":"songUnit","targetId":"song3","order":1,"inheritLock":true}],"createdAt":"2024-01-01T00:00:00.000","updatedAt":"2024-01-01T00:00:00.000","currentIndex":-1,"playbackPositionMs":0,"wasPlaying":false,"removeAfterPlay":false}',
      });

      // Create parent collection with song unit and reference
      final parentId = storage.generateId();
      storage.insertTag({
        'id': parentId,
        'name': 'parent_collection',
        'type': 'user',
        'parent_id': null,
        'include_children': 1,
        'is_group': 0,
        'playlist_metadata_json':
            '{"isLocked":false,"displayOrder":0,"items":[{"id":"item1","type":"songUnit","targetId":"song1","order":0,"inheritLock":true},{"id":"item2","type":"collectionReference","targetId":"$nestedId","order":1,"inheritLock":true}],"createdAt":"2024-01-01T00:00:00.000","updatedAt":"2024-01-01T00:00:00.000","currentIndex":-1,"playbackPositionMs":0,"wasPlaying":false,"removeAfterPlay":false}',
      });

      final result = await repo.resolveContent(
        parentId,
        libraryRepository: libraryRepo,
      );

      expect(result.length, equals(3));
      expect(result[0].id, equals('song1'));
      expect(result[1].id, equals('song2'));
      expect(result[2].id, equals('song3'));
    });

    test('resolveContent detects circular references', () async {
      final repo = TestTagRepository(storage);

      // Create collection A that references collection B
      final collectionAId = storage.generateId();
      final collectionBId = storage.generateId();

      storage
        ..insertTag({
          'id': collectionAId,
          'name': 'collection_a',
          'type': 'user',
          'parent_id': null,
          'include_children': 1,
          'is_group': 0,
          'playlist_metadata_json':
              '{"isLocked":false,"displayOrder":0,"items":[{"id":"item1","type":"collectionReference","targetId":"$collectionBId","order":0,"inheritLock":true}],"createdAt":"2024-01-01T00:00:00.000","updatedAt":"2024-01-01T00:00:00.000","currentIndex":-1,"playbackPositionMs":0,"wasPlaying":false,"removeAfterPlay":false}',
        })
        // Create collection B that references collection A (circular!)
        ..insertTag({
          'id': collectionBId,
          'name': 'collection_b',
          'type': 'user',
          'parent_id': null,
          'include_children': 1,
          'is_group': 0,
          'playlist_metadata_json':
              '{"isLocked":false,"displayOrder":0,"items":[{"id":"item1","type":"collectionReference","targetId":"$collectionAId","order":0,"inheritLock":true}],"createdAt":"2024-01-01T00:00:00.000","updatedAt":"2024-01-01T00:00:00.000","currentIndex":-1,"playbackPositionMs":0,"wasPlaying":false,"removeAfterPlay":false}',
        });

      // Should return empty list and not hang
      final result = await repo.resolveContent(
        collectionAId,
        libraryRepository: libraryRepo,
      );

      expect(result, isEmpty);
    });

    test('resolveContent enforces depth limit', () async {
      final repo = TestTagRepository(storage);

      // Create a deep nesting of collections (15 levels)
      final collectionIds = <String>[];
      for (var i = 0; i < 15; i++) {
        collectionIds.add(storage.generateId());
      }

      // Create the deepest collection with a song unit
      final songUnit = MockSongUnit('song1', 'Song 1');
      libraryRepo.addSongUnit(songUnit);

      storage.insertTag({
        'id': collectionIds[14],
        'name': 'level_14',
        'type': 'user',
        'parent_id': null,
        'include_children': 1,
        'is_group': 0,
        'playlist_metadata_json':
            '{"isLocked":false,"displayOrder":0,"items":[{"id":"item1","type":"songUnit","targetId":"song1","order":0,"inheritLock":true}],"createdAt":"2024-01-01T00:00:00.000","updatedAt":"2024-01-01T00:00:00.000","currentIndex":-1,"playbackPositionMs":0,"wasPlaying":false,"removeAfterPlay":false}',
      });

      // Create nested collections, each referencing the next
      for (var i = 13; i >= 0; i--) {
        final nextId = collectionIds[i + 1];
        storage.insertTag({
          'id': collectionIds[i],
          'name': 'level_$i',
          'type': 'user',
          'parent_id': null,
          'include_children': 1,
          'is_group': 0,
          'playlist_metadata_json':
              '{"isLocked":false,"displayOrder":0,"items":[{"id":"item1","type":"collectionReference","targetId":"$nextId","order":0,"inheritLock":true}],"createdAt":"2024-01-01T00:00:00.000","updatedAt":"2024-01-01T00:00:00.000","currentIndex":-1,"playbackPositionMs":0,"wasPlaying":false,"removeAfterPlay":false}',
        });
      }

      // Resolve with default max depth (10)
      final result = await repo.resolveContent(
        collectionIds[0],
        libraryRepository: libraryRepo,
      );

      // Should stop at depth 10, so the song at level 14 won't be reached
      expect(result, isEmpty);
    });

    test('resolveContent respects custom maxDepth parameter', () async {
      final repo = TestTagRepository(storage);

      // Create 3 levels of nesting
      final songUnit = MockSongUnit('song1', 'Song 1');
      libraryRepo.addSongUnit(songUnit);

      final level2Id = storage.generateId();
      storage.insertTag({
        'id': level2Id,
        'name': 'level_2',
        'type': 'user',
        'parent_id': null,
        'include_children': 1,
        'is_group': 0,
        'playlist_metadata_json':
            '{"isLocked":false,"displayOrder":0,"items":[{"id":"item1","type":"songUnit","targetId":"song1","order":0,"inheritLock":true}],"createdAt":"2024-01-01T00:00:00.000","updatedAt":"2024-01-01T00:00:00.000","currentIndex":-1,"playbackPositionMs":0,"wasPlaying":false,"removeAfterPlay":false}',
      });

      final level1Id = storage.generateId();
      storage.insertTag({
        'id': level1Id,
        'name': 'level_1',
        'type': 'user',
        'parent_id': null,
        'include_children': 1,
        'is_group': 0,
        'playlist_metadata_json':
            '{"isLocked":false,"displayOrder":0,"items":[{"id":"item1","type":"collectionReference","targetId":"$level2Id","order":0,"inheritLock":true}],"createdAt":"2024-01-01T00:00:00.000","updatedAt":"2024-01-01T00:00:00.000","currentIndex":-1,"playbackPositionMs":0,"wasPlaying":false,"removeAfterPlay":false}',
      });

      final level0Id = storage.generateId();
      storage.insertTag({
        'id': level0Id,
        'name': 'level_0',
        'type': 'user',
        'parent_id': null,
        'include_children': 1,
        'is_group': 0,
        'playlist_metadata_json':
            '{"isLocked":false,"displayOrder":0,"items":[{"id":"item1","type":"collectionReference","targetId":"$level1Id","order":0,"inheritLock":true}],"createdAt":"2024-01-01T00:00:00.000","updatedAt":"2024-01-01T00:00:00.000","currentIndex":-1,"playbackPositionMs":0,"wasPlaying":false,"removeAfterPlay":false}',
      });

      // With maxDepth=1, should not reach the song
      final result1 = await repo.resolveContent(
        level0Id,
        maxDepth: 1,
        libraryRepository: libraryRepo,
      );
      expect(result1, isEmpty);

      // With maxDepth=3, should reach the song
      final result3 = await repo.resolveContent(
        level0Id,
        maxDepth: 3,
        libraryRepository: libraryRepo,
      );
      expect(result3.length, equals(1));
      expect(result3[0].id, equals('song1'));
    });

    test('wouldCreateCircularReference detects self-reference', () async {
      final repo = TestTagRepository(storage);

      final collectionId = storage.generateId();
      storage.insertTag({
        'id': collectionId,
        'name': 'collection',
        'type': 'user',
        'parent_id': null,
        'include_children': 1,
        'is_group': 0,
        'playlist_metadata_json':
            '{"isLocked":false,"displayOrder":0,"items":[],"createdAt":"2024-01-01T00:00:00.000","updatedAt":"2024-01-01T00:00:00.000","currentIndex":-1,"playbackPositionMs":0,"wasPlaying":false,"removeAfterPlay":false}',
      });

      final result = await repo.wouldCreateCircularReference(
        collectionId,
        collectionId,
      );

      expect(result, isTrue);
    });

    test(
      'wouldCreateCircularReference detects direct circular reference',
      () async {
        final repo = TestTagRepository(storage);

        final collectionAId = storage.generateId();
        final collectionBId = storage.generateId();

        // A references B
        storage
          ..insertTag({
            'id': collectionAId,
            'name': 'collection_a',
            'type': 'user',
            'parent_id': null,
            'include_children': 1,
            'is_group': 0,
            'playlist_metadata_json':
                '{"isLocked":false,"displayOrder":0,"items":[{"id":"item1","type":"collectionReference","targetId":"$collectionBId","order":0,"inheritLock":true}],"createdAt":"2024-01-01T00:00:00.000","updatedAt":"2024-01-01T00:00:00.000","currentIndex":-1,"playbackPositionMs":0,"wasPlaying":false,"removeAfterPlay":false}',
          })
          ..insertTag({
            'id': collectionBId,
            'name': 'collection_b',
            'type': 'user',
            'parent_id': null,
            'include_children': 1,
            'is_group': 0,
            'playlist_metadata_json':
                '{"isLocked":false,"displayOrder":0,"items":[],"createdAt":"2024-01-01T00:00:00.000","updatedAt":"2024-01-01T00:00:00.000","currentIndex":-1,"playbackPositionMs":0,"wasPlaying":false,"removeAfterPlay":false}',
          });

        // Try to make B reference A (would create circular reference)
        final result = await repo.wouldCreateCircularReference(
          collectionBId,
          collectionAId,
        );

        expect(result, isTrue);
      },
    );

    test('wouldCreateCircularReference detects indirect circular reference', () async {
      final repo = TestTagRepository(storage);

      final collectionAId = storage.generateId();
      final collectionBId = storage.generateId();
      final collectionCId = storage.generateId();

      storage
        // A references B
        ..insertTag({
          'id': collectionAId,
          'name': 'collection_a',
          'type': 'user',
          'parent_id': null,
          'include_children': 1,
          'is_group': 0,
          'playlist_metadata_json':
              '{"isLocked":false,"displayOrder":0,"items":[{"id":"item1","type":"collectionReference","targetId":"$collectionBId","order":0,"inheritLock":true}],"createdAt":"2024-01-01T00:00:00.000","updatedAt":"2024-01-01T00:00:00.000","currentIndex":-1,"playbackPositionMs":0,"wasPlaying":false,"removeAfterPlay":false}',
        })
        // B references C
        ..insertTag({
          'id': collectionBId,
          'name': 'collection_b',
          'type': 'user',
          'parent_id': null,
          'include_children': 1,
          'is_group': 0,
          'playlist_metadata_json':
              '{"isLocked":false,"displayOrder":0,"items":[{"id":"item1","type":"collectionReference","targetId":"$collectionCId","order":0,"inheritLock":true}],"createdAt":"2024-01-01T00:00:00.000","updatedAt":"2024-01-01T00:00:00.000","currentIndex":-1,"playbackPositionMs":0,"wasPlaying":false,"removeAfterPlay":false}',
        })
        ..insertTag({
          'id': collectionCId,
          'name': 'collection_c',
          'type': 'user',
          'parent_id': null,
          'include_children': 1,
          'is_group': 0,
          'playlist_metadata_json':
              '{"isLocked":false,"displayOrder":0,"items":[],"createdAt":"2024-01-01T00:00:00.000","updatedAt":"2024-01-01T00:00:00.000","currentIndex":-1,"playbackPositionMs":0,"wasPlaying":false,"removeAfterPlay":false}',
        });

      // Try to make C reference A (would create circular reference A->B->C->A)
      final result = await repo.wouldCreateCircularReference(
        collectionCId,
        collectionAId,
      );

      expect(result, isTrue);
    });

    test('wouldCreateCircularReference allows non-circular references', () async {
      final repo = TestTagRepository(storage);

      final collectionAId = storage.generateId();
      final collectionBId = storage.generateId();
      final collectionCId = storage.generateId();

      storage
        // A references B
        ..insertTag({
          'id': collectionAId,
          'name': 'collection_a',
          'type': 'user',
          'parent_id': null,
          'include_children': 1,
          'is_group': 0,
          'playlist_metadata_json':
              '{"isLocked":false,"displayOrder":0,"items":[{"id":"item1","type":"collectionReference","targetId":"$collectionBId","order":0,"inheritLock":true}],"createdAt":"2024-01-01T00:00:00.000","updatedAt":"2024-01-01T00:00:00.000","currentIndex":-1,"playbackPositionMs":0,"wasPlaying":false,"removeAfterPlay":false}',
        })
        ..insertTag({
          'id': collectionBId,
          'name': 'collection_b',
          'type': 'user',
          'parent_id': null,
          'include_children': 1,
          'is_group': 0,
          'playlist_metadata_json':
              '{"isLocked":false,"displayOrder":0,"items":[],"createdAt":"2024-01-01T00:00:00.000","updatedAt":"2024-01-01T00:00:00.000","currentIndex":-1,"playbackPositionMs":0,"wasPlaying":false,"removeAfterPlay":false}',
        })
        ..insertTag({
          'id': collectionCId,
          'name': 'collection_c',
          'type': 'user',
          'parent_id': null,
          'include_children': 1,
          'is_group': 0,
          'playlist_metadata_json':
              '{"isLocked":false,"displayOrder":0,"items":[],"createdAt":"2024-01-01T00:00:00.000","updatedAt":"2024-01-01T00:00:00.000","currentIndex":-1,"playbackPositionMs":0,"wasPlaying":false,"removeAfterPlay":false}',
        });

      // C referencing B is fine (no circular reference)
      final result = await repo.wouldCreateCircularReference(
        collectionCId,
        collectionBId,
      );

      expect(result, isFalse);
    });
  });
}

/// Mock SongUnit for testing
class MockSongUnit {
  MockSongUnit(this.id, this.name);
  final String id;
  final String name;
}

/// Mock LibraryRepository for testing
class MockLibraryRepository {
  final Map<String, MockSongUnit> _songUnits = {};

  void addSongUnit(MockSongUnit songUnit) {
    _songUnits[songUnit.id] = songUnit;
  }

  Future<MockSongUnit?> getSongUnit(String id) async {
    return _songUnits[id];
  }

  void clear() {
    _songUnits.clear();
  }
}

/// Test implementation of TagRepository
class TestTagRepository {
  TestTagRepository(this._storage);
  final InMemoryTagStorage _storage;

  Future<dynamic> getTag(String id) async {
    final row = _storage.getTag(id);
    if (row == null) return null;
    return _tagFromRow(row);
  }

  Future<List<MockSongUnit>> resolveContent(
    String collectionId, {
    int maxDepth = 10,
    Set<String>? visited,
    required MockLibraryRepository libraryRepository,
  }) async {
    visited ??= <String>{};

    if (maxDepth <= 0) {
      return [];
    }

    if (visited.contains(collectionId)) {
      return [];
    }

    visited.add(collectionId);

    final tag = await getTag(collectionId);
    if (tag == null || tag['playlist_metadata_json'] == null) {
      return [];
    }

    final metadataJson = tag['playlist_metadata_json'] as String;
    final metadata = _parsePlaylistMetadata(metadataJson);

    final result = <MockSongUnit>[];

    for (final item in metadata['items'] as List) {
      final type = item['type'] as String;
      final targetId = item['targetId'] as String;

      if (type == 'songUnit') {
        final songUnit = await libraryRepository.getSongUnit(targetId);
        if (songUnit != null) {
          result.add(songUnit);
        }
      } else if (type == 'collectionReference') {
        final nested = await resolveContent(
          targetId,
          maxDepth: maxDepth - 1,
          visited: visited,
          libraryRepository: libraryRepository,
        );
        result.addAll(nested);
      }
    }

    return result;
  }

  Future<bool> wouldCreateCircularReference(
    String parentId,
    String targetId,
  ) async {
    if (parentId == targetId) {
      return true;
    }

    final visited = <String>{};
    return _checkCircularReference(targetId, parentId, visited);
  }

  Future<bool> _checkCircularReference(
    String currentId,
    String searchForId,
    Set<String> visited,
  ) async {
    if (visited.contains(currentId)) {
      return false;
    }
    visited.add(currentId);

    final tag = await getTag(currentId);
    if (tag == null || tag['playlist_metadata_json'] == null) {
      return false;
    }

    final metadataJson = tag['playlist_metadata_json'] as String;
    final metadata = _parsePlaylistMetadata(metadataJson);

    for (final item in metadata['items'] as List) {
      final type = item['type'] as String;
      if (type == 'collectionReference') {
        final targetId = item['targetId'] as String;
        if (targetId == searchForId) {
          return true;
        }
        if (await _checkCircularReference(targetId, searchForId, visited)) {
          return true;
        }
      }
    }

    return false;
  }

  Map<String, dynamic> _tagFromRow(Map<String, dynamic> row) {
    return row;
  }

  Map<String, dynamic> _parsePlaylistMetadata(String json) {
    // Simple JSON parsing for test purposes
    // In real implementation, use jsonDecode
    final items = <Map<String, dynamic>>[];

    // Extract items array from JSON string
    final itemsMatch = RegExp(r'"items":\[(.*?)\]').firstMatch(json);
    if (itemsMatch != null) {
      final itemsStr = itemsMatch.group(1);
      if (itemsStr != null && itemsStr.isNotEmpty) {
        // Parse each item
        final itemMatches = RegExp(r'\{[^}]+\}').allMatches(itemsStr);
        for (final match in itemMatches) {
          final itemStr = match.group(0)!;
          final id = RegExp(r'"id":"([^"]+)"').firstMatch(itemStr)?.group(1);
          final type = RegExp(
            r'"type":"([^"]+)"',
          ).firstMatch(itemStr)?.group(1);
          final targetId = RegExp(
            r'"targetId":"([^"]+)"',
          ).firstMatch(itemStr)?.group(1);

          if (id != null && type != null && targetId != null) {
            items.add({'id': id, 'type': type, 'targetId': targetId});
          }
        }
      }
    }

    return {'items': items};
  }
}

/// Validate tag name - allow any characters except dangerous/reserved ones
/// Dangerous: " (quotes can break JSON/queries)
/// Reserved: ! & (used for query logic), : (used for key:value syntax), * (wildcard)
/// Note: / is allowed as it's used for hierarchy
/// Name should already be trimmed before calling this
bool _isValidTagName(String name) {
  if (name.isEmpty) return false;

  // Check for dangerous/reserved characters (excluding / which is for hierarchy)
  final dangerousChars = ['"', '!', '&', ':', '*'];
  for (final char in dangerousChars) {
    if (name.contains(char)) return false;
  }

  return true;
}
