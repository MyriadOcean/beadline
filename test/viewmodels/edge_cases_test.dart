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
  // Empty Collections Edge Cases
  // Validates: Requirements 14.6, 15.3
  // ==========================================================================
  group('Empty Collections', () {
    test('Shuffling an empty collection does not crash', () async {
      final emptyCollection = await tagRepo.createCollection('Empty Playlist');

      // Should complete without error
      await viewModel.shuffle(emptyCollection.id);

      final items = await tagRepo.getCollectionItems(emptyCollection.id);
      expect(items, isEmpty);
    });

    test('Shuffling a single-item collection does not change it', () async {
      final song = _makeSongUnit(title: 'Only Song');
      await libraryRepo.addSongUnit(song);

      final collection = await tagRepo.createCollection('Single Item');
      await tagRepo.addItemToCollection(
        collection.id,
        PlaylistItem(
          id: _uuid.v4(),
          type: PlaylistItemType.songUnit,
          targetId: song.id,
          order: 0,
        ),
      );

      await viewModel.shuffle(collection.id);

      final items = await tagRepo.getCollectionItems(collection.id);
      expect(items.length, equals(1));
      expect(items[0].targetId, equals(song.id));
    });

    test('Deduplicating an empty collection returns 0', () async {
      final emptyCollection = await tagRepo.createCollection('Empty Dedup');

      final removed = await viewModel.deduplicate(emptyCollection.id);
      expect(removed, equals(0));
    });

    test('Deduplicating a single-item collection returns 0', () async {
      final song = _makeSongUnit(title: 'Unique Song');
      await libraryRepo.addSongUnit(song);

      final collection = await tagRepo.createCollection('Single Dedup');
      await tagRepo.addItemToCollection(
        collection.id,
        PlaylistItem(
          id: _uuid.v4(),
          type: PlaylistItemType.songUnit,
          targetId: song.id,
          order: 0,
        ),
      );

      final removed = await viewModel.deduplicate(collection.id);
      expect(removed, equals(0));
    });

    test('Clearing an already empty collection does not crash', () async {
      final emptyCollection = await tagRepo.createCollection('Empty Clear');

      await viewModel.clearCollection(emptyCollection.id);

      final tag = await tagRepo.getTag(emptyCollection.id);
      expect(tag!.isCollection, isTrue);
      expect(tag.playlistMetadata!.items, isEmpty);
    });

    test(
      'Resolving content of an empty collection returns empty list',
      () async {
        final emptyCollection = await tagRepo.createCollection('Empty Resolve');

        final content = await viewModel.resolveContent(emptyCollection.id);
        expect(content, isEmpty);
      },
    );

    test('Adding empty collection to queue returns null', () async {
      final emptyPlaylist = await tagRepo.createCollection('Empty Add');

      final group = await viewModel.addCollectionToQueue(emptyPlaylist.id);
      expect(
        group,
        isNull,
        reason: 'Should not create group for empty collection',
      );
    });
  });

  // ==========================================================================
  // Missing Song Units Edge Cases (Queue Restoration)
  // Validates: Requirements 14.6
  // ==========================================================================
  group('Missing Song Units', () {
    test('Resolving content skips missing song units gracefully', () async {
      final song1 = _makeSongUnit(id: 'existing_song', title: 'Existing');
      await libraryRepo.addSongUnit(song1);

      final collection = await tagRepo.createCollection('Has Missing');
      // Add an existing song unit
      await tagRepo.addItemToCollection(
        collection.id,
        PlaylistItem(
          id: _uuid.v4(),
          type: PlaylistItemType.songUnit,
          targetId: 'existing_song',
          order: 0,
        ),
      );
      // Add a reference to a song unit that doesn't exist
      await tagRepo.addItemToCollection(
        collection.id,
        PlaylistItem(
          id: _uuid.v4(),
          type: PlaylistItemType.songUnit,
          targetId: 'deleted_song_id',
          order: 1,
        ),
      );
      // Add another existing song unit
      await tagRepo.addItemToCollection(
        collection.id,
        PlaylistItem(
          id: _uuid.v4(),
          type: PlaylistItemType.songUnit,
          targetId: 'existing_song',
          order: 2,
        ),
      );

      final content = await viewModel.resolveContent(collection.id);
      // Should only return the existing song units, skipping the missing one
      expect(content.length, equals(2));
      expect(content[0].id, equals('existing_song'));
      expect(content[1].id, equals('existing_song'));
    });

    test('Queue loads gracefully when all song units are missing', () async {
      // Add items to the active queue that reference non-existent song units
      final activeQueue = await tagRepo.getTag('default');
      expect(activeQueue, isNotNull);

      await tagRepo.addItemToCollection(
        'default',
        PlaylistItem(
          id: _uuid.v4(),
          type: PlaylistItemType.songUnit,
          targetId: 'nonexistent_1',
          order: 0,
        ),
      );
      await tagRepo.addItemToCollection(
        'default',
        PlaylistItem(
          id: _uuid.v4(),
          type: PlaylistItemType.songUnit,
          targetId: 'nonexistent_2',
          order: 1,
        ),
      );

      // Resolve content should return empty (all missing)
      final content = await viewModel.resolveContent('default');
      expect(content, isEmpty);
    });

    test(
      'Adding collection with some missing songs to queue only includes existing ones',
      () async {
        final song1 = _makeSongUnit(id: 'real_song_1', title: 'Real Song 1');
        final song2 = _makeSongUnit(id: 'real_song_2', title: 'Real Song 2');
        await libraryRepo.addSongUnit(song1);
        await libraryRepo.addSongUnit(song2);

        // Create a playlist with mix of existing and missing songs
        final playlist = await tagRepo.createCollection('Mixed Playlist');
        await tagRepo.addItemToCollection(
          playlist.id,
          PlaylistItem(
            id: _uuid.v4(),
            type: PlaylistItemType.songUnit,
            targetId: 'real_song_1',
            order: 0,
          ),
        );
        await tagRepo.addItemToCollection(
          playlist.id,
          PlaylistItem(
            id: _uuid.v4(),
            type: PlaylistItemType.songUnit,
            targetId: 'ghost_song',
            order: 1,
          ),
        );
        await tagRepo.addItemToCollection(
          playlist.id,
          PlaylistItem(
            id: _uuid.v4(),
            type: PlaylistItemType.songUnit,
            targetId: 'real_song_2',
            order: 2,
          ),
        );

        // Add to queue - resolveContent is called internally
        final group = await viewModel.addCollectionToQueue(playlist.id);
        expect(group, isNotNull);

        // The group should contain only the 2 existing songs
        final groupItems = await tagRepo.getCollectionItems(group!.id);
        expect(groupItems.length, equals(2));
        expect(groupItems[0].targetId, equals('real_song_1'));
        expect(groupItems[1].targetId, equals('real_song_2'));
      },
    );

    test(
      'Resolving content with missing referenced collection returns partial results',
      () async {
        final song1 = _makeSongUnit(id: 'song_a', title: 'Song A');
        await libraryRepo.addSongUnit(song1);

        final collection = await tagRepo.createCollection('Has Missing Ref');
        await tagRepo.addItemToCollection(
          collection.id,
          PlaylistItem(
            id: _uuid.v4(),
            type: PlaylistItemType.songUnit,
            targetId: 'song_a',
            order: 0,
          ),
        );
        // Reference to a collection that doesn't exist
        await tagRepo.addItemToCollection(
          collection.id,
          PlaylistItem(
            id: _uuid.v4(),
            type: PlaylistItemType.collectionReference,
            targetId: 'nonexistent_collection',
            order: 1,
          ),
        );

        final content = await viewModel.resolveContent(collection.id);
        // Should return the existing song, skip the missing reference
        expect(content.length, equals(1));
        expect(content[0].id, equals('song_a'));
      },
    );
  });

  // ==========================================================================
  // Maximum Nesting Depth Edge Cases
  // Validates: Requirements 15.4, 15.5
  // ==========================================================================
  group('Maximum Nesting Depth', () {
    test(
      'Resolving stops at depth 10 and returns empty for deeper content',
      () async {
        final deepSong = _makeSongUnit(id: 'deep_song', title: 'Deep Song');
        await libraryRepo.addSongUnit(deepSong);

        // Create a chain of 12 collections, each referencing the next
        // Level 11 has the song, but depth limit is 10 so it should not be reached
        final collectionIds = <String>[];
        for (var i = 0; i < 12; i++) {
          final c = await tagRepo.createCollection('Level $i');
          collectionIds.add(c.id);
        }

        // Add the song to the deepest collection (level 11)
        await tagRepo.addItemToCollection(
          collectionIds[11],
          PlaylistItem(
            id: _uuid.v4(),
            type: PlaylistItemType.songUnit,
            targetId: 'deep_song',
            order: 0,
          ),
        );

        // Chain references: level 0 -> level 1 -> ... -> level 11
        for (var i = 0; i < 11; i++) {
          await tagRepo.addItemToCollection(
            collectionIds[i],
            PlaylistItem(
              id: _uuid.v4(),
              type: PlaylistItemType.collectionReference,
              targetId: collectionIds[i + 1],
              order: 0,
            ),
          );
        }

        // Resolve from level 0 - should NOT reach the song at level 11
        final content = await viewModel.resolveContent(collectionIds[0]);
        expect(
          content,
          isEmpty,
          reason: 'Song at depth 12 should not be reachable with max depth 10',
        );
      },
    );

    test('Content at exactly depth 10 is reachable', () async {
      final reachableSong = _makeSongUnit(id: 'reachable', title: 'Reachable');
      await libraryRepo.addSongUnit(reachableSong);

      // Create a chain of 10 collections (depth 0-9)
      // Level 9 has the song, which is at depth 10 from level 0
      final collectionIds = <String>[];
      for (var i = 0; i < 10; i++) {
        final c = await tagRepo.createCollection('Depth $i');
        collectionIds.add(c.id);
      }

      // Add the song to level 9
      await tagRepo.addItemToCollection(
        collectionIds[9],
        PlaylistItem(
          id: _uuid.v4(),
          type: PlaylistItemType.songUnit,
          targetId: 'reachable',
          order: 0,
        ),
      );

      // Chain references: level 0 -> level 1 -> ... -> level 9
      for (var i = 0; i < 9; i++) {
        await tagRepo.addItemToCollection(
          collectionIds[i],
          PlaylistItem(
            id: _uuid.v4(),
            type: PlaylistItemType.collectionReference,
            targetId: collectionIds[i + 1],
            order: 0,
          ),
        );
      }

      // Resolve from level 0 - the song at level 9 should be reachable
      // (depth 0 resolves level 0, depth 1 resolves level 1, ..., depth 9 resolves level 9)
      final content = await viewModel.resolveContent(collectionIds[0]);
      expect(
        content.length,
        equals(1),
        reason: 'Song at depth 10 should be reachable',
      );
      expect(content[0].id, equals('reachable'));
    });

    test(
      'Mixed content with deep nesting returns only reachable songs',
      () async {
        final shallowSong = _makeSongUnit(id: 'shallow', title: 'Shallow');
        final deepSong = _makeSongUnit(id: 'deep', title: 'Deep');
        await libraryRepo.addSongUnit(shallowSong);
        await libraryRepo.addSongUnit(deepSong);

        // Create root collection with a direct song and a deep reference chain
        final root = await tagRepo.createCollection('Root');
        await tagRepo.addItemToCollection(
          root.id,
          PlaylistItem(
            id: _uuid.v4(),
            type: PlaylistItemType.songUnit,
            targetId: 'shallow',
            order: 0,
          ),
        );

        // Create deep chain (12 levels)
        final deepIds = <String>[];
        for (var i = 0; i < 12; i++) {
          final c = await tagRepo.createCollection('Deep $i');
          deepIds.add(c.id);
        }

        await tagRepo.addItemToCollection(
          deepIds[11],
          PlaylistItem(
            id: _uuid.v4(),
            type: PlaylistItemType.songUnit,
            targetId: 'deep',
            order: 0,
          ),
        );

        for (var i = 0; i < 11; i++) {
          await tagRepo.addItemToCollection(
            deepIds[i],
            PlaylistItem(
              id: _uuid.v4(),
              type: PlaylistItemType.collectionReference,
              targetId: deepIds[i + 1],
              order: 0,
            ),
          );
        }

        // Add deep chain reference to root
        await tagRepo.addItemToCollection(
          root.id,
          PlaylistItem(
            id: _uuid.v4(),
            type: PlaylistItemType.collectionReference,
            targetId: deepIds[0],
            order: 1,
          ),
        );

        final content = await viewModel.resolveContent(root.id);
        // Should get the shallow song but not the deep one
        expect(content.length, equals(1));
        expect(content[0].id, equals('shallow'));
      },
    );
  });

  // ==========================================================================
  // Circular Reference Attempts
  // Validates: Requirements 15.3
  // ==========================================================================
  group('Circular Reference Prevention', () {
    test('Self-reference is detected and rejected', () async {
      final collection = await tagRepo.createCollection('Self Ref');

      final isCircular = await viewModel.wouldCreateCircularReference(
        collection.id,
        collection.id,
      );
      expect(isCircular, isTrue);
    });

    test('Direct circular reference (A -> B -> A) is detected', () async {
      final collA = await tagRepo.createCollection('Collection A');
      final collB = await tagRepo.createCollection('Collection B');

      // A references B
      await tagRepo.addItemToCollection(
        collA.id,
        PlaylistItem(
          id: _uuid.v4(),
          type: PlaylistItemType.collectionReference,
          targetId: collB.id,
          order: 0,
        ),
      );

      // Check if B -> A would be circular
      final isCircular = await viewModel.wouldCreateCircularReference(
        collB.id,
        collA.id,
      );
      expect(isCircular, isTrue);
    });

    test(
      'Indirect circular reference (A -> B -> C -> A) is detected',
      () async {
        final collA = await tagRepo.createCollection('A');
        final collB = await tagRepo.createCollection('B');
        final collC = await tagRepo.createCollection('C');

        // A -> B
        await tagRepo.addItemToCollection(
          collA.id,
          PlaylistItem(
            id: _uuid.v4(),
            type: PlaylistItemType.collectionReference,
            targetId: collB.id,
            order: 0,
          ),
        );

        // B -> C
        await tagRepo.addItemToCollection(
          collB.id,
          PlaylistItem(
            id: _uuid.v4(),
            type: PlaylistItemType.collectionReference,
            targetId: collC.id,
            order: 0,
          ),
        );

        // Check if C -> A would be circular
        final isCircular = await viewModel.wouldCreateCircularReference(
          collC.id,
          collA.id,
        );
        expect(isCircular, isTrue);
      },
    );

    test('Non-circular reference is allowed', () async {
      final collA = await tagRepo.createCollection('X');
      final collB = await tagRepo.createCollection('Y');
      final collC = await tagRepo.createCollection('Z');

      // A -> B
      await tagRepo.addItemToCollection(
        collA.id,
        PlaylistItem(
          id: _uuid.v4(),
          type: PlaylistItemType.collectionReference,
          targetId: collB.id,
          order: 0,
        ),
      );

      // C -> B is fine (no cycle)
      final isCircular = await viewModel.wouldCreateCircularReference(
        collC.id,
        collB.id,
      );
      expect(isCircular, isFalse);
    });

    test(
      'addCollectionReference rejects circular reference via error',
      () async {
        final collA = await tagRepo.createCollection('Ref A');
        final collB = await tagRepo.createCollection('Ref B');

        // A references B
        await viewModel.addCollectionReference(collA.id, collB.id);

        // Try to make B reference A (circular) - should set error
        await viewModel.addCollectionReference(collB.id, collA.id);

        // The error should be set
        expect(viewModel.error, isNotNull);
        expect(viewModel.error, contains('circular reference'));

        // B should NOT have a reference to A
        final bItems = await tagRepo.getCollectionItems(collB.id);
        final hasRefToA = bItems.any(
          (item) =>
              item.type == PlaylistItemType.collectionReference &&
              item.targetId == collA.id,
        );
        expect(
          hasRefToA,
          isFalse,
          reason: 'Circular reference should have been rejected',
        );
      },
    );

    test('Resolving circular references does not hang', () async {
      final collA = await tagRepo.createCollection('Loop A');
      final collB = await tagRepo.createCollection('Loop B');

      // Manually create circular reference (bypassing the check)
      await tagRepo.addItemToCollection(
        collA.id,
        PlaylistItem(
          id: _uuid.v4(),
          type: PlaylistItemType.collectionReference,
          targetId: collB.id,
          order: 0,
        ),
      );
      await tagRepo.addItemToCollection(
        collB.id,
        PlaylistItem(
          id: _uuid.v4(),
          type: PlaylistItemType.collectionReference,
          targetId: collA.id,
          order: 0,
        ),
      );

      // resolveContent should handle this gracefully (not hang)
      final content = await viewModel.resolveContent(collA.id);
      expect(
        content,
        isEmpty,
        reason:
            'Circular reference should result in empty content, not infinite loop',
      );
    });
  });

  // ==========================================================================
  // Operations on non-existent collections
  // Validates: Requirements 15.3
  // ==========================================================================
  group('Non-existent Collection Operations', () {
    test('Shuffling a non-existent collection sets error', () async {
      await viewModel.shuffle('nonexistent_id');
      expect(viewModel.error, isNotNull);
    });

    test('Deduplicating a non-existent collection returns 0', () async {
      final removed = await viewModel.deduplicate('nonexistent_id');
      expect(removed, equals(0));
    });

    test('Clearing a non-existent collection sets error', () async {
      await viewModel.clearCollection('nonexistent_id');
      expect(viewModel.error, isNotNull);
    });

    test(
      'Resolving content of non-existent collection returns empty',
      () async {
        final content = await viewModel.resolveContent('nonexistent_id');
        expect(content, isEmpty);
      },
    );

    test('Adding non-existent collection to queue returns null', () async {
      final group = await viewModel.addCollectionToQueue('nonexistent_id');
      expect(group, isNull);
    });

    test('Toggling lock on non-existent collection sets error', () async {
      await viewModel.toggleLock('nonexistent_id');
      expect(viewModel.error, isNotNull);
    });
  });
}
