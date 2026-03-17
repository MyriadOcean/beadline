/// Task 8.4: Unit tests for reference edge cases
///
/// Tests:
/// - Adding reference to different collection types
/// - Circular reference prevention
/// - Reference to missing collection
///
/// **Validates: Requirements 11.1, 11.5, 11.7, 15.3**
library;

import 'package:beadline/models/playlist_metadata.dart';
import 'package:beadline/models/tag.dart';
import 'package:beadline/viewmodels/tag_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

// Reuse mock infrastructure from shuffle_locks_property_test.dart
import 'shuffle_locks_property_test.dart';

/// Test context for reference edge case tests.
class ReferenceTestContext {
  ReferenceTestContext() {
    songUnitStorage = InMemorySongUnitStorage();
    tagStorage = InMemoryTagStorage();
    libraryRepo = MockLibraryRepository(songUnitStorage);
    tagRepo = MockTagRepository(tagStorage);
    settingsRepo = MockSettingsRepository();
    playbackStorage = MockPlaybackStateStorage();

    // Create default queue
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

  void dispose() {
    viewModel.dispose();
    libraryRepo.dispose();
    tagRepo.dispose();
    songUnitStorage.clear();
    tagStorage.clear();
  }
}

void main() {
  group('Reference Edge Cases (Task 8.4)', () {
    late ReferenceTestContext ctx;

    setUp(() {
      ctx = ReferenceTestContext();
    });

    tearDown(() {
      ctx.dispose();
    });

    // ========================================================================
    // Adding references to different collection types (Req 11.1, 11.7)
    // ========================================================================

    group('Adding references to different collection types', () {
      test(
        'playlist can reference another playlist (collection → collection)',
        () async {
          // Wait for async init
          await Future.delayed(const Duration(milliseconds: 20));

          final playlistA = await ctx.viewModel.createCollection('Playlist A');
          final playlistB = await ctx.viewModel.createCollection('Playlist B');

          // Add a song to playlist B so it has content
          final song = ShuffleTestGenerators.makeSongUnit(title: 'Song 1');
          await ctx.libraryRepo.addSongUnit(song);
          await ctx.viewModel.addSongUnitToCollection(playlistB.id, song.id);

          // Add reference from A to B
          await ctx.viewModel.addCollectionReference(
            playlistA.id,
            playlistB.id,
          );

          // Verify the reference was added
          final updatedA = await ctx.tagRepo.getTag(playlistA.id);
          expect(updatedA, isNotNull);
          expect(updatedA!.playlistMetadata!.items.length, equals(1));
          expect(
            updatedA.playlistMetadata!.items[0].type,
            equals(PlaylistItemType.collectionReference),
          );
          expect(
            updatedA.playlistMetadata!.items[0].targetId,
            equals(playlistB.id),
          );
        },
      );

      test('playlist can reference a group', () async {
        await Future.delayed(const Duration(milliseconds: 20));

        final playlist = await ctx.viewModel.createCollection('My Playlist');
        final group = await ctx.viewModel.createCollection(
          'My Group',
          parentId: playlist.id,
          isGroup: true,
        );

        // Add a song to the group
        final song = ShuffleTestGenerators.makeSongUnit(title: 'Group Song');
        await ctx.libraryRepo.addSongUnit(song);
        await ctx.viewModel.addSongUnitToCollection(group.id, song.id);

        // Create another playlist and reference the group
        final otherPlaylist = await ctx.viewModel.createCollection(
          'Other Playlist',
        );
        await ctx.viewModel.addCollectionReference(otherPlaylist.id, group.id);

        // Verify the reference was added
        final updated = await ctx.tagRepo.getTag(otherPlaylist.id);
        expect(updated, isNotNull);
        expect(updated!.playlistMetadata!.items.length, equals(1));
        expect(
          updated.playlistMetadata!.items[0].type,
          equals(PlaylistItemType.collectionReference),
        );
        expect(updated.playlistMetadata!.items[0].targetId, equals(group.id));
      });

      test('queue can reference a playlist', () async {
        await Future.delayed(const Duration(milliseconds: 20));

        final playlist = await ctx.viewModel.createCollection('Ref Playlist');

        // Add songs to the playlist
        final song = ShuffleTestGenerators.makeSongUnit(title: 'PL Song');
        await ctx.libraryRepo.addSongUnit(song);
        await ctx.viewModel.addSongUnitToCollection(playlist.id, song.id);

        // Add reference from the default queue to the playlist
        await ctx.viewModel.addCollectionReference('default', playlist.id);

        // Verify the reference was added to the queue
        final queue = await ctx.tagRepo.getTag('default');
        expect(queue, isNotNull);
        final refItems = queue!.playlistMetadata!.items
            .where((i) => i.type == PlaylistItemType.collectionReference)
            .toList();
        expect(refItems.length, equals(1));
        expect(refItems[0].targetId, equals(playlist.id));
      });
    });

    // ========================================================================
    // Circular reference prevention (Req 11.5)
    // ========================================================================

    group('Circular reference prevention', () {
      test('A references B, then B tries to reference A → prevented', () async {
        await Future.delayed(const Duration(milliseconds: 20));

        final collA = await ctx.viewModel.createCollection('Collection A');
        final collB = await ctx.viewModel.createCollection('Collection B');

        // A references B
        await ctx.viewModel.addCollectionReference(collA.id, collB.id);

        // B tries to reference A → should be prevented
        await ctx.viewModel.addCollectionReference(collB.id, collA.id);

        // Verify B was NOT modified (still has no items)
        final updatedB = await ctx.tagRepo.getTag(collB.id);
        expect(
          updatedB!.playlistMetadata!.items.length,
          equals(0),
          reason: 'B should not have a reference to A (circular)',
        );

        // Verify error was set
        expect(ctx.viewModel.error, isNotNull);
        expect(ctx.viewModel.error, contains('circular reference'));
      });

      test(
        'self-reference prevention: A tries to reference itself → prevented',
        () async {
          await Future.delayed(const Duration(milliseconds: 20));

          final collA = await ctx.viewModel.createCollection('Self Ref');

          // A tries to reference itself
          await ctx.viewModel.addCollectionReference(collA.id, collA.id);

          // Verify A was NOT modified
          final updated = await ctx.tagRepo.getTag(collA.id);
          expect(
            updated!.playlistMetadata!.items.length,
            equals(0),
            reason: 'A should not reference itself',
          );

          // Verify error was set
          expect(ctx.viewModel.error, isNotNull);
          expect(ctx.viewModel.error, contains('circular reference'));
        },
      );

      test(
        'indirect circular: A→B→C, C tries to reference A → prevented',
        () async {
          await Future.delayed(const Duration(milliseconds: 20));

          final collA = await ctx.viewModel.createCollection('A');
          final collB = await ctx.viewModel.createCollection('B');
          final collC = await ctx.viewModel.createCollection('C');

          // Build chain: A → B → C
          await ctx.viewModel.addCollectionReference(collA.id, collB.id);
          await ctx.viewModel.addCollectionReference(collB.id, collC.id);

          // C tries to reference A → should be prevented
          await ctx.viewModel.addCollectionReference(collC.id, collA.id);

          // Verify C only has 0 items (the B→C ref is on B, not C)
          final updatedC = await ctx.tagRepo.getTag(collC.id);
          expect(
            updatedC!.playlistMetadata!.items.length,
            equals(0),
            reason: 'C should not reference A (indirect circular)',
          );

          expect(ctx.viewModel.error, isNotNull);
          expect(ctx.viewModel.error, contains('circular reference'));
        },
      );

      test(
        'wouldCreateCircularReference returns true for self-reference',
        () async {
          await Future.delayed(const Duration(milliseconds: 20));

          final coll = await ctx.viewModel.createCollection('Test');
          final result = await ctx.viewModel.wouldCreateCircularReference(
            coll.id,
            coll.id,
          );
          expect(result, isTrue);
        },
      );

      test(
        'wouldCreateCircularReference returns false for non-circular',
        () async {
          await Future.delayed(const Duration(milliseconds: 20));

          final collA = await ctx.viewModel.createCollection('A');
          final collB = await ctx.viewModel.createCollection('B');

          // No references exist, so A→B is not circular
          final result = await ctx.viewModel.wouldCreateCircularReference(
            collA.id,
            collB.id,
          );
          expect(result, isFalse);
        },
      );
    });

    // ========================================================================
    // Reference to missing/invalid targets (Req 15.3)
    // ========================================================================

    group('Reference to missing or invalid targets', () {
      test(
        'reference to non-existent collection ID is handled gracefully',
        () async {
          await Future.delayed(const Duration(milliseconds: 20));

          final playlist = await ctx.viewModel.createCollection('My Playlist');

          // Try to add a reference to a non-existent ID
          // The wouldCreateCircularReference check will look up the target;
          // since it doesn't exist, it's not circular, so the reference item
          // gets added. But resolving it should return empty.
          await ctx.viewModel.addCollectionReference(
            playlist.id,
            'non_existent_id',
          );

          // The reference item should be added (the ViewModel doesn't validate
          // target existence, only circularity)
          final updated = await ctx.tagRepo.getTag(playlist.id);
          final refItems = updated!.playlistMetadata!.items
              .where((i) => i.type == PlaylistItemType.collectionReference)
              .toList();
          expect(refItems.length, equals(1));
          expect(refItems[0].targetId, equals('non_existent_id'));

          // Resolving the content should return empty (target doesn't exist)
          final resolved = await ctx.viewModel.resolveContent(playlist.id);
          expect(
            resolved,
            isEmpty,
            reason:
                'Resolving a reference to a non-existent collection should return empty',
          );
        },
      );

      test('reference to a non-collection tag is handled gracefully', () async {
        await Future.delayed(const Duration(milliseconds: 20));

        final playlist = await ctx.viewModel.createCollection('My Playlist');

        // Create a plain tag (not a collection - no PlaylistMetadata)
        final plainTag = await ctx.viewModel.createTag('just-a-tag');
        expect(plainTag, isNotNull);
        expect(plainTag!.isCollection, isFalse);

        // Add a reference to the plain tag
        await ctx.viewModel.addCollectionReference(playlist.id, plainTag.id);

        // The reference item should be added
        final updated = await ctx.tagRepo.getTag(playlist.id);
        final refItems = updated!.playlistMetadata!.items
            .where((i) => i.type == PlaylistItemType.collectionReference)
            .toList();
        expect(refItems.length, equals(1));
        expect(refItems[0].targetId, equals(plainTag.id));

        // Resolving should return empty (target is not a collection)
        final resolved = await ctx.viewModel.resolveContent(playlist.id);
        expect(
          resolved,
          isEmpty,
          reason:
              'Resolving a reference to a non-collection tag should return empty',
        );
      });
    });
  });
}
