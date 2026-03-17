/// Task 14.2: Property tests for collection isolation
///
/// Properties tested:
/// - Property 31: Collection Copy Semantics on Queue Addition
/// - Property 32: Collection Isolation After Copy
///
/// **Validates: Requirements 16.1, 16.2, 16.3, 16.4, 16.5, 16.6**
library;

import 'dart:math';

import 'package:beadline/models/playlist_metadata.dart';
import 'package:beadline/models/tag.dart';
import 'package:beadline/viewmodels/tag_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'shuffle_locks_property_test.dart';

// ============================================================================
// Test context helper for collection isolation tests
// ============================================================================

class CollectionIsolationTestContext {
  CollectionIsolationTestContext() {
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

  /// Create a playlist (collection) with the given songs.
  Future<Tag> createPlaylistWithSongs(
    List<dynamic> songs, {
    String? name,
  }) async {
    final playlist = await tagRepo.createCollection(
      name ?? 'Playlist_${_uuid.v4().substring(0, 8)}',
    );
    for (var i = 0; i < songs.length; i++) {
      await tagRepo.addItemToCollection(
        playlist.id,
        PlaylistItem(
          id: _uuid.v4(),
          type: PlaylistItemType.songUnit,
          targetId: songs[i].id as String,
          order: i,
        ),
      );
    }
    return (await tagRepo.getTag(playlist.id))!;
  }

  /// Get song unit items from a collection.
  Future<List<PlaylistItem>> getSongUnitItems(String collectionId) async {
    final tag = await tagRepo.getTag(collectionId);
    if (tag == null || tag.playlistMetadata == null) return [];
    return tag.playlistMetadata!.items
        .where((i) => i.type == PlaylistItemType.songUnit)
        .toList();
  }

  /// Get song unit target IDs from a collection's items.
  Future<List<String>> getSongUnitTargetIds(String collectionId) async {
    final items = await getSongUnitItems(collectionId);
    return items.map((i) => i.targetId).toList();
  }

  /// Get playlist item IDs from a collection.
  Future<List<String>> getPlaylistItemIds(String collectionId) async {
    final items = await getSongUnitItems(collectionId);
    return items.map((i) => i.id).toList();
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
  group('Collection Isolation Property Tests (Task 14.2)', () {
    // ========================================================================
    // Feature: queue-playlist-system, Property 31: Collection Copy Semantics on Queue Addition
    // **Validates: Requirements 16.1, 16.2**
    //
    // For any playlist with song units, adding it to a queue should create a
    // new group whose song unit entries are independent PlaylistItem instances
    // (different IDs) pointing to the same song unit target IDs, and the
    // group's collection ID should differ from the playlist's ID.
    // ========================================================================
    test(
      'Property 31: Collection Copy Semantics on Queue Addition - '
      'group has independent PlaylistItem instances with same target IDs',
      () async {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          final ctx = CollectionIsolationTestContext();
          await Future.delayed(const Duration(milliseconds: 10));

          // Create a playlist with 1-8 songs
          final songCount =
              1 + CollectionIsolationTestContext._random.nextInt(8);
          final songs = await ctx.createSongs(songCount, prefix: 'P31_$i');
          final playlist = await ctx.createPlaylistWithSongs(songs);

          // Get playlist's PlaylistItem IDs and target IDs before adding to queue
          final playlistItemIds = await ctx.getPlaylistItemIds(playlist.id);
          final playlistTargetIds = await ctx.getSongUnitTargetIds(playlist.id);

          // Add playlist to queue
          final group = await ctx.viewModel.addCollectionToQueue(playlist.id);

          // Verify group was created
          expect(
            group,
            isNotNull,
            reason: 'Iteration $i: group should be created',
          );

          // 1. Group's collection ID should differ from the playlist's ID
          expect(
            group!.id,
            isNot(equals(playlist.id)),
            reason: 'Iteration $i: group ID should differ from playlist ID',
          );

          // 2. Group's PlaylistItem IDs should all be different from playlist's
          final groupItemIds = await ctx.getPlaylistItemIds(group.id);
          for (final groupItemId in groupItemIds) {
            expect(
              playlistItemIds.contains(groupItemId),
              isFalse,
              reason:
                  'Iteration $i: group PlaylistItem ID "$groupItemId" '
                  'should not match any playlist PlaylistItem ID',
            );
          }

          // 3. Group's target IDs should match the playlist's target IDs
          final groupTargetIds = await ctx.getSongUnitTargetIds(group.id);
          expect(
            groupTargetIds,
            equals(playlistTargetIds),
            reason:
                'Iteration $i: group target IDs should match playlist target IDs',
          );

          // 4. Item counts should match
          expect(
            groupItemIds.length,
            equals(playlistItemIds.length),
            reason:
                'Iteration $i: group should have same number of items as playlist',
          );

          ctx.dispose();
        }
      },
    );

    // ========================================================================
    // Feature: queue-playlist-system, Property 32: Collection Isolation After Copy
    // **Validates: Requirements 16.3, 16.4, 16.5, 16.6**
    //
    // For any playlist that has been added to a queue as a group:
    // - Removing a song unit from the queue group should not change the
    //   playlist's item count
    // - Adding a song unit to the playlist should not change the queue
    //   group's item count
    // - Reordering the queue group should not change the playlist's item order
    // ========================================================================
    test('Property 32: Collection Isolation After Copy - '
        'mutations on group do not affect playlist and vice versa', () async {
      const iterations = 100;

      for (var i = 0; i < iterations; i++) {
        final ctx = CollectionIsolationTestContext();
        await Future.delayed(const Duration(milliseconds: 10));

        // Create a playlist with 3-8 songs (need at least 3 for reorder + remove)
        final songCount = 3 + CollectionIsolationTestContext._random.nextInt(6);
        final songs = await ctx.createSongs(songCount, prefix: 'P32_$i');
        final playlist = await ctx.createPlaylistWithSongs(songs);

        // Add playlist to queue
        final group = await ctx.viewModel.addCollectionToQueue(playlist.id);
        expect(
          group,
          isNotNull,
          reason: 'Iteration $i: group should be created',
        );

        // Record initial state
        final initialPlaylistTargetIds = await ctx.getSongUnitTargetIds(
          playlist.id,
        );
        final initialGroupTargetIds = await ctx.getSongUnitTargetIds(group!.id);
        final initialPlaylistCount = initialPlaylistTargetIds.length;
        final initialGroupCount = initialGroupTargetIds.length;

        // --- Test 16.3: Remove a song from the queue group ---
        final groupItems = await ctx.getSongUnitItems(group.id);
        final removeIndex = CollectionIsolationTestContext._random.nextInt(
          groupItems.length,
        );
        final itemToRemove = groupItems[removeIndex];
        await ctx.tagRepo.removeItemFromCollection(group.id, itemToRemove.id);

        // Playlist item count should be unchanged
        final playlistAfterGroupRemove = await ctx.getSongUnitItems(
          playlist.id,
        );
        expect(
          playlistAfterGroupRemove.length,
          equals(initialPlaylistCount),
          reason:
              'Iteration $i: removing from group should not affect playlist count',
        );

        // Playlist target IDs should be unchanged
        final playlistTargetIdsAfterGroupRemove = await ctx
            .getSongUnitTargetIds(playlist.id);
        expect(
          playlistTargetIdsAfterGroupRemove,
          equals(initialPlaylistTargetIds),
          reason:
              'Iteration $i: removing from group should not affect playlist contents',
        );

        // --- Test 16.4: Add a song to the playlist ---
        final extraSong = (await ctx.createSongs(1, prefix: 'Extra_$i')).first;
        await ctx.tagRepo.addItemToCollection(
          playlist.id,
          PlaylistItem(
            id: const Uuid().v4(),
            type: PlaylistItemType.songUnit,
            targetId: extraSong.id as String,
            order: initialPlaylistCount,
          ),
        );

        // Group item count should be unchanged (minus the one we removed)
        final groupAfterPlaylistAdd = await ctx.getSongUnitItems(group.id);
        expect(
          groupAfterPlaylistAdd.length,
          equals(initialGroupCount - 1),
          reason:
              'Iteration $i: adding to playlist should not affect group count',
        );

        // --- Test 16.5: Reorder the queue group ---
        final currentGroupItems = await ctx.getSongUnitItems(group.id);
        if (currentGroupItems.length >= 2) {
          // Swap first and last items
          await ctx.tagRepo.reorderCollection(
            group.id,
            0,
            currentGroupItems.length - 1,
          );

          // Playlist order should be unchanged
          final playlistTargetIdsAfterGroupReorder = await ctx
              .getSongUnitTargetIds(playlist.id);
          // The playlist now has the extra song appended, so compare
          // the original portion
          final originalPortionAfterReorder = playlistTargetIdsAfterGroupReorder
              .sublist(0, initialPlaylistCount);
          expect(
            originalPortionAfterReorder,
            equals(initialPlaylistTargetIds),
            reason:
                'Iteration $i: reordering group should not affect playlist order',
          );
        }

        // --- Test 16.6: Same song unit exists independently in both ---
        // Verify the playlist still has all its original songs plus the extra
        final finalPlaylistTargetIds = await ctx.getSongUnitTargetIds(
          playlist.id,
        );
        expect(
          finalPlaylistTargetIds.length,
          equals(initialPlaylistCount + 1),
          reason: 'Iteration $i: playlist should have original songs + 1 extra',
        );

        // Verify the group has its songs minus the removed one
        final finalGroupTargetIds = await ctx.getSongUnitTargetIds(group.id);
        expect(
          finalGroupTargetIds.length,
          equals(initialGroupCount - 1),
          reason: 'Iteration $i: group should have original songs - 1 removed',
        );

        ctx.dispose();
      }
    });
  });
}
