/// Task 11.2: Property tests for tag associations
///
/// Properties tested:
/// - Property 1: Tag-Song Unit Bidirectional Association
/// - Property 2: Tag Collection Membership
/// - Property 3: Tag CRUD Operations
/// - Property 4: Tag Hierarchy Preservation
///
/// **Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.5, 2.6**
library;

import 'dart:math';

import 'package:beadline/models/metadata.dart';
import 'package:beadline/models/playback_preferences.dart';
import 'package:beadline/models/song_unit.dart';
import 'package:beadline/models/source_collection.dart';
import 'package:beadline/models/tag.dart';
import 'package:beadline/viewmodels/tag_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'shuffle_locks_property_test.dart';

// ============================================================================
// Generators for tag association tests
// ============================================================================

class TagAssociationGenerators {
  static final Random _random = Random();
  static const Uuid _uuid = Uuid();

  /// Generate a random tag name (1-30 chars, no reserved characters)
  static String tagName() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789 _-';
    final length = 1 + _random.nextInt(30);
    return String.fromCharCodes(
      List.generate(
        length,
        (_) => chars.codeUnitAt(_random.nextInt(chars.length)),
      ),
    ).trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Generate a unique tag name to avoid collisions
  static String uniqueTagName() => 'tag_${_uuid.v4().substring(0, 8)}';

  /// Generate a random SongUnit and register it in storage
  static Future<SongUnit> createSongUnit(MockLibraryRepository repo) async {
    final su = SongUnit(
      id: _uuid.v4(),
      metadata: Metadata(
        title: 'Song_${_random.nextInt(100000)}',
        artists: const ['Artist'],
        album: 'Album',
        duration: Duration(seconds: 60 + _random.nextInt(240)),
      ),
      sources: const SourceCollection(),
      preferences: PlaybackPreferences.defaults(),
    );
    await repo.addSongUnit(su);
    return su;
  }

  /// Generate a random count in [min, max]
  static int randomInt(int min, int max) =>
      min + _random.nextInt(max - min + 1);
}

// ============================================================================
// Test context for tag association tests
// ============================================================================

class TagAssociationTestContext {
  TagAssociationTestContext() {
    songUnitStorage = InMemorySongUnitStorage();
    tagStorage = InMemoryTagStorage();
    libraryRepo = MockLibraryRepository(songUnitStorage);
    tagRepo = MockTagRepository(tagStorage);
    settingsRepo = MockSettingsRepository();
    playbackStorage = MockPlaybackStateStorage();

    // Create default queue so TagViewModel initializes properly
    tagStorage.add(
      const Tag(id: 'default', name: 'Default Queue', type: TagType.user),
    );

    viewModel = TagViewModel(
      tagRepository: tagRepo,
      libraryRepository: libraryRepo,
      settingsRepository: settingsRepo,
      playbackStateStorage: playbackStorage,
    );
  }

  late final InMemorySongUnitStorage songUnitStorage;
  late final InMemoryTagStorage tagStorage;
  late final MockLibraryRepository libraryRepo;
  late final MockTagRepository tagRepo;
  late final MockSettingsRepository settingsRepo;
  late final MockPlaybackStateStorage playbackStorage;
  late final TagViewModel viewModel;

  void dispose() {
    viewModel.dispose();
    libraryRepo.dispose();
    tagRepo.dispose();
    songUnitStorage.clear();
    tagStorage.clear();
  }
}

// ============================================================================
// Property tests
// ============================================================================

