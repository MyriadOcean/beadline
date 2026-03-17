import 'package:beadline/models/playlist_metadata.dart';
import 'package:beadline/repositories/tag_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

// =============================================================================
// Reuse the mock helpers from reference_resolution_property_test.dart
// =============================================================================

class MockSongUnit {
  MockSongUnit(this.id, this.name);
  final String id;
  final String name;
}

class MockLibraryRepository {
  final Map<String, MockSongUnit> _songUnits = {};

  void addSongUnit(MockSongUnit su) {
    _songUnits[su.id] = su;
  }

  Future<MockSongUnit?> getSongUnit(String id) async => _songUnits[id];

  void clear() => _songUnits.clear();
}

/// Helper to create collections with UUID-based IDs (avoids timestamp collisions).
class TestContext {
  TestContext()
    : libraryRepo = MockLibraryRepository() {
    repository = TagRepository();
  }

  static const Uuid _uuid = Uuid();

  late final TagRepository repository;
  final MockLibraryRepository libraryRepo;

  Future<String> createCollection(String name, {bool isGroup = false}) async {
    final collection = await repository.createCollection(name, isGroup: isGroup);
    return collection.id;
  }

  PlaylistItem songUnitItem(String targetId, {int order = 0}) {
    return PlaylistItem(
      id: _uuid.v4(),
      type: PlaylistItemType.songUnit,
      targetId: targetId,
      order: order,
    );
  }

  PlaylistItem collectionRefItem(String targetId, {int order = 0}) {
    return PlaylistItem(
      id: _uuid.v4(),
      type: PlaylistItemType.collectionReference,
      targetId: targetId,
      order: order,
    );
  }

  MockSongUnit addMockSongUnit(String name) {
    final su = MockSongUnit(_uuid.v4(), name);
    libraryRepo.addSongUnit(su);
    return su;
  }

  void dispose() {
    repository.dispose();
  }
}

