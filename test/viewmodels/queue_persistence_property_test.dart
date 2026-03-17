/// Task 4.4: Property tests for queue persistence
///
/// Properties tested:
/// - Property 11: Queue Persistence Round Trip
/// - Property 23: Lock State Persistence
///
/// **Validates: Requirements 4.7, 7.7, 14.2, 14.3, 14.4**
library;

import 'dart:math';

import 'package:beadline/models/playlist_metadata.dart';
import 'package:beadline/models/tag.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

// Reuse mock infrastructure from shuffle_locks_property_test.dart
import 'shuffle_locks_property_test.dart';

// ============================================================================
// Test generators for persistence tests
// ============================================================================

class PersistenceTestGenerators {
  static final Random _random = Random();
  static const Uuid _uuid = Uuid();

  /// Generate a random lock state.
  static bool randomBool() => _random.nextBool();

  /// Generate a random currentIndex in range [-1, itemCount-1].
  /// -1 means not playing, >=0 means active queue at that index.
  static int randomCurrentIndex(int itemCount) {
    if (itemCount == 0) return -1;
    // 30% chance of -1 (not playing), 70% chance of valid index
    if (_random.nextDouble() < 0.3) return -1;
    return _random.nextInt(itemCount);
  }

  /// Generate a random playback position in ms (0 to 300000 = 5 min).
  static int randomPlaybackPositionMs() => _random.nextInt(300001);

  /// Generate a random display order.
  static int randomDisplayOrder() => _random.nextInt(100);

  /// Generate a list of PlaylistItems (song unit references) with random order.
  static List<PlaylistItem> randomSongUnitItems(List<String> songUnitIds) {
    final items = <PlaylistItem>[];
    for (var i = 0; i < songUnitIds.length; i++) {
      items.add(
        PlaylistItem(
          id: _uuid.v4(),
          type: PlaylistItemType.songUnit,
          targetId: songUnitIds[i],
          order: i,
        ),
      );
    }
    return items;
  }
}

// ============================================================================
// Property tests
// ============================================================================

