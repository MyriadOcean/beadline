/// Task 11.1: Bidirectional Tag-Song Unit Association Tests
/// Validates: Requirements 2.1, 2.2, 2.3, 2.6
///
/// Verifies that:
/// - addTagToSongUnit updates both directions
/// - removeTagFromSongUnit updates both directions
/// - getSongUnitsWithTag returns correct results
/// - getTagsForSongUnit returns correct results
library;

import 'dart:math';

import 'package:beadline/models/metadata.dart';
import 'package:beadline/models/playback_preferences.dart';
import 'package:beadline/models/song_unit.dart';
import 'package:beadline/models/source_collection.dart';
import 'package:beadline/models/tag.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

// =============================================================================
// Lightweight in-memory storage that simulates the bidirectional association
// between tags and song units (the song_unit_tags junction table).
// =============================================================================

class InMemoryTagStore {
  final Map<String, Tag> _tags = {};
  int _counter = 0;

  String _nextId() => 'tag_${_counter++}';

  Tag createTag(String name, {TagType type = TagType.user, String? parentId}) {
    final id = _nextId();
    final tag = Tag(id: id, name: name, type: type, parentId: parentId);
    _tags[id] = tag;
    return tag;
  }

  Tag? getTag(String id) => _tags[id];

  void deleteTag(String id) => _tags.remove(id);

  List<Tag> getAll() => _tags.values.toList();

  void clear() {
    _tags.clear();
    _counter = 0;
  }
}

class InMemorySongUnitStore {
  final Map<String, SongUnit> _songUnits = {};

  void add(SongUnit su) => _songUnits[su.id] = su;
  void update(SongUnit su) => _songUnits[su.id] = su;
  SongUnit? get(String id) => _songUnits[id];
  List<SongUnit> getAll() => _songUnits.values.toList();
  void clear() => _songUnits.clear();
}

/// Simulates the bidirectional association logic from TagViewModel.
/// This mirrors the real implementation:
/// - addTagToSongUnit: adds tagId to SongUnit.tagIds
/// - removeTagFromSongUnit: removes tagId from SongUnit.tagIds
/// - getSongUnitsWithTag: filters all song units by tagId
/// - getTagsForSongUnit: looks up tags from SongUnit.tagIds
class BidirectionalAssociationService {
  BidirectionalAssociationService(this._tagStore, this._songUnitStore);

  final InMemoryTagStore _tagStore;
  final InMemorySongUnitStore _songUnitStore;
  String? lastError;

  /// Add a tag to a song unit (mirrors TagViewModel.addTagToSongUnit)
  Future<void> addTagToSongUnit(String songUnitId, String tagId) async {
    lastError = null;
    final songUnit = _songUnitStore.get(songUnitId);
    if (songUnit == null) {
      lastError = 'Song Unit not found';
      return;
    }

    // Idempotent: skip if already associated
    if (songUnit.tagIds.contains(tagId)) {
      return;
    }

    final updated = songUnit.copyWith(tagIds: [...songUnit.tagIds, tagId]);
    _songUnitStore.update(updated);
  }

  /// Remove a tag from a song unit (mirrors TagViewModel.removeTagFromSongUnit)
  Future<void> removeTagFromSongUnit(String songUnitId, String tagId) async {
    lastError = null;
    final songUnit = _songUnitStore.get(songUnitId);
    if (songUnit == null) {
      lastError = 'Song Unit not found';
      return;
    }

    final updated = songUnit.copyWith(
      tagIds: songUnit.tagIds.where((id) => id != tagId).toList(),
    );
    _songUnitStore.update(updated);
  }

  /// Get all song units that have a specific tag
  /// (mirrors what LocalDatabase.getSongUnitsWithTag does via junction table)
  Future<List<SongUnit>> getSongUnitsWithTag(String tagId) async {
    return _songUnitStore
        .getAll()
        .where((su) => su.tagIds.contains(tagId))
        .toList();
  }

  /// Get all tags for a specific song unit
  /// (mirrors what LocalDatabase.getTagsForSongUnit does via junction table)
  Future<List<Tag>> getTagsForSongUnit(String songUnitId) async {
    final songUnit = _songUnitStore.get(songUnitId);
    if (songUnit == null) return [];
    final tags = <Tag>[];
    for (final tagId in songUnit.tagIds) {
      final tag = _tagStore.getTag(tagId);
      if (tag != null) tags.add(tag);
    }
    return tags;
  }
}

