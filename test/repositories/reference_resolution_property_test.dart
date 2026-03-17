import 'dart:math';

import 'package:beadline/models/playlist_metadata.dart';
import 'package:beadline/repositories/tag_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

// =============================================================================
// Mock helpers for reference resolution property tests
// =============================================================================

/// Lightweight mock song unit for resolveContent tests
class MockSongUnit {
  MockSongUnit(this.id, this.name);
  final String id;
  final String name;
}

/// Mock library repository that resolveContent uses to fetch song units
class MockLibraryRepository {
  final Map<String, MockSongUnit> _songUnits = {};

  void addSongUnit(MockSongUnit su) {
    _songUnits[su.id] = su;
  }

  Future<MockSongUnit?> getSongUnit(String id) async {
    return _songUnits[id];
  }

  void clear() {
    _songUnits.clear();
  }
}

/// Test generators for reference resolution property tests
class RefTestGenerators {
  static final Random _random = Random();
  static const Uuid _uuid = Uuid();

  static String collectionName() {
    const chars = 'abcdefghijklmnopqrstuvwxyz';
    final length = 3 + _random.nextInt(8);
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => chars.codeUnitAt(_random.nextInt(chars.length)),
      ),
    );
  }

  static String id() => _uuid.v4();

  static int randomInt(int min, int max) {
    return min + _random.nextInt(max - min + 1);
  }

  static List<String> uniqueSongUnitIds(int count) {
    return List.generate(count, (_) => id());
  }

  static PlaylistItem songUnitItem(String targetId, {int order = 0}) {
    return PlaylistItem(
      id: _uuid.v4(),
      type: PlaylistItemType.songUnit,
      targetId: targetId,
      order: order,
    );
  }

  static PlaylistItem collectionRefItem(String targetId, {int order = 0}) {
    return PlaylistItem(
      id: _uuid.v4(),
      type: PlaylistItemType.collectionReference,
      targetId: targetId,
      order: order,
    );
  }
}

/// Helper context that creates collections with UUID-based IDs to avoid
/// timestamp-based ID collisions from TagRepository._generateId().
class TestContext {
  TestContext()
    : libraryRepo = MockLibraryRepository() {
    repository = TagRepository();
  }

  late final TagRepository repository;
  final MockLibraryRepository libraryRepo;

  /// Create a collection using the TagRepository API.
  Future<String> createCollection(String name, {bool isGroup = false}) async {
    final collection = await repository.createCollection(name, isGroup: isGroup);
    return collection.id;
  }

  void dispose() {
    repository.dispose();
  }
}

