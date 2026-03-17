/// Task 4.2: Property tests for shuffle with locks
///
/// Properties tested:
/// - Property 21: Locked Collection Shuffle Integrity
/// - Property 22: Unlocked Song Unit Shuffle
/// - Property 26: Locked Group Position Randomization
/// - Property 27: Shuffle Preserves Lock State
///
/// **Validates: Requirements 7.4, 7.5, 12.1, 12.2, 12.3, 12.4, 12.6**
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
// Test generators
// ============================================================================

class ShuffleTestGenerators {
  static final Random _random = Random();
  static const Uuid _uuid = Uuid();

  static String id() => _uuid.v4();

  static int randomInt(int min, int max) =>
      min + _random.nextInt(max - min + 1);

  static SongUnit makeSongUnit({String? title}) {
    return SongUnit(
      id: _uuid.v4(),
      metadata: Metadata(
        title: title ?? 'Song_${_random.nextInt(10000)}',
        artists: const ['Artist'],
        album: 'Album',
        duration: Duration(seconds: 60 + _random.nextInt(240)),
      ),
      sources: const SourceCollection(),
      preferences: PlaybackPreferences.defaults(),
    );
  }
}

// ============================================================================
// In-memory storage helpers
// ============================================================================

class InMemorySongUnitStorage {
  final Map<String, SongUnit> _songUnits = {};
  void add(SongUnit su) => _songUnits[su.id] = su;
  void update(SongUnit su) => _songUnits[su.id] = su;
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
  Future<void> addSongUnit(SongUnit su) async {
    _storage.add(su);
    _eventController.add(SongUnitAdded(su));
  }

  @override
  Future<void> updateSongUnit(SongUnit su) async {
    _storage.update(su);
    _eventController.add(SongUnitUpdated(su));
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
  }) async => throw UnimplementedError();

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
  Future<void> removeItemFromPlaylist(String playlistId, String itemId) async =>
      removeItemFromCollection(playlistId, itemId);
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
  Future<List<Tag>> getPlaylistTags() async => getCollections();
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
  Future<void> reorderPlaylistItems(
    String playlistId,
    List<String> itemIds,
  ) async => reorderCollectionItems(playlistId, itemIds);
  @override
  Future<void> addToCollection(String collectionId, PlaylistItem item) async =>
      addItemToCollection(collectionId, item);
  @override
  Future<void> removeFromCollection(String collectionId, String itemId) async =>
      removeItemFromCollection(collectionId, itemId);
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
  @Deprecated('Use createCollection instead')
  Future<Tag> createPlaylist(String name, {String? parentId}) async =>
      createCollection(name, parentId: parentId);
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
  Future<void> setActiveQueueId(String queueId) async =>
      _activeQueueId = queueId;
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
// Test context helper
// ============================================================================

