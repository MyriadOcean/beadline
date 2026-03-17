/// Task 16.2: Property tests for drag-and-drop operations
///
/// Properties tested:
/// - Property 33: Move Song Unit Into and Out of Group
/// - Property 34: Display Order Consistency After Move
/// - Property 35: Group Move Preserves Contents
///
/// **Validates: Requirements 17.2, 17.3, 17.5, 17.7**
library;

import 'dart:math';

import 'package:beadline/models/playlist_metadata.dart';
import 'package:beadline/models/tag.dart';
import 'package:beadline/viewmodels/tag_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'shuffle_locks_property_test.dart';

// ============================================================================
// Test context helper for drag-and-drop tests
// ============================================================================

class DragDropTestContext {
  DragDropTestContext() {
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

  /// Create a group within a parent collection and add songs to it.
  /// Also adds a collectionReference to the parent.
  /// Returns the group Tag.
  Future<Tag> createGroupWithSongs(
    String parentId,
    List<dynamic> songs, {
    String? name,
  }) async {
    final group = await tagRepo.createCollection(
      name ?? 'Group_${_uuid.v4().substring(0, 8)}',
      parentId: parentId,
      isGroup: true,
    );
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

  /// Get song unit target IDs from a collection.
  Future<List<String>> getSongUnitTargetIds(String collectionId) async {
    final items = await getSongUnitItems(collectionId);
    return items.map((i) => i.targetId).toList();
  }

  /// Check that display orders in a collection are sequential (0, 1, 2, ...)
  /// with no gaps and no duplicates.
  Future<bool> hasSequentialOrders(String collectionId) async {
    final items = await getItems(collectionId);
    if (items.isEmpty) return true;
    final orders = items.map((i) => i.order).toList()..sort();
    for (var i = 0; i < orders.length; i++) {
      if (orders[i] != i) return false;
    }
    return true;
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
  group('Drag-and-Drop Property Tests (Task 16.2)', () {
    // ========================================================================
    // Feature: queue-playlist-system, Property 33: Move Song Unit Into and Out of Group
    // **Validates: Requirements 17.2, 17.3**
    //
    // For any song unit at the top level of a collection and any group within
    // that collection, moving the song unit into the group should result in
    // the song unit being present in the group and absent from the top level;
    // moving it back out should restore it to the top level and remove it
    // from the group.
    // ========================================================================
    test(
      'Property 33: Move Song Unit Into and Out of Group - '
      'moving into group removes from top level, moving out restores',
      () async {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          final ctx = DragDropTestContext();
          await Future.delayed(const Duration(milliseconds: 10));

          // Use a standalone collection (not the active queue) to avoid
          // queue-specific side effects
          final collection = await ctx.tagRepo.createCollection('Coll_$i');

          // Add 2-6 top-level songs
          final topLevelCount = 2 + DragDropTestContext._random.nextInt(5);
          final topLevelSongs = await ctx.createSongs(
            topLevelCount,
            prefix: 'Top_$i',
          );
          final topLevelItemIds = <String>[];
          for (final song in topLevelSongs) {
            final itemId = await ctx.addSongToCollection(collection.id, song);
            topLevelItemIds.add(itemId);
          }

          // Create a group with 0-3 existing songs
          final groupSongCount = DragDropTestContext._random.nextInt(4);
          final groupSongs = await ctx.createSongs(
            groupSongCount,
            prefix: 'Grp_$i',
          );
          final group = await ctx.createGroupWithSongs(
            collection.id,
            groupSongs,
            name: 'Group_$i',
          );

          // Pick a random top-level song to move into the group
          final moveIdx = DragDropTestContext._random.nextInt(topLevelCount);
          final songToMove = topLevelSongs[moveIdx];
          final itemIdToMove = topLevelItemIds[moveIdx];

          // --- Move INTO group ---
          await ctx.viewModel.moveSongUnitToGroup(
            collection.id,
            itemIdToMove,
            group.id,
          );

          // Verify: song is in the group
          final groupIdsAfterMoveIn = await ctx.getSongUnitTargetIds(group.id);
          expect(
            groupIdsAfterMoveIn.contains(songToMove.id as String),
            isTrue,
            reason: 'Iteration $i: song should be in group after move-in',
          );

          // Verify: song is NOT at the top level
          final topLevelIdsAfterMoveIn = await ctx.getSongUnitTargetIds(
            collection.id,
          );
          expect(
            topLevelIdsAfterMoveIn.contains(songToMove.id as String),
            isFalse,
            reason:
                'Iteration $i: song should not be at top level after move-in',
          );

          // --- Move OUT of group ---
          // Find the new item ID for the song in the group
          final groupItemsAfterMoveIn = await ctx.getSongUnitItems(group.id);
          final movedItem = groupItemsAfterMoveIn.firstWhere(
            (item) => item.targetId == (songToMove.id as String),
          );

          await ctx.viewModel.moveSongUnitOutOfGroup(
            group.id,
            movedItem.id,
            collection.id,
            insertIndex: 0,
          );

          // Verify: song is back at the top level
          final topLevelIdsAfterMoveOut = await ctx.getSongUnitTargetIds(
            collection.id,
          );
          expect(
            topLevelIdsAfterMoveOut.contains(songToMove.id as String),
            isTrue,
            reason: 'Iteration $i: song should be at top level after move-out',
          );

          // Verify: song is NOT in the group
          final groupIdsAfterMoveOut = await ctx.getSongUnitTargetIds(group.id);
          expect(
            groupIdsAfterMoveOut.contains(songToMove.id as String),
            isFalse,
            reason: 'Iteration $i: song should not be in group after move-out',
          );

          // Verify: total song count is preserved
          final totalAfter =
              topLevelIdsAfterMoveOut.length + groupIdsAfterMoveOut.length;
          final totalBefore = topLevelCount + groupSongCount;
          expect(
            totalAfter,
            equals(totalBefore),
            reason: 'Iteration $i: total song count should be preserved',
          );

          ctx.dispose();
        }
      },
    );

    // ========================================================================
    // Feature: queue-playlist-system, Property 34: Display Order Consistency After Move
    // **Validates: Requirements 17.5**
    //
    // For any collection after a move operation (into group, out of group, or
    // between groups), the display orders of all items in every affected
    // collection should be sequential with no gaps and no duplicates.
    // ========================================================================
    test('Property 34: Display Order Consistency After Move - '
        'display orders are sequential after move operations', () async {
      const iterations = 100;

      for (var i = 0; i < iterations; i++) {
        final ctx = DragDropTestContext();
        await Future.delayed(const Duration(milliseconds: 10));

        final collection = await ctx.tagRepo.createCollection('Coll_$i');

        // Add 3-6 top-level songs
        final topLevelCount = 3 + DragDropTestContext._random.nextInt(4);
        final topLevelSongs = await ctx.createSongs(
          topLevelCount,
          prefix: 'Top_$i',
        );
        final topLevelItemIds = <String>[];
        for (final song in topLevelSongs) {
          final itemId = await ctx.addSongToCollection(collection.id, song);
          topLevelItemIds.add(itemId);
        }

        // Create two groups with 1-3 songs each
        final groupASongCount = 1 + DragDropTestContext._random.nextInt(3);
        final groupASongs = await ctx.createSongs(
          groupASongCount,
          prefix: 'GA_$i',
        );
        final groupA = await ctx.createGroupWithSongs(
          collection.id,
          groupASongs,
          name: 'GroupA_$i',
        );

        final groupBSongCount = 1 + DragDropTestContext._random.nextInt(3);
        final groupBSongs = await ctx.createSongs(
          groupBSongCount,
          prefix: 'GB_$i',
        );
        final groupB = await ctx.createGroupWithSongs(
          collection.id,
          groupBSongs,
          name: 'GroupB_$i',
        );

        // Randomly choose a move operation type
        final opType = DragDropTestContext._random.nextInt(3);

        if (opType == 0) {
          // Move a top-level song into groupA
          final moveIdx = DragDropTestContext._random.nextInt(topLevelCount);
          await ctx.viewModel.moveSongUnitToGroup(
            collection.id,
            topLevelItemIds[moveIdx],
            groupA.id,
          );
        } else if (opType == 1) {
          // Move a song from groupA out to top level
          final groupAItems = await ctx.getSongUnitItems(groupA.id);
          if (groupAItems.isNotEmpty) {
            final moveIdx = DragDropTestContext._random.nextInt(
              groupAItems.length,
            );
            await ctx.viewModel.moveSongUnitOutOfGroup(
              groupA.id,
              groupAItems[moveIdx].id,
              collection.id,
              insertIndex: 0,
            );
          }
        } else {
          // Move a song from groupA into groupB (via moveSongUnitToGroup
          // which searches child groups)
          final groupAItems = await ctx.getSongUnitItems(groupA.id);
          if (groupAItems.isNotEmpty) {
            final moveIdx = DragDropTestContext._random.nextInt(
              groupAItems.length,
            );
            await ctx.viewModel.moveSongUnitToGroup(
              collection.id,
              groupAItems[moveIdx].id,
              groupB.id,
            );
          }
        }

        // Verify display orders are sequential in all affected collections
        expect(
          await ctx.hasSequentialOrders(collection.id),
          isTrue,
          reason:
              'Iteration $i (op=$opType): parent collection orders should be sequential',
        );
        expect(
          await ctx.hasSequentialOrders(groupA.id),
          isTrue,
          reason:
              'Iteration $i (op=$opType): groupA orders should be sequential',
        );
        expect(
          await ctx.hasSequentialOrders(groupB.id),
          isTrue,
          reason:
              'Iteration $i (op=$opType): groupB orders should be sequential',
        );

        ctx.dispose();
      }
    });

    // ========================================================================
    // Feature: queue-playlist-system, Property 35: Group Move Preserves Contents
    // **Validates: Requirements 17.7**
    //
    // For any group within a collection, moving the group to a different
    // position should not change the set or order of song units within
    // that group.
    // ========================================================================
    test(
      'Property 35: Group Move Preserves Contents - '
      'moving a group does not change its internal song units or their order',
      () async {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          final ctx = DragDropTestContext();
          await Future.delayed(const Duration(milliseconds: 10));

          final collection = await ctx.tagRepo.createCollection('Coll_$i');

          // Add 1-3 top-level songs to give the collection some items
          final topLevelCount = 1 + DragDropTestContext._random.nextInt(3);
          final topLevelSongs = await ctx.createSongs(
            topLevelCount,
            prefix: 'Top_$i',
          );
          for (final song in topLevelSongs) {
            await ctx.addSongToCollection(collection.id, song);
          }

          // Create 2-4 groups with 1-5 songs each
          final groupCount = 2 + DragDropTestContext._random.nextInt(3);
          final groups = <Tag>[];
          final groupContentsBefore = <String, List<String>>{};

          for (var g = 0; g < groupCount; g++) {
            final songCount = 1 + DragDropTestContext._random.nextInt(5);
            final songs = await ctx.createSongs(songCount, prefix: 'G${g}_$i');
            final group = await ctx.createGroupWithSongs(
              collection.id,
              songs,
              name: 'Group${g}_$i',
            );
            groups.add(group);

            // Record the group's song unit target IDs in order
            groupContentsBefore[group.id] = await ctx.getSongUnitTargetIds(
              group.id,
            );
          }

          // Pick a random group to move
          final moveGroupIdx = DragDropTestContext._random.nextInt(groupCount);
          final groupToMove = groups[moveGroupIdx];

          // Find the PlaylistItem ID for this group's collection reference
          // in the parent collection
          final parentItems = await ctx.getItems(collection.id);
          final groupRefItem = parentItems.firstWhere(
            (item) =>
                item.type == PlaylistItemType.collectionReference &&
                item.targetId == groupToMove.id,
          );

          // Pick a new position (different from current when possible)
          final totalParentItems = parentItems.length;
          var newIndex = DragDropTestContext._random.nextInt(totalParentItems);
          if (totalParentItems > 1) {
            final currentIndex = parentItems.indexOf(groupRefItem);
            while (newIndex == currentIndex) {
              newIndex = DragDropTestContext._random.nextInt(totalParentItems);
            }
          }

          // Move the group
          await ctx.viewModel.moveGroup(
            collection.id,
            groupRefItem.id,
            newIndex,
          );

          // Verify ALL groups' contents are unchanged
          for (final group in groups) {
            final contentsAfter = await ctx.getSongUnitTargetIds(group.id);
            expect(
              contentsAfter,
              equals(groupContentsBefore[group.id]),
              reason:
                  'Iteration $i: group "${group.name}" contents should be '
                  'unchanged after moving group "${groupToMove.name}"',
            );
          }

          // Also verify the moved group is still in the parent collection
          final parentItemsAfter = await ctx.getItems(collection.id);
          final movedGroupStillPresent = parentItemsAfter.any(
            (item) =>
                item.type == PlaylistItemType.collectionReference &&
                item.targetId == groupToMove.id,
          );
          expect(
            movedGroupStillPresent,
            isTrue,
            reason:
                'Iteration $i: moved group should still be referenced in parent',
          );

          // Verify total item count in parent is preserved
          expect(
            parentItemsAfter.length,
            equals(parentItems.length),
            reason:
                'Iteration $i: parent item count should be preserved after group move',
          );

          ctx.dispose();
        }
      },
    );
  });
}
