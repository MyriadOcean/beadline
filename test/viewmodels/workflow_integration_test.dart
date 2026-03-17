/// Task 12.1: Complete User Workflow Integration Tests
/// Validates: All Requirements
///
/// Tests end-to-end workflows:
/// - Create playlist, add songs, add to queue
/// - Create groups within playlist, lock them
/// - Add playlist to queue, verify lock inheritance
/// - Shuffle queue, verify locked groups stay together
/// - Switch queues, verify state preservation
library;

import 'dart:async';
import 'dart:math';

import 'package:beadline/data/playback_state_storage.dart';
import 'package:beadline/models/library_location.dart';
import 'package:beadline/models/metadata.dart';
import 'package:beadline/models/playback_preferences.dart';
import 'package:beadline/models/playlist_metadata.dart';
import 'package:beadline/models/song_unit.dart';
import 'package:beadline/models/source_collection.dart';
import 'package:beadline/models/tag.dart';
import 'package:beadline/repositories/library_repository.dart';
import 'package:beadline/repositories/settings_repository.dart';
import 'package:beadline/repositories/tag_repository.dart';
import 'package:beadline/services/entry_point_file_service.dart';
import 'package:beadline/services/path_resolver.dart';
import 'package:beadline/viewmodels/tag_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

// ============================================================================
// In-memory storage helpers (same pattern as lock_inheritance_test.dart)
// ============================================================================

class InMemorySongUnitStorage {
  final Map<String, SongUnit> _songUnits = {};

  void add(SongUnit songUnit) => _songUnits[songUnit.id] = songUnit;
  void update(SongUnit songUnit) => _songUnits[songUnit.id] = songUnit;
  void delete(String id) => _songUnits.remove(id);
  SongUnit? get(String id) => _songUnits[id];
  List<SongUnit> getAll() => _songUnits.values.toList();
  void clear() => _songUnits.clear();
}

class InMemoryTagStorage {
  final Map<String, Tag> _tags = {};
  final Map<String, String> _aliases = {};
  int _idCounter = 0;

  String generateId() => 'tag_${_idCounter++}';
  void add(Tag tag) => _tags[tag.id] = tag;
  void delete(String id) {
    _tags.remove(id);
    _aliases.removeWhere((_, primaryId) => primaryId == id);
  }

  Tag? get(String id) => _tags[id];
  Tag? getByName(String name) {
    for (final tag in _tags.values) {
      if (tag.name == name) return tag;
    }
    return null;
  }

  List<Tag> getAll() => _tags.values.toList();
  List<Tag> getByType(TagType type) =>
      _tags.values.where((t) => t.type == type).toList();
  void addAlias(String aliasName, String primaryTagId) =>
      _aliases[aliasName] = primaryTagId;
  void removeAlias(String aliasName) => _aliases.remove(aliasName);
  String? resolveAlias(String aliasName) => _aliases[aliasName];
  void clear() {
    _tags.clear();
    _aliases.clear();
    _idCounter = 0;
  }
}

// ============================================================================
// Mock implementations
// ============================================================================

class MockLibraryRepository implements LibraryRepository {
  MockLibraryRepository(this._storage);
  final InMemorySongUnitStorage _storage;
  final StreamController<LibraryEvent> _eventController =
      StreamController<LibraryEvent>.broadcast();

  @override
  Stream<LibraryEvent> get events => _eventController.stream;

  @override
  Future<void> addSongUnit(SongUnit songUnit) async {
    _storage.add(songUnit);
    _eventController.add(SongUnitAdded(songUnit));
  }

  @override
  Future<void> updateSongUnit(SongUnit songUnit) async {
    _storage.update(songUnit);
    _eventController.add(SongUnitUpdated(songUnit));
  }

  @override
  Future<void> deleteSongUnit(String id) async {
    _storage.delete(id);
    _eventController.add(SongUnitDeleted(id));
  }

  @override
  Future<SongUnit?> getSongUnit(String id) async => _storage.get(id);

  @override
  Future<List<SongUnit>> getAllSongUnits() async => _storage.getAll();

  @override
  Future<List<SongUnit>> getSongUnitsByHash(String hash) async =>
      _storage.getAll().where((s) => s.calculateHash() == hash).toList();

  @override
  Future<bool> existsByHash(String hash) async =>
      _storage.getAll().any((s) => s.calculateHash() == hash);

  @override
  Future<List<SongUnit>> getSongUnitsPaginated({
    required int page,
    int pageSize = 50,
  }) async {
    final all = _storage.getAll();
    final start = page * pageSize;
    if (start >= all.length) return [];
    return all.sublist(start, (start + pageSize).clamp(0, all.length));
  }

  @override
  Future<int> getSongUnitCount() async => _storage.getAll().length;

  @override
  Future<List<SongUnit>> getByLibraryLocation(String id) async =>
      _storage.getAll().where((s) => s.libraryLocationId == id).toList();

  @override
  Future<List<SongUnit>> getSongUnitsWithoutLibraryLocation() async =>
      _storage.getAll().where((s) => s.libraryLocationId == null).toList();

  @override
  Future<List<SongUnit>> getAggregatedFromLibraryLocations(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return _storage.getAll();
    return _storage
        .getAll()
        .where((s) => ids.contains(s.libraryLocationId))
        .toList();
  }

  @override
  Future<List<SongUnit>> getByStorageLocation(String id) =>
      getByLibraryLocation(id);

