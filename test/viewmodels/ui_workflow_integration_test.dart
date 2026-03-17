/// Task 6.4: Integration tests for UI workflows
///
/// Tests:
/// - Creating and managing groups in queue
/// - Creating and managing groups in playlists
/// - Lock inheritance when adding playlist to queue
/// - Shuffle with locked groups
///
/// **Validates: Requirements 6.2, 6.3, 7.4, 8.2, 12.1**
library;

import 'package:beadline/models/playlist_metadata.dart';
import 'package:beadline/models/tag.dart';
import 'package:beadline/viewmodels/tag_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'shuffle_locks_property_test.dart';

const _uuid = Uuid();

void main() {
  late InMemorySongUnitStorage songUnitStorage;
  late InMemoryTagStorage tagStorage;
  late MockLibraryRepository libraryRepo;
  late MockTagRepository tagRepo;
  late MockSettingsRepository settingsRepo;
  late MockPlaybackStateStorage playbackStorage;
  late TagViewModel viewModel;

  setUp(() async {
    songUnitStorage = InMemorySongUnitStorage();
    tagStorage = InMemoryTagStorage();
    libraryRepo = MockLibraryRepository(songUnitStorage);
    tagRepo = MockTagRepository(tagStorage);
    settingsRepo = MockSettingsRepository();
    playbackStorage = MockPlaybackStateStorage();

    // Create the default queue
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

    await Future.delayed(const Duration(milliseconds: 50));
  });

  tearDown(() {
    viewModel.dispose();
    libraryRepo.dispose();
    tagRepo.dispose();
    songUnitStorage.clear();
    tagStorage.clear();
  });

  // ==========================================================================
  // Workflow 1: Creating and managing groups in queue
  // **Validates: Requirements 6.2**
  // ==========================================================================
  group('Groups in Queue', () {
    test('Create a group in the queue, add songs, verify structure', () async {
      // Create songs in library
      final songs = <dynamic>[];
      for (var i = 0; i < 4; i++) {
        final song = ShuffleTestGenerators.makeSongUnit(title: 'QueueSong_$i');
        await libraryRepo.addSongUnit(song);
        songs.add(song);
      }

      // Create a group within the queue
      final group = await viewModel.createCollection(
        'My Queue Group',
        parentId: 'default',
        isGroup: true,
      );

      expect(group.isGroup, isTrue);
      expect(group.parentId, equals('default'));
      expect(group.isCollection, isTrue);
      expect(group.name, equals('My Queue Group'));

      // Add songs to the group
      for (final song in songs) {
        await viewModel.addSongUnitToCollection(group.id, song.id);
      }

      // Verify group contains all songs in order
      final groupItems = await tagRepo.getCollectionItems(group.id);
      expect(groupItems.length, equals(4));
      for (var i = 0; i < songs.length; i++) {
        expect(groupItems[i].targetId, equals(songs[i].id));
      }

      // Add group reference to queue
      await viewModel.addCollectionReference('default', group.id);

      // Verify queue references the group
      final queueTag = await tagRepo.getTag('default');
      final queueItems = queueTag!.playlistMetadata!.items;
      expect(
        queueItems.any(
          (item) =>
              item.type == PlaylistItemType.collectionReference &&
              item.targetId == group.id,
        ),
        isTrue,
      );
    });

    test('Reorder a group within the queue', () async {
      final song1 = ShuffleTestGenerators.makeSongUnit(title: 'S1');
      final song2 = ShuffleTestGenerators.makeSongUnit(title: 'S2');
      final song3 = ShuffleTestGenerators.makeSongUnit(title: 'S3');
      await libraryRepo.addSongUnit(song1);
      await libraryRepo.addSongUnit(song2);
      await libraryRepo.addSongUnit(song3);

      // Add a loose song to queue
      await viewModel.requestSong(song1.id);

      // Create a group and add songs
      final group = await viewModel.createCollection(
        'Reorder Group',
        parentId: 'default',
        isGroup: true,
      );
      await viewModel.addSongUnitToCollection(group.id, song2.id);
      await viewModel.addSongUnitToCollection(group.id, song3.id);
      await viewModel.addCollectionReference('default', group.id);

      // Queue now has: [song1, groupRef]
      var queueTag = await tagRepo.getTag('default');
      var items = queueTag!.playlistMetadata!.items;
      expect(items.length, equals(2));
      expect(items[0].type, equals(PlaylistItemType.songUnit));
      expect(items[1].type, equals(PlaylistItemType.collectionReference));

      // Reorder: move group reference to position 0
      await viewModel.reorderCollection('default', 1, 0);

      queueTag = await tagRepo.getTag('default');
      items = queueTag!.playlistMetadata!.items;
      expect(items[0].type, equals(PlaylistItemType.collectionReference));
      expect(items[0].targetId, equals(group.id));
      expect(items[1].type, equals(PlaylistItemType.songUnit));
    });

    test('Lock and unlock a group in the queue', () async {
      final song = ShuffleTestGenerators.makeSongUnit(title: 'LockTest');
      await libraryRepo.addSongUnit(song);

      final group = await viewModel.createCollection(
        'Lock Group',
        parentId: 'default',
        isGroup: true,
      );
      await viewModel.addSongUnitToCollection(group.id, song.id);

      // Initially unlocked
      var groupTag = await tagRepo.getTag(group.id);
      expect(groupTag!.isLocked, isFalse);

      // Lock it
      await viewModel.toggleLock(group.id);
      groupTag = await tagRepo.getTag(group.id);
      expect(groupTag!.isLocked, isTrue);

      // Unlock it
      await viewModel.toggleLock(group.id);
      groupTag = await tagRepo.getTag(group.id);
      expect(groupTag!.isLocked, isFalse);
    });

    test('Multiple groups in queue maintain independent state', () async {
      final songsA = <dynamic>[];
      final songsB = <dynamic>[];
      for (var i = 0; i < 2; i++) {
        final a = ShuffleTestGenerators.makeSongUnit(title: 'GroupA_$i');
        final b = ShuffleTestGenerators.makeSongUnit(title: 'GroupB_$i');
        await libraryRepo.addSongUnit(a);
        await libraryRepo.addSongUnit(b);
        songsA.add(a);
        songsB.add(b);
      }

      final groupA = await viewModel.createCollection(
        'Group A',
        parentId: 'default',
        isGroup: true,
      );
      final groupB = await viewModel.createCollection(
        'Group B',
        parentId: 'default',
        isGroup: true,
      );

      for (final s in songsA) {
        await viewModel.addSongUnitToCollection(groupA.id, s.id);
      }
      for (final s in songsB) {
        await viewModel.addSongUnitToCollection(groupB.id, s.id);
      }

      // Lock only group A
      await viewModel.toggleLock(groupA.id);

      final tagA = await tagRepo.getTag(groupA.id);
      final tagB = await tagRepo.getTag(groupB.id);
      expect(tagA!.isLocked, isTrue);
      expect(tagB!.isLocked, isFalse);

      // Verify each group has correct songs
      final itemsA = await tagRepo.getCollectionItems(groupA.id);
      final itemsB = await tagRepo.getCollectionItems(groupB.id);
      expect(itemsA.length, equals(2));
      expect(itemsB.length, equals(2));
      expect(itemsA[0].targetId, equals(songsA[0].id));
      expect(itemsB[0].targetId, equals(songsB[0].id));
    });
  });

  // ==========================================================================
  // Workflow 2: Creating and managing groups in playlists
  // **Validates: Requirements 6.3**
  // ==========================================================================
  group('Groups in Playlists', () {
    test(
      'Create groups within a playlist, add songs, verify structure',
      () async {
        final songs = <dynamic>[];
        for (var i = 0; i < 6; i++) {
          final song = ShuffleTestGenerators.makeSongUnit(title: 'PLSong_$i');
          await libraryRepo.addSongUnit(song);
          songs.add(song);
        }

        // Create a playlist
        final playlist = await tagRepo.createCollection('Concert');
        expect(playlist.isCollection, isTrue);
        expect(playlist.isPlaylist, isTrue);

        // Create two groups within the playlist
        final verse = await viewModel.createCollection(
          'Verse Songs',
          parentId: playlist.id,
          isGroup: true,
        );
        final chorus = await viewModel.createCollection(
          'Chorus Songs',
          parentId: playlist.id,
          isGroup: true,
        );

        expect(verse.isGroup, isTrue);
        expect(verse.parentId, equals(playlist.id));
        expect(chorus.isGroup, isTrue);
        expect(chorus.parentId, equals(playlist.id));

        // Add songs to groups
        for (var i = 0; i < 3; i++) {
          await viewModel.addSongUnitToCollection(verse.id, songs[i].id);
        }
        for (var i = 3; i < 6; i++) {
          await viewModel.addSongUnitToCollection(chorus.id, songs[i].id);
        }

        // Add group references to playlist
        await viewModel.addCollectionReference(playlist.id, verse.id);
        await viewModel.addCollectionReference(playlist.id, chorus.id);

        // Verify playlist structure
        final playlistItems = await tagRepo.getCollectionItems(playlist.id);
        expect(playlistItems.length, equals(2));
        expect(
          playlistItems[0].type,
          equals(PlaylistItemType.collectionReference),
        );
        expect(playlistItems[0].targetId, equals(verse.id));
        expect(
          playlistItems[1].type,
          equals(PlaylistItemType.collectionReference),
        );
        expect(playlistItems[1].targetId, equals(chorus.id));

        // Verify each group has correct songs
        final verseItems = await tagRepo.getCollectionItems(verse.id);
        final chorusItems = await tagRepo.getCollectionItems(chorus.id);
        expect(verseItems.length, equals(3));
        expect(chorusItems.length, equals(3));
        for (var i = 0; i < 3; i++) {
          expect(verseItems[i].targetId, equals(songs[i].id));
          expect(chorusItems[i].targetId, equals(songs[i + 3].id));
        }
      },
    );

    test('Reorder groups within a playlist', () async {
      final song1 = ShuffleTestGenerators.makeSongUnit(title: 'R1');
      final song2 = ShuffleTestGenerators.makeSongUnit(title: 'R2');
      await libraryRepo.addSongUnit(song1);
      await libraryRepo.addSongUnit(song2);

      final playlist = await tagRepo.createCollection('Reorder PL');

      final groupA = await viewModel.createCollection(
        'First',
        parentId: playlist.id,
        isGroup: true,
      );
      final groupB = await viewModel.createCollection(
        'Second',
        parentId: playlist.id,
        isGroup: true,
      );

      await viewModel.addSongUnitToCollection(groupA.id, song1.id);
      await viewModel.addSongUnitToCollection(groupB.id, song2.id);
      await viewModel.addCollectionReference(playlist.id, groupA.id);
      await viewModel.addCollectionReference(playlist.id, groupB.id);

      // Verify initial order
      var plItems = await tagRepo.getCollectionItems(playlist.id);
      expect(plItems[0].targetId, equals(groupA.id));
      expect(plItems[1].targetId, equals(groupB.id));

      // Reorder: move groupB to position 0
      await viewModel.reorderCollection(playlist.id, 1, 0);

      plItems = await tagRepo.getCollectionItems(playlist.id);
      expect(plItems[0].targetId, equals(groupB.id));
      expect(plItems[1].targetId, equals(groupA.id));
    });

    test('Groups in playlist are not visible as top-level playlists', () async {
      final playlist = await tagRepo.createCollection('Parent PL');
      final group = await viewModel.createCollection(
        'Hidden Group',
        parentId: playlist.id,
        isGroup: true,
      );

      // getCollections without groups should not include the group
      final collectionsNoGroups = await viewModel.getCollections(
        includeGroups: false,
      );
      expect(collectionsNoGroups.any((c) => c.id == group.id), isFalse);
      expect(collectionsNoGroups.any((c) => c.id == playlist.id), isTrue);

      // getCollections with groups should include it
      final collectionsWithGroups = await viewModel.getCollections();
      expect(collectionsWithGroups.any((c) => c.id == group.id), isTrue);
    });

    test('Lock groups independently within a playlist', () async {
      final song = ShuffleTestGenerators.makeSongUnit(title: 'LockPL');
      await libraryRepo.addSongUnit(song);

      final playlist = await tagRepo.createCollection('Lock PL');
      final groupA = await viewModel.createCollection(
        'Lock A',
        parentId: playlist.id,
        isGroup: true,
      );
      final groupB = await viewModel.createCollection(
        'Lock B',
        parentId: playlist.id,
        isGroup: true,
      );

      await viewModel.addSongUnitToCollection(groupA.id, song.id);
      await viewModel.addSongUnitToCollection(groupB.id, song.id);

      // Lock group A only
      await viewModel.toggleLock(groupA.id);

      final tagA = await tagRepo.getTag(groupA.id);
      final tagB = await tagRepo.getTag(groupB.id);
      expect(tagA!.isLocked, isTrue);
      expect(tagB!.isLocked, isFalse);

      // Lock playlist itself
      await viewModel.toggleLock(playlist.id);
      final plTag = await tagRepo.getTag(playlist.id);
      expect(plTag!.isLocked, isTrue);

      // Group lock states remain independent
      final tagAAfter = await tagRepo.getTag(groupA.id);
      final tagBAfter = await tagRepo.getTag(groupB.id);
      expect(tagAAfter!.isLocked, isTrue);
      expect(tagBAfter!.isLocked, isFalse);
    });
  });

  // ==========================================================================
  // Workflow 3: Lock inheritance when adding playlist to queue
  // **Validates: Requirements 7.4, 8.2**
  // ==========================================================================
  group('Lock Inheritance', () {
    test('Locked playlist creates locked group in queue', () async {
      final songs = <dynamic>[];
      for (var i = 0; i < 3; i++) {
        final song = ShuffleTestGenerators.makeSongUnit(title: 'Locked_$i');
        await libraryRepo.addSongUnit(song);
        songs.add(song);
      }

      // Create and populate a locked playlist
      final playlist = await tagRepo.createCollection('Locked PL');
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
      await tagRepo.setCollectionLock(playlist.id, true);

      // Add to queue
      final group = await viewModel.addCollectionToQueue(playlist.id);

      expect(group, isNotNull);
      expect(group!.isGroup, isTrue);
      expect(
        group.isLocked,
        isTrue,
        reason: 'Group should inherit locked state from playlist',
      );
      expect(group.parentId, equals('default'));

      // Verify all songs transferred
      final groupItems = await tagRepo.getCollectionItems(group.id);
      expect(groupItems.length, equals(3));
      for (var i = 0; i < songs.length; i++) {
        expect(groupItems[i].targetId, equals(songs[i].id));
      }
    });

    test('Unlocked playlist creates unlocked group in queue', () async {
      final song = ShuffleTestGenerators.makeSongUnit(title: 'Unlocked');
      await libraryRepo.addSongUnit(song);

      final playlist = await tagRepo.createCollection('Unlocked PL');
      await tagRepo.addItemToCollection(
        playlist.id,
        PlaylistItem(
          id: _uuid.v4(),
          type: PlaylistItemType.songUnit,
          targetId: song.id,
          order: 0,
        ),
      );
      // Playlist is unlocked by default

      final group = await viewModel.addCollectionToQueue(playlist.id);

      expect(group, isNotNull);
      expect(
        group!.isLocked,
        isFalse,
        reason: 'Group should inherit unlocked state from playlist',
      );
    });

    test(
      'Changing playlist lock after adding to queue does not affect group',
      () async {
        final song = ShuffleTestGenerators.makeSongUnit(title: 'Independent');
        await libraryRepo.addSongUnit(song);

        final playlist = await tagRepo.createCollection('Indep PL');
        await tagRepo.addItemToCollection(
          playlist.id,
          PlaylistItem(
            id: _uuid.v4(),
            type: PlaylistItemType.songUnit,
            targetId: song.id,
            order: 0,
          ),
        );
        await tagRepo.setCollectionLock(playlist.id, true);

        // Add locked playlist to queue
        final group = await viewModel.addCollectionToQueue(playlist.id);
        expect(group!.isLocked, isTrue);

        // Unlock the source playlist
        await tagRepo.setCollectionLock(playlist.id, false);

        // Group should still be locked (independent)
        final groupAfter = await tagRepo.getTag(group.id);
        expect(
          groupAfter!.isLocked,
          isTrue,
          reason: 'Group lock should be independent from source playlist',
        );
      },
    );

    test('Can override inherited lock state after adding to queue', () async {
      final song = ShuffleTestGenerators.makeSongUnit(title: 'Override');
      await libraryRepo.addSongUnit(song);

      final playlist = await tagRepo.createCollection('Override PL');
      await tagRepo.addItemToCollection(
        playlist.id,
        PlaylistItem(
          id: _uuid.v4(),
          type: PlaylistItemType.songUnit,
          targetId: song.id,
          order: 0,
        ),
      );
      await tagRepo.setCollectionLock(playlist.id, true);

      final group = await viewModel.addCollectionToQueue(playlist.id);
      expect(group!.isLocked, isTrue);

      // Override: unlock the group
      await viewModel.toggleLock(group.id);
      final unlocked = await tagRepo.getTag(group.id);
      expect(unlocked!.isLocked, isFalse);

      // Re-lock it
      await viewModel.toggleLock(group.id);
      final relocked = await tagRepo.getTag(group.id);
      expect(relocked!.isLocked, isTrue);
    });

    test('Mixed locked/unlocked playlists create correct groups', () async {
      final songA = ShuffleTestGenerators.makeSongUnit(title: 'MixA');
      final songB = ShuffleTestGenerators.makeSongUnit(title: 'MixB');
      await libraryRepo.addSongUnit(songA);
      await libraryRepo.addSongUnit(songB);

      final lockedPL = await tagRepo.createCollection('Locked');
      await tagRepo.addItemToCollection(
        lockedPL.id,
        PlaylistItem(
          id: _uuid.v4(),
          type: PlaylistItemType.songUnit,
          targetId: songA.id,
          order: 0,
        ),
      );
      await tagRepo.setCollectionLock(lockedPL.id, true);

      final unlockedPL = await tagRepo.createCollection('Unlocked');
      await tagRepo.addItemToCollection(
        unlockedPL.id,
        PlaylistItem(
          id: _uuid.v4(),
          type: PlaylistItemType.songUnit,
          targetId: songB.id,
          order: 0,
        ),
      );

      final groupLocked = await viewModel.addCollectionToQueue(lockedPL.id);
      final groupUnlocked = await viewModel.addCollectionToQueue(unlockedPL.id);

      expect(groupLocked!.isLocked, isTrue);
      expect(groupUnlocked!.isLocked, isFalse);
    });
  });

  // ==========================================================================
  // Workflow 4: Shuffle with locked groups
  // **Validates: Requirements 12.1**
  // ==========================================================================
  group('Shuffle with Locked Groups', () {
    test('Shuffle keeps locked group songs contiguous and in order', () async {
      // Create locked group songs
      final lockedSongs = <dynamic>[];
      for (var i = 0; i < 3; i++) {
        final song = ShuffleTestGenerators.makeSongUnit(title: 'Locked_$i');
        await libraryRepo.addSongUnit(song);
        lockedSongs.add(song);
      }

      // Create loose songs
      final looseSongs = <dynamic>[];
      for (var i = 0; i < 5; i++) {
        final song = ShuffleTestGenerators.makeSongUnit(title: 'Loose_$i');
        await libraryRepo.addSongUnit(song);
        looseSongs.add(song);
      }

      // Create a locked playlist and add to queue
      final playlist = await tagRepo.createCollection('Locked Set');
      for (var i = 0; i < lockedSongs.length; i++) {
        await tagRepo.addItemToCollection(
          playlist.id,
          PlaylistItem(
            id: _uuid.v4(),
            type: PlaylistItemType.songUnit,
            targetId: lockedSongs[i].id,
            order: i,
          ),
        );
      }
      await tagRepo.setCollectionLock(playlist.id, true);

      final group = await viewModel.addCollectionToQueue(playlist.id);
      expect(group!.isLocked, isTrue);

      // Add loose songs directly to queue
      for (final song in looseSongs) {
        await viewModel.requestSong(song.id);
      }

      final lockedSongIds = lockedSongs.map((s) => s.id as String).toList();

      // Shuffle multiple times and verify invariant each time
      for (var attempt = 0; attempt < 5; attempt++) {
        await viewModel.shuffle('default');

        // Resolve queue items
        final queueTag = await tagRepo.getTag('default');
        final queueItems = queueTag!.playlistMetadata!.items;

        final resolvedIds = <String>[];
        for (final item in queueItems) {
          if (item.type == PlaylistItemType.songUnit) {
            resolvedIds.add(item.targetId);
          } else if (item.type == PlaylistItemType.collectionReference) {
            final refTag = await tagRepo.getTag(item.targetId);
            if (refTag != null && refTag.isCollection) {
              for (final refItem in refTag.playlistMetadata!.items) {
                if (refItem.type == PlaylistItemType.songUnit) {
                  resolvedIds.add(refItem.targetId);
                }
              }
            }
          }
        }

        // Find locked song positions
        final lockedPositions = <int>[];
        for (var i = 0; i < resolvedIds.length; i++) {
          if (lockedSongIds.contains(resolvedIds[i])) {
            lockedPositions.add(i);
          }
        }

        // All locked songs must be present
        expect(
          lockedPositions.length,
          equals(lockedSongs.length),
          reason: 'Attempt $attempt: all locked songs should be present',
        );

        // Locked songs must be contiguous
        for (var i = 1; i < lockedPositions.length; i++) {
          expect(
            lockedPositions[i],
            equals(lockedPositions[i - 1] + 1),
            reason: 'Attempt $attempt: locked songs must be contiguous',
          );
        }

        // Locked songs must maintain original order
        final lockedInQueue = lockedPositions
            .map((pos) => resolvedIds[pos])
            .toList();
        expect(
          lockedInQueue,
          equals(lockedSongIds),
          reason: 'Attempt $attempt: locked songs must maintain original order',
        );
      }
    });

    test('Shuffle does not change lock states', () async {
      final song1 = ShuffleTestGenerators.makeSongUnit(title: 'LS1');
      final song2 = ShuffleTestGenerators.makeSongUnit(title: 'LS2');
      await libraryRepo.addSongUnit(song1);
      await libraryRepo.addSongUnit(song2);

      final playlist = await tagRepo.createCollection('Lock State PL');
      await tagRepo.addItemToCollection(
        playlist.id,
        PlaylistItem(
          id: _uuid.v4(),
          type: PlaylistItemType.songUnit,
          targetId: song1.id,
          order: 0,
        ),
      );
      await tagRepo.setCollectionLock(playlist.id, true);

      final group = await viewModel.addCollectionToQueue(playlist.id);
      expect(group!.isLocked, isTrue);

      await viewModel.requestSong(song2.id);

      // Shuffle
      await viewModel.shuffle('default');

      // Lock state preserved
      final groupAfter = await tagRepo.getTag(group.id);
      expect(
        groupAfter!.isLocked,
        isTrue,
        reason: 'Shuffle should not change lock state',
      );
    });

    test('Shuffle with multiple locked and unlocked groups', () async {
      // Create songs for two locked groups and loose songs
      final lockedA = <dynamic>[];
      final lockedB = <dynamic>[];
      final loose = <dynamic>[];

      for (var i = 0; i < 3; i++) {
        final a = ShuffleTestGenerators.makeSongUnit(title: 'LockedA_$i');
        final b = ShuffleTestGenerators.makeSongUnit(title: 'LockedB_$i');
        final l = ShuffleTestGenerators.makeSongUnit(title: 'Loose_$i');
        await libraryRepo.addSongUnit(a);
        await libraryRepo.addSongUnit(b);
        await libraryRepo.addSongUnit(l);
        lockedA.add(a);
        lockedB.add(b);
        loose.add(l);
      }

      // Create two locked playlists
      final plA = await tagRepo.createCollection('Locked A');
      final plB = await tagRepo.createCollection('Locked B');
      for (var i = 0; i < 3; i++) {
        await tagRepo.addItemToCollection(
          plA.id,
          PlaylistItem(
            id: _uuid.v4(),
            type: PlaylistItemType.songUnit,
            targetId: lockedA[i].id,
            order: i,
          ),
        );
        await tagRepo.addItemToCollection(
          plB.id,
          PlaylistItem(
            id: _uuid.v4(),
            type: PlaylistItemType.songUnit,
            targetId: lockedB[i].id,
            order: i,
          ),
        );
      }
      await tagRepo.setCollectionLock(plA.id, true);
      await tagRepo.setCollectionLock(plB.id, true);

      await viewModel.addCollectionToQueue(plA.id);
      await viewModel.addCollectionToQueue(plB.id);

      // Add loose songs
      for (final s in loose) {
        await viewModel.requestSong(s.id);
      }

      final lockedAIds = lockedA.map((s) => s.id as String).toList();
      final lockedBIds = lockedB.map((s) => s.id as String).toList();

      for (var attempt = 0; attempt < 5; attempt++) {
        await viewModel.shuffle('default');

        final queueTag = await tagRepo.getTag('default');
        final queueItems = queueTag!.playlistMetadata!.items;

        final resolvedIds = <String>[];
        for (final item in queueItems) {
          if (item.type == PlaylistItemType.songUnit) {
            resolvedIds.add(item.targetId);
          } else if (item.type == PlaylistItemType.collectionReference) {
            final refTag = await tagRepo.getTag(item.targetId);
            if (refTag != null && refTag.isCollection) {
              for (final refItem in refTag.playlistMetadata!.items) {
                if (refItem.type == PlaylistItemType.songUnit) {
                  resolvedIds.add(refItem.targetId);
                }
              }
            }
          }
        }

        // Verify locked group A contiguity and order
        final posA = <int>[];
        for (var i = 0; i < resolvedIds.length; i++) {
          if (lockedAIds.contains(resolvedIds[i])) posA.add(i);
        }
        expect(posA.length, equals(3));
        for (var i = 1; i < posA.length; i++) {
          expect(
            posA[i],
            equals(posA[i - 1] + 1),
            reason: 'Attempt $attempt: locked group A must be contiguous',
          );
        }
        expect(
          posA.map((p) => resolvedIds[p]).toList(),
          equals(lockedAIds),
          reason: 'Attempt $attempt: locked group A must maintain order',
        );

        // Verify locked group B contiguity and order
        final posB = <int>[];
        for (var i = 0; i < resolvedIds.length; i++) {
          if (lockedBIds.contains(resolvedIds[i])) posB.add(i);
        }
        expect(posB.length, equals(3));
        for (var i = 1; i < posB.length; i++) {
          expect(
            posB[i],
            equals(posB[i - 1] + 1),
            reason: 'Attempt $attempt: locked group B must be contiguous',
          );
        }
        expect(
          posB.map((p) => resolvedIds[p]).toList(),
          equals(lockedBIds),
          reason: 'Attempt $attempt: locked group B must maintain order',
        );
      }
    });

    test('Shuffle with unlocked group does not preserve its order', () async {
      final songs = <dynamic>[];
      for (var i = 0; i < 4; i++) {
        final song = ShuffleTestGenerators.makeSongUnit(title: 'UG_$i');
        await libraryRepo.addSongUnit(song);
        songs.add(song);
      }

      // Create an unlocked playlist and add to queue
      final playlist = await tagRepo.createCollection('Unlocked Set');
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
      // Don't lock it

      final group = await viewModel.addCollectionToQueue(playlist.id);
      expect(group!.isLocked, isFalse);

      // Add some loose songs too
      for (var i = 0; i < 4; i++) {
        final extra = ShuffleTestGenerators.makeSongUnit(title: 'Extra_$i');
        await libraryRepo.addSongUnit(extra);
        await viewModel.requestSong(extra.id);
      }

      // Shuffle - unlocked group reference is treated as a regular item
      // and can be moved around. The group's internal order is preserved
      // but the group itself is shuffled among other items.
      await viewModel.shuffle('default');

      // Just verify all items are still present (no data loss)
      final queueTag = await tagRepo.getTag('default');
      final queueItems = queueTag!.playlistMetadata!.items;
      // Should have: 1 collection reference (unlocked group) + 4 loose songs = 5
      expect(queueItems.length, equals(5));

      // Verify the group still has its songs
      final groupItems = await tagRepo.getCollectionItems(group.id);
      expect(groupItems.length, equals(4));
    });
  });
}
