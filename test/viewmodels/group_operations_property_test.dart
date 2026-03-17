/// Task 7.2: Property tests for group operations
///
/// Properties tested:
/// - Property 14: Group Creation from Playlist
/// - Property 16: Group Parent Relationship
/// - Property 17: Group Song Unit Addition
/// - Property 18: Group Order Preservation
/// - Property 19: Group Reordering
/// - Property 20: Song Unit Movement Between Groups
///
/// **Validates: Requirements 5.4, 6.4, 6.5, 6.6, 6.7, 6.8**
library;

import 'dart:math';

import 'package:beadline/models/playlist_metadata.dart';
import 'package:beadline/models/tag.dart';
import 'package:beadline/viewmodels/tag_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'shuffle_locks_property_test.dart';

// ============================================================================
// Test context helper for group operations
// ============================================================================

class GroupTestContext {
  GroupTestContext() {
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

  /// Create a playlist (non-group collection) with the given songs.
  Future<Tag> createPlaylistWithSongs(
    List<dynamic> songs, {
    bool locked = false,
  }) async {
    final playlist = await tagRepo.createCollection(
      'Playlist_${_uuid.v4().substring(0, 8)}',
    );
    for (var i = 0; i < songs.length; i++) {
      await tagRepo.addItemToCollection(
        playlist.id,
        PlaylistItem(
          id: _uuid.v4(),
          type: PlaylistItemType.songUnit,
          targetId: songs[i].id,
          order: i,
        ),
      );
    }
    if (locked) {
      await tagRepo.setCollectionLock(playlist.id, true);
    }
    return (await tagRepo.getTag(playlist.id))!;
  }

  /// Get the items of a collection by ID.
  Future<List<PlaylistItem>> getItems(String collectionId) async {
    final tag = await tagRepo.getTag(collectionId);
    return tag?.playlistMetadata?.items ?? [];
  }

  /// Get song unit IDs from a collection's items (songUnit type only).
  Future<List<String>> getSongUnitIds(String collectionId) async {
    final items = await getItems(collectionId);
    return items
        .where((i) => i.type == PlaylistItemType.songUnit)
        .map((i) => i.targetId)
        .toList();
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
  group('Group Operations Property Tests (Task 7.2)', () {
    // ========================================================================
    // Feature: queue-playlist-system, Property 14: Group Creation from Playlist
    // **Validates: Requirements 5.4**
    //
    // For any playlist added to the queue, a group should be created
    // containing exactly the song units from that playlist.
    // ========================================================================
    test(
      'Property 14: Group Creation from Playlist - '
      'adding playlist to queue creates group with exactly the same song units',
      () async {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          final ctx = GroupTestContext();
          await Future.delayed(const Duration(milliseconds: 10));

          // Create a playlist with 1-8 songs
          final songCount = 1 + GroupTestContext._random.nextInt(8);
          final songs = await ctx.createSongs(songCount, prefix: 'P14');
          final songIds = songs.map((s) => s.id as String).toList();

          final playlist = await ctx.createPlaylistWithSongs(songs);

          // Add playlist to queue
          final group = await ctx.viewModel.addCollectionToQueue(playlist.id);

          // Verify group was created
          expect(
            group,
            isNotNull,
            reason: 'Iteration $i: group should be created',
          );

          // Verify group contains exactly the same song units
          final groupSongIds = await ctx.getSongUnitIds(group!.id);
          expect(
            groupSongIds,
            equals(songIds),
            reason:
                'Iteration $i: group should contain exactly the playlist songs in order',
          );

          // Verify the group is marked as a group
          expect(
            group.isGroup,
            isTrue,
            reason: 'Iteration $i: created tag should be a group',
          );

          ctx.dispose();
        }
      },
    );

    // ========================================================================
    // Feature: queue-playlist-system, Property 16: Group Parent Relationship
    // **Validates: Requirements 6.4**
    //
    // For any group created in a collection, the group's parent should be
    // set to the containing collection.
    // ========================================================================
    test('Property 16: Group Parent Relationship - '
        'group parent is set to the containing collection', () async {
      const iterations = 100;

      for (var i = 0; i < iterations; i++) {
        final ctx = GroupTestContext();
        await Future.delayed(const Duration(milliseconds: 10));

        // Create a playlist with 1-5 songs and add to queue
        final songCount = 1 + GroupTestContext._random.nextInt(5);
        final songs = await ctx.createSongs(songCount, prefix: 'P16');
        final playlist = await ctx.createPlaylistWithSongs(songs);

        final group = await ctx.viewModel.addCollectionToQueue(playlist.id);
        expect(
          group,
          isNotNull,
          reason: 'Iteration $i: group should be created',
        );

        // Verify parent is the active queue
        expect(
          group!.parentId,
          equals('default'),
          reason: 'Iteration $i: group parent should be the active queue',
        );

        // Also test creating a group directly in a standalone collection
        final standaloneCollection = await ctx.tagRepo.createCollection(
          'Standalone_$i',
        );
        final directGroup = await ctx.viewModel.createCollection(
          'DirectGroup_$i',
          parentId: standaloneCollection.id,
          isGroup: true,
        );

        expect(
          directGroup.parentId,
          equals(standaloneCollection.id),
          reason:
              'Iteration $i: directly created group parent should be the standalone collection',
        );

        ctx.dispose();
      }
    });

    // ========================================================================
    // Feature: queue-playlist-system, Property 17: Group Song Unit Addition
    // **Validates: Requirements 6.5**
    //
    // For any group and song unit, adding the song unit to the group should
    // result in it being present in the group.
    // ========================================================================
    test('Property 17: Group Song Unit Addition - '
        'adding a song unit to a group makes it present in the group', () async {
      const iterations = 100;

      for (var i = 0; i < iterations; i++) {
        final ctx = GroupTestContext();
        await Future.delayed(const Duration(milliseconds: 10));

        // Create a group within the queue
        final group = await ctx.viewModel.createCollection(
          'Group_$i',
          parentId: 'default',
          isGroup: true,
        );

        // Add 1-6 song units one by one
        final songCount = 1 + GroupTestContext._random.nextInt(6);
        final songs = await ctx.createSongs(songCount, prefix: 'P17');
        final addedIds = <String>[];

        for (final song in songs) {
          await ctx.viewModel.addSongUnitToCollection(group.id, song.id);
          addedIds.add(song.id as String);

          // Verify the song is present after each addition
          final currentIds = await ctx.getSongUnitIds(group.id);
          expect(
            currentIds.contains(song.id),
            isTrue,
            reason:
                'Iteration $i: song ${song.id} should be present after adding',
          );
        }

        // Verify all songs are present at the end
        final finalIds = await ctx.getSongUnitIds(group.id);
        expect(
          finalIds.toSet(),
          equals(addedIds.toSet()),
          reason: 'Iteration $i: all added songs should be present',
        );

        ctx.dispose();
      }
    });

    // ========================================================================
    // Feature: queue-playlist-system, Property 18: Group Order Preservation
    // **Validates: Requirements 6.6**
    //
    // For any group and sequence of song units, the order of song units
    // within the group should be maintained.
    // ========================================================================
    test('Property 18: Group Order Preservation - '
        'song units maintain their insertion order within a group', () async {
      const iterations = 100;

      for (var i = 0; i < iterations; i++) {
        final ctx = GroupTestContext();
        await Future.delayed(const Duration(milliseconds: 10));

        // Create a group
        final group = await ctx.viewModel.createCollection(
          'Group_$i',
          parentId: 'default',
          isGroup: true,
        );

        // Add 2-8 songs in a specific order
        final songCount = 2 + GroupTestContext._random.nextInt(7);
        final songs = await ctx.createSongs(songCount, prefix: 'P18');
        final expectedOrder = <String>[];

        for (final song in songs) {
          await ctx.viewModel.addSongUnitToCollection(group.id, song.id);
          expectedOrder.add(song.id as String);
        }

        // Verify order is preserved
        final actualOrder = await ctx.getSongUnitIds(group.id);
        expect(
          actualOrder,
          equals(expectedOrder),
          reason: 'Iteration $i: song order should match insertion order',
        );

        ctx.dispose();
      }
    });

    // ========================================================================
    // Feature: queue-playlist-system, Property 19: Group Reordering
    // **Validates: Requirements 6.7**
    //
    // For any collection with multiple groups, reordering groups should
    // change their positions as specified.
    // ========================================================================
    test(
      'Property 19: Group Reordering - '
      'reordering items in a collection changes positions as specified',
      () async {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          final ctx = GroupTestContext();
          await Future.delayed(const Duration(milliseconds: 10));

          // Create a parent collection
          final parent = await ctx.tagRepo.createCollection('Parent_$i');

          // Add 3-6 groups to the parent
          final groupCount = 3 + GroupTestContext._random.nextInt(4);
          final groupIds = <String>[];

          for (var g = 0; g < groupCount; g++) {
            final group = await ctx.viewModel.createCollection(
              'SubGroup_${i}_$g',
              parentId: parent.id,
              isGroup: true,
            );
            // Add the group as a collection reference in the parent
            await ctx.viewModel.addCollectionReference(parent.id, group.id);
            groupIds.add(group.id);
          }

          // Get original item order
          final originalItems = await ctx.getItems(parent.id);
          expect(
            originalItems.length,
            equals(groupCount),
            reason: 'Iteration $i: parent should have $groupCount items',
          );

          // Pick random oldIndex and newIndex
          final oldIndex = GroupTestContext._random.nextInt(groupCount);
          var newIndex = GroupTestContext._random.nextInt(groupCount);
          // Ensure they differ when possible
          if (groupCount > 1) {
            while (newIndex == oldIndex) {
              newIndex = GroupTestContext._random.nextInt(groupCount);
            }
          }

          final movedItemTargetId = originalItems[oldIndex].targetId;

          // Perform reorder
          await ctx.viewModel.reorderCollection(parent.id, oldIndex, newIndex);

          // Verify the moved item is now at newIndex
          final reorderedItems = await ctx.getItems(parent.id);
          expect(
            reorderedItems.length,
            equals(groupCount),
            reason:
                'Iteration $i: item count should be preserved after reorder',
          );
          expect(
            reorderedItems[newIndex].targetId,
            equals(movedItemTargetId),
            reason:
                'Iteration $i: item at oldIndex=$oldIndex should now be at newIndex=$newIndex',
          );

          // Verify all original items are still present
          final originalTargetIds = originalItems
              .map((i) => i.targetId)
              .toSet();
          final reorderedTargetIds = reorderedItems
              .map((i) => i.targetId)
              .toSet();
          expect(
            reorderedTargetIds,
            equals(originalTargetIds),
            reason: 'Iteration $i: all items should be preserved after reorder',
          );

          ctx.dispose();
        }
      },
    );

    // ========================================================================
    // Feature: queue-playlist-system, Property 20: Song Unit Movement Between Groups
    // **Validates: Requirements 6.8**
    //
    // For any song unit in group A, moving it to group B should result in
    // it being removed from A and added to B.
    // ========================================================================
    test(
      'Property 20: Song Unit Movement Between Groups - '
      'moving a song unit from group A to group B removes from A and adds to B',
      () async {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          final ctx = GroupTestContext();
          await Future.delayed(const Duration(milliseconds: 10));

          // Create two groups
          final groupA = await ctx.viewModel.createCollection(
            'GroupA_$i',
            parentId: 'default',
            isGroup: true,
          );
          final groupB = await ctx.viewModel.createCollection(
            'GroupB_$i',
            parentId: 'default',
            isGroup: true,
          );

          // Add 2-5 songs to group A
          final songCountA = 2 + GroupTestContext._random.nextInt(4);
          final songsA = await ctx.createSongs(songCountA, prefix: 'A');
          for (final song in songsA) {
            await ctx.viewModel.addSongUnitToCollection(groupA.id, song.id);
          }

          // Add 0-3 songs to group B
          final songCountB = GroupTestContext._random.nextInt(4);
          final songsB = await ctx.createSongs(songCountB, prefix: 'B');
          for (final song in songsB) {
            await ctx.viewModel.addSongUnitToCollection(groupB.id, song.id);
          }

          // Pick a random song from group A to move
          final moveIndex = GroupTestContext._random.nextInt(songCountA);
          final songToMove = songsA[moveIndex];

          // Get the item ID for the song in group A (needed for removal)
          final groupAItems = await ctx.getItems(groupA.id);
          final itemToRemove = groupAItems.firstWhere(
            (item) => item.targetId == songToMove.id,
          );

          // Move: remove from A, add to B
          await ctx.viewModel.removeFromCollection(groupA.id, itemToRemove.id);
          await ctx.viewModel.addSongUnitToCollection(groupB.id, songToMove.id);

          // Verify song is no longer in group A
          final groupAIdsAfter = await ctx.getSongUnitIds(groupA.id);
          expect(
            groupAIdsAfter.contains(songToMove.id),
            isFalse,
            reason: 'Iteration $i: moved song should not be in group A',
          );

          // Verify song is now in group B
          final groupBIdsAfter = await ctx.getSongUnitIds(groupB.id);
          expect(
            groupBIdsAfter.contains(songToMove.id),
            isTrue,
            reason: 'Iteration $i: moved song should be in group B',
          );

          // Verify group A has one fewer song
          expect(
            groupAIdsAfter.length,
            equals(songCountA - 1),
            reason: 'Iteration $i: group A should have one fewer song',
          );

          // Verify group B has one more song
          expect(
            groupBIdsAfter.length,
            equals(songCountB + 1),
            reason: 'Iteration $i: group B should have one more song',
          );

          ctx.dispose();
        }
      },
    );
  });
}