void main() {
  // ===========================================================================
  // Task 2.5: Unit tests for edge cases
  // Validates: Requirements 11.5, 15.3, 15.4, 15.5
  // ===========================================================================

  group('Circular Reference Detection (Req 11.5, 15.3)', () {
    late TestContext ctx;

    setUp(() {
      ctx = TestContext();
    });

    tearDown(() {
      ctx.dispose();
    });

    test('self-reference is detected as circular', () async {
      final collA = await ctx.createCollection('A');

      final result = await ctx.repository.wouldCreateCircularReference(
        collA,
        collA,
      );
      expect(result, isTrue);
    });

    test('direct A->B, B->A is detected as circular', () async {
      final collA = await ctx.createCollection('A');
      final collB = await ctx.createCollection('B');

      // A already references B
      await ctx.repository.addItemToCollection(
        collA,
        ctx.collectionRefItem(collB),
      );

      // Would B->A be circular? Yes.
      final result = await ctx.repository.wouldCreateCircularReference(
        collB,
        collA,
      );
      expect(result, isTrue);
    });

    test('indirect A->B->C, C->A is detected as circular', () async {
      final collA = await ctx.createCollection('A');
      final collB = await ctx.createCollection('B');
      final collC = await ctx.createCollection('C');

      // Build chain: A -> B -> C
      await ctx.repository.addItemToCollection(
        collA,
        ctx.collectionRefItem(collB),
      );
      await ctx.repository.addItemToCollection(
        collB,
        ctx.collectionRefItem(collC),
      );

      // Would C->A be circular? Yes.
      final result = await ctx.repository.wouldCreateCircularReference(
        collC,
        collA,
      );
      expect(result, isTrue);
    });

    test('long chain A->B->C->D->E, E->A is detected as circular', () async {
      final ids = <String>[];
      for (var i = 0; i < 5; i++) {
        ids.add(await ctx.createCollection('chain_$i'));
      }

      // Build chain: A -> B -> C -> D -> E
      for (var i = 0; i < 4; i++) {
        await ctx.repository.addItemToCollection(
          ids[i],
          ctx.collectionRefItem(ids[i + 1]),
        );
      }

      // Would E->A be circular? Yes.
      final result = await ctx.repository.wouldCreateCircularReference(
        ids[4],
        ids[0],
      );
      expect(result, isTrue);
    });

    test('non-circular reference is allowed', () async {
      final collA = await ctx.createCollection('A');
      final collB = await ctx.createCollection('B');
      final collC = await ctx.createCollection('C');

      // A -> B (no chain involving C)
      await ctx.repository.addItemToCollection(
        collA,
        ctx.collectionRefItem(collB),
      );

      // Would A->C be circular? No.
      final result = await ctx.repository.wouldCreateCircularReference(
        collA,
        collC,
      );
      expect(result, isFalse);
    });

    test('diamond shape is not circular', () async {
      // A -> B, A -> C, B -> D, C -> D
      // Adding D -> E should NOT be circular
      final collA = await ctx.createCollection('A');
      final collB = await ctx.createCollection('B');
      final collC = await ctx.createCollection('C');
      final collD = await ctx.createCollection('D');
      final collE = await ctx.createCollection('E');

      await ctx.repository.addItemToCollection(
        collA,
        ctx.collectionRefItem(collB),
      );
      await ctx.repository.addItemToCollection(
        collA,
        ctx.collectionRefItem(collC),
      );
      await ctx.repository.addItemToCollection(
        collB,
        ctx.collectionRefItem(collD),
      );
      await ctx.repository.addItemToCollection(
        collC,
        ctx.collectionRefItem(collD),
      );

      // D -> E is fine (no cycle)
      final result = await ctx.repository.wouldCreateCircularReference(
        collD,
        collE,
      );
      expect(result, isFalse);

      // But E -> A would be circular if D referenced E and we check E -> A
      // Actually D doesn't reference E yet, so E -> A is not circular
      final result2 = await ctx.repository.wouldCreateCircularReference(
        collE,
        collA,
      );
      expect(result2, isFalse);
    });

    test(
      'circular detection with mixed item types (song units + refs)',
      () async {
        final collA = await ctx.createCollection('A');
        final collB = await ctx.createCollection('B');

        // A has a song unit AND a reference to B
        final su = ctx.addMockSongUnit('song1');
        await ctx.repository.addItemToCollection(
          collA,
          ctx.songUnitItem(su.id),
        );
        await ctx.repository.addItemToCollection(
          collA,
          ctx.collectionRefItem(collB, order: 1),
        );

        // Would B->A be circular? Yes, because A references B.
        final result = await ctx.repository.wouldCreateCircularReference(
          collB,
          collA,
        );
        expect(result, isTrue);
      },
    );

    test('reference to non-collection tag is not circular', () async {
      final collA = await ctx.createCollection('A');

      // Create a plain tag (not a collection)
      final plainTag = await ctx.repository.createTag('plain_tag');

      // Would collA -> plainTag be circular? No.
      final result = await ctx.repository.wouldCreateCircularReference(
        collA,
        plainTag.id,
      );
      expect(result, isFalse);
    });
  });

  group('Depth Limit Enforcement (Req 15.4, 15.5)', () {
    late TestContext ctx;

    setUp(() {
      ctx = TestContext();
    });

    tearDown(() {
      ctx.dispose();
    });

    test(
      'resolveContent stops at maxDepth and returns empty for deep items',
      () async {
        // Create chain: C0 -> C1 -> C2, song at C2
        // With maxDepth=2, C0 (depth 2) -> C1 (depth 1) -> C2 (depth 0) => stops
        final c0 = await ctx.createCollection('level0');
        final c1 = await ctx.createCollection('level1');
        final c2 = await ctx.createCollection('level2');

        await ctx.repository.addItemToCollection(c0, ctx.collectionRefItem(c1));
        await ctx.repository.addItemToCollection(c1, ctx.collectionRefItem(c2));

        final su = ctx.addMockSongUnit('deep_song');
        await ctx.repository.addItemToCollection(c2, ctx.songUnitItem(su.id));

        // maxDepth=2: C0 uses depth 2, C1 uses depth 1, C2 would need depth 0 => stops
        final resolved = await ctx.repository.resolveContent(
          c0,
          maxDepth: 2,
          libraryRepository: ctx.libraryRepo,
        );
        expect(
          resolved,
          isEmpty,
          reason: 'Song at level 2 should not be reachable with maxDepth=2',
        );
      },
    );

    test('resolveContent returns items within depth limit', () async {
      // Chain: C0 -> C1, song at C1
      // With maxDepth=2: C0 (depth 2) -> C1 (depth 1) => song reachable
      final c0 = await ctx.createCollection('level0');
      final c1 = await ctx.createCollection('level1');

      await ctx.repository.addItemToCollection(c0, ctx.collectionRefItem(c1));

      final su = ctx.addMockSongUnit('reachable_song');
      await ctx.repository.addItemToCollection(c1, ctx.songUnitItem(su.id));

      final resolved = await ctx.repository.resolveContent(
        c0,
        maxDepth: 2,
        libraryRepository: ctx.libraryRepo,
      );
      expect(resolved.length, equals(1));
      expect((resolved[0] as MockSongUnit).id, equals(su.id));
    });

    test('maxDepth=1 only resolves direct items', () async {
      final c0 = await ctx.createCollection('root');
      final c1 = await ctx.createCollection('child');

      // Direct song in c0
      final directSu = ctx.addMockSongUnit('direct');
      await ctx.repository.addItemToCollection(
        c0,
        ctx.songUnitItem(directSu.id),
      );

      // Reference to c1 which has another song
      await ctx.repository.addItemToCollection(
        c0,
        ctx.collectionRefItem(c1, order: 1),
      );
      final nestedSu = ctx.addMockSongUnit('nested');
      await ctx.repository.addItemToCollection(
        c1,
        ctx.songUnitItem(nestedSu.id),
      );

      // maxDepth=1: c0 (depth 1) can read its own items, but c1 would need depth 0 => stops
      final resolved = await ctx.repository.resolveContent(
        c0,
        maxDepth: 1,
        libraryRepository: ctx.libraryRepo,
      );
      expect(resolved.length, equals(1));
      expect((resolved[0] as MockSongUnit).id, equals(directSu.id));
    });

    test('maxDepth=0 returns empty immediately', () async {
      final c0 = await ctx.createCollection('root');
      final su = ctx.addMockSongUnit('song');
      await ctx.repository.addItemToCollection(c0, ctx.songUnitItem(su.id));

      final resolved = await ctx.repository.resolveContent(
        c0,
        maxDepth: 0,
        libraryRepository: ctx.libraryRepo,
      );
      expect(resolved, isEmpty);
    });

    test('default maxDepth=10 resolves 9 levels deep', () async {
      // Build a chain of 10 collections (levels 0-9), song at level 9
      // With maxDepth=10: level 0 uses 10, level 1 uses 9, ..., level 9 uses 1 => reachable
      final ids = <String>[];
      for (var i = 0; i < 10; i++) {
        ids.add(await ctx.createCollection('level_$i'));
      }
      for (var i = 0; i < 9; i++) {
        await ctx.repository.addItemToCollection(
          ids[i],
          ctx.collectionRefItem(ids[i + 1]),
        );
      }

      final su = ctx.addMockSongUnit('deep_song');
      await ctx.repository.addItemToCollection(ids[9], ctx.songUnitItem(su.id));

      // Default maxDepth=10 should reach level 9
      final resolved = await ctx.repository.resolveContent(
        ids[0],
        libraryRepository: ctx.libraryRepo,
      );
      expect(resolved.length, equals(1));
      expect((resolved[0] as MockSongUnit).id, equals(su.id));
    });

    test('default maxDepth=10 does NOT resolve 10 levels deep', () async {
      // Build a chain of 11 collections (levels 0-10), song at level 10
      // With maxDepth=10: level 10 would need depth 0 => stops
      final ids = <String>[];
      for (var i = 0; i < 11; i++) {
        ids.add(await ctx.createCollection('level_$i'));
      }
      for (var i = 0; i < 10; i++) {
        await ctx.repository.addItemToCollection(
          ids[i],
          ctx.collectionRefItem(ids[i + 1]),
        );
      }

      final su = ctx.addMockSongUnit('unreachable_song');
      await ctx.repository.addItemToCollection(
        ids[10],
        ctx.songUnitItem(su.id),
      );

      final resolved = await ctx.repository.resolveContent(
        ids[0],
        libraryRepository: ctx.libraryRepo,
      );
      expect(
        resolved,
        isEmpty,
        reason: 'Song at level 10 should not be reachable with maxDepth=10',
      );
    });

    test(
      'circular reference in resolveContent returns partial results',
      () async {
        // A -> B -> A (circular), but A also has a direct song
        final collA = await ctx.createCollection('A');
        final collB = await ctx.createCollection('B');

        final su = ctx.addMockSongUnit('song_in_A');
        await ctx.repository.addItemToCollection(
          collA,
          ctx.songUnitItem(su.id),
        );
        await ctx.repository.addItemToCollection(
          collA,
          ctx.collectionRefItem(collB, order: 1),
        );
        await ctx.repository.addItemToCollection(
          collB,
          ctx.collectionRefItem(collA),
        );

        // Should resolve A's direct song, then try B which tries A again (visited) => stops
        final resolved = await ctx.repository.resolveContent(
          collA,
          libraryRepository: ctx.libraryRepo,
        );
        expect(resolved.length, equals(1));
        expect((resolved[0] as MockSongUnit).id, equals(su.id));
      },
    );
  });

  group('Empty Collections (Req 15.3)', () {
    late TestContext ctx;

    setUp(() {
      ctx = TestContext();
    });

    tearDown(() {
      ctx.dispose();
    });

    test('resolveContent on empty collection returns empty list', () async {
      final coll = await ctx.createCollection('empty');

      final resolved = await ctx.repository.resolveContent(
        coll,
        libraryRepository: ctx.libraryRepo,
      );
      expect(resolved, isEmpty);
    });

    test('getCollectionItems on empty collection returns empty list', () async {
      final coll = await ctx.createCollection('empty');

      final items = await ctx.repository.getCollectionItems(coll);
      expect(items, isEmpty);
    });

    test(
      'resolveContent with reference to empty collection returns empty',
      () async {
        final parent = await ctx.createCollection('parent');
        final empty = await ctx.createCollection('empty_child');

        await ctx.repository.addItemToCollection(
          parent,
          ctx.collectionRefItem(empty),
        );

        final resolved = await ctx.repository.resolveContent(
          parent,
          libraryRepository: ctx.libraryRepo,
        );
        expect(resolved, isEmpty);
      },
    );

    test('resolveContent on non-existent collection returns empty', () async {
      final resolved = await ctx.repository.resolveContent(
        'non_existent_id',
        libraryRepository: ctx.libraryRepo,
      );
      expect(resolved, isEmpty);
    });

    test('resolveContent on non-collection tag returns empty', () async {
      final tag = await ctx.repository.createTag('regular_tag');

      final resolved = await ctx.repository.resolveContent(
        tag.id,
        libraryRepository: ctx.libraryRepo,
      );
      expect(resolved, isEmpty);
    });

    test('wouldCreateCircularReference with empty collections', () async {
      final collA = await ctx.createCollection('A');
      final collB = await ctx.createCollection('B');

      // Both empty - no references exist, so no circular reference
      final result = await ctx.repository.wouldCreateCircularReference(
        collA,
        collB,
      );
      expect(result, isFalse);
    });
  });

  group('Single-Item Collections (Req 15.3)', () {
    late TestContext ctx;

    setUp(() {
      ctx = TestContext();
    });

    tearDown(() {
      ctx.dispose();
    });

    test('resolveContent on collection with one song unit', () async {
      final coll = await ctx.createCollection('single');
      final su = ctx.addMockSongUnit('only_song');

      await ctx.repository.addItemToCollection(coll, ctx.songUnitItem(su.id));

      final resolved = await ctx.repository.resolveContent(
        coll,
        libraryRepository: ctx.libraryRepo,
      );
      expect(resolved.length, equals(1));
      expect((resolved[0] as MockSongUnit).id, equals(su.id));
    });

    test(
      'resolveContent on collection with one reference to single-item collection',
      () async {
        final parent = await ctx.createCollection('parent');
        final child = await ctx.createCollection('child');
        final su = ctx.addMockSongUnit('nested_song');

        await ctx.repository.addItemToCollection(
          child,
          ctx.songUnitItem(su.id),
        );
        await ctx.repository.addItemToCollection(
          parent,
          ctx.collectionRefItem(child),
        );

        final resolved = await ctx.repository.resolveContent(
          parent,
          libraryRepository: ctx.libraryRepo,
        );
        expect(resolved.length, equals(1));
        expect((resolved[0] as MockSongUnit).id, equals(su.id));
      },
    );

    test(
      'getCollectionItems on single-item collection returns one item',
      () async {
        final coll = await ctx.createCollection('single');
        final su = ctx.addMockSongUnit('song');

        await ctx.repository.addItemToCollection(coll, ctx.songUnitItem(su.id));

        final items = await ctx.repository.getCollectionItems(coll);
        expect(items.length, equals(1));
        expect(items[0].targetId, equals(su.id));
        expect(items[0].type, equals(PlaylistItemType.songUnit));
      },
    );

    test('removing the only item from a collection clears metadata', () async {
      final coll = await ctx.createCollection('single');
      final su = ctx.addMockSongUnit('song');
      final item = ctx.songUnitItem(su.id);

      await ctx.repository.addItemToCollection(coll, item);

      // Remove the only item
      await ctx.repository.removeItemFromCollection(coll, item.id);

      // Collection should now have no items (metadata cleared)
      final items = await ctx.repository.getCollectionItems(coll);
      expect(items, isEmpty);
    });

    test(
      'single-item collection with missing song unit resolves empty',
      () async {
        final coll = await ctx.createCollection('single');
        // Add a song unit item but DON'T register it in the mock library
        await ctx.repository.addItemToCollection(
          coll,
          ctx.songUnitItem('non_existent_song_id'),
        );

        final resolved = await ctx.repository.resolveContent(
          coll,
          libraryRepository: ctx.libraryRepo,
        );
        expect(
          resolved,
          isEmpty,
          reason: 'Missing song unit should be skipped during resolution',
        );
      },
    );

    test(
      'single reference to non-existent collection resolves empty',
      () async {
        final parent = await ctx.createCollection('parent');
        await ctx.repository.addItemToCollection(
          parent,
          ctx.collectionRefItem('non_existent_collection_id'),
        );

        final resolved = await ctx.repository.resolveContent(
          parent,
          libraryRepository: ctx.libraryRepo,
        );
        expect(
          resolved,
          isEmpty,
          reason:
              'Reference to non-existent collection should resolve to empty',
        );
      },
    );
  });
}