// =============================================================================
// Test helpers
// =============================================================================

final _random = Random();
const _uuid = Uuid();

SongUnit _randomSongUnit({List<String>? tagIds}) {
  return SongUnit(
    id: _uuid.v4(),
    metadata: Metadata(
      title: 'Song ${_random.nextInt(10000)}',
      artists: ['Artist ${_random.nextInt(100)}'],
      album: 'Album ${_random.nextInt(100)}',
      year: 2000 + _random.nextInt(25),
      duration: Duration(seconds: 60 + _random.nextInt(300)),
    ),
    sources: const SourceCollection(),
    tagIds: tagIds ?? [],
    preferences: PlaybackPreferences.defaults(),
  );
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  late InMemoryTagStore tagStore;
  late InMemorySongUnitStore songUnitStore;
  late BidirectionalAssociationService service;

  setUp(() {
    tagStore = InMemoryTagStore();
    songUnitStore = InMemorySongUnitStore();
    service = BidirectionalAssociationService(tagStore, songUnitStore);
  });

  tearDown(() {
    tagStore.clear();
    songUnitStore.clear();
  });

  // ==========================================================================
  // Requirement 2.1: Adding tags to Song Units
  // Requirement 2.6: Adding Song Units to a tag
  // ==========================================================================

  group('addTagToSongUnit updates both directions', () {
    test('song unit appears in getSongUnitsWithTag after adding', () async {
      final tag = tagStore.createTag('rock');
      final su = _randomSongUnit();
      songUnitStore.add(su);

      // Before
      var result = await service.getSongUnitsWithTag(tag.id);
      expect(result.any((s) => s.id == su.id), isFalse);

      // Add
      await service.addTagToSongUnit(su.id, tag.id);

      // After
      result = await service.getSongUnitsWithTag(tag.id);
      expect(result.any((s) => s.id == su.id), isTrue);
    });

    test('tag appears in getTagsForSongUnit after adding', () async {
      final tag = tagStore.createTag('jazz');
      final su = _randomSongUnit();
      songUnitStore.add(su);

      // Before
      var tags = await service.getTagsForSongUnit(su.id);
      expect(tags.any((t) => t.id == tag.id), isFalse);

      // Add
      await service.addTagToSongUnit(su.id, tag.id);

      // After
      tags = await service.getTagsForSongUnit(su.id);
      expect(tags.any((t) => t.id == tag.id), isTrue);
    });

    test('adding same tag twice is idempotent', () async {
      final tag = tagStore.createTag('pop');
      final su = _randomSongUnit();
      songUnitStore.add(su);

      await service.addTagToSongUnit(su.id, tag.id);
      await service.addTagToSongUnit(su.id, tag.id);

      final tags = await service.getTagsForSongUnit(su.id);
      expect(tags.where((t) => t.id == tag.id).length, equals(1));
    });
  });

  // ==========================================================================
  // Requirement 2.2: Each tag as a collection of Song Units
  // ==========================================================================

  group('tag acts as collection of Song Units', () {
    test('multiple song units with same tag form a collection', () async {
      final tag = tagStore.createTag('favorites');
      final songUnits = <SongUnit>[];

      for (var i = 0; i < 5; i++) {
        final su = _randomSongUnit();
        songUnitStore.add(su);
        songUnits.add(su);
        await service.addTagToSongUnit(su.id, tag.id);
      }

      final collection = await service.getSongUnitsWithTag(tag.id);
      expect(collection.length, equals(5));
      for (final su in songUnits) {
        expect(collection.any((s) => s.id == su.id), isTrue);
      }
    });

    test(
      'song unit with multiple tags appears in each tag collection',
      () async {
        final tagA = tagStore.createTag('tagA');
        final tagB = tagStore.createTag('tagB');
        final su = _randomSongUnit();
        songUnitStore.add(su);

        await service.addTagToSongUnit(su.id, tagA.id);
        await service.addTagToSongUnit(su.id, tagB.id);

        final collA = await service.getSongUnitsWithTag(tagA.id);
        final collB = await service.getSongUnitsWithTag(tagB.id);
        expect(collA.any((s) => s.id == su.id), isTrue);
        expect(collB.any((s) => s.id == su.id), isTrue);
      },
    );
  });

  // ==========================================================================
  // Requirement 2.3: View all Song Units associated with a tag
  // ==========================================================================

  group('getSongUnitsWithTag returns correct results', () {
    test('returns only song units with that specific tag', () async {
      final tagA = tagStore.createTag('tagA');
      final tagB = tagStore.createTag('tagB');

      final suWithA = _randomSongUnit();
      final suWithB = _randomSongUnit();
      final suWithBoth = _randomSongUnit();
      final suWithNone = _randomSongUnit();

      songUnitStore
        ..add(suWithA)
        ..add(suWithB)
        ..add(suWithBoth)
        ..add(suWithNone);

      await service.addTagToSongUnit(suWithA.id, tagA.id);
      await service.addTagToSongUnit(suWithB.id, tagB.id);
      await service.addTagToSongUnit(suWithBoth.id, tagA.id);
      await service.addTagToSongUnit(suWithBoth.id, tagB.id);

      final collA = await service.getSongUnitsWithTag(tagA.id);
      expect(collA.length, equals(2));
      expect(collA.any((s) => s.id == suWithA.id), isTrue);
      expect(collA.any((s) => s.id == suWithBoth.id), isTrue);
      expect(collA.any((s) => s.id == suWithB.id), isFalse);
      expect(collA.any((s) => s.id == suWithNone.id), isFalse);

      final collB = await service.getSongUnitsWithTag(tagB.id);
      expect(collB.length, equals(2));
      expect(collB.any((s) => s.id == suWithB.id), isTrue);
      expect(collB.any((s) => s.id == suWithBoth.id), isTrue);
    });

    test('returns empty list for tag with no song units', () async {
      final tag = tagStore.createTag('empty');
      final result = await service.getSongUnitsWithTag(tag.id);
      expect(result, isEmpty);
    });

    test('returns empty list for non-existent tag', () async {
      final result = await service.getSongUnitsWithTag('nonexistent');
      expect(result, isEmpty);
    });
  });

  group('getTagsForSongUnit returns correct results', () {
    test('returns only tags on that song unit', () async {
      final tag1 = tagStore.createTag('genre');
      final tag2 = tagStore.createTag('mood');
      final tag3 = tagStore.createTag('era');

      final su = _randomSongUnit();
      songUnitStore.add(su);

      await service.addTagToSongUnit(su.id, tag1.id);
      await service.addTagToSongUnit(su.id, tag2.id);
      // tag3 NOT added

      final tags = await service.getTagsForSongUnit(su.id);
      expect(tags.length, equals(2));
      expect(tags.any((t) => t.id == tag1.id), isTrue);
      expect(tags.any((t) => t.id == tag2.id), isTrue);
      expect(tags.any((t) => t.id == tag3.id), isFalse);
    });

    test('returns empty list for song unit with no tags', () async {
      final su = _randomSongUnit();
      songUnitStore.add(su);
      final tags = await service.getTagsForSongUnit(su.id);
      expect(tags, isEmpty);
    });

    test('returns empty list for non-existent song unit', () async {
      final tags = await service.getTagsForSongUnit('nonexistent');
      expect(tags, isEmpty);
    });
  });

  // ==========================================================================
  // removeTagFromSongUnit updates both directions
  // ==========================================================================

  group('removeTagFromSongUnit updates both directions', () {
    test('removes song unit from getSongUnitsWithTag', () async {
      final tag = tagStore.createTag('removable');
      final su = _randomSongUnit();
      songUnitStore.add(su);

      await service.addTagToSongUnit(su.id, tag.id);
      expect(
        (await service.getSongUnitsWithTag(tag.id)).any((s) => s.id == su.id),
        isTrue,
      );

      await service.removeTagFromSongUnit(su.id, tag.id);
      expect(
        (await service.getSongUnitsWithTag(tag.id)).any((s) => s.id == su.id),
        isFalse,
      );
    });

    test('removes tag from getTagsForSongUnit', () async {
      final tag = tagStore.createTag('temporary');
      final su = _randomSongUnit();
      songUnitStore.add(su);

      await service.addTagToSongUnit(su.id, tag.id);
      expect(
        (await service.getTagsForSongUnit(su.id)).any((t) => t.id == tag.id),
        isTrue,
      );

      await service.removeTagFromSongUnit(su.id, tag.id);
      expect(
        (await service.getTagsForSongUnit(su.id)).any((t) => t.id == tag.id),
        isFalse,
      );
    });

    test('does not affect other song units with same tag', () async {
      final tag = tagStore.createTag('shared');
      final su1 = _randomSongUnit();
      final su2 = _randomSongUnit();
      songUnitStore
        ..add(su1)
        ..add(su2);

      await service.addTagToSongUnit(su1.id, tag.id);
      await service.addTagToSongUnit(su2.id, tag.id);

      await service.removeTagFromSongUnit(su1.id, tag.id);

      final collection = await service.getSongUnitsWithTag(tag.id);
      expect(collection.any((s) => s.id == su1.id), isFalse);
      expect(collection.any((s) => s.id == su2.id), isTrue);
    });

    test('does not affect other tags on same song unit', () async {
      final tagKeep = tagStore.createTag('keep');
      final tagRemove = tagStore.createTag('remove');
      final su = _randomSongUnit();
      songUnitStore.add(su);

      await service.addTagToSongUnit(su.id, tagKeep.id);
      await service.addTagToSongUnit(su.id, tagRemove.id);

      await service.removeTagFromSongUnit(su.id, tagRemove.id);

      final tags = await service.getTagsForSongUnit(su.id);
      expect(tags.any((t) => t.id == tagKeep.id), isTrue);
      expect(tags.any((t) => t.id == tagRemove.id), isFalse);
    });

    test('removing tag not on song unit is a no-op', () async {
      final tag = tagStore.createTag('never_added');
      final su = _randomSongUnit();
      songUnitStore.add(su);

      await service.removeTagFromSongUnit(su.id, tag.id);

      final tags = await service.getTagsForSongUnit(su.id);
      expect(tags, isEmpty);
      expect(service.lastError, isNull);
    });
  });

  // ==========================================================================
  // Bidirectional consistency
  // ==========================================================================

  group('bidirectional consistency', () {
    test('both query directions agree after complex operations', () async {
      final tags = <Tag>[];
      for (var i = 0; i < 3; i++) {
        tags.add(tagStore.createTag('consistency_$i'));
      }

      final songUnits = <SongUnit>[];
      for (var i = 0; i < 4; i++) {
        final su = _randomSongUnit();
        songUnitStore.add(su);
        songUnits.add(su);
      }

      // Association pattern:
      // su0: tag0, tag1
      // su1: tag1, tag2
      // su2: tag0, tag2
      // su3: (none)
      await service.addTagToSongUnit(songUnits[0].id, tags[0].id);
      await service.addTagToSongUnit(songUnits[0].id, tags[1].id);
      await service.addTagToSongUnit(songUnits[1].id, tags[1].id);
      await service.addTagToSongUnit(songUnits[1].id, tags[2].id);
      await service.addTagToSongUnit(songUnits[2].id, tags[0].id);
      await service.addTagToSongUnit(songUnits[2].id, tags[2].id);

      // Verify from tag direction
      final withTag0 = await service.getSongUnitsWithTag(tags[0].id);
      expect(
        withTag0.map((s) => s.id).toSet(),
        equals({songUnits[0].id, songUnits[2].id}),
      );

      final withTag1 = await service.getSongUnitsWithTag(tags[1].id);
      expect(
        withTag1.map((s) => s.id).toSet(),
        equals({songUnits[0].id, songUnits[1].id}),
      );

      final withTag2 = await service.getSongUnitsWithTag(tags[2].id);
      expect(
        withTag2.map((s) => s.id).toSet(),
        equals({songUnits[1].id, songUnits[2].id}),
      );

      // Verify from song unit direction
      final tagsForSu0 = await service.getTagsForSongUnit(songUnits[0].id);
      expect(
        tagsForSu0.map((t) => t.id).toSet(),
        equals({tags[0].id, tags[1].id}),
      );

      final tagsForSu1 = await service.getTagsForSongUnit(songUnits[1].id);
      expect(
        tagsForSu1.map((t) => t.id).toSet(),
        equals({tags[1].id, tags[2].id}),
      );

      final tagsForSu2 = await service.getTagsForSongUnit(songUnits[2].id);
      expect(
        tagsForSu2.map((t) => t.id).toSet(),
        equals({tags[0].id, tags[2].id}),
      );

      final tagsForSu3 = await service.getTagsForSongUnit(songUnits[3].id);
      expect(tagsForSu3, isEmpty);

      // Cross-check: for every (songUnit, tag) pair, both directions agree
      for (final su in songUnits) {
        final suTags = await service.getTagsForSongUnit(su.id);
        for (final tag in tags) {
          final susWithTag = await service.getSongUnitsWithTag(tag.id);
          final tagOnSu = suTags.any((t) => t.id == tag.id);
          final suInTag = susWithTag.any((s) => s.id == su.id);
          expect(
            tagOnSu,
            equals(suInTag),
            reason: 'Bidirectional mismatch: su=${su.id}, tag=${tag.id}',
          );
        }
      }
    });

    test('consistency holds after add-remove-add cycle', () async {
      final tag = tagStore.createTag('cycle');
      final su = _randomSongUnit();
      songUnitStore.add(su);

      // Add
      await service.addTagToSongUnit(su.id, tag.id);
      expect((await service.getSongUnitsWithTag(tag.id)).length, equals(1));
      expect((await service.getTagsForSongUnit(su.id)).length, equals(1));

      // Remove
      await service.removeTagFromSongUnit(su.id, tag.id);
      expect(await service.getSongUnitsWithTag(tag.id), isEmpty);
      expect(await service.getTagsForSongUnit(su.id), isEmpty);

      // Re-add
      await service.addTagToSongUnit(su.id, tag.id);
      expect((await service.getSongUnitsWithTag(tag.id)).length, equals(1));
      expect((await service.getTagsForSongUnit(su.id)).length, equals(1));
    });
  });

  // ==========================================================================
  // Edge cases
  // ==========================================================================

  group('edge cases', () {
    test('addTagToSongUnit with non-existent song unit sets error', () async {
      final tag = tagStore.createTag('orphan');
      await service.addTagToSongUnit('nonexistent_su', tag.id);
      expect(service.lastError, isNotNull);
    });

    test(
      'removeTagFromSongUnit with non-existent song unit sets error',
      () async {
        final tag = tagStore.createTag('orphan2');
        await service.removeTagFromSongUnit('nonexistent_su', tag.id);
        expect(service.lastError, isNotNull);
      },
    );

    test(
      'song unit with pre-existing tags: getTagsForSongUnit works',
      () async {
        final tag = tagStore.createTag('preexisting');
        final su = _randomSongUnit(tagIds: [tag.id]);
        songUnitStore.add(su);

        final tags = await service.getTagsForSongUnit(su.id);
        expect(tags.length, equals(1));
        expect(tags.first.id, equals(tag.id));
      },
    );

    test('large number of associations maintains consistency', () async {
      final tag = tagStore.createTag('bulk');
      final songUnits = <SongUnit>[];

      for (var i = 0; i < 50; i++) {
        final su = _randomSongUnit();
        songUnitStore.add(su);
        songUnits.add(su);
        await service.addTagToSongUnit(su.id, tag.id);
      }

      final collection = await service.getSongUnitsWithTag(tag.id);
      expect(collection.length, equals(50));

      // Remove half
      for (var i = 0; i < 25; i++) {
        await service.removeTagFromSongUnit(songUnits[i].id, tag.id);
      }

      final afterRemoval = await service.getSongUnitsWithTag(tag.id);
      expect(afterRemoval.length, equals(25));

      // Verify the right ones remain
      for (var i = 25; i < 50; i++) {
        expect(afterRemoval.any((s) => s.id == songUnits[i].id), isTrue);
      }
      for (var i = 0; i < 25; i++) {
        expect(afterRemoval.any((s) => s.id == songUnits[i].id), isFalse);
      }
    });
  });
}