class ShuffleTestContext {
  ShuffleTestContext() {
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

  static const Uuid _uuid = Uuid();

  /// Create a locked group in the default queue with the given songs.
  /// Returns the group tag ID.
  Future<String> createLockedGroupInQueue(List<SongUnit> songs) async {
    // Create a source playlist with the songs
    final playlist = await tagRepo.createCollection(
      'LockedPL_${_uuid.v4().substring(0, 8)}',
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
    await tagRepo.setCollectionLock(playlist.id, true);

    // Add to queue via addCollectionToQueue (creates a locked group)
    final group = await viewModel.addCollectionToQueue(playlist.id);
    return group!.id;
  }

  /// Create an unlocked group in the default queue with the given songs.
  /// Returns the group tag ID.
  Future<String> createUnlockedGroupInQueue(List<SongUnit> songs) async {
    final playlist = await tagRepo.createCollection(
      'UnlockedPL_${_uuid.v4().substring(0, 8)}',
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
    // Don't lock it

    final group = await viewModel.addCollectionToQueue(playlist.id);
    return group!.id;
  }

  /// Add a loose (ungrouped) song directly to the queue.
  Future<void> addLooseSong(SongUnit song) async {
    await viewModel.requestSong(song.id);
  }

  /// Create and register a list of song units in the library.
  Future<List<SongUnit>> createSongs(
    int count, {
    String prefix = 'Song',
  }) async {
    final songs = <SongUnit>[];
    for (var i = 0; i < count; i++) {
      final song = ShuffleTestGenerators.makeSongUnit(title: '${prefix}_$i');
      await libraryRepo.addSongUnit(song);
      songs.add(song);
    }
    return songs;
  }

  /// Resolve the queue items into a flat list of song unit IDs,
  /// expanding collection references into their constituent songs.
  Future<List<String>> resolveQueueSongIds() async {
    final queueTag = await tagRepo.getTag('default');
    if (queueTag == null || queueTag.playlistMetadata == null) return [];
    final items = queueTag.playlistMetadata!.items;
    final result = <String>[];
    for (final item in items) {
      if (item.type == PlaylistItemType.songUnit) {
        result.add(item.targetId);
      } else if (item.type == PlaylistItemType.collectionReference) {
        final refTag = await tagRepo.getTag(item.targetId);
        if (refTag != null && refTag.isCollection) {
          for (final refItem in refTag.playlistMetadata!.items) {
            if (refItem.type == PlaylistItemType.songUnit) {
              result.add(refItem.targetId);
            }
          }
        }
      }
    }
    return result;
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
  group('Shuffle with Locks Property Tests (Task 4.2)', () {
    // ========================================================================
    // Feature: queue-playlist-system, Property 21: Locked Collection Shuffle Integrity
    // **Validates: Requirements 7.4, 7.8, 12.2, 12.5**
    //
    // For any queue containing locked collections, shuffling should keep all
    // song units within each locked collection contiguous and in their
    // original order.
    // ========================================================================
    test(
      'Property 21: Locked Collection Shuffle Integrity - '
      'locked groups remain contiguous and in original order after shuffle',
      () async {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          final ctx = ShuffleTestContext();
          await Future.delayed(const Duration(milliseconds: 10));

          // Create a locked group with 2-5 songs
          final lockedCount = ShuffleTestGenerators.randomInt(2, 5);
          final lockedSongs = await ctx.createSongs(
            lockedCount,
            prefix: 'Locked',
          );
          final lockedSongIds = lockedSongs.map((s) => s.id).toList();
          await ctx.createLockedGroupInQueue(lockedSongs);

          // Add 3-6 loose songs
          final looseCount = ShuffleTestGenerators.randomInt(3, 6);
          final looseSongs = await ctx.createSongs(looseCount, prefix: 'Loose');
          for (final song in looseSongs) {
            await ctx.addLooseSong(song);
          }

          // Shuffle
          await ctx.viewModel.shuffle('default');

          // Resolve the queue and find locked song positions
          final resolvedIds = await ctx.resolveQueueSongIds();

          final lockedPositions = <int>[];
          for (var j = 0; j < resolvedIds.length; j++) {
            if (lockedSongIds.contains(resolvedIds[j])) {
              lockedPositions.add(j);
            }
          }

          // Verify all locked songs are present
          expect(
            lockedPositions.length,
            equals(lockedCount),
            reason: 'Iteration $i: all locked songs should be present',
          );

          // Verify contiguity
          for (var j = 1; j < lockedPositions.length; j++) {
            expect(
              lockedPositions[j],
              equals(lockedPositions[j - 1] + 1),
              reason: 'Iteration $i: locked songs must be contiguous',
            );
          }

          // Verify original order within the locked group
          final lockedInQueue = lockedPositions
              .map((pos) => resolvedIds[pos])
              .toList();
          expect(
            lockedInQueue,
            equals(lockedSongIds),
            reason: 'Iteration $i: locked songs must maintain original order',
          );

          ctx.dispose();
        }
      },
    );

    // ========================================================================
    // Feature: queue-playlist-system, Property 22: Unlocked Song Unit Shuffle
    // **Validates: Requirements 7.5, 12.3**
    //
    // For any queue with unlocked song units, shuffling should randomize
    // their positions. Since shuffle is random, we verify that across
    // multiple shuffles at least one produces a different order, and that
    // the set of items is always preserved.
    // ========================================================================
    test('Property 22: Unlocked Song Unit Shuffle - '
        'unlocked songs are randomized and set is preserved', () async {
      const iterations = 100;

      for (var i = 0; i < iterations; i++) {
        final ctx = ShuffleTestContext();
        await Future.delayed(const Duration(milliseconds: 10));

        // Create 5-8 loose songs (no locked groups)
        final songCount = ShuffleTestGenerators.randomInt(5, 8);
        final songs = await ctx.createSongs(songCount, prefix: 'Unlocked');
        final originalIds = songs.map((s) => s.id).toSet();

        for (final song in songs) {
          await ctx.addLooseSong(song);
        }

        // Get original order
        final originalOrder = await ctx.resolveQueueSongIds();

        // Shuffle multiple times and check:
        // 1. Set is always preserved
        // 2. At least one shuffle produces a different order
        var foundDifferentOrder = false;

        for (var attempt = 0; attempt < 10; attempt++) {
          await ctx.viewModel.shuffle('default');
          final shuffledIds = await ctx.resolveQueueSongIds();

          // Set must be preserved
          expect(
            shuffledIds.toSet(),
            equals(originalIds),
            reason:
                'Iteration $i, attempt $attempt: set of songs must be preserved',
          );

          // Check if order changed
          if (!_listEquals(shuffledIds, originalOrder)) {
            foundDifferentOrder = true;
          }
        }

        // With 5+ items and 10 attempts, the probability of never changing
        // order is astronomically low (1/n!)^10
        expect(
          foundDifferentOrder,
          isTrue,
          reason:
              'Iteration $i: shuffle should produce a different order '
              'at least once across 10 attempts with $songCount songs',
        );

        ctx.dispose();
      }
    });

    // ========================================================================
    // Feature: queue-playlist-system, Property 26: Locked Group Position Randomization
    // **Validates: Requirements 12.4**
    //
    // For any queue with multiple locked groups, shuffling should randomize
    // the positions of the groups as units. We verify that across multiple
    // shuffles, the relative positions of locked groups change at least once.
    // ========================================================================
    test('Property 26: Locked Group Position Randomization - '
        'locked groups are repositioned as units during shuffle', () async {
      const iterations = 100;

      for (var i = 0; i < iterations; i++) {
        final ctx = ShuffleTestContext();
        await Future.delayed(const Duration(milliseconds: 10));

        // Create 2-3 locked groups with 2-3 songs each
        final groupCount = ShuffleTestGenerators.randomInt(2, 3);
        final groupSongIds = <List<String>>[];

        for (var g = 0; g < groupCount; g++) {
          final count = ShuffleTestGenerators.randomInt(2, 3);
          final songs = await ctx.createSongs(count, prefix: 'Group$g');
          groupSongIds.add(songs.map((s) => s.id).toList());
          await ctx.createLockedGroupInQueue(songs);
        }

        // Add 3-5 loose songs to give room for position changes
        final looseSongs = await ctx.createSongs(
          ShuffleTestGenerators.randomInt(3, 5),
          prefix: 'Loose',
        );
        for (final song in looseSongs) {
          await ctx.addLooseSong(song);
        }

        // Record initial group start positions
        final initialIds = await ctx.resolveQueueSongIds();
        final initialGroupStarts = <int>[];
        for (final gIds in groupSongIds) {
          final startPos = initialIds.indexOf(gIds.first);
          initialGroupStarts.add(startPos);
        }

        // Shuffle multiple times and check if group positions change
        var foundDifferentPositions = false;

        for (var attempt = 0; attempt < 15; attempt++) {
          await ctx.viewModel.shuffle('default');
          final shuffledIds = await ctx.resolveQueueSongIds();

          final currentGroupStarts = <int>[];
          for (final gIds in groupSongIds) {
            final startPos = shuffledIds.indexOf(gIds.first);
            currentGroupStarts.add(startPos);
          }

          if (!_listEquals(
            currentGroupStarts.map((e) => e.toString()).toList(),
            initialGroupStarts.map((e) => e.toString()).toList(),
          )) {
            foundDifferentPositions = true;
            break;
          }
        }

        expect(
          foundDifferentPositions,
          isTrue,
          reason:
              'Iteration $i: locked group positions should change '
              'at least once across 15 shuffle attempts',
        );

        ctx.dispose();
      }
    });

    // ========================================================================
    // Feature: queue-playlist-system, Property 27: Shuffle Preserves Lock State
    // **Validates: Requirements 12.6**
    //
    // For any queue with locked and unlocked collections, shuffling should
    // not change any lock states.
    // ========================================================================
    test('Property 27: Shuffle Preserves Lock State - '
        'lock states are unchanged after shuffle', () async {
      const iterations = 100;

      for (var i = 0; i < iterations; i++) {
        final ctx = ShuffleTestContext();
        await Future.delayed(const Duration(milliseconds: 10));

        // Create a mix of locked and unlocked groups
        final lockedGroupIds = <String>[];
        final unlockedGroupIds = <String>[];

        // 1-2 locked groups
        final lockedCount = ShuffleTestGenerators.randomInt(1, 2);
        for (var g = 0; g < lockedCount; g++) {
          final songs = await ctx.createSongs(
            ShuffleTestGenerators.randomInt(2, 3),
            prefix: 'Locked$g',
          );
          final groupId = await ctx.createLockedGroupInQueue(songs);
          lockedGroupIds.add(groupId);
        }

        // 1-2 unlocked groups
        final unlockedCount = ShuffleTestGenerators.randomInt(1, 2);
        for (var g = 0; g < unlockedCount; g++) {
          final songs = await ctx.createSongs(
            ShuffleTestGenerators.randomInt(2, 3),
            prefix: 'Unlocked$g',
          );
          final groupId = await ctx.createUnlockedGroupInQueue(songs);
          unlockedGroupIds.add(groupId);
        }

        // Add some loose songs
        final looseSongs = await ctx.createSongs(
          ShuffleTestGenerators.randomInt(2, 4),
          prefix: 'Loose',
        );
        for (final song in looseSongs) {
          await ctx.addLooseSong(song);
        }

        // Record lock states before shuffle
        final lockStatesBefore = <String, bool>{};
        for (final gId in [...lockedGroupIds, ...unlockedGroupIds]) {
          final tag = await ctx.tagRepo.getTag(gId);
          lockStatesBefore[gId] = tag!.isLocked;
        }

        // Shuffle multiple times
        for (var attempt = 0; attempt < 5; attempt++) {
          await ctx.viewModel.shuffle('default');

          // Verify lock states are unchanged
          for (final gId in [...lockedGroupIds, ...unlockedGroupIds]) {
            final tag = await ctx.tagRepo.getTag(gId);
            expect(
              tag!.isLocked,
              equals(lockStatesBefore[gId]),
              reason:
                  'Iteration $i, attempt $attempt: '
                  'lock state of group $gId should not change after shuffle',
            );
          }
        }

        ctx.dispose();
      }
    });
  });
}

/// Helper to compare two lists for equality.
bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
