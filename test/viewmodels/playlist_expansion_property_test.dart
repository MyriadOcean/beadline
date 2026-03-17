/// Task 8.2: Property tests for playlist expansion in queue
///
/// Properties tested:
/// - Property 12: Playlist Expansion in Queue
/// - Property 13: Playlist Order Preservation in Queue
/// - Property 15: Collection Addition to Queue
///
/// **Validates: Requirements 5.2, 5.3, 5.6**
library;

import 'dart:math';

import 'package:beadline/models/playlist_metadata.dart';
import 'package:beadline/models/tag.dart';
import 'package:beadline/viewmodels/tag_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'shuffle_locks_property_test.dart';

// ============================================================================
// Test context helper for playlist expansion tests
// ============================================================================

class PlaylistExpansionTestContext {
  PlaylistExpansionTestContext() {
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
          targetId: songs[i].id,
          order: i,
        ),
      );
    }
    return (await tagRepo.getTag(playlist.id))!;
  }

  /// Create a collection that is a "general tag" (not specifically a playlist,
  /// but still a collection with songs). Used for Property 15.
  Future<Tag> createCollectionWithSongs(
    List<dynamic> songs, {
    String? name,
  }) async {
    // Same as playlist - in the unified model, any collection works
    return createPlaylistWithSongs(
      songs,
      name: name ?? 'Collection_${_uuid.v4().substring(0, 8)}',
    );
  }

  /// Get song unit IDs from a collection's items, recursively resolving
  /// nested collection references (sub-groups).
  Future<List<String>> getSongUnitIds(String collectionId) async {
    final tag = await tagRepo.getTag(collectionId);
    if (tag == null || tag.playlistMetadata == null) return [];
    final result = <String>[];
    for (final item in tag.playlistMetadata!.items) {
      if (item.type == PlaylistItemType.songUnit) {
        result.add(item.targetId);
      } else if (item.type == PlaylistItemType.collectionReference) {
        result.addAll(await getSongUnitIds(item.targetId));
      }
    }
    return result;
  }

  /// Resolve the queue items into a flat list of song unit IDs,
  /// expanding collection references recursively into their constituent songs.
  Future<List<String>> resolveQueueSongIds() async {
    final queueTag = await tagRepo.getTag('default');
    if (queueTag == null || queueTag.playlistMetadata == null) return [];
    return getSongUnitIds('default');
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
  group('Playlist Expansion Property Tests (Task 8.2)', () {
    // ========================================================================
    // Feature: queue-playlist-system, Property 12: Playlist Expansion in Queue
    // **Validates: Requirements 5.2**
    //
    // For any playlist, adding it to the queue should result in all song
    // units from the playlist being added to the queue.
    // ========================================================================
    test('Property 12: Playlist Expansion in Queue - '
        'all song units from playlist are present in queue after adding', () async {
      const iterations = 100;

      for (var i = 0; i < iterations; i++) {
        final ctx = PlaylistExpansionTestContext();
        await Future.delayed(const Duration(milliseconds: 10));

        // Create a playlist with 1-10 songs
        final songCount = 1 + PlaylistExpansionTestContext._random.nextInt(10);
        final songs = await ctx.createSongs(songCount, prefix: 'P12_$i');
        final songIds = songs.map((s) => s.id as String).toSet();

        final playlist = await ctx.createPlaylistWithSongs(songs);

        // Add playlist to queue
        final group = await ctx.viewModel.addCollectionToQueue(playlist.id);

        // Verify group was created
        expect(
          group,
          isNotNull,
          reason: 'Iteration $i: group should be created',
        );

        // Get the song unit IDs in the created group
        final groupSongIds = (await ctx.getSongUnitIds(group!.id)).toSet();

        // Verify ALL song units from the playlist are present in the group
        expect(
          groupSongIds,
          equals(songIds),
          reason:
              'Iteration $i: all $songCount playlist songs should be in the queue group',
        );

        // Also verify via full queue resolution
        final queueSongIds = (await ctx.resolveQueueSongIds()).toSet();
        expect(
          queueSongIds.containsAll(songIds),
          isTrue,
          reason:
              'Iteration $i: all playlist songs should be resolvable from queue',
        );

        ctx.dispose();
      }
    });

    // ========================================================================
    // Feature: queue-playlist-system, Property 13: Playlist Order Preservation in Queue
    // **Validates: Requirements 5.3**
    //
    // For any playlist with ordered song units, adding it to the queue
    // should preserve the relative order of those song units in the queue.
    // ========================================================================
    test('Property 13: Playlist Order Preservation in Queue - '
        'song unit order from playlist is preserved in queue group', () async {
      const iterations = 100;

      for (var i = 0; i < iterations; i++) {
        final ctx = PlaylistExpansionTestContext();
        await Future.delayed(const Duration(milliseconds: 10));

        // Create a playlist with 2-10 songs (need at least 2 to verify order)
        final songCount = 2 + PlaylistExpansionTestContext._random.nextInt(9);
        final songs = await ctx.createSongs(songCount, prefix: 'P13_$i');
        final expectedOrder = songs.map((s) => s.id as String).toList();

        final playlist = await ctx.createPlaylistWithSongs(songs);

        // Add playlist to queue
        final group = await ctx.viewModel.addCollectionToQueue(playlist.id);
        expect(
          group,
          isNotNull,
          reason: 'Iteration $i: group should be created',
        );

        // Get the ordered song unit IDs from the group
        final groupSongIds = await ctx.getSongUnitIds(group!.id);

        // Verify the order matches exactly
        expect(
          groupSongIds,
          equals(expectedOrder),
          reason:
              'Iteration $i: song order in queue group should match playlist order',
        );

        // Also verify order via queue resolution
        final queueSongIds = await ctx.resolveQueueSongIds();

        // Extract the subsequence of playlist songs from the queue
        final playlistSongsInQueue = queueSongIds
            .where(expectedOrder.contains)
            .toList();

        expect(
          playlistSongsInQueue,
          equals(expectedOrder),
          reason:
              'Iteration $i: relative order of playlist songs in queue should be preserved',
        );

        ctx.dispose();
      }
    });

    // ========================================================================
    // Feature: queue-playlist-system, Property 15: Collection Addition to Queue
    // **Validates: Requirements 5.6**
    //
    // For any collection tag, adding it to the queue should add all song
    // units from that collection to the queue.
    // ========================================================================
    test(
      'Property 15: Collection Addition to Queue - '
      'any collection tag added to queue results in all its songs in queue',
      () async {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          final ctx = PlaylistExpansionTestContext();
          await Future.delayed(const Duration(milliseconds: 10));

          // Randomly choose collection type: plain collection, locked, or nested
          final collectionType = PlaylistExpansionTestContext._random.nextInt(
            3,
          );

          final songCount = 1 + PlaylistExpansionTestContext._random.nextInt(8);
          final songs = await ctx.createSongs(songCount, prefix: 'P15_$i');
          final songIds = songs.map((s) => s.id as String).toSet();

          Tag collection;

          switch (collectionType) {
            case 0:
              // Plain collection (unlocked)
              collection = await ctx.createCollectionWithSongs(
                songs,
                name: 'PlainCol_$i',
              );
              break;
            case 1:
              // Locked collection
              collection = await ctx.createCollectionWithSongs(
                songs,
                name: 'LockedCol_$i',
              );
              await ctx.tagRepo.setCollectionLock(collection.id, true);
              collection = (await ctx.tagRepo.getTag(collection.id))!;
              break;
            default:
              // Collection with a nested sub-collection reference
              // Split songs: some direct, some in a sub-collection
              final splitPoint =
                  1 +
                  PlaylistExpansionTestContext._random.nextInt(
                    songCount > 1 ? songCount - 1 : 1,
                  );
              final directSongs = songs.sublist(
                0,
                splitPoint.clamp(0, songs.length),
              );
              final nestedSongs = songs.sublist(
                splitPoint.clamp(0, songs.length),
              );

              // Create the sub-collection
              final subCollection = await ctx.createCollectionWithSongs(
                nestedSongs,
                name: 'SubCol_$i',
              );

              // Create the parent collection with direct songs + reference
              collection = await ctx.tagRepo.createCollection('ParentCol_$i');
              for (var j = 0; j < directSongs.length; j++) {
                await ctx.tagRepo.addItemToCollection(
                  collection.id,
                  PlaylistItem(
                    id: const Uuid().v4(),
                    type: PlaylistItemType.songUnit,
                    targetId: directSongs[j].id,
                    order: j,
                  ),
                );
              }
              // Add reference to sub-collection
              await ctx.tagRepo.addItemToCollection(
                collection.id,
                PlaylistItem(
                  id: const Uuid().v4(),
                  type: PlaylistItemType.collectionReference,
                  targetId: subCollection.id,
                  order: directSongs.length,
                ),
              );
              collection = (await ctx.tagRepo.getTag(collection.id))!;
              break;
          }

          // Add collection to queue
          final group = await ctx.viewModel.addCollectionToQueue(collection.id);

          // Verify group was created
          expect(
            group,
            isNotNull,
            reason:
                'Iteration $i (type=$collectionType): group should be created',
          );

          // Get all song unit IDs from the group
          final groupSongIds = (await ctx.getSongUnitIds(group!.id)).toSet();

          // Verify all song units from the collection are present
          expect(
            groupSongIds,
            equals(songIds),
            reason:
                'Iteration $i (type=$collectionType): all $songCount collection songs '
                'should be in the queue group',
          );

          // Verify via full queue resolution
          final queueSongIds = (await ctx.resolveQueueSongIds()).toSet();
          expect(
            queueSongIds.containsAll(songIds),
            isTrue,
            reason:
                'Iteration $i (type=$collectionType): all collection songs '
                'should be resolvable from queue',
          );

          ctx.dispose();
        }
      },
    );
  });
}
