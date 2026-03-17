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
// In-memory storage helpers
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

  // Stub out remaining SettingsRepository methods
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

  group('Task 4.5: Lock Inheritance', () {
    // ========================================================================
    // Requirement 8.2: Locked playlist → locked group in queue
    // ========================================================================
    test(
      'Req 8.2: Adding a locked playlist to queue creates a locked group',
      () async {
        // Create songs
        final song1 = _makeSongUnit(title: 'Song A');
        final song2 = _makeSongUnit(title: 'Song B');
        await libraryRepo.addSongUnit(song1);
        await libraryRepo.addSongUnit(song2);

        // Create a playlist and add songs
        final playlist = await tagRepo.createCollection('My Playlist');
        await tagRepo.addItemToCollection(
          playlist.id,
          PlaylistItem(
            id: _uuid.v4(),
            type: PlaylistItemType.songUnit,
            targetId: song1.id,
            order: 0,
          ),
        );
        await tagRepo.addItemToCollection(
          playlist.id,
          PlaylistItem(
            id: _uuid.v4(),
            type: PlaylistItemType.songUnit,
            targetId: song2.id,
            order: 1,
          ),
        );

        // Lock the playlist
        await tagRepo.setCollectionLock(playlist.id, true);

        // Add playlist to queue
        final group = await viewModel.addCollectionToQueue(playlist.id);

        // Verify group was created and is locked
        expect(group, isNotNull);
        expect(group!.isGroup, isTrue);
        expect(
          group.isLocked,
          isTrue,
          reason: 'Group should inherit locked state from playlist',
        );
        expect(
          group.parentId,
          equals('default'),
          reason: 'Group parent should be the active queue',
        );
      },
    );

    // ========================================================================
    // Requirement 8.3: Unlocked playlist → unlocked group in queue
    // ========================================================================
    test(
      'Req 8.3: Adding an unlocked playlist to queue creates an unlocked group',
      () async {
        final song1 = _makeSongUnit();
        await libraryRepo.addSongUnit(song1);

        final playlist = await tagRepo.createCollection('Unlocked Playlist');
        await tagRepo.addItemToCollection(
          playlist.id,
          PlaylistItem(
            id: _uuid.v4(),
            type: PlaylistItemType.songUnit,
            targetId: song1.id,
            order: 0,
          ),
        );

        // Playlist is unlocked by default (isLocked = false)
        final playlistTag = await tagRepo.getTag(playlist.id);
        expect(
          playlistTag!.isLocked,
          isFalse,
          reason: 'Playlist should be unlocked by default',
        );

        // Add to queue
        final group = await viewModel.addCollectionToQueue(playlist.id);

        expect(group, isNotNull);
        expect(
          group!.isLocked,
          isFalse,
          reason: 'Group should inherit unlocked state from playlist',
        );
      },
    );

    // ========================================================================
    // Requirement 8.4: Allow overriding inherited lock state
    // ========================================================================
    test(
      'Req 8.4: Can override inherited lock state via overrideLock parameter',
      () async {
        final song1 = _makeSongUnit();
        await libraryRepo.addSongUnit(song1);

        // Create a locked playlist
        final playlist = await tagRepo.createCollection('Locked Playlist');
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

        // Add to queue but override lock to false
        final group = await viewModel.addCollectionToQueue(
          playlist.id,
          overrideLock: false,
        );

        expect(group, isNotNull);
        expect(
          group!.isLocked,
          isFalse,
          reason: 'Override should set group to unlocked',
        );
      },
    );

    test(
      'Req 8.4: Can override unlocked playlist to create locked group',
      () async {
        final song1 = _makeSongUnit();
        await libraryRepo.addSongUnit(song1);

        // Create an unlocked playlist
        final playlist = await tagRepo.createCollection('Unlocked Playlist 2');
        await tagRepo.addItemToCollection(
          playlist.id,
          PlaylistItem(
            id: _uuid.v4(),
            type: PlaylistItemType.songUnit,
            targetId: song1.id,
            order: 0,
          ),
        );

        // Add to queue but override lock to true
        final group = await viewModel.addCollectionToQueue(
          playlist.id,
          overrideLock: true,
        );

        expect(group, isNotNull);
        expect(
          group!.isLocked,
          isTrue,
          reason: 'Override should set group to locked',
        );
      },
    );

    test('Req 8.4: Can toggle lock on group after creation', () async {
      final song1 = _makeSongUnit();
      await libraryRepo.addSongUnit(song1);

      final playlist = await tagRepo.createCollection('Toggle Test');
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

      // Add to queue (inherits locked)
      final group = await viewModel.addCollectionToQueue(playlist.id);
      expect(group!.isLocked, isTrue);

      // Toggle lock on the group
      await viewModel.toggleLock(group.id);

      // Verify group is now unlocked
      final updatedGroup = await tagRepo.getTag(group.id);
      expect(
        updatedGroup!.isLocked,
        isFalse,
        reason: 'Group lock should be togglable after creation',
      );
    });

    // ========================================================================
    // Requirement 8.5: Playlist lock changes don't affect existing queue groups
    // ========================================================================
    test(
      'Req 8.5: Changing playlist lock does NOT affect existing queue group',
      () async {
        final song1 = _makeSongUnit();
        await libraryRepo.addSongUnit(song1);

        // Create a locked playlist
        final playlist = await tagRepo.createCollection('Independence Test');
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

        // Add to queue (group inherits locked)
        final group = await viewModel.addCollectionToQueue(playlist.id);
        expect(group!.isLocked, isTrue);

        // Now unlock the source playlist
        await tagRepo.setCollectionLock(playlist.id, false);

        // Verify the group is still locked (independent)
        final groupAfterChange = await tagRepo.getTag(group.id);
        expect(
          groupAfterChange!.isLocked,
          isTrue,
          reason: 'Group lock state should be independent from source playlist',
        );

        // Verify the playlist is indeed unlocked
        final playlistAfterChange = await tagRepo.getTag(playlist.id);
        expect(playlistAfterChange!.isLocked, isFalse);
      },
    );

    test(
      'Req 8.5: Changing group lock does NOT affect source playlist',
      () async {
        final song1 = _makeSongUnit();
        await libraryRepo.addSongUnit(song1);

        final playlist = await tagRepo.createCollection('Reverse Independence');
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

        // Add to queue
        final group = await viewModel.addCollectionToQueue(playlist.id);

        // Unlock the group
        await viewModel.toggleLock(group!.id);

        // Verify playlist is still locked
        final playlistAfter = await tagRepo.getTag(playlist.id);
        expect(
          playlistAfter!.isLocked,
          isTrue,
          reason:
              'Source playlist lock should not be affected by group lock changes',
        );
      },
    );

    // ========================================================================
    // Additional: Group contains correct songs
    // ========================================================================
    test('Group created from playlist contains all songs in order', () async {
      final songs = <SongUnit>[];
      for (var i = 0; i < 5; i++) {
        final song = _makeSongUnit(title: 'Song $i');
        await libraryRepo.addSongUnit(song);
        songs.add(song);
      }

      final playlist = await tagRepo.createCollection('Ordered Playlist');
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

      final group = await viewModel.addCollectionToQueue(playlist.id);
      expect(group, isNotNull);

      // Verify group has all songs
      final groupItems = await tagRepo.getCollectionItems(group!.id);
      expect(groupItems.length, equals(5));

      // Verify order is preserved
      for (var i = 0; i < songs.length; i++) {
        expect(
          groupItems[i].targetId,
          equals(songs[i].id),
          reason: 'Song at index $i should match',
        );
      }
    });

    test('Adding empty collection to queue returns null', () async {
      final emptyPlaylist = await tagRepo.createCollection('Empty');

      final group = await viewModel.addCollectionToQueue(emptyPlaylist.id);
      expect(
        group,
        isNull,
        reason: 'Should not create group for empty collection',
      );
    });

    test('Adding non-existent collection to queue returns null', () async {
      final group = await viewModel.addCollectionToQueue('nonexistent_id');
      expect(group, isNull);
    });

    test(
      'Multiple playlists added to queue create independent groups',
      () async {
        final song1 = _makeSongUnit();
        final song2 = _makeSongUnit();
        await libraryRepo.addSongUnit(song1);
        await libraryRepo.addSongUnit(song2);

        // Create two playlists with different lock states
        final lockedPlaylist = await tagRepo.createCollection('Locked PL');
        await tagRepo.addItemToCollection(
          lockedPlaylist.id,
          PlaylistItem(
            id: _uuid.v4(),
            type: PlaylistItemType.songUnit,
            targetId: song1.id,
            order: 0,
          ),
        );
        await tagRepo.setCollectionLock(lockedPlaylist.id, true);

        final unlockedPlaylist = await tagRepo.createCollection('Unlocked PL');
        await tagRepo.addItemToCollection(
          unlockedPlaylist.id,
          PlaylistItem(
            id: _uuid.v4(),
            type: PlaylistItemType.songUnit,
            targetId: song2.id,
            order: 0,
          ),
        );

        // Add both to queue
        final group1 = await viewModel.addCollectionToQueue(lockedPlaylist.id);
        final group2 = await viewModel.addCollectionToQueue(
          unlockedPlaylist.id,
        );

        expect(group1!.isLocked, isTrue);
        expect(group2!.isLocked, isFalse);

        // They should be independent
        expect(group1.id, isNot(equals(group2.id)));
      },
    );
  });
}