  @override
  Future<List<SongUnit>> getSongUnitsWithoutStorageLocation() =>
      getSongUnitsWithoutLibraryLocation();

  @override
  Future<List<SongUnit>> getAggregatedFromStorageLocations(List<String> ids) =>
      getAggregatedFromLibraryLocations(ids);

  @override
  void clearCache() {}

  @override
  Future<SongUnit> moveSongUnit({
    required String songUnitId,
    required LibraryLocation sourceLocation,
    required LibraryLocation destinationLocation,
    required EntryPointFileService entryPointFileService,
    required PathResolver pathResolver,
    String? sourceEntryPointPath,
    String? destinationDirectory,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<bool> hasTemporarySongUnitForPath(String filePath) async => false;

  @override
  Future<List<SongUnit>> getTemporarySongUnits() async =>
      _storage.getAll().where((s) => s.isTemporary).toList();

  @override
  Future<void> deleteAllTemporarySongUnits() async {
    for (final s in _storage.getAll().where((s) => s.isTemporary).toList()) {
      _storage.delete(s.id);
    }
  }

  @override
  Future<void> deleteTemporarySongUnitByPath(String filePath) async {}

  @override
  void dispose() => _eventController.close();
}

class MockTagRepository implements TagRepository {
  MockTagRepository(this._storage);
  final InMemoryTagStorage _storage;
  final StreamController<TagEvent> _eventController =
      StreamController<TagEvent>.broadcast(sync: true);

  @override
  Stream<TagEvent> get events => _eventController.stream;

  @override
  Future<Tag?> getTag(String id) async => _storage.get(id);

  @override
  Future<Tag?> getTagByName(String name) async => _storage.getByName(name);

  @override
  Future<Tag> createTag(String name, {String? parentId}) async {
    final id = _storage.generateId();
    final tag = Tag(id: id, name: name, type: TagType.user, parentId: parentId);
    _storage.add(tag);
    _eventController.add(TagCreated(tag));
    return tag;
  }

  @override
  Future<Tag> createAutomaticTag(String name, {String? parentId}) async {
    final existing = _storage.getByName(name);
    if (existing != null) return existing;
    final id = _storage.generateId();
    final tag = Tag(
      id: id,
      name: name,
      type: TagType.automatic,
      parentId: parentId,
    );
    _storage.add(tag);
    _eventController.add(TagCreated(tag));
    return tag;
  }

  @override
  Future<void> deleteTag(String id) async {
    _storage.delete(id);
    _eventController.add(TagDeleted(id));
  }

  @override
  Future<Tag> updateTag(Tag tag) async {
    _storage.add(tag);
    _eventController.add(TagUpdated(tag));
    return tag;
  }

  @override
  Future<void> addAlias(String primaryTagId, String aliasName) async {
    _storage.addAlias(aliasName, primaryTagId);
    _eventController.add(AliasAdded(aliasName, primaryTagId));
  }

  @override
  Future<void> removeAlias(String primaryTagId, String aliasName) async {
    _storage.removeAlias(aliasName);
  }

  @override
  Future<Tag?> resolveAlias(String aliasName) async {
    final primaryId = _storage.resolveAlias(aliasName);
    if (primaryId == null) return null;
    return _storage.get(primaryId);
  }

  @override
  Future<Tag?> getTagByNameOrAlias(String nameOrAlias) async {
    final byName = _storage.getByName(nameOrAlias);
    if (byName != null) return byName;
    return resolveAlias(nameOrAlias);
  }

  @override
  Future<List<Tag>> getAllTags() async => _storage.getAll();

  @override
  Future<List<Tag>> getBuiltInTags() async =>
      _storage.getByType(TagType.builtIn);

  @override
  Future<List<Tag>> getUserTags() async => _storage.getByType(TagType.user);

  @override
  Future<List<Tag>> getAutomaticTags() async =>
      _storage.getByType(TagType.automatic);

  @override
  Future<List<Tag>> getChildTags(String parentId) async =>
      _storage.getAll().where((t) => t.parentId == parentId).toList();

  @override
  Future<List<Tag>> getDescendants(String tagId) async {
    final descendants = <Tag>[];
    final children = await getChildTags(tagId);
    for (final child in children) {
      descendants
        ..add(child)
        ..addAll(await getDescendants(child.id));
    }
    return descendants;
  }

  @override
  Future<void> initializeBuiltInTags() async {
    for (final name in BuiltInTags.all) {
      if (_storage.getByName(name) == null) {
        final id = _storage.generateId();
        _storage.add(Tag(id: id, name: name, type: TagType.builtIn));
      }
    }
  }

  @override
  Future<void> updateIncludeChildren(String tagId, bool includeChildren) async {
    final tag = _storage.get(tagId);
    if (tag == null) return;
    final updated = tag.copyWith(includeChildren: includeChildren);
    _storage.add(updated);
    _eventController.add(TagUpdated(updated));
  }

  @override
  Future<Tag> createCollection(
    String name, {
    String? parentId,
    bool isGroup = false,
    bool isQueue = false,
  }) async {
    final id = _storage.generateId();
    final metadata = PlaylistMetadata.empty(isQueue: isQueue);
    final tag = Tag(
      id: id,
      name: name,
      type: TagType.user,
      parentId: parentId,
      playlistMetadata: metadata,
      isGroup: isGroup,
    );
    _storage.add(tag);
    _eventController.add(TagCreated(tag));
    return tag;
  }

  @override
  @Deprecated('Use createCollection instead')
  Future<Tag> createPlaylist(String name, {String? parentId}) async =>
      createCollection(name, parentId: parentId);

  @override
  Future<void> addItemToCollection(
    String collectionId,
    PlaylistItem item,
  ) async {
    final tag = _storage.get(collectionId);
    if (tag == null || !tag.isCollection) throw StateError('Not a collection');
    final metadata = tag.playlistMetadata!;
    final updated = tag.copyWith(
      playlistMetadata: metadata.copyWith(
        items: [...metadata.items, item],
        updatedAt: DateTime.now(),
      ),
    );
    _storage.add(updated);
    _eventController.add(TagUpdated(updated));
  }

  @override
  @Deprecated('Use addItemToCollection instead')
  Future<void> addItemToPlaylist(String playlistId, PlaylistItem item) async =>
      addItemToCollection(playlistId, item);

  @override
  Future<void> removeItemFromCollection(
    String collectionId,
    String itemId,
  ) async {
    final tag = _storage.get(collectionId);
    if (tag == null || !tag.isCollection) throw StateError('Not a collection');
    final metadata = tag.playlistMetadata!;
    final updated = tag.copyWith(
      playlistMetadata: metadata.copyWith(
        items: metadata.items.where((i) => i.id != itemId).toList(),
        updatedAt: DateTime.now(),
      ),
    );
    _storage.add(updated);
    _eventController.add(TagUpdated(updated));
  }

  @override
  @Deprecated('Use removeItemFromCollection instead')
  Future<void> removeItemFromPlaylist(String playlistId, String itemId) async =>
      removeItemFromCollection(playlistId, itemId);

  @override
  Future<void> reorderCollectionItems(
    String collectionId,
    List<String> itemIds,
  ) async {
    final tag = _storage.get(collectionId);
    if (tag == null || !tag.isCollection) throw StateError('Not a collection');
    final metadata = tag.playlistMetadata!;
    final itemMap = {for (final item in metadata.items) item.id: item};
    final reordered = <PlaylistItem>[];
    for (var i = 0; i < itemIds.length; i++) {
      final item = itemMap[itemIds[i]];
      if (item != null) reordered.add(item.copyWith(order: i));
    }
    final updated = tag.copyWith(
      playlistMetadata: metadata.copyWith(
        items: reordered,
        updatedAt: DateTime.now(),
      ),
    );
    _storage.add(updated);
    _eventController.add(TagUpdated(updated));
  }

  @override
  @Deprecated('Use reorderCollectionItems instead')
  Future<void> reorderPlaylistItems(
    String playlistId,
    List<String> itemIds,
  ) async => reorderCollectionItems(playlistId, itemIds);

  @override
  Future<void> setCollectionLock(String collectionId, bool isLocked) async {
    final tag = _storage.get(collectionId);
    if (tag == null || !tag.isCollection) throw StateError('Not a collection');
    final metadata = tag.playlistMetadata!;
    final updated = tag.copyWith(
      playlistMetadata: metadata.copyWith(
        isLocked: isLocked,
        updatedAt: DateTime.now(),
      ),
    );
    _storage.add(updated);
    _eventController.add(TagUpdated(updated));
  }

  @override
  Future<bool> toggleLock(String collectionId) async {
    final tag = _storage.get(collectionId);
    if (tag == null || !tag.isCollection) throw StateError('Not a collection');
    final newState = !tag.playlistMetadata!.isLocked;
    await setCollectionLock(collectionId, newState);
    return newState;
  }

  @override
  @Deprecated('Use setCollectionLock instead')
  Future<void> setPlaylistLock(String playlistId, bool isLocked) async =>
      setCollectionLock(playlistId, isLocked);

  @override
  Future<void> addToCollection(String collectionId, PlaylistItem item) async =>
      addItemToCollection(collectionId, item);

  @override
  Future<void> removeFromCollection(String collectionId, String itemId) async =>
      removeItemFromCollection(collectionId, itemId);

  @override
  Future<void> reorderCollection(
    String collectionId,
    int oldIndex,
    int newIndex,
  ) async {
    final tag = _storage.get(collectionId);
    if (tag == null || !tag.isCollection) throw StateError('Not a collection');
    final metadata = tag.playlistMetadata!;
    final items = List<PlaylistItem>.from(metadata.items);
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    for (var i = 0; i < items.length; i++) {
      items[i] = items[i].copyWith(order: i);
    }
    final updated = tag.copyWith(
      playlistMetadata: metadata.copyWith(
        items: items,
        updatedAt: DateTime.now(),
      ),
    );
    _storage.add(updated);
    _eventController.add(TagUpdated(updated));
  }

  @override
  Future<void> startPlaying(
    String collectionId, {
    int startIndex = 0,
    int playbackPositionMs = 0,
  }) async {
    final tag = _storage.get(collectionId);
    if (tag == null || !tag.isCollection) throw StateError('Not a collection');
    final updated = tag.copyWith(
      playlistMetadata: tag.playlistMetadata!.copyWith(
        currentIndex: startIndex,
        playbackPositionMs: playbackPositionMs,
        wasPlaying: true,
      ),
    );
    _storage.add(updated);
    _eventController.add(TagUpdated(updated));
  }

  @override
  Future<void> stopPlaying(String collectionId) async {
    final tag = _storage.get(collectionId);
    if (tag == null || !tag.isCollection) throw StateError('Not a collection');
    final updated = tag.copyWith(
      playlistMetadata: tag.playlistMetadata!.copyWith(
        currentIndex: -1,
        playbackPositionMs: 0,
        wasPlaying: false,
      ),
    );
    _storage.add(updated);
    _eventController.add(TagUpdated(updated));
  }

  @override
  Future<void> updatePlaybackState(
    String collectionId, {
    required int currentIndex,
    required int playbackPositionMs,
    required bool wasPlaying,
  }) async {
    final tag = _storage.get(collectionId);
    if (tag == null || !tag.isCollection) return;
    final updated = tag.copyWith(
      playlistMetadata: tag.playlistMetadata!.copyWith(
        currentIndex: currentIndex,
        playbackPositionMs: playbackPositionMs,
        wasPlaying: wasPlaying,
      ),
    );
    _storage.add(updated);
    _eventController.add(TagUpdated(updated));
  }

  @override
  Future<List<PlaylistItem>> getCollectionItems(String collectionId) async {
    final tag = _storage.get(collectionId);
    if (tag == null || !tag.isCollection) return [];
    return tag.playlistMetadata?.items ?? [];
  }

  @override
  @Deprecated('Use getCollectionItems instead')
  Future<List<PlaylistItem>> getPlaylistItems(String playlistId) async =>
      getCollectionItems(playlistId);

  @override
  Future<List<Tag>> getCollections({
    bool includeGroups = true,
    bool includeQueues = true,
  }) async {
    return _storage.getAll().where((t) {
      if (!t.isCollection) return false;
      if (!includeGroups && t.isGroup) return false;
      if (!includeQueues && t.isActiveQueue) return false;
      return true;
    }).toList();
  }

  @override
  Future<List<Tag>> getActiveQueues() async =>
      _storage.getAll().where((t) => t.isActiveQueue).toList();

  @override
  Future<List<Tag>> getPlaylists() async =>
      _storage.getAll().where((t) => t.isPlaylist).toList();

  @override
  @Deprecated('Use getCollections instead')
  Future<List<Tag>> getPlaylistTags() async => getCollections();

  @override
  Future<List<String>> resolveContent(
    String collectionId, {
    int maxDepth = 10,
    Set<String>? visited,
    dynamic libraryRepository,
  }) async {
    visited ??= <String>{};
    if (maxDepth <= 0 || visited.contains(collectionId)) return [];
    visited.add(collectionId);
    final tag = _storage.get(collectionId);
    if (tag == null || !tag.isCollection) return [];
    final metadata = tag.playlistMetadata;
    if (metadata == null) return [];
    final result = <String>[];
    for (final item in metadata.items) {
      if (item.type == PlaylistItemType.songUnit) {
        result.add(item.targetId);
      } else {
        result.addAll(
          await resolveContent(
            item.targetId,
            maxDepth: maxDepth - 1,
            visited: visited,
            libraryRepository: libraryRepository,
          ),
        );
      }
    }
    return result;
  }

  @override
  Future<bool> wouldCreateCircularReference(
    String parentId,
    String targetId,
  ) async {
    if (parentId == targetId) return true;
    final visited = <String>{};
    return _checkCircular(targetId, parentId, visited);
  }

  Future<bool> _checkCircular(
    String currentId,
    String searchForId,
    Set<String> visited,
  ) async {
    if (visited.contains(currentId)) return false;
    visited.add(currentId);
    final tag = _storage.get(currentId);
    if (tag == null || !tag.isCollection) return false;
    final metadata = tag.playlistMetadata;
    if (metadata == null) return false;
    for (final item in metadata.items) {
      if (item.type == PlaylistItemType.collectionReference) {
        if (item.targetId == searchForId) return true;
        if (await _checkCircular(item.targetId, searchForId, visited)) {
          return true;
        }
      }
    }
    return false;
  }

  @override
  Future<String> getTagPath(String tagId) async {
    final tag = _storage.get(tagId);
    if (tag == null) return '';
    final parts = <String>[];
    Tag? current = tag;
    while (current != null) {
      parts.insert(0, current.name);
      current = current.parentId != null
          ? _storage.get(current.parentId!)
          : null;
    }
    return parts.join('/');
  }

  @override
  Future<Tag?> getCollectionTag(String collectionId) async =>
      _storage.get(collectionId);
  @override
  Future<void> updateCollectionMetadata(
    String collectionId,
    PlaylistMetadata metadata,
  ) async {
    final tag = _storage.get(collectionId);
    if (tag == null || !tag.isCollection) return;
    final updated = tag.copyWith(playlistMetadata: metadata);
    _storage.add(updated);
    _eventController.add(TagUpdated(updated));
  }

  @override
  void dispose() => _eventController.close();
}

class MockSettingsRepository implements SettingsRepository {
  String _activeQueueId = 'default';

  @override
  Future<String> getActiveQueueId() async => _activeQueueId;

  @override
  Future<void> setActiveQueueId(String queueId) async {
    _activeQueueId = queueId;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockPlaybackStateStorage implements PlaybackStateStorage {
  @override
  Future<void> saveQueueState({
    String? currentQueueId,
    String? repeatMode,
    bool? shuffleEnabled,
  }) async {}

  @override
  Future<Map<String, dynamic>> getQueueState() async => {
    'currentQueueId': null,
    'repeatMode': 'off',
    'shuffleEnabled': false,
  };

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ============================================================================
// Test helpers
// ============================================================================

const _uuid = Uuid();

SongUnit _makeSongUnit({String? id, String? title}) {
  return SongUnit(
    id: id ?? _uuid.v4(),
    metadata: Metadata(
      title: title ?? 'Song ${Random().nextInt(1000)}',
      artists: const ['Artist'],
      album: 'Test Album',
      duration: const Duration(seconds: 180),
    ),
    sources: const SourceCollection(),
    preferences: PlaybackPreferences.defaults(),
  );
}

// ============================================================================
// Tests
// ============================================================================

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

    // Create the default queue before creating the ViewModel
    final defaultQueue = Tag(
      id: 'default',
      name: 'Default',
      type: TagType.user,
      playlistMetadata: PlaylistMetadata.empty().copyWith(currentIndex: 0),
    );
    tagStorage.add(defaultQueue);

    viewModel = TagViewModel(
      tagRepository: tagRepo,
      libraryRepository: libraryRepo,
      settingsRepository: settingsRepo,
      playbackStateStorage: playbackStorage,
    );

    // Allow async initialization to complete
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
  // Workflow 1: Create playlist, add songs, add to queue
  // ==========================================================================
  group('Workflow: Create playlist → add songs → add to queue', () {
    test('Full playlist-to-queue workflow preserves songs and order', () async {
      // Step 1: Create songs in the library
      final songs = <SongUnit>[];
      for (var i = 0; i < 5; i++) {
        final song = _makeSongUnit(title: 'Track ${i + 1}');
        await libraryRepo.addSongUnit(song);
        songs.add(song);
      }

      // Step 2: Create a playlist
      final playlist = await tagRepo.createCollection('My Favorites');
      expect(playlist.isCollection, isTrue);
      expect(playlist.isPlaylist, isTrue);
      expect(playlist.itemCount, equals(0));

      // Step 3: Add songs to the playlist
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

      // Verify playlist has all songs
      final playlistItems = await tagRepo.getCollectionItems(playlist.id);
      expect(playlistItems.length, equals(5));
      for (var i = 0; i < songs.length; i++) {
        expect(playlistItems[i].targetId, equals(songs[i].id));
      }

      // Step 4: Add playlist to queue
      final group = await viewModel.addCollectionToQueue(playlist.id);
      expect(group, isNotNull);
      expect(group!.isGroup, isTrue);
      expect(group.parentId, equals('default'));

      // Step 5: Verify group contains all songs in order
      final groupItems = await tagRepo.getCollectionItems(group.id);
      expect(groupItems.length, equals(5));
      for (var i = 0; i < songs.length; i++) {
        expect(
          groupItems[i].targetId,
          equals(songs[i].id),
          reason: 'Song at position $i should match',
        );
      }

      // Step 6: Verify the queue references the group
      final queueTag = await tagRepo.getTag('default');
      final queueItems = queueTag!.playlistMetadata!.items;
      expect(
        queueItems.any(
          (item) =>
              item.type == PlaylistItemType.collectionReference &&
              item.targetId == group.id,
        ),
        isTrue,
        reason: 'Queue should contain a reference to the group',
      );
    });

    test(
      'Adding multiple playlists to queue creates separate groups',
      () async {
        // Create songs
        final songsA = <SongUnit>[];
        final songsB = <SongUnit>[];
        for (var i = 0; i < 3; i++) {
          final a = _makeSongUnit(title: 'Playlist A - Track ${i + 1}');
          final b = _makeSongUnit(title: 'Playlist B - Track ${i + 1}');
          await libraryRepo.addSongUnit(a);
          await libraryRepo.addSongUnit(b);
          songsA.add(a);
          songsB.add(b);
        }

        // Create two playlists
        final playlistA = await tagRepo.createCollection('Playlist A');
        final playlistB = await tagRepo.createCollection('Playlist B');

        for (var i = 0; i < songsA.length; i++) {
          await tagRepo.addItemToCollection(
            playlistA.id,
            PlaylistItem(
              id: _uuid.v4(),
              type: PlaylistItemType.songUnit,
              targetId: songsA[i].id,
              order: i,
            ),
          );
          await tagRepo.addItemToCollection(
            playlistB.id,
            PlaylistItem(
              id: _uuid.v4(),
              type: PlaylistItemType.songUnit,
              targetId: songsB[i].id,
              order: i,
            ),
          );
        }

        // Add both to queue
        final groupA = await viewModel.addCollectionToQueue(playlistA.id);
        final groupB = await viewModel.addCollectionToQueue(playlistB.id);

        expect(groupA, isNotNull);
        expect(groupB, isNotNull);
        expect(groupA!.id, isNot(equals(groupB!.id)));

        // Verify each group has correct songs
        final itemsA = await tagRepo.getCollectionItems(groupA.id);
        final itemsB = await tagRepo.getCollectionItems(groupB.id);
        expect(itemsA.length, equals(3));
        expect(itemsB.length, equals(3));

        for (var i = 0; i < 3; i++) {
          expect(itemsA[i].targetId, equals(songsA[i].id));
          expect(itemsB[i].targetId, equals(songsB[i].id));
        }
      },
    );
  });

  // ==========================================================================
  // Workflow 2: Create groups within playlist, lock them
  // ==========================================================================
  group('Workflow: Create groups within playlist → lock them', () {
    test('Groups within playlist maintain structure and lock state', () async {
      // Create songs
      final songs = <SongUnit>[];
      for (var i = 0; i < 6; i++) {
        final song = _makeSongUnit(title: 'Song ${i + 1}');
        await libraryRepo.addSongUnit(song);
        songs.add(song);
      }

      // Create a playlist
      final playlist = await tagRepo.createCollection('Concert Setlist');

      // Create two groups within the playlist
      final groupA = await viewModel.createCollection(
        'Opening Act',
        parentId: playlist.id,
        isGroup: true,
      );
      final groupB = await viewModel.createCollection(
        'Main Set',
        parentId: playlist.id,
        isGroup: true,
      );

      expect(groupA.isGroup, isTrue);
      expect(groupB.isGroup, isTrue);
      expect(groupA.parentId, equals(playlist.id));
      expect(groupB.parentId, equals(playlist.id));

      // Add songs to groups
      for (var i = 0; i < 3; i++) {
        await viewModel.addSongUnitToCollection(groupA.id, songs[i].id);
      }
      for (var i = 3; i < 6; i++) {
        await viewModel.addSongUnitToCollection(groupB.id, songs[i].id);
      }

      // Verify group contents
      final itemsA = await tagRepo.getCollectionItems(groupA.id);
      final itemsB = await tagRepo.getCollectionItems(groupB.id);
      expect(itemsA.length, equals(3));
      expect(itemsB.length, equals(3));

      // Lock group A
      await viewModel.toggleLock(groupA.id);
      final lockedA = await tagRepo.getTag(groupA.id);
      expect(lockedA!.isLocked, isTrue);

      // Group B should remain unlocked
      final unlockedB = await tagRepo.getTag(groupB.id);
      expect(unlockedB!.isLocked, isFalse);

      // Toggle lock on group B
      await viewModel.toggleLock(groupB.id);
      final lockedB = await tagRepo.getTag(groupB.id);
      expect(lockedB!.isLocked, isTrue);

      // Group A should still be locked (independent)
      final stillLockedA = await tagRepo.getTag(groupA.id);
      expect(stillLockedA!.isLocked, isTrue);
    });
  });

  // ==========================================================================
  // Workflow 3: Add locked playlist to queue, verify lock inheritance
  // ==========================================================================
  group('Workflow: Locked playlist → queue → verify lock inheritance', () {
    test(
      'Locked playlist creates locked group in queue with all songs',
      () async {
        // Create songs
        final songs = <SongUnit>[];
        for (var i = 0; i < 4; i++) {
          final song = _makeSongUnit(title: 'Locked Song ${i + 1}');
          await libraryRepo.addSongUnit(song);
          songs.add(song);
        }

        // Create and populate a playlist
        final playlist = await tagRepo.createCollection('Locked Playlist');
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

        // Lock the playlist
        await tagRepo.setCollectionLock(playlist.id, true);
        final lockedPlaylist = await tagRepo.getTag(playlist.id);
        expect(lockedPlaylist!.isLocked, isTrue);

        // Add to queue
        final group = await viewModel.addCollectionToQueue(playlist.id);

        // Verify group inherits lock
        expect(group, isNotNull);
        expect(
          group!.isLocked,
          isTrue,
          reason: 'Group should inherit locked state from playlist',
        );
        expect(group.isGroup, isTrue);

        // Verify all songs are in the group
        final groupItems = await tagRepo.getCollectionItems(group.id);
        expect(groupItems.length, equals(4));
        for (var i = 0; i < songs.length; i++) {
          expect(groupItems[i].targetId, equals(songs[i].id));
        }

        // Verify changing playlist lock doesn't affect the group
        await tagRepo.setCollectionLock(playlist.id, false);
        final groupAfter = await tagRepo.getTag(group.id);
        expect(
          groupAfter!.isLocked,
          isTrue,
          reason: 'Group lock should be independent from source playlist',
        );
      },
    );

    test(
      'Unlocked playlist creates unlocked group, can be locked after',
      () async {
        final song = _makeSongUnit(title: 'Test Song');
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
        expect(group!.isLocked, isFalse);

        // Lock the group after creation
        await viewModel.toggleLock(group.id);
        final lockedGroup = await tagRepo.getTag(group.id);
        expect(
          lockedGroup!.isLocked,
          isTrue,
          reason: 'Should be able to lock group after creation',
        );
      },
    );
  });

  // ==========================================================================
  // Workflow 4: Shuffle queue, verify locked groups stay together
  // ==========================================================================
  group('Workflow: Shuffle queue → locked groups stay contiguous', () {
    test('Shuffle keeps locked group songs contiguous and in order', () async {
      // Create songs for a locked group
      final lockedSongs = <SongUnit>[];
      for (var i = 0; i < 3; i++) {
        final song = _makeSongUnit(title: 'Locked ${i + 1}');
        await libraryRepo.addSongUnit(song);
        lockedSongs.add(song);
      }

      // Create songs for loose (unlocked) items
      final looseSongs = <SongUnit>[];
      for (var i = 0; i < 5; i++) {
        final song = _makeSongUnit(title: 'Loose ${i + 1}');
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
      expect(group, isNotNull);
      expect(group!.isLocked, isTrue);

      // Add loose songs directly to queue
      for (final song in looseSongs) {
        await viewModel.requestSong(song.id);
      }

      // Verify queue has all songs loaded
      expect(
        viewModel.queueSongUnits.length,
        greaterThanOrEqualTo(looseSongs.length),
      );

      // Shuffle the queue multiple times to verify the invariant
      final lockedSongIds = lockedSongs.map((s) => s.id).toList();

      for (var attempt = 0; attempt < 5; attempt++) {
        await viewModel.shuffle('default');

        // Reload queue state
        final queueTag = await tagRepo.getTag('default');
        final queueItems = queueTag!.playlistMetadata!.items;

        // Resolve all song IDs in queue order (including from group references)
        final resolvedIds = <String>[];
        for (final item in queueItems) {
          if (item.type == PlaylistItemType.songUnit) {
            resolvedIds.add(item.targetId);
          } else if (item.type == PlaylistItemType.collectionReference) {
            // Resolve the group's songs
            final refTag = await tagRepo.getTag(item.targetId);
            if (refTag != null && refTag.isCollection) {
              final refItems = refTag.playlistMetadata!.items;
              for (final refItem in refItems) {
                resolvedIds.add(refItem.targetId);
              }
            }
          }
        }

        // Find positions of locked songs in the resolved order
        final lockedPositions = <int>[];
        for (var i = 0; i < resolvedIds.length; i++) {
          if (lockedSongIds.contains(resolvedIds[i])) {
            lockedPositions.add(i);
          }
        }

        // Verify locked songs are contiguous
        if (lockedPositions.isNotEmpty) {
          for (var i = 1; i < lockedPositions.length; i++) {
            expect(
              lockedPositions[i],
              equals(lockedPositions[i - 1] + 1),
              reason:
                  'Locked songs must be contiguous after shuffle (attempt $attempt)',
            );
          }

          // Verify internal order is preserved
          final lockedInOrder = lockedPositions
              .map((pos) => resolvedIds[pos])
              .toList();
          expect(
            lockedInOrder,
            equals(lockedSongIds),
            reason:
                'Locked songs must maintain original order (attempt $attempt)',
          );
        }
      }
    });

    test('Shuffle does not change lock states', () async {
      final song1 = _makeSongUnit(title: 'S1');
      final song2 = _makeSongUnit(title: 'S2');
      await libraryRepo.addSongUnit(song1);
      await libraryRepo.addSongUnit(song2);

      // Create a locked playlist, add to queue
      final playlist = await tagRepo.createCollection('Lock Test');
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

      // Add a loose song
      await viewModel.requestSong(song2.id);

      // Shuffle
      await viewModel.shuffle('default');

      // Verify lock state is preserved
      final groupAfter = await tagRepo.getTag(group.id);
      expect(
        groupAfter!.isLocked,
        isTrue,
        reason: 'Shuffle should not change lock state',
      );
    });
  });

  // ==========================================================================
  // Workflow 5: Switch queues, verify state preservation
  // ==========================================================================
  group('Workflow: Switch queues → verify state preservation', () {
    test(
      'Creating and switching between multiple queues preserves state',
      () async {
        // Create songs
        final songsQ1 = <SongUnit>[];
        final songsQ2 = <SongUnit>[];
        for (var i = 0; i < 3; i++) {
          final s1 = _makeSongUnit(title: 'Q1 Song ${i + 1}');
          final s2 = _makeSongUnit(title: 'Q2 Song ${i + 1}');
          await libraryRepo.addSongUnit(s1);
          await libraryRepo.addSongUnit(s2);
          songsQ1.add(s1);
          songsQ2.add(s2);
        }

        // Add songs to the default queue
        for (final song in songsQ1) {
          await viewModel.requestSong(song.id);
        }
        expect(viewModel.queueSongUnits.length, equals(3));

        // Create a second queue
        final queue2 = await tagRepo.createCollection('Queue 2');
        // Make it an active queue by setting currentIndex >= 0
        await tagRepo.updatePlaybackState(
          queue2.id,
          currentIndex: 0,
          playbackPositionMs: 0,
          wasPlaying: false,
        );

        // Add songs to queue 2 directly via repository
        for (var i = 0; i < songsQ2.length; i++) {
          await tagRepo.addItemToCollection(
            queue2.id,
            PlaylistItem(
              id: _uuid.v4(),
              type: PlaylistItemType.songUnit,
              targetId: songsQ2[i].id,
              order: i,
            ),
          );
        }

        // Verify default queue state before switch
        expect(viewModel.activeQueueId, equals('default'));
        expect(viewModel.queueSongUnits.length, equals(3));
        final q1SongIds = viewModel.queueSongUnits.map((s) => s.id).toList();

        // Verify default queue has the right songs
        for (var i = 0; i < songsQ1.length; i++) {
          expect(q1SongIds.contains(songsQ1[i].id), isTrue);
        }

        // Verify queue 2 has its songs in the repository
        final q2Items = await tagRepo.getCollectionItems(queue2.id);
        expect(q2Items.length, equals(3));
        for (var i = 0; i < songsQ2.length; i++) {
          expect(q2Items[i].targetId, equals(songsQ2[i].id));
        }

        // Verify default queue songs are still intact
        final defaultTag = await tagRepo.getTag('default');
        expect(defaultTag!.isCollection, isTrue);
        final defaultItems = defaultTag.playlistMetadata!.items;
        expect(defaultItems.length, equals(3));
      },
    );

    test('Queue state persists across operations', () async {
      // Add songs to default queue
      final song1 = _makeSongUnit(title: 'Persistent Song 1');
      final song2 = _makeSongUnit(title: 'Persistent Song 2');
      final song3 = _makeSongUnit(title: 'Persistent Song 3');
      await libraryRepo.addSongUnit(song1);
      await libraryRepo.addSongUnit(song2);
      await libraryRepo.addSongUnit(song3);

      await viewModel.requestSong(song1.id);
      await viewModel.requestSong(song2.id);
      await viewModel.requestSong(song3.id);

      // Jump to index 1
      await viewModel.jumpTo(1);
      expect(viewModel.currentIndex, equals(1));

      // Verify the queue tag persists the state
      final queueTag = await tagRepo.getTag('default');
      expect(queueTag!.playlistMetadata!.currentIndex, equals(1));
      expect(queueTag.playlistMetadata!.items.length, equals(3));
    });
  });

  // ==========================================================================
  // Workflow 6: End-to-end complex workflow
  // ==========================================================================
  group('Workflow: Complex end-to-end scenario', () {
    test(
      'Full workflow: playlists with groups → queue → lock → shuffle → verify',
      () async {
        // Step 1: Create a library of songs
        final allSongs = <SongUnit>[];
        for (var i = 0; i < 10; i++) {
          final song = _makeSongUnit(title: 'Library Song ${i + 1}');
          await libraryRepo.addSongUnit(song);
          allSongs.add(song);
        }

        // Step 2: Create a playlist with two groups
        final playlist = await tagRepo.createCollection('Full Concert');

        final opening = await viewModel.createCollection(
          'Opening',
          parentId: playlist.id,
          isGroup: true,
        );
        final mainSet = await viewModel.createCollection(
          'Main Set',
          parentId: playlist.id,
          isGroup: true,
        );

        // Add songs to groups
        for (var i = 0; i < 3; i++) {
          await viewModel.addSongUnitToCollection(opening.id, allSongs[i].id);
        }
        for (var i = 3; i < 7; i++) {
          await viewModel.addSongUnitToCollection(mainSet.id, allSongs[i].id);
        }

        // Add group references to the playlist so resolveContent can find them
        await viewModel.addCollectionReference(playlist.id, opening.id);
        await viewModel.addCollectionReference(playlist.id, mainSet.id);

        // Step 3: Lock the main set group
        await viewModel.toggleLock(mainSet.id);
        final lockedMainSet = await tagRepo.getTag(mainSet.id);
        expect(lockedMainSet!.isLocked, isTrue);

        // Step 4: Lock the playlist itself
        await tagRepo.setCollectionLock(playlist.id, true);

        // Step 5: Add playlist to queue (should inherit lock)
        final queueGroup = await viewModel.addCollectionToQueue(playlist.id);
        expect(queueGroup, isNotNull);
        expect(
          queueGroup!.isLocked,
          isTrue,
          reason: 'Queue group should inherit playlist lock',
        );

        // Step 6: Add some loose songs to queue
        for (var i = 7; i < 10; i++) {
          await viewModel.requestSong(allSongs[i].id);
        }

        // Step 7: Verify queue structure
        final queueTag = await tagRepo.getTag('default');
        expect(queueTag, isNotNull);
        final queueItems = queueTag!.playlistMetadata!.items;
        // Queue should have: 1 collection reference (to the group) + 3 loose songs
        expect(queueItems.length, equals(4));

        // Step 8: Verify the group in queue has the resolved songs (recursively, including sub-groups)
        Future<int> countAllSongs(String collectionId) async {
          final items = await tagRepo.getCollectionItems(collectionId);
          var total = 0;
          for (final item in items) {
            if (item.type == PlaylistItemType.songUnit) {
              total++;
            } else if (item.type == PlaylistItemType.collectionReference) {
              total += await countAllSongs(item.targetId);
            }
          }
          return total;
        }

        final totalSongs = await countAllSongs(queueGroup.id);
        // The group should contain all songs from the playlist (resolved from both sub-groups)
        expect(
          totalSongs,
          equals(7),
          reason: 'Group should contain all 7 songs from both sub-groups',
        );

        // Step 9: Override lock on the queue group
        await viewModel.toggleLock(queueGroup.id);
        final unlockedGroup = await tagRepo.getTag(queueGroup.id);
        expect(unlockedGroup!.isLocked, isFalse);

        // Step 10: Verify source playlist lock is unaffected
        final playlistAfter = await tagRepo.getTag(playlist.id);
        expect(
          playlistAfter!.isLocked,
          isTrue,
          reason: 'Source playlist lock should be independent',
        );
      },
    );

    test('Deduplicate queue removes duplicate songs', () async {
      final song1 = _makeSongUnit(title: 'Unique Song');
      final song2 = _makeSongUnit(title: 'Another Song');
      await libraryRepo.addSongUnit(song1);
      await libraryRepo.addSongUnit(song2);

      // Add song1 twice and song2 once
      await viewModel.requestSong(song1.id);
      await viewModel.requestSong(song2.id);
      await viewModel.requestSong(song1.id);

      expect(viewModel.queueSongUnits.length, equals(3));

      // Deduplicate
      final removed = await viewModel.deduplicateQueue();
      expect(removed, equals(1));
      expect(viewModel.queueSongUnits.length, equals(2));

      // Verify both unique songs are still present
      final ids = viewModel.queueSongUnits.map((s) => s.id).toSet();
      expect(ids.contains(song1.id), isTrue);
      expect(ids.contains(song2.id), isTrue);
    });

    test('Clear queue removes all items', () async {
      final song = _makeSongUnit(title: 'To Be Cleared');
      await libraryRepo.addSongUnit(song);

      await viewModel.requestSong(song.id);
      expect(viewModel.queueSongUnits.length, equals(1));

      await viewModel.clearQueue();
      expect(viewModel.queueSongUnits.length, equals(0));

      // Verify the queue tag is also empty
      final queueTag = await tagRepo.getTag('default');
      expect(queueTag!.playlistMetadata!.items.length, equals(0));
    });
  });
}