void main() {
  group('Tag Associations Property Tests (Task 11.2)', () {
    // ========================================================================
    // Feature: queue-playlist-system, Property 1: Tag-Song Unit Bidirectional Association
    // **Validates: Requirements 2.1, 2.6**
    //
    // For any song unit and any tag, adding the tag to the song unit should
    // result in the song unit appearing in the tag's collection, and vice versa.
    // ========================================================================
    test('Property 1: Tag-Song Unit Bidirectional Association - '
        'adding tag to song unit creates bidirectional link', () async {
      const iterations = 100;

      for (var i = 0; i < iterations; i++) {
        final ctx = TagAssociationTestContext();
        await Future.delayed(const Duration(milliseconds: 5));

        // Generate random song unit and tag
        final su = await TagAssociationGenerators.createSongUnit(
          ctx.libraryRepo,
        );
        final tagName = TagAssociationGenerators.uniqueTagName();
        final tag = await ctx.tagRepo.createTag(tagName);

        // Add tag to song unit via ViewModel
        await ctx.viewModel.addTagToSongUnit(su.id, tag.id);

        // Direction 1: song unit should appear when querying by tag
        final songUnitsWithTag = await ctx.libraryRepo.getAllSongUnits();
        final matchingSongUnits = songUnitsWithTag
            .where((s) => s.tagIds.contains(tag.id))
            .toList();
        expect(
          matchingSongUnits.any((s) => s.id == su.id),
          isTrue,
          reason: 'Iteration $i: song unit should appear in tag collection',
        );

        // Direction 2: tag should appear on the song unit
        final updatedSu = await ctx.libraryRepo.getSongUnit(su.id);
        expect(
          updatedSu,
          isNotNull,
          reason: 'Iteration $i: song unit should still exist',
        );
        expect(
          updatedSu!.tagIds.contains(tag.id),
          isTrue,
          reason: 'Iteration $i: tag should be on the song unit',
        );

        ctx.dispose();
      }
    });

    // ========================================================================
    // Feature: queue-playlist-system, Property 2: Tag Collection Membership
    // **Validates: Requirements 2.2, 2.3**
    //
    // For any tag, querying its collection should return exactly the set of
    // song units that have that tag.
    // ========================================================================
    test(
      'Property 2: Tag Collection Membership - '
      'tag collection contains exactly the song units with that tag',
      () async {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          final ctx = TagAssociationTestContext();
          await Future.delayed(const Duration(milliseconds: 5));

          // Create a tag
          final tagName = TagAssociationGenerators.uniqueTagName();
          final tag = await ctx.tagRepo.createTag(tagName);

          // Create a random number of song units (2-8)
          final totalCount = TagAssociationGenerators.randomInt(2, 8);
          final allSongUnits = <SongUnit>[];
          for (var j = 0; j < totalCount; j++) {
            allSongUnits.add(
              await TagAssociationGenerators.createSongUnit(ctx.libraryRepo),
            );
          }

          // Randomly select a subset to tag (at least 1)
          final taggedCount = TagAssociationGenerators.randomInt(1, totalCount);
          final taggedIds = <String>{};
          final indices = List.generate(totalCount, (idx) => idx)..shuffle();
          for (var j = 0; j < taggedCount; j++) {
            final su = allSongUnits[indices[j]];
            await ctx.viewModel.addTagToSongUnit(su.id, tag.id);
            taggedIds.add(su.id);
          }

          // Query the collection: all song units that have this tag
          final allSus = await ctx.libraryRepo.getAllSongUnits();
          final collectionIds = allSus
              .where((s) => s.tagIds.contains(tag.id))
              .map((s) => s.id)
              .toSet();

          // Verify exact match
          expect(
            collectionIds,
            equals(taggedIds),
            reason:
                'Iteration $i: tag collection should contain exactly '
                'the tagged song units ($taggedCount of $totalCount)',
          );

          ctx.dispose();
        }
      },
    );

    // ========================================================================
    // Feature: queue-playlist-system, Property 3: Tag CRUD Operations
    // **Validates: Requirements 2.4**
    //
    // For any tag name, creating a tag should make it retrievable, renaming
    // should change its name, and deleting should make it non-retrievable.
    // ========================================================================
    test('Property 3: Tag CRUD Operations - '
        'create, rename, delete lifecycle works correctly', () async {
      const iterations = 100;

      for (var i = 0; i < iterations; i++) {
        final ctx = TagAssociationTestContext();
        await Future.delayed(const Duration(milliseconds: 5));

        final originalName = TagAssociationGenerators.uniqueTagName();
        final newName = TagAssociationGenerators.uniqueTagName();

        // CREATE: tag should be retrievable after creation
        final tag = await ctx.viewModel.createTag(originalName);
        expect(
          tag,
          isNotNull,
          reason: 'Iteration $i: createTag should return a tag',
        );

        final retrieved = await ctx.tagRepo.getTag(tag!.id);
        expect(
          retrieved,
          isNotNull,
          reason: 'Iteration $i: created tag should be retrievable',
        );
        expect(
          retrieved!.name,
          equals(originalName),
          reason: 'Iteration $i: retrieved tag should have correct name',
        );

        // RENAME: tag name should change
        await ctx.viewModel.renameTag(tag.id, newName);

        final renamed = await ctx.tagRepo.getTag(tag.id);
        expect(
          renamed,
          isNotNull,
          reason: 'Iteration $i: renamed tag should still be retrievable',
        );
        expect(
          renamed!.name,
          equals(newName),
          reason: 'Iteration $i: tag name should be updated',
        );

        // DELETE: tag should no longer be retrievable
        await ctx.viewModel.deleteTag(tag.id);

        final deleted = await ctx.tagRepo.getTag(tag.id);
        expect(
          deleted,
          isNull,
          reason: 'Iteration $i: deleted tag should not be retrievable',
        );

        ctx.dispose();
      }
    });

    // ========================================================================
    // Feature: queue-playlist-system, Property 4: Tag Hierarchy Preservation
    // **Validates: Requirements 2.5**
    //
    // For any tag with a parent, the parent-child relationship should be
    // maintained and retrievable.
    // ========================================================================
    test('Property 4: Tag Hierarchy Preservation - '
        'parent-child relationships are maintained', () async {
      const iterations = 100;

      for (var i = 0; i < iterations; i++) {
        final ctx = TagAssociationTestContext();
        await Future.delayed(const Duration(milliseconds: 5));

        // Create a parent tag
        final parentName = TagAssociationGenerators.uniqueTagName();
        final parent = await ctx.viewModel.createTag(parentName);
        expect(
          parent,
          isNotNull,
          reason: 'Iteration $i: parent tag should be created',
        );

        // Create 1-4 child tags under the parent
        final childCount = TagAssociationGenerators.randomInt(1, 4);
        final childIds = <String>[];

        for (var c = 0; c < childCount; c++) {
          final childName = TagAssociationGenerators.uniqueTagName();
          final child = await ctx.viewModel.createTag(
            childName,
            parentId: parent!.id,
          );
          expect(
            child,
            isNotNull,
            reason: 'Iteration $i: child tag $c should be created',
          );
          childIds.add(child!.id);
        }

        // Verify: each child's parentId points to the parent
        for (var c = 0; c < childCount; c++) {
          final child = await ctx.tagRepo.getTag(childIds[c]);
          expect(
            child,
            isNotNull,
            reason: 'Iteration $i: child $c should be retrievable',
          );
          expect(
            child!.parentId,
            equals(parent!.id),
            reason: 'Iteration $i: child $c parentId should match parent',
          );
        }

        // Verify: getChildTags returns exactly the children we created
        final children = await ctx.tagRepo.getChildTags(parent!.id);
        final retrievedChildIds = children.map((t) => t.id).toSet();
        expect(
          retrievedChildIds,
          equals(childIds.toSet()),
          reason:
              'Iteration $i: getChildTags should return exactly '
              '$childCount children',
        );

        // Verify: parent has no parentId itself (it's a root tag)
        final retrievedParent = await ctx.tagRepo.getTag(parent.id);
        expect(
          retrievedParent!.parentId,
          isNull,
          reason: 'Iteration $i: parent should have no parentId',
        );

        ctx.dispose();
      }
    });
  });
}
