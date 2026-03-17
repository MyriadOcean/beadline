/// Task 17.3: Property tests for multi-select bulk move
///
/// Properties tested:
/// - Property 36: Bulk Move Preserves Relative Order
/// - Property 37: Bulk Move Clears Selection
///
/// **Validates: Requirements 18.3, 18.4, 18.5, 18.6**
library;

import 'dart:math';

import 'package:beadline/models/playlist_metadata.dart';
import 'package:beadline/models/tag.dart';
import 'package:beadline/viewmodels/tag_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'shuffle_locks_property_test.dart';

// ============================================================================
// Test context helper for bulk move tests
// ============================================================================

class BulkMoveTestContext {
  BulkMoveTestContext() {
    songUnitStorage = InMemorySongUnitStorage();
    tagStorage = InMemoryTagStorage();
    libraryRepo = MockLibraryRepository(songUnitStorage);
    tagRepo = MockTagRepository(tagStorage);
    settingsRepo = MockSettingsRepository();
    playbackStorage = MockPlaybackStateStorage();

    // Create default queue (active)
    tagStorage.add(
      Tag(
        id: 'default',
        name: 'Default Queue',
        type: TagType.user,
        playlistMetadata: PlaylistMetadata.empty().copyWith(currentIndex: 0),
      ),
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

  static const Uuid _uuid = Uuid();
  static final Random _random = Random();

  /// Create song units and register them in the library.
  Future<List<dynamic>> createSongs(int count, {String prefix = 'Song'}) async {
    final songs = <dynamic>[];
    for (var i = 0; i < count; i++) {
      final song = ShuffleTestGenerators.makeSongUnit(title: '${prefix}_$i');
      await libraryRepo.addSongUnit(song);
      songs.add(song);
    }
    return songs;
  }

  /// Create a group within a parent collection.
  /// Also adds a collectionReference to the parent.
  /// Returns the group Tag.
  Future<Tag> createGroup(String parentId, {String? name}) async {
    final group = await tagRepo.createCollection(
      name ?? 'Group_${_uuid.v4().substring(0, 8)}',
      parentId: parentId,
      isGroup: true,
    );
    // Add a collection reference in the parent
    final parentTag = await tagRepo.getTag(parentId);
    final parentItems = parentTag?.playlistMetadata?.items ?? [];
    await tagRepo.addItemToCollection(
      parentId,
      PlaylistItem(
        id: _uuid.v4(),
        type: PlaylistItemType.collectionReference,
        targetId: group.id,
        order: parentItems.length,
      ),
    );
    return (await tagRepo.getTag(group.id))!;
  }

  /// Create a group with songs already in it.
  Future<Tag> createGroupWithSongs(
    String parentId,
    List<dynamic> songs, {
    String? name,
  }) async {
    final group = await createGroup(parentId, name: name);
    for (var i = 0; i < songs.length; i++) {
      await tagRepo.addItemToCollection(
        group.id,
        PlaylistItem(
          id: _uuid.v4(),
          type: PlaylistItemType.songUnit,
          targetId: songs[i].id as String,
          order: i,
        ),
      );
    }
    return (await tagRepo.getTag(group.id))!;
  }

  /// Add a song unit directly to a collection at the top level.
  /// Returns the PlaylistItem ID.
  Future<String> addSongToCollection(
    String collectionId,
    dynamic song, {
    int? order,
  }) async {
    final tag = await tagRepo.getTag(collectionId);
    final items = tag?.playlistMetadata?.items ?? [];
    final itemId = _uuid.v4();
    await tagRepo.addItemToCollection(
      collectionId,
      PlaylistItem(
        id: itemId,
        type: PlaylistItemType.songUnit,
        targetId: song.id as String,
        order: order ?? items.length,
      ),
    );
    return itemId;
  }

  /// Get all items from a collection.
  Future<List<PlaylistItem>> getItems(String collectionId) async {
    final tag = await tagRepo.getTag(collectionId);
    return tag?.playlistMetadata?.items ?? [];
  }

  /// Get song unit items only from a collection.
  Future<List<PlaylistItem>> getSongUnitItems(String collectionId) async {
    final items = await getItems(collectionId);
    return items.where((i) => i.type == PlaylistItemType.songUnit).toList();
  }

  /// Get song unit target IDs from a collection (in order).
  Future<List<String>> getSongUnitTargetIds(String collectionId) async {
    final items = await getSongUnitItems(collectionId);
    items.sort((a, b) => a.order.compareTo(b.order));
    return items.map((i) => i.targetId).toList();
  }

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
  group('Bulk Move Property Tests (Task 17.3)', () {
    // ========================================================================
    // Feature: queue-playlist-system, Property 36: Bulk Move Preserves Relative Order
    // **Validates: Requirements 18.3, 18.4, 18.5**
    //
    // For any set of selected song units in a collection, bulk moving them
    // into a group (or out of a group) should result in all selected items
    // being in the target location, and their relative order should match
    // their original relative order.
    // ========================================================================
    test('Property 36 (bulkMoveToGroup): selected top-level items moved into '
        'group preserve their relative order', () async {
      const iterations = 100;

      for (var i = 0; i < iterations; i++) {
        final ctx = BulkMoveTestContext();
        await Future.delayed(const Duration(milliseconds: 10));

        // Use a standalone collection to avoid queue side effects
        final collection = await ctx.tagRepo.createCollection('Coll_$i');

        // Add 4-8 top-level songs
        final songCount = 4 + BulkMoveTestContext._random.nextInt(5);
        final songs = await ctx.createSongs(songCount, prefix: 'S_$i');
        final itemIds = <String>[];
        for (final song in songs) {
          final itemId = await ctx.addSongToCollection(collection.id, song);
          itemIds.add(itemId);
        }

        // Create an empty target group
        final group = await ctx.createGroup(collection.id, name: 'Target_$i');

        // Randomly select 2+ items (at least 2 to test relative order)
        final selectCount =
            2 + BulkMoveTestContext._random.nextInt(songCount - 1);
        final indices = List.generate(songCount, (j) => j)..shuffle();
        final selectedIndices = indices.sublist(0, selectCount)..sort();

        // Record the original relative order of selected songs
        final expectedOrder = selectedIndices
            .map((idx) => songs[idx].id as String)
            .toList();

        // Select the items in the ViewModel
        for (final idx in selectedIndices) {
          ctx.viewModel.toggleSelection(itemIds[idx]);
        }

        // Bulk move to group
        await ctx.viewModel.bulkMoveToGroup(collection.id, group.id);

        // Verify: all selected items are now in the group
        final groupTargetIds = await ctx.getSongUnitTargetIds(group.id);
        for (final songId in expectedOrder) {
          expect(
            groupTargetIds.contains(songId),
            isTrue,
            reason: 'Iteration $i: selected song $songId should be in group',
          );
        }

        // Verify: relative order is preserved
        final movedIds = groupTargetIds.where(expectedOrder.contains).toList();
        expect(
          movedIds,
          equals(expectedOrder),
          reason:
              'Iteration $i: relative order of moved items should be preserved',
        );

        // Verify: selected items are NOT at the top level anymore
        final topLevelIds = await ctx.getSongUnitTargetIds(collection.id);
        for (final songId in expectedOrder) {
          expect(
            topLevelIds.contains(songId),
            isFalse,
            reason:
                'Iteration $i: moved song $songId should not be at top level',
          );
        }

        // Verify: non-selected items remain at top level
        final nonSelectedSongIds = <String>[];
        for (var j = 0; j < songCount; j++) {
          if (!selectedIndices.contains(j)) {
            nonSelectedSongIds.add(songs[j].id as String);
          }
        }
        for (final songId in nonSelectedSongIds) {
          expect(
            topLevelIds.contains(songId),
            isTrue,
            reason:
                'Iteration $i: non-selected song $songId should remain at top level',
          );
        }

        ctx.dispose();
      }
    });

    test('Property 36 (bulkRemoveFromGroup): selected items in a group moved '
        'to top-level preserve their relative order', () async {
      const iterations = 100;

      for (var i = 0; i < iterations; i++) {
        final ctx = BulkMoveTestContext();
        await Future.delayed(const Duration(milliseconds: 10));

        final collection = await ctx.tagRepo.createCollection('Coll_$i');

        // Add 1-3 top-level songs (so top level isn't empty)
        final topCount = 1 + BulkMoveTestContext._random.nextInt(3);
        final topSongs = await ctx.createSongs(topCount, prefix: 'Top_$i');
        for (final song in topSongs) {
          await ctx.addSongToCollection(collection.id, song);
        }

        // Create a group with 3-6 songs
        final groupSongCount = 3 + BulkMoveTestContext._random.nextInt(4);
        final groupSongs = await ctx.createSongs(
          groupSongCount,
          prefix: 'Grp_$i',
        );
        final group = await ctx.createGroupWithSongs(
          collection.id,
          groupSongs,
          name: 'Source_$i',
        );

        // Get the item IDs for songs in the group
        final groupItems = await ctx.getSongUnitItems(group.id);
        groupItems.sort((a, b) => a.order.compareTo(b.order));

        // Randomly select 2+ items from the group
        final selectCount =
            2 + BulkMoveTestContext._random.nextInt(groupSongCount - 1);
        final indices = List.generate(groupSongCount, (j) => j)..shuffle();
        final selectedIndices = indices.sublist(0, selectCount)..sort();

        // Record expected order (by their original order in the group)
        final expectedOrder = selectedIndices
            .map((idx) => groupItems[idx].targetId)
            .toList();

        // Select the items
        for (final idx in selectedIndices) {
          ctx.viewModel.toggleSelection(groupItems[idx].id);
        }

        // Bulk remove from group
        await ctx.viewModel.bulkRemoveFromGroup(collection.id);

        // Verify: all selected items are now at the top level
        final topLevelIds = await ctx.getSongUnitTargetIds(collection.id);
        for (final songId in expectedOrder) {
          expect(
            topLevelIds.contains(songId),
            isTrue,
            reason: 'Iteration $i: removed song $songId should be at top level',
          );
        }

        // Verify: relative order is preserved among the moved items
        // They should appear at the end of the top-level list in order
        final movedInTopLevel = topLevelIds
            .where(expectedOrder.contains)
            .toList();
        expect(
          movedInTopLevel,
          equals(expectedOrder),
          reason:
              'Iteration $i: relative order of removed items should be preserved',
        );

        // Verify: selected items are NOT in the group anymore
        final remainingGroupIds = await ctx.getSongUnitTargetIds(group.id);
        for (final songId in expectedOrder) {
          expect(
            remainingGroupIds.contains(songId),
            isFalse,
            reason: 'Iteration $i: removed song $songId should not be in group',
          );
        }

        ctx.dispose();
      }
    });

    // ========================================================================
    // Feature: queue-playlist-system, Property 37: Bulk Move Clears Selection
    // **Validates: Requirements 18.6**
    //
    // For any non-empty selection of song units, after performing a bulk
    // move operation, the selection set should be empty.
    // ========================================================================
    test(
      'Property 37 (bulkMoveToGroup): selection is cleared after bulk move to group',
      () async {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          final ctx = BulkMoveTestContext();
          await Future.delayed(const Duration(milliseconds: 10));

          final collection = await ctx.tagRepo.createCollection('Coll_$i');

          // Add 3-7 top-level songs
          final songCount = 3 + BulkMoveTestContext._random.nextInt(5);
          final songs = await ctx.createSongs(songCount, prefix: 'S_$i');
          final itemIds = <String>[];
          for (final song in songs) {
            final itemId = await ctx.addSongToCollection(collection.id, song);
            itemIds.add(itemId);
          }

          // Create target group
          final group = await ctx.createGroup(collection.id, name: 'Target_$i');

          // Select 1+ random items
          final selectCount =
              1 + BulkMoveTestContext._random.nextInt(songCount);
          final indices = List.generate(songCount, (j) => j)..shuffle();
          for (var j = 0; j < selectCount; j++) {
            ctx.viewModel.toggleSelection(itemIds[indices[j]]);
          }

          // Verify selection is non-empty before the operation
          expect(
            ctx.viewModel.hasSelection,
            isTrue,
            reason:
                'Iteration $i: selection should be non-empty before bulk move',
          );

          // Bulk move to group
          await ctx.viewModel.bulkMoveToGroup(collection.id, group.id);

          // Verify selection is cleared
          expect(
            ctx.viewModel.hasSelection,
            isFalse,
            reason:
                'Iteration $i: selection should be empty after bulkMoveToGroup',
          );
          expect(
            ctx.viewModel.selectionCount,
            equals(0),
            reason:
                'Iteration $i: selectionCount should be 0 after bulkMoveToGroup',
          );

          ctx.dispose();
        }
      },
    );

    test(
      'Property 37 (bulkRemoveFromGroup): selection is cleared after bulk remove from group',
      () async {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          final ctx = BulkMoveTestContext();
          await Future.delayed(const Duration(milliseconds: 10));

          final collection = await ctx.tagRepo.createCollection('Coll_$i');

          // Create a group with 2-6 songs
          final groupSongCount = 2 + BulkMoveTestContext._random.nextInt(5);
          final groupSongs = await ctx.createSongs(
            groupSongCount,
            prefix: 'Grp_$i',
          );
          final group = await ctx.createGroupWithSongs(
            collection.id,
            groupSongs,
            name: 'Source_$i',
          );

          // Get item IDs from the group
          final groupItems = await ctx.getSongUnitItems(group.id);

          // Select 1+ random items from the group
          final selectCount =
              1 + BulkMoveTestContext._random.nextInt(groupSongCount);
          final indices = List.generate(groupSongCount, (j) => j)..shuffle();
          for (var j = 0; j < selectCount; j++) {
            ctx.viewModel.toggleSelection(groupItems[indices[j]].id);
          }

          // Verify selection is non-empty before the operation
          expect(
            ctx.viewModel.hasSelection,
            isTrue,
            reason:
                'Iteration $i: selection should be non-empty before bulk remove',
          );

          // Bulk remove from group
          await ctx.viewModel.bulkRemoveFromGroup(collection.id);

          // Verify selection is cleared
          expect(
            ctx.viewModel.hasSelection,
            isFalse,
            reason:
                'Iteration $i: selection should be empty after bulkRemoveFromGroup',
          );
          expect(
            ctx.viewModel.selectionCount,
            equals(0),
            reason:
                'Iteration $i: selectionCount should be 0 after bulkRemoveFromGroup',
          );

          ctx.dispose();
        }
      },
    );
  });
}
