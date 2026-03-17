import 'dart:math';

import 'package:beadline/models/playlist_metadata.dart';
import 'package:beadline/repositories/tag_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

/// Test generators for collection property tests
class CollectionTestGenerators {
  static final Random _random = Random();
  static const Uuid _uuid = Uuid();

  /// Generate a unique collection name
  static String collectionName() {
    const chars = 'abcdefghijklmnopqrstuvwxyz';
    final length = 3 + _random.nextInt(10);
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => chars.codeUnitAt(_random.nextInt(chars.length)),
      ),
    );
  }

  /// Generate a unique song unit ID
  static String songUnitId() => _uuid.v4();

  /// Generate a PlaylistItem for a song unit
  static PlaylistItem songUnitItem(String targetId, {int order = 0}) {
    return PlaylistItem(
      id: _uuid.v4(),
      type: PlaylistItemType.songUnit,
      targetId: targetId,
      order: order,
    );
  }

  /// Generate a random count in range
  static int randomInt(int min, int max) {
    return min + _random.nextInt(max - min + 1);
  }

  /// Generate a list of unique song unit IDs
  static List<String> uniqueSongUnitIds(int count) {
    return List.generate(count, (_) => songUnitId());
  }
}

void main() {
  group('Collection Operations Property Tests (Task 2.2)', () {
    late TagRepository repository;

    setUp(() {
      repository = TagRepository();
    });

    tearDown(() {
      repository.dispose();
    });

    // ========================================================================
    // Feature: queue-playlist-system, Property 5: Playlist Order Preservation
    // **Validates: Requirements 3.5**
    // For any playlist and sequence of song units, adding them in order
    // should result in the playlist containing them in that same order.
    // ========================================================================
    test(
      'Property 5: Playlist Order Preservation - adding song units in order preserves that order',
      () async {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          // Create a playlist
          final playlist = await repository.createCollection(
            'playlist_${CollectionTestGenerators.collectionName()}_$i',
          );

          // Generate a random number of song unit IDs (2-10)
          final count = CollectionTestGenerators.randomInt(2, 10);
          final songUnitIds = CollectionTestGenerators.uniqueSongUnitIds(count);

          // Add them in order
          for (var j = 0; j < songUnitIds.length; j++) {
            final item = CollectionTestGenerators.songUnitItem(
              songUnitIds[j],
              order: j,
            );
            await repository.addItemToCollection(playlist.id, item);
          }

          // Retrieve items and verify order
          final items = await repository.getCollectionItems(playlist.id);
          expect(
            items.length,
            equals(count),
            reason: 'Iteration $i: playlist should contain $count items',
          );

          for (var j = 0; j < count; j++) {
            expect(
              items[j].targetId,
              equals(songUnitIds[j]),
              reason:
                  'Iteration $i: item at index $j should be ${songUnitIds[j]}',
            );
          }
        }
      },
    );

    // ========================================================================
    // Feature: queue-playlist-system, Property 6: Playlist Reordering
    // **Validates: Requirements 3.6**
    // For any playlist with song units, reordering two song units should
    // swap their positions while preserving all other positions.
    // ========================================================================
    test(
      'Property 6: Playlist Reordering - reordering swaps positions and preserves others',
      () async {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          // Create a playlist with 3-8 items
          final playlist = await repository.createCollection(
            'playlist_${CollectionTestGenerators.collectionName()}_$i',
          );

          final count = CollectionTestGenerators.randomInt(3, 8);
          final songUnitIds = CollectionTestGenerators.uniqueSongUnitIds(count);

          for (var j = 0; j < count; j++) {
            final item = CollectionTestGenerators.songUnitItem(
              songUnitIds[j],
              order: j,
            );
            await repository.addItemToCollection(playlist.id, item);
          }

          // Pick two random distinct indices to swap
          final oldIndex = CollectionTestGenerators.randomInt(0, count - 1);
          var newIndex = CollectionTestGenerators.randomInt(0, count - 1);
          while (newIndex == oldIndex) {
            newIndex = CollectionTestGenerators.randomInt(0, count - 1);
          }

          // Get items before reorder to track IDs
          final itemsBefore = await repository.getCollectionItems(playlist.id);
          final targetIdsBefore = itemsBefore
              .map((item) => item.targetId)
              .toList();

          // Perform reorder (move item from oldIndex to newIndex)
          await repository.reorderCollection(playlist.id, oldIndex, newIndex);

          // Get items after reorder
          final itemsAfter = await repository.getCollectionItems(playlist.id);
          final targetIdsAfter = itemsAfter
              .map((item) => item.targetId)
              .toList();

          // Verify same number of items
          expect(
            targetIdsAfter.length,
            equals(count),
            reason: 'Iteration $i: item count should be preserved',
          );

          // Verify all original items are still present
          expect(
            targetIdsAfter.toSet(),
            equals(targetIdsBefore.toSet()),
            reason: 'Iteration $i: all items should still be present',
          );

          // Simulate the expected reorder: remove from oldIndex, insert at newIndex
          final expected = List<String>.from(targetIdsBefore);
          final moved = expected.removeAt(oldIndex);
          expected.insert(newIndex, moved);

          expect(
            targetIdsAfter,
            equals(expected),
            reason:
                'Iteration $i: reorder from $oldIndex to $newIndex should match expected',
          );
        }
      },
    );

    // ========================================================================
    // Feature: queue-playlist-system, Property 7: Queue Order Preservation
    // **Validates: Requirements 4.3**
    // For any queue and sequence of song units, the order of song units
    // in the queue should be maintained until explicitly changed.
    // ========================================================================
    test(
      'Property 7: Queue Order Preservation - queue maintains insertion order until changed',
      () async {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          // Create a queue (collection with currentIndex >= 0 makes it active)
          final queue = await repository.createCollection(
            'queue_${CollectionTestGenerators.collectionName()}_$i',
          );
          // Make it an active queue
          await repository.startPlaying(queue.id);

          // Add a random number of song units (2-10)
          final count = CollectionTestGenerators.randomInt(2, 10);
          final songUnitIds = CollectionTestGenerators.uniqueSongUnitIds(count);

          for (var j = 0; j < songUnitIds.length; j++) {
            final item = CollectionTestGenerators.songUnitItem(
              songUnitIds[j],
              order: j,
            );
            await repository.addItemToCollection(queue.id, item);
          }

          // Read back multiple times - order should be stable
          for (var read = 0; read < 3; read++) {
            final items = await repository.getCollectionItems(queue.id);
            expect(
              items.length,
              equals(count),
              reason:
                  'Iteration $i, read $read: queue should have $count items',
            );

            for (var j = 0; j < count; j++) {
              expect(
                items[j].targetId,
                equals(songUnitIds[j]),
                reason:
                    'Iteration $i, read $read: item at index $j should be stable',
              );
            }
          }
        }
      },
    );

    // ========================================================================
    // Feature: queue-playlist-system, Property 8: Queue Addition
    // **Validates: Requirements 4.4, 5.1**
    // For any song unit, adding it to the queue should result in the
    // song unit being present in the queue.
    // ========================================================================
    test(
      'Property 8: Queue Addition - adding a song unit makes it present in the queue',
      () async {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          // Create a queue
          final queue = await repository.createCollection(
            'queue_${CollectionTestGenerators.collectionName()}_$i',
          );
          await repository.startPlaying(queue.id);

          // Pre-populate with 0-5 existing items
          final existingCount = CollectionTestGenerators.randomInt(0, 5);
          for (var j = 0; j < existingCount; j++) {
            final item = CollectionTestGenerators.songUnitItem(
              CollectionTestGenerators.songUnitId(),
              order: j,
            );
            await repository.addItemToCollection(queue.id, item);
          }

          // Add a new song unit
          final newSongUnitId = CollectionTestGenerators.songUnitId();
          final newItem = CollectionTestGenerators.songUnitItem(
            newSongUnitId,
            order: existingCount,
          );
          await repository.addItemToCollection(queue.id, newItem);

          // Verify the new song unit is present
          final items = await repository.getCollectionItems(queue.id);
          final targetIds = items.map((item) => item.targetId).toList();

          expect(
            targetIds,
            contains(newSongUnitId),
            reason:
                'Iteration $i: newly added song unit should be in the queue',
          );
          expect(
            items.length,
            equals(existingCount + 1),
            reason: 'Iteration $i: queue should have one more item',
          );
        }
      },
    );

    // ========================================================================
    // Feature: queue-playlist-system, Property 9: Queue Reordering
    // **Validates: Requirements 4.5**
    // For any queue with song units, reordering should change positions
    // as specified while preserving all other song units.
    // ========================================================================
    test(
      'Property 9: Queue Reordering - reordering changes positions as specified, preserves all items',
      () async {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          // Create a queue with 3-8 items
          final queue = await repository.createCollection(
            'queue_${CollectionTestGenerators.collectionName()}_$i',
          );
          await repository.startPlaying(queue.id);

          final count = CollectionTestGenerators.randomInt(3, 8);
          final songUnitIds = CollectionTestGenerators.uniqueSongUnitIds(count);

          for (var j = 0; j < count; j++) {
            final item = CollectionTestGenerators.songUnitItem(
              songUnitIds[j],
              order: j,
            );
            await repository.addItemToCollection(queue.id, item);
          }

          // Pick random old and new indices
          final oldIndex = CollectionTestGenerators.randomInt(0, count - 1);
          var newIndex = CollectionTestGenerators.randomInt(0, count - 1);
          while (newIndex == oldIndex) {
            newIndex = CollectionTestGenerators.randomInt(0, count - 1);
          }

          final itemsBefore = await repository.getCollectionItems(queue.id);
          final targetIdsBefore = itemsBefore
              .map((item) => item.targetId)
              .toList();

          // Reorder
          await repository.reorderCollection(queue.id, oldIndex, newIndex);

          final itemsAfter = await repository.getCollectionItems(queue.id);
          final targetIdsAfter = itemsAfter
              .map((item) => item.targetId)
              .toList();

          // All items preserved
          expect(
            targetIdsAfter.length,
            equals(count),
            reason: 'Iteration $i: item count should be preserved',
          );
          expect(
            targetIdsAfter.toSet(),
            equals(targetIdsBefore.toSet()),
            reason: 'Iteration $i: all items should still be present',
          );

          // Verify expected positions
          final expected = List<String>.from(targetIdsBefore);
          final moved = expected.removeAt(oldIndex);
          expected.insert(newIndex, moved);

          expect(
            targetIdsAfter,
            equals(expected),
            reason:
                'Iteration $i: reorder from $oldIndex to $newIndex should match expected',
          );
        }
      },
    );

    // ========================================================================
    // Feature: queue-playlist-system, Property 10: Queue Removal
    // **Validates: Requirements 4.6**
    // For any song unit in the queue, removing it should result in the
    // song unit no longer being in the queue.
    // ========================================================================
    test(
      'Property 10: Queue Removal - removing a song unit makes it absent from the queue',
      () async {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          // Create a queue with 2-8 items
          final queue = await repository.createCollection(
            'queue_${CollectionTestGenerators.collectionName()}_$i',
          );
          await repository.startPlaying(queue.id);

          final count = CollectionTestGenerators.randomInt(2, 8);
          final songUnitIds = CollectionTestGenerators.uniqueSongUnitIds(count);
          final itemIds = <String>[];

          for (var j = 0; j < count; j++) {
            final item = CollectionTestGenerators.songUnitItem(
              songUnitIds[j],
              order: j,
            );
            await repository.addItemToCollection(queue.id, item);
            itemIds.add(item.id);
          }

          // Pick a random item to remove
          final removeIndex = CollectionTestGenerators.randomInt(0, count - 1);
          final removedItemId = itemIds[removeIndex];
          final removedSongUnitId = songUnitIds[removeIndex];

          // Remove it
          await repository.removeItemFromCollection(queue.id, removedItemId);

          // Verify the removed song unit is no longer present
          final itemsAfter = await repository.getCollectionItems(queue.id);
          final targetIdsAfter = itemsAfter
              .map((item) => item.targetId)
              .toList();

          expect(
            targetIdsAfter,
            isNot(contains(removedSongUnitId)),
            reason:
                'Iteration $i: removed song unit should not be in the queue',
          );

          // Verify remaining items are preserved (count - 1 unless collection
          // became empty and metadata was cleared)
          if (count > 1) {
            expect(
              itemsAfter.length,
              equals(count - 1),
              reason: 'Iteration $i: queue should have one fewer item',
            );

            // Verify remaining items are the correct ones
            for (var j = 0; j < count; j++) {
              if (j != removeIndex) {
                expect(
                  targetIdsAfter,
                  contains(songUnitIds[j]),
                  reason:
                      'Iteration $i: non-removed item ${songUnitIds[j]} should still be present',
                );
              }
            }
          }
        }
      },
    );
  });
}
