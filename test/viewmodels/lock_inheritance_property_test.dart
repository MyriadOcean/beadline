/// Task 4.6: Property tests for lock inheritance
///
/// Properties tested:
/// - Property 24: Lock Inheritance from Playlist
/// - Property 25: Lock State Independence
///
/// **Validates: Requirements 8.2, 8.3, 8.5**
library;

import 'dart:math';

import 'package:beadline/models/playlist_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

// Reuse mock infrastructure from shuffle_locks_property_test.dart
import 'shuffle_locks_property_test.dart';

void main() {
  group('Lock Inheritance Property Tests (Task 4.6)', () {
    // ========================================================================
    // Feature: queue-playlist-system, Property 24: Lock Inheritance from Playlist
    // **Validates: Requirements 8.2, 8.3**
    //
    // For any playlist with a lock state, adding it to the queue should
    // create a group with the same lock state.
    // ========================================================================
    test('Property 24: Lock Inheritance from Playlist - '
        'group inherits lock state from source playlist', () async {
      const iterations = 100;
      final random = Random();

      for (var i = 0; i < iterations; i++) {
        final ctx = ShuffleTestContext();

        // Create a playlist with random songs
        final songCount = 2 + random.nextInt(5); // 2-6 songs
        final songs = await ctx.createSongs(songCount, prefix: 'P24');

        final playlist = await ctx.tagRepo.createCollection('Playlist_$i');
        for (var j = 0; j < songs.length; j++) {
          await ctx.tagRepo.addItemToCollection(
            playlist.id,
            PlaylistItem(
              id: ShuffleTestGenerators.id(),
              type: PlaylistItemType.songUnit,
              targetId: songs[j].id,
              order: j,
            ),
          );
        }

        // Randomly set lock state on the playlist
        final sourceLocked = random.nextBool();
        if (sourceLocked) {
          await ctx.tagRepo.setCollectionLock(playlist.id, true);
        }

        // Add playlist to queue
        final group = await ctx.viewModel.addCollectionToQueue(playlist.id);

        // Verify group was created
        expect(
          group,
          isNotNull,
          reason: 'Iteration $i: group should be created',
        );

        // Verify group's lock state matches the source playlist
        expect(
          group!.isLocked,
          equals(sourceLocked),
          reason:
              'Iteration $i: group lock state (${group.isLocked}) '
              'should match source playlist lock state ($sourceLocked)',
        );

        // Verify group is actually a group
        expect(
          group.isGroup,
          isTrue,
          reason: 'Iteration $i: created tag should be a group',
        );

        // Verify group contains the correct number of songs
        expect(
          group.playlistMetadata!.items.length,
          equals(songCount),
          reason: 'Iteration $i: group should contain all songs',
        );

        ctx.dispose();
      }
    });

    // ========================================================================
    // Feature: queue-playlist-system, Property 25: Lock State Independence
    // **Validates: Requirements 8.5**
    //
    // For any playlist and group created from it in the queue, changing the
    // playlist's lock state should not affect the group's lock state.
    // ========================================================================
    test('Property 25: Lock State Independence - '
        'changing playlist lock does not affect queue group lock', () async {
      const iterations = 100;
      final random = Random();

      for (var i = 0; i < iterations; i++) {
        final ctx = ShuffleTestContext();

        // Create a playlist with random songs
        final songCount = 2 + random.nextInt(4); // 2-5 songs
        final songs = await ctx.createSongs(songCount, prefix: 'P25');

        final playlist = await ctx.tagRepo.createCollection('Playlist_$i');
        for (var j = 0; j < songs.length; j++) {
          await ctx.tagRepo.addItemToCollection(
            playlist.id,
            PlaylistItem(
              id: ShuffleTestGenerators.id(),
              type: PlaylistItemType.songUnit,
              targetId: songs[j].id,
              order: j,
            ),
          );
        }

        // Set initial lock state randomly
        final initialLocked = random.nextBool();
        await ctx.tagRepo.setCollectionLock(playlist.id, initialLocked);

        // Add playlist to queue - group inherits lock state
        final group = await ctx.viewModel.addCollectionToQueue(playlist.id);
        expect(
          group,
          isNotNull,
          reason: 'Iteration $i: group should be created',
        );

        final groupId = group!.id;
        final groupLockAfterCreation = group.isLocked;

        // Verify initial inheritance
        expect(
          groupLockAfterCreation,
          equals(initialLocked),
          reason: 'Iteration $i: group should initially inherit lock state',
        );

        // Now toggle the playlist's lock state 1-3 times
        final toggleCount = 1 + random.nextInt(3);
        var currentPlaylistLock = initialLocked;
        for (var t = 0; t < toggleCount; t++) {
          currentPlaylistLock = !currentPlaylistLock;
          await ctx.tagRepo.setCollectionLock(playlist.id, currentPlaylistLock);
        }

        // Verify the playlist lock actually changed
        final updatedPlaylist = await ctx.tagRepo.getTag(playlist.id);
        expect(
          updatedPlaylist!.isLocked,
          equals(currentPlaylistLock),
          reason: 'Iteration $i: playlist lock should have changed',
        );

        // Verify the group's lock state is UNCHANGED
        final updatedGroup = await ctx.tagRepo.getTag(groupId);
        expect(
          updatedGroup!.isLocked,
          equals(groupLockAfterCreation),
          reason:
              'Iteration $i: group lock state should remain '
              '$groupLockAfterCreation after playlist lock changed to '
              '$currentPlaylistLock',
        );

        ctx.dispose();
      }
    });
  });
}