void main() {
  group('Reference Resolution Property Tests (Task 2.4)', () {
    // ========================================================================
    // Feature: queue-playlist-system, Property 28: Reference Semantics
    // **Validates: Requirements 11.2, 11.3, 11.4**
    //
    // For any collection with a reference to another collection, modifying
    // the target collection should be visible when resolving the reference.
    // Since references store a pointer (not a copy), resolveContent should
    // always reflect the target's current state.
    // ========================================================================
    test(
      'Property 28: Reference Semantics - modifying target collection is visible through reference',
      () async {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          final ctx = TestContext();

          // Create target collection with some initial song units
          final targetId = await ctx.createCollection(
            'target_${RefTestGenerators.collectionName()}',
          );

          final initialCount = RefTestGenerators.randomInt(1, 5);
          final initialSongIds = RefTestGenerators.uniqueSongUnitIds(
            initialCount,
          );

          for (var j = 0; j < initialCount; j++) {
            ctx.libraryRepo.addSongUnit(
              MockSongUnit(initialSongIds[j], 'song_$j'),
            );
            await ctx.repository.addItemToCollection(
              targetId,
              RefTestGenerators.songUnitItem(initialSongIds[j], order: j),
            );
          }

          // Create referencing collection that references the target
          final refId = await ctx.createCollection(
            'ref_${RefTestGenerators.collectionName()}',
          );
          await ctx.repository.addItemToCollection(
            refId,
            RefTestGenerators.collectionRefItem(targetId),
          );

          // Resolve before modification - should see initial songs
          final beforeMod = await ctx.repository.resolveContent(
            refId,
            libraryRepository: ctx.libraryRepo,
          );
          expect(
            beforeMod.length,
            equals(initialCount),
            reason:
                'Iteration $i: reference should resolve to $initialCount initial songs',
          );

          // Modify target: add new song units
          final addCount = RefTestGenerators.randomInt(1, 3);
          final newSongIds = RefTestGenerators.uniqueSongUnitIds(addCount);

          for (var j = 0; j < addCount; j++) {
            ctx.libraryRepo.addSongUnit(
              MockSongUnit(newSongIds[j], 'new_song_$j'),
            );
            await ctx.repository.addItemToCollection(
              targetId,
              RefTestGenerators.songUnitItem(
                newSongIds[j],
                order: initialCount + j,
              ),
            );
          }

          // Resolve after modification - should see all songs (initial + new)
          final afterMod = await ctx.repository.resolveContent(
            refId,
            libraryRepository: ctx.libraryRepo,
          );
          expect(
            afterMod.length,
            equals(initialCount + addCount),
            reason:
                'Iteration $i: reference should reflect target modification '
                '($initialCount + $addCount = ${initialCount + addCount})',
          );

          // Verify the new song IDs are present in the resolved content
          final resolvedIds = afterMod
              .map((su) => (su as MockSongUnit).id)
              .toSet();
          for (final newId in newSongIds) {
            expect(
              resolvedIds,
              contains(newId),
              reason:
                  'Iteration $i: newly added song $newId should be visible through reference',
            );
          }

          ctx.dispose();
        }
      },
    );

    // ========================================================================
    // Feature: queue-playlist-system, Property 29: Circular Reference Prevention
    // **Validates: Requirements 11.5**
    //
    // For any two collections A and B, if A references B (directly or
    // indirectly), then attempting to add a reference from B to A should
    // be rejected (wouldCreateCircularReference returns true).
    // ========================================================================
    test(
      'Property 29: Circular Reference Prevention - direct and indirect circular references are detected',
      () async {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          final ctx = TestContext();

          // Decide chain length: 2 = direct (A->B, B->A), 3+ = indirect
          final chainLength = RefTestGenerators.randomInt(2, 5);
          final collections = <String>[];

          // Create a chain of collections
          for (var j = 0; j < chainLength; j++) {
            final collId = await ctx.createCollection(
              'chain_${RefTestGenerators.collectionName()}_$j',
            );
            collections.add(collId);
          }

          // Build the forward chain: A -> B -> C -> ... -> N
          for (var j = 0; j < chainLength - 1; j++) {
            await ctx.repository.addItemToCollection(
              collections[j],
              RefTestGenerators.collectionRefItem(collections[j + 1]),
            );
          }

          // The last collection referencing back to the first should be circular
          final wouldBeCircular = await ctx.repository
              .wouldCreateCircularReference(
                collections[chainLength - 1],
                collections[0],
              );
          expect(
            wouldBeCircular,
            isTrue,
            reason:
                'Iteration $i: chain of length $chainLength - '
                'adding reference from last to first should be circular',
          );

          // Self-reference should always be circular
          final selfRef = await ctx.repository.wouldCreateCircularReference(
            collections[0],
            collections[0],
          );
          expect(
            selfRef,
            isTrue,
            reason: 'Iteration $i: self-reference should always be circular',
          );

          // Reference from a middle node back to first should be circular
          if (chainLength >= 3) {
            final midIndex = RefTestGenerators.randomInt(1, chainLength - 1);
            final midToFirst = await ctx.repository
                .wouldCreateCircularReference(
                  collections[midIndex],
                  collections[0],
                );
            expect(
              midToFirst,
              isTrue,
              reason:
                  'Iteration $i: reference from middle node $midIndex back to first should be circular',
            );
          }

          // Adding a reference from first to a NEW collection should NOT be circular
          final newCollId = await ctx.createCollection(
            'new_${RefTestGenerators.collectionName()}',
          );
          final notCircular = await ctx.repository.wouldCreateCircularReference(
            collections[0],
            newCollId,
          );
          expect(
            notCircular,
            isFalse,
            reason:
                'Iteration $i: reference to unrelated collection should not be circular',
          );

          ctx.dispose();
        }
      },
    );

    // ========================================================================
    // Feature: queue-playlist-system, Property 30: Recursive Resolution
    // **Validates: Requirements 15.1, 15.2**
    //
    // For any collection containing nested groups and references,
    // resolving should recursively expand all nested structures up to
    // the depth limit. The total resolved song units should equal the
    // sum of all song units across all nested levels (within depth limit).
    // ========================================================================
    test(
      'Property 30: Recursive Resolution - nested groups and references are recursively expanded',
      () async {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          final ctx = TestContext();

          // Create a root collection
          final rootId = await ctx.createCollection(
            'root_${RefTestGenerators.collectionName()}',
          );

          // Decide nesting depth (1-4 levels, well within limit of 10)
          final depth = RefTestGenerators.randomInt(1, 4);
          var totalSongCount = 0;

          // Add some direct song units to root
          final rootSongCount = RefTestGenerators.randomInt(0, 3);
          for (var j = 0; j < rootSongCount; j++) {
            final sid = RefTestGenerators.id();
            ctx.libraryRepo.addSongUnit(MockSongUnit(sid, 'root_song_$j'));
            await ctx.repository.addItemToCollection(
              rootId,
              RefTestGenerators.songUnitItem(sid, order: j),
            );
            totalSongCount++;
          }

          // Build nested chain: root -> level1 -> level2 -> ...
          var currentParentId = rootId;
          var currentOrder = rootSongCount;

          for (var level = 0; level < depth; level++) {
            // Create a nested collection (alternating group/non-group)
            final nestedId = await ctx.createCollection(
              'nested_${RefTestGenerators.collectionName()}_$level',
              isGroup: level.isEven,
            );

            // Add reference from parent to this nested collection
            await ctx.repository.addItemToCollection(
              currentParentId,
              RefTestGenerators.collectionRefItem(
                nestedId,
                order: currentOrder,
              ),
            );

            // Add some song units to this nested collection
            final nestedSongCount = RefTestGenerators.randomInt(1, 3);
            for (var j = 0; j < nestedSongCount; j++) {
              final sid = RefTestGenerators.id();
              ctx.libraryRepo.addSongUnit(
                MockSongUnit(sid, 'level${level}_song_$j'),
              );
              await ctx.repository.addItemToCollection(
                nestedId,
                RefTestGenerators.songUnitItem(sid, order: j),
              );
              totalSongCount++;
            }

            currentParentId = nestedId;
            currentOrder = 0;
          }

          // Resolve from root - should get ALL song units across all levels
          final resolved = await ctx.repository.resolveContent(
            rootId,
            libraryRepository: ctx.libraryRepo,
          );

          expect(
            resolved.length,
            equals(totalSongCount),
            reason:
                'Iteration $i: recursive resolution with depth $depth should '
                'return all $totalSongCount song units',
          );

          ctx.dispose();
        }
      },
    );

    // ========================================================================
    // Property 30 (continued): Depth limit enforcement
    // Verify that resolution stops at the depth limit and doesn't resolve
    // structures beyond maxDepth.
    //
    // resolveContent semantics: with maxDepth=N, the method can process
    // N levels (level 0 uses maxDepth=N, level 1 uses N-1, ..., level N-1
    // uses 1). At level N, maxDepth would be 0 and returns empty.
    // So a song at level K (0-indexed) is reachable iff maxDepth > K,
    // i.e. maxDepth >= K+1.
    // In a chain of totalLevels collections where the song is at the last
    // level (index totalLevels-1), it's reachable iff maxDepth >= totalLevels.
    // ========================================================================
    test(
      'Property 30: Recursive Resolution - respects depth limit for deeply nested structures',
      () async {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          final ctx = TestContext();

          // Create a chain deeper than the chosen maxDepth
          final maxDepth = RefTestGenerators.randomInt(2, 5);
          final totalLevels = maxDepth + RefTestGenerators.randomInt(1, 3);

          final collectionIds = <String>[];

          for (var level = 0; level < totalLevels; level++) {
            final collId = await ctx.createCollection(
              'deep_${RefTestGenerators.collectionName()}_$level',
            );
            collectionIds.add(collId);

            // Chain: each collection references the next
            if (level > 0) {
              await ctx.repository.addItemToCollection(
                collectionIds[level - 1],
                RefTestGenerators.collectionRefItem(collId),
              );
            }
          }

          // Add a song unit ONLY at the deepest level
          final deepSongId = RefTestGenerators.id();
          ctx.libraryRepo.addSongUnit(MockSongUnit(deepSongId, 'deep_song'));
          await ctx.repository.addItemToCollection(
            collectionIds.last,
            RefTestGenerators.songUnitItem(deepSongId),
          );

          // Resolve from root with limited depth
          final resolved = await ctx.repository.resolveContent(
            collectionIds[0],
            maxDepth: maxDepth,
            libraryRepository: ctx.libraryRepo,
          );

          // Song is at level (totalLevels - 1). Reachable iff maxDepth >= totalLevels.
          // Since totalLevels > maxDepth by construction, the song should NOT be reachable.
          expect(
            resolved.length,
            equals(0),
            reason:
                'Iteration $i: song at level ${totalLevels - 1} should NOT be '
                'reachable with maxDepth=$maxDepth (totalLevels=$totalLevels)',
          );

          ctx.dispose();
        }
      },
    );
  });
}