void main() {
  group('Queue Persistence Property Tests (Task 4.4)', () {
    // ========================================================================
    // Feature: queue-playlist-system, Property 11: Queue Persistence Round Trip
    // **Validates: Requirements 4.7, 14.2, 14.3, 14.4**
    //
    // For any queue state (song units, order, lock states, current index),
    // saving and then loading should produce an equivalent queue state.
    // ========================================================================
    test('Property 11: Queue Persistence Round Trip - '
        'saving and loading queue state preserves all properties', () async {
      const iterations = 100;

      for (var i = 0; i < iterations; i++) {
        final ctx = ShuffleTestContext();

        // Generate random song count (1-10)
        final songCount = ShuffleTestGenerators.randomInt(1, 10);
        final songs = await ctx.createSongs(songCount, prefix: 'P11_$i');
        final songIds = songs.map((s) => s.id).toList();

        // Build random playlist items
        final items = PersistenceTestGenerators.randomSongUnitItems(songIds);

        // Generate random queue state
        final isLocked = PersistenceTestGenerators.randomBool();
        final currentIndex = PersistenceTestGenerators.randomCurrentIndex(
          songCount,
        );
        final playbackPositionMs =
            PersistenceTestGenerators.randomPlaybackPositionMs();
        final wasPlaying = PersistenceTestGenerators.randomBool();
        final removeAfterPlay = PersistenceTestGenerators.randomBool();
        final displayOrder = PersistenceTestGenerators.randomDisplayOrder();

        // Create a queue tag with the random state
        final now = DateTime.now();
        final queueTag = Tag(
          id: 'queue_$i',
          name: 'TestQueue_$i',
          type: TagType.user,
          playlistMetadata: PlaylistMetadata(
            isLocked: isLocked,
            displayOrder: displayOrder,
            items: items,
            currentIndex: currentIndex,
            playbackPositionMs: playbackPositionMs,
            wasPlaying: wasPlaying,
            removeAfterPlay: removeAfterPlay,
            createdAt: now,
            updatedAt: now,
          ),
        );

        // Save (persist) the queue via updateTag
        await ctx.tagRepo.updateTag(queueTag);

        // Load (retrieve) the queue via getTag
        final loaded = await ctx.tagRepo.getTag('queue_$i');

        // Verify the loaded state matches the saved state
        expect(
          loaded,
          isNotNull,
          reason: 'Iteration $i: queue should be retrievable after save',
        );

        final loadedMeta = loaded!.playlistMetadata;
        expect(
          loadedMeta,
          isNotNull,
          reason: 'Iteration $i: loaded queue should have metadata',
        );

        // Verify all queue state properties are preserved
        expect(
          loadedMeta!.isLocked,
          equals(isLocked),
          reason: 'Iteration $i: isLocked should be preserved',
        );
        expect(
          loadedMeta.currentIndex,
          equals(currentIndex),
          reason: 'Iteration $i: currentIndex should be preserved',
        );
        expect(
          loadedMeta.playbackPositionMs,
          equals(playbackPositionMs),
          reason: 'Iteration $i: playbackPositionMs should be preserved',
        );
        expect(
          loadedMeta.wasPlaying,
          equals(wasPlaying),
          reason: 'Iteration $i: wasPlaying should be preserved',
        );
        expect(
          loadedMeta.removeAfterPlay,
          equals(removeAfterPlay),
          reason: 'Iteration $i: removeAfterPlay should be preserved',
        );
        expect(
          loadedMeta.displayOrder,
          equals(displayOrder),
          reason: 'Iteration $i: displayOrder should be preserved',
        );

        // Verify item count
        expect(
          loadedMeta.items.length,
          equals(items.length),
          reason: 'Iteration $i: item count should be preserved',
        );

        // Verify item order and content
        for (var j = 0; j < items.length; j++) {
          expect(
            loadedMeta.items[j].id,
            equals(items[j].id),
            reason: 'Iteration $i: item $j id should be preserved',
          );
          expect(
            loadedMeta.items[j].type,
            equals(items[j].type),
            reason: 'Iteration $i: item $j type should be preserved',
          );
          expect(
            loadedMeta.items[j].targetId,
            equals(items[j].targetId),
            reason: 'Iteration $i: item $j targetId should be preserved',
          );
          expect(
            loadedMeta.items[j].order,
            equals(items[j].order),
            reason: 'Iteration $i: item $j order should be preserved',
          );
        }

        // Verify song unit order matches original
        final loadedSongIds = loadedMeta.items
            .map((item) => item.targetId)
            .toList();
        expect(
          loadedSongIds,
          equals(songIds),
          reason: 'Iteration $i: song unit order should be preserved',
        );

        // Verify the tag-level properties
        expect(
          loaded.name,
          equals('TestQueue_$i'),
          reason: 'Iteration $i: queue name should be preserved',
        );
        expect(
          loaded.type,
          equals(TagType.user),
          reason: 'Iteration $i: queue type should be preserved',
        );

        ctx.dispose();
      }
    });

    // ========================================================================
    // Feature: queue-playlist-system, Property 23: Lock State Persistence
    // **Validates: Requirements 7.7**
    //
    // For any collection with a lock state, saving and loading should
    // preserve the lock state.
    // ========================================================================
    test(
      'Property 23: Lock State Persistence - '
      'lock state is preserved across save and load for any collection',
      () async {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          final ctx = ShuffleTestContext();

          // Create a random number of collections (2-5) with random lock states
          final collectionCount = ShuffleTestGenerators.randomInt(2, 5);
          final expectedLockStates = <String, bool>{};

          for (var c = 0; c < collectionCount; c++) {
            final isLocked = PersistenceTestGenerators.randomBool();
            final isGroup = PersistenceTestGenerators.randomBool();

            // Create collection
            final collection = await ctx.tagRepo.createCollection(
              'Collection_${i}_$c',
              parentId: isGroup ? 'default' : null,
              isGroup: isGroup,
            );

            // Add some random songs to make it realistic
            final songCount = ShuffleTestGenerators.randomInt(0, 5);
            final songs = await ctx.createSongs(
              songCount,
              prefix: 'L23_${i}_$c',
            );
            for (var s = 0; s < songs.length; s++) {
              await ctx.tagRepo.addItemToCollection(
                collection.id,
                PlaylistItem(
                  id: const Uuid().v4(),
                  type: PlaylistItemType.songUnit,
                  targetId: songs[s].id,
                  order: s,
                ),
              );
            }

            // Set the lock state
            await ctx.tagRepo.setCollectionLock(collection.id, isLocked);
            expectedLockStates[collection.id] = isLocked;
          }

          // Now load each collection and verify lock state
          for (final entry in expectedLockStates.entries) {
            final loaded = await ctx.tagRepo.getTag(entry.key);
            expect(
              loaded,
              isNotNull,
              reason: 'Iteration $i: collection ${entry.key} should exist',
            );
            expect(
              loaded!.isLocked,
              equals(entry.value),
              reason:
                  'Iteration $i: lock state of ${entry.key} should be '
                  '${entry.value} but was ${loaded.isLocked}',
            );
          }

          // Also verify that toggling lock and re-loading preserves the new state
          for (final entry in expectedLockStates.entries) {
            final newLockState = !entry.value;
            await ctx.tagRepo.setCollectionLock(entry.key, newLockState);

            final reloaded = await ctx.tagRepo.getTag(entry.key);
            expect(
              reloaded,
              isNotNull,
              reason:
                  'Iteration $i: collection ${entry.key} should exist after toggle',
            );
            expect(
              reloaded!.isLocked,
              equals(newLockState),
              reason:
                  'Iteration $i: toggled lock state of ${entry.key} should be '
                  '$newLockState but was ${reloaded.isLocked}',
            );
          }

          ctx.dispose();
        }
      },
    );
  });
}
