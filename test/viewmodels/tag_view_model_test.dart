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

/// Test generators
class ViewModelTestGenerators {
  static final Random _random = Random();
  static const Uuid _uuid = Uuid();

  static String randomString({int minLength = 3, int maxLength = 15}) {
    final length = minLength + _random.nextInt(maxLength - minLength + 1);
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => chars.codeUnitAt(_random.nextInt(chars.length)),
      ),
    );
  }

  static String validTagName() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_- ';
    // Add some Unicode characters for testing
    const unicodeChars = '中文日本語한국어';
    const allChars = chars + unicodeChars;
    final length = 3 + _random.nextInt(10);

    var name = String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => allChars.codeUnitAt(_random.nextInt(allChars.length)),
      ),
    ).trim(); // Ensure no leading/trailing whitespace

    // Ensure not empty after trim
    if (name.isEmpty) name = 'tag';

    return name;
  }

  static SongUnit randomSongUnit({List<String>? tagIds}) {
    return SongUnit(
      id: _uuid.v4(),
      metadata: Metadata(
        title: randomString(),
        artists: [randomString()],
        album: randomString(),
        year: 2000 + _random.nextInt(25),
        duration: Duration(seconds: 60 + _random.nextInt(300)),
      ),
      sources: const SourceCollection(),
      tagIds: tagIds ?? [],
      preferences: PlaybackPreferences.defaults(),
    );
  }

  static Tag randomTag({TagType? type}) {
    return Tag(
      id: _uuid.v4(),
      name: validTagName(),
      type: type ?? TagType.user,
    );
  }
}

/// In-memory storage for Song Units
class InMemorySongUnitStorage {
  final Map<String, SongUnit> _songUnits = {};

  void add(SongUnit songUnit) {
    _songUnits[songUnit.id] = songUnit;
  }

  void update(SongUnit songUnit) {
    _songUnits[songUnit.id] = songUnit;
  }

  void delete(String id) {
    _songUnits.remove(id);
  }

  SongUnit? get(String id) => _songUnits[id];

  List<SongUnit> getAll() => _songUnits.values.toList();

  void clear() => _songUnits.clear();
}

/// In-memory storage for Tags
class InMemoryTagStorage {
  final Map<String, Tag> _tags = {};
  final Map<String, String> _aliases = {};
  int _idCounter = 0;

  String generateId() => 'tag_${_idCounter++}';

  void add(Tag tag) {
    _tags[tag.id] = tag;
  }

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

  void addAlias(String aliasName, String primaryTagId) {
    _aliases[aliasName] = primaryTagId;
  }

  void removeAlias(String aliasName) {
    _aliases.remove(aliasName);
  }

  String? resolveAlias(String aliasName) => _aliases[aliasName];

  void clear() {
    _tags.clear();
    _aliases.clear();
    _idCounter = 0;
  }
}

/// Mock LibraryRepository for testing
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
  Future<SongUnit?> getSongUnit(String id) async {
    return _storage.get(id);
  }

  @override
  Future<List<SongUnit>> getAllSongUnits() async {
    return _storage.getAll();
  }

  @override
  Future<List<SongUnit>> getSongUnitsByHash(String hash) async {
    return _storage.getAll().where((s) => s.calculateHash() == hash).toList();
  }

  @override
  Future<bool> existsByHash(String hash) async {
    return _storage.getAll().any((s) => s.calculateHash() == hash);
  }

  @override
  Future<List<SongUnit>> getSongUnitsPaginated({
    required int page,
    int pageSize = 50,
  }) async {
    final all = _storage.getAll();
    final start = page * pageSize;
    if (start >= all.length) return [];
    final end = (start + pageSize).clamp(0, all.length);
    return all.sublist(start, end);
  }

  @override
  Future<int> getSongUnitCount() async {
    return _storage.getAll().length;
  }

  @override
  Future<List<SongUnit>> getByLibraryLocation(String libraryLocationId) async {
    return _storage
        .getAll()
        .where((s) => s.libraryLocationId == libraryLocationId)
        .toList();
  }

  @override
  Future<List<SongUnit>> getSongUnitsWithoutLibraryLocation() async {
    return _storage.getAll().where((s) => s.libraryLocationId == null).toList();
  }

  @override
  Future<List<SongUnit>> getAggregatedFromLibraryLocations(
    List<String> libraryLocationIds,
  ) async {
    if (libraryLocationIds.isEmpty) {
      return _storage.getAll();
    }
    return _storage
        .getAll()
        .where((s) => libraryLocationIds.contains(s.libraryLocationId))
        .toList();
  }

  @override
  Future<List<SongUnit>> getByStorageLocation(String storageLocationId) =>
      getByLibraryLocation(storageLocationId);

  @override
  Future<List<SongUnit>> getSongUnitsWithoutStorageLocation() =>
      getSongUnitsWithoutLibraryLocation();

  @override
  Future<List<SongUnit>> getAggregatedFromStorageLocations(
    List<String> storageLocationIds,
  ) => getAggregatedFromLibraryLocations(storageLocationIds);

  @override
  void clearCache() {
    // No-op for mock
  }

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
    final songUnit = _storage.get(songUnitId);
    if (songUnit == null) {
      throw Exception('Song Unit not found');
    }
    final updatedSongUnit = songUnit.copyWith(
      libraryLocationId: destinationLocation.id,
    );
    _storage.update(updatedSongUnit);
    _eventController.add(
      SongUnitMoved(updatedSongUnit, sourceLocation.id, destinationLocation.id),
    );
    return updatedSongUnit;
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
  void dispose() {
    _eventController.close();
  }
}

/// Mock TagRepository for testing
class MockTagRepository implements TagRepository {
  MockTagRepository(this._storage);
  final InMemoryTagStorage _storage;
  final StreamController<TagEvent> _eventController =
      StreamController<TagEvent>.broadcast(sync: true);

  @override
  Stream<TagEvent> get events => _eventController.stream;

  @override
  Future<Tag?> getTag(String id) async {
    return _storage.get(id);
  }

  @override
  Future<Tag?> getTagByName(String name) async {
    return _storage.getByName(name);
  }

  @override
  Future<Tag> createTag(String name, {String? parentId}) async {
    if (!_isValidTagName(name)) {
      throw ArgumentError('Invalid tag name');
    }

    final existing = _storage.getByName(name);
    if (existing != null) {
      throw StateError('Tag already exists');
    }

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
    final tag = _storage.get(id);
    if (tag == null) return;

    if (tag.type == TagType.builtIn) {
      throw StateError('Cannot delete built-in tag');
    }

    _storage.delete(id);
    _eventController.add(TagDeleted(id));
  }

  @override
  Future<void> addAlias(String primaryTagId, String aliasName) async {
    final existingAlias = _storage.resolveAlias(aliasName);
    if (existingAlias != null) {
      throw StateError('Alias already exists');
    }

    _storage.addAlias(aliasName, primaryTagId);
    _eventController.add(AliasAdded(aliasName, primaryTagId));
  }

  @override
  Future<Tag?> resolveAlias(String aliasName) async {
    final primaryId = _storage.resolveAlias(aliasName);
    if (primaryId == null) return null;
    return _storage.get(primaryId);
  }

  @override
  Future<void> removeAlias(String primaryTagId, String aliasName) async {
    _storage.removeAlias(aliasName);
  }

  @override
  Future<Tag?> getTagByNameOrAlias(String nameOrAlias) async {
    final byName = _storage.getByName(nameOrAlias);
    if (byName != null) return byName;
    return resolveAlias(nameOrAlias);
  }

  @override
  Future<List<Tag>> getAllTags() async {
    return _storage.getAll();
  }

  @override
  Future<List<Tag>> getBuiltInTags() async {
    return _storage.getByType(TagType.builtIn);
  }

  @override
  Future<List<Tag>> getUserTags() async {
    return _storage.getByType(TagType.user);
  }

  @override
  Future<List<Tag>> getAutomaticTags() async {
    return _storage.getByType(TagType.automatic);
  }

  @override
  Future<List<Tag>> getChildTags(String parentId) async {
    return _storage.getAll().where((t) => t.parentId == parentId).toList();
  }

  @override
  Future<List<Tag>> getDescendants(String tagId) async {
    final descendants = <Tag>[];
    await _collectDescendants(tagId, descendants);
    return descendants;
  }

  Future<void> _collectDescendants(String tagId, List<Tag> descendants) async {
    final children = await getChildTags(tagId);
    for (final child in children) {
      descendants.add(child);
      await _collectDescendants(child.id, descendants);
    }
  }

  @override
  Future<void> initializeBuiltInTags() async {
    for (final name in BuiltInTags.all) {
      if (_storage.getByName(name) == null) {
        final id = _storage.generateId();
        final tag = Tag(id: id, name: name, type: TagType.builtIn);
        _storage.add(tag);
      }
    }
  }

  @override
  Future<void> updateIncludeChildren(String tagId, bool includeChildren) async {
    final tag = _storage.get(tagId);
    if (tag == null) return;

    final updatedTag = tag.copyWith(includeChildren: includeChildren);
    _storage.add(updatedTag);
    _eventController.add(TagUpdated(updatedTag));
  }

  bool _isValidTagName(String name) {
    if (name.isEmpty) return false;

    // Check for dangerous/reserved characters (excluding / which is for hierarchy)
    final dangerousChars = ['"', '!', '&', ':', '*'];
    for (final char in dangerousChars) {
      if (name.contains(char)) return false;
    }

    return true;
  }

  @override
  Future<Tag> updateTag(Tag tag) async {
    _storage.add(tag);
    _eventController.add(TagUpdated(tag));
    return tag;
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
  dynamic noSuchMethod(Invocation invocation) => null;

  @override
  void dispose() {
    _eventController.close();
  }
}

class MockSettingsRepo implements SettingsRepository {
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

class MockPlaybackStorage implements PlaybackStateStorage {
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

void main() {
  group('TagViewModel Property Tests', () {
    late InMemorySongUnitStorage songUnitStorage;
    late InMemoryTagStorage tagStorage;
    late MockLibraryRepository libraryRepository;
    late MockTagRepository tagRepository;
    late MockSettingsRepo settingsRepository;
    late MockPlaybackStorage playbackStorage;
    late TagViewModel viewModel;

    setUp(() async {
      songUnitStorage = InMemorySongUnitStorage();
      tagStorage = InMemoryTagStorage();
      libraryRepository = MockLibraryRepository(songUnitStorage);
      tagRepository = MockTagRepository(tagStorage);
      settingsRepository = MockSettingsRepo();
      playbackStorage = MockPlaybackStorage();

      // Create default queue
      final defaultQueue = Tag(
        id: 'default',
        name: 'Default',
        type: TagType.user,
        playlistMetadata: PlaylistMetadata.empty().copyWith(currentIndex: 0),
      );
      tagStorage.add(defaultQueue);

      viewModel = TagViewModel(
        tagRepository: tagRepository,
        libraryRepository: libraryRepository,
        settingsRepository: settingsRepository,
        playbackStateStorage: playbackStorage,
      );

      await Future.delayed(const Duration(milliseconds: 50));
    });

    tearDown(() {
      viewModel.dispose();
      libraryRepository.dispose();
      tagRepository.dispose();
      songUnitStorage.clear();
      tagStorage.clear();
    });

    // Feature: song-unit-core, Property 16: Tag association idempotence
    // **Validates: Requirements 5.1**
    test(
      'Property 16: For any Song Unit and tag, adding the same tag multiple times SHALL result in the tag being associated exactly once',
      () async {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          // Create a tag
          final tag = await tagRepository.createTag(
            'tag_${ViewModelTestGenerators.validTagName()}_$i',
          );

          // Create a Song Unit without the tag
          final songUnit = ViewModelTestGenerators.randomSongUnit();
          await libraryRepository.addSongUnit(songUnit);

          // Add the tag multiple times (2-5 times)
          final addCount = 2 + Random().nextInt(4);
          for (var j = 0; j < addCount; j++) {
            await viewModel.addTagToSongUnit(songUnit.id, tag.id);
          }

          // Verify the tag is associated exactly once
          final updatedSongUnit = await libraryRepository.getSongUnit(
            songUnit.id,
          );
          expect(updatedSongUnit, isNotNull);

          final tagCount = updatedSongUnit!.tagIds
              .where((id) => id == tag.id)
              .length;
          expect(
            tagCount,
            equals(1),
            reason:
                'Tag should be associated exactly once after $addCount additions',
          );
        }
      },
    );

    test(
      'Property 16 (edge case): Adding tag to Song Unit that already has it',
      () async {
        // Create a tag
        final tag = await tagRepository.createTag('existing_tag');

        // Create a Song Unit with the tag already
        final songUnit = ViewModelTestGenerators.randomSongUnit(
          tagIds: [tag.id],
        );
        await libraryRepository.addSongUnit(songUnit);

        // Try to add the same tag again
        await viewModel.addTagToSongUnit(songUnit.id, tag.id);

        // Verify still only one association
        final updatedSongUnit = await libraryRepository.getSongUnit(
          songUnit.id,
        );
        expect(
          updatedSongUnit!.tagIds.where((id) => id == tag.id).length,
          equals(1),
        );
      },
    );

    // Feature: song-unit-core, Property 17: Tag removal preserves definition
    // **Validates: Requirements 5.2**
    test(
      'Property 17: For any tag removal from a Song Unit, the tag definition SHALL remain in the global tag registry',
      () async {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          // Create a tag
          final tagName =
              'preserve_tag_${ViewModelTestGenerators.validTagName()}_$i';
          final tag = await tagRepository.createTag(tagName);

          // Create a Song Unit with the tag
          final songUnit = ViewModelTestGenerators.randomSongUnit(
            tagIds: [tag.id],
          );
          await libraryRepository.addSongUnit(songUnit);

          // Remove the tag from the Song Unit
          await viewModel.removeTagFromSongUnit(songUnit.id, tag.id);

          // Verify the tag definition still exists in the registry
          final tagInRegistry = await tagRepository.getTag(tag.id);
          expect(
            tagInRegistry,
            isNotNull,
            reason: 'Tag definition should remain after removal from Song Unit',
          );
          expect(tagInRegistry!.name, equals(tagName));
          expect(tagInRegistry.type, equals(TagType.user));

          // Verify the tag is no longer associated with the Song Unit
          final updatedSongUnit = await libraryRepository.getSongUnit(
            songUnit.id,
          );
          expect(
            updatedSongUnit!.tagIds.contains(tag.id),
            isFalse,
            reason: 'Tag should be removed from Song Unit',
          );
        }
      },
    );

    test(
      'Property 17 (multiple Song Units): Tag persists after removal from all Song Units',
      () async {
        // Create a tag
        final tag = await tagRepository.createTag('shared_tag');

        // Create multiple Song Units with the tag
        final songUnits = <SongUnit>[];
        for (var i = 0; i < 5; i++) {
          final songUnit = ViewModelTestGenerators.randomSongUnit(
            tagIds: [tag.id],
          );
          await libraryRepository.addSongUnit(songUnit);
          songUnits.add(songUnit);
        }

        // Remove the tag from all Song Units
        for (final songUnit in songUnits) {
          await viewModel.removeTagFromSongUnit(songUnit.id, tag.id);
        }

        // Verify the tag definition still exists
        final tagInRegistry = await tagRepository.getTag(tag.id);
        expect(tagInRegistry, isNotNull);
        expect(tagInRegistry!.name, equals('shared_tag'));
      },
    );

    // Feature: song-unit-core, Property 18: Batch operation atomicity
    // **Validates: Requirements 5.4**
    test(
      'Property 18: For any batch tag operation on multiple Song Units, either all operations SHALL succeed or all SHALL fail',
      () async {
        const iterations = 50;

        for (var i = 0; i < iterations; i++) {
          // Create tags
          final tags = <Tag>[];
          for (var j = 0; j < 3; j++) {
            final tag = await tagRepository.createTag(
              'batch_tag_${ViewModelTestGenerators.validTagName()}_${i}_$j',
            );
            tags.add(tag);
          }
          final tagIds = tags.map((t) => t.id).toList();

          // Create multiple Song Units
          final songUnits = <SongUnit>[];
          final songUnitCount = 2 + Random().nextInt(5);
          for (var j = 0; j < songUnitCount; j++) {
            final songUnit = ViewModelTestGenerators.randomSongUnit();
            await libraryRepository.addSongUnit(songUnit);
            songUnits.add(songUnit);
          }
          final songUnitIds = songUnits.map((s) => s.id).toList();

          // Perform batch add
          await viewModel.batchAddTags(songUnitIds, tagIds);

          // Verify all Song Units have all tags
          for (final songUnitId in songUnitIds) {
            final updatedSongUnit = await libraryRepository.getSongUnit(
              songUnitId,
            );
            expect(updatedSongUnit, isNotNull);

            for (final tagId in tagIds) {
              expect(
                updatedSongUnit!.tagIds.contains(tagId),
                isTrue,
                reason:
                    'Song Unit $songUnitId should have tag $tagId after batch add',
              );
            }
          }
        }
      },
    );

    test(
      'Property 18 (batch remove): All tags removed from all Song Units',
      () async {
        // Create tags
        final tags = <Tag>[];
        for (var i = 0; i < 3; i++) {
          final tag = await tagRepository.createTag('remove_tag_$i');
          tags.add(tag);
        }
        final tagIds = tags.map((t) => t.id).toList();

        // Create Song Units with all tags
        final songUnits = <SongUnit>[];
        for (var i = 0; i < 5; i++) {
          final songUnit = ViewModelTestGenerators.randomSongUnit(
            tagIds: tagIds,
          );
          await libraryRepository.addSongUnit(songUnit);
          songUnits.add(songUnit);
        }
        final songUnitIds = songUnits.map((s) => s.id).toList();

        // Perform batch remove
        await viewModel.batchRemoveTags(songUnitIds, tagIds);

        // Verify all tags removed from all Song Units
        for (final songUnitId in songUnitIds) {
          final updatedSongUnit = await libraryRepository.getSongUnit(
            songUnitId,
          );
          expect(updatedSongUnit, isNotNull);

          for (final tagId in tagIds) {
            expect(
              updatedSongUnit!.tagIds.contains(tagId),
              isFalse,
              reason:
                  'Song Unit $songUnitId should not have tag $tagId after batch remove',
            );
          }
        }

        // Verify tag definitions still exist
        for (final tag in tags) {
          final tagInRegistry = await tagRepository.getTag(tag.id);
          expect(
            tagInRegistry,
            isNotNull,
            reason: 'Tag definition should persist after batch removal',
          );
        }
      },
    );

    // ========================================================================
    // Selection State Management Tests (Task 17.1, Requirements 18.1, 18.7)
    // ========================================================================

    test('Selection: toggleSelection adds and removes items', () {
      expect(viewModel.hasSelection, isFalse);
      expect(viewModel.selectionCount, 0);

      viewModel.toggleSelection('item-1');
      expect(viewModel.isSelected('item-1'), isTrue);
      expect(viewModel.selectionCount, 1);
      expect(viewModel.hasSelection, isTrue);

      viewModel.toggleSelection('item-2');
      expect(viewModel.isSelected('item-2'), isTrue);
      expect(viewModel.selectionCount, 2);

      // Toggle off
      viewModel.toggleSelection('item-1');
      expect(viewModel.isSelected('item-1'), isFalse);
      expect(viewModel.selectionCount, 1);
    });

    test('Selection: clearSelection removes all selections', () {
      viewModel
        ..toggleSelection('a')
        ..toggleSelection('b')
        ..toggleSelection('c');
      expect(viewModel.selectionCount, 3);

      viewModel.clearSelection();
      expect(viewModel.hasSelection, isFalse);
      expect(viewModel.selectionCount, 0);
      expect(viewModel.isSelected('a'), isFalse);
    });

    test('Selection: selectedItemIds returns unmodifiable copy', () {
      viewModel.toggleSelection('x');
      final ids = viewModel.selectedItemIds;
      expect(ids.contains('x'), isTrue);

      // Modifying the returned set should not affect internal state
      expect(() => ids.add('y'), throwsUnsupportedError);
      expect(viewModel.selectionCount, 1);
    });

    test('Selection: isSelected returns false for unselected items', () {
      expect(viewModel.isSelected('nonexistent'), isFalse);
    });

    test('Selection: toggling same item twice returns to unselected', () {
      viewModel.toggleSelection('item');
      expect(viewModel.isSelected('item'), isTrue);
      viewModel.toggleSelection('item');
      expect(viewModel.isSelected('item'), isFalse);
      // Selection mode stays active until explicitly cleared
      expect(viewModel.hasSelection, isTrue);
      viewModel.clearSelection();
      expect(viewModel.hasSelection, isFalse);
    });

    test('Selection: clearSelection on empty selection is a no-op', () {
      expect(viewModel.hasSelection, isFalse);
      viewModel.clearSelection(); // should not throw
      expect(viewModel.hasSelection, isFalse);
    });

    test('Selection: notifyListeners called on toggle and clear', () {
      var notifyCount = 0;
      viewModel
        ..addListener(() => notifyCount++)
        ..toggleSelection('a');
      expect(notifyCount, 1);

      viewModel.toggleSelection('b');
      expect(notifyCount, 2);

      viewModel.clearSelection();
      expect(notifyCount, 3);
    });

    // ========================================================================
    // getTagPanelTags Tests (Task 19.1, Requirements 19.1-19.4)
    // ========================================================================

    test(
      'getTagPanelTags: returns only user non-group non-collection tags',
      () async {
        tagStorage
          // Add built-in tag
          ..add(const Tag(id: 'bi1', name: 'name', type: TagType.builtIn))
          // Add automatic tag
          ..add(
            const Tag(id: 'auto1', name: 'user:alice', type: TagType.automatic),
          )
          // Add user tag (non-group)
          ..add(const Tag(id: 'u1', name: 'rock', type: TagType.user))
          // Add user tag that is a group
          ..add(
            const Tag(
              id: 'g1',
              name: 'my-group',
              type: TagType.user,
              isGroup: true,
            ),
          )
          // Add another user tag (non-group)
          ..add(const Tag(id: 'u2', name: 'jazz', type: TagType.user));

        await viewModel.loadTags();

        final panelTags = viewModel.getTagPanelTags();
        final panelIds = panelTags.map((t) => t.id).toSet();

        expect(
          panelIds.contains('u1'),
          isTrue,
          reason: 'User non-group tag should be included',
        );
        expect(
          panelIds.contains('u2'),
          isTrue,
          reason: 'User non-group tag should be included',
        );
        expect(
          panelIds.contains('bi1'),
          isFalse,
          reason: 'Built-in tag should be excluded',
        );
        expect(
          panelIds.contains('auto1'),
          isFalse,
          reason: 'Automatic tag should be excluded',
        );
        expect(
          panelIds.contains('g1'),
          isFalse,
          reason: 'Group tag should be excluded',
        );
      },
    );

    test(
      'getTagPanelTags: returns empty list when no user non-group non-collection tags exist',
      () async {
        tagStorage
          // Only built-in and automatic tags (plus the default queue from setUp)
          ..add(const Tag(id: 'bi1', name: 'artist', type: TagType.builtIn))
          ..add(
            const Tag(
              id: 'auto1',
              name: 'playlist:main',
              type: TagType.automatic,
            ),
          )
          // User tag but is a group
          ..add(
            const Tag(
              id: 'g1',
              name: 'group1',
              type: TagType.user,
              isGroup: true,
            ),
          );

        await viewModel.loadTags();

        final panelTags = viewModel.getTagPanelTags();
        // Default queue is a collection, so it should be excluded too
        expect(panelTags, isEmpty);
      },
    );

    test(
      'getTagPanelTags: excludes user tags with playlistMetadata (collections)',
      () async {
        tagStorage
          // User collection (playlist) - not a group, but IS a collection - should be excluded
          ..add(
            Tag(
              id: 'pl1',
              name: 'My Playlist',
              type: TagType.user,
              playlistMetadata: PlaylistMetadata.empty(),
            ),
          )
          // User collection that IS a group - should be excluded
          ..add(
            Tag(
              id: 'grp1',
              name: 'Sub Group',
              type: TagType.user,
              playlistMetadata: PlaylistMetadata.empty(),
              isGroup: true,
            ),
          )
          // Pure user tag (no playlistMetadata) - should be included
          ..add(const Tag(id: 'u1', name: 'rock', type: TagType.user));

        await viewModel.loadTags();

        final panelTags = viewModel.getTagPanelTags();
        final panelIds = panelTags.map((t) => t.id).toSet();

        expect(
          panelIds.contains('pl1'),
          isFalse,
          reason: 'User playlist (collection) should be excluded',
        );
        expect(
          panelIds.contains('grp1'),
          isFalse,
          reason: 'User group should be excluded',
        );
        expect(
          panelIds.contains('u1'),
          isTrue,
          reason: 'Pure user tag should be included',
        );
      },
    );

    test('getTagPanelTags: reflects newly created and deleted tags', () async {
      await viewModel.loadTags();
      expect(
        viewModel.getTagPanelTags().where((t) => t.name == 'new-tag'),
        isEmpty,
      );

      // Create a new user tag
      await viewModel.createTag('new-tag');
      // Wait for event propagation
      await Future.delayed(const Duration(milliseconds: 20));

      final afterCreate = viewModel.getTagPanelTags();
      expect(
        afterCreate.any((t) => t.name == 'new-tag'),
        isTrue,
        reason: 'Newly created tag should appear immediately',
      );

      // Delete it
      final newTag = afterCreate.firstWhere((t) => t.name == 'new-tag');
      await viewModel.deleteTag(newTag.id);
      await Future.delayed(const Duration(milliseconds: 20));

      final afterDelete = viewModel.getTagPanelTags();
      expect(
        afterDelete.any((t) => t.name == 'new-tag'),
        isFalse,
        reason: 'Deleted tag should disappear immediately',
      );
    });

    test(
      'Property 18 (partial existing tags): Batch add handles Song Units with some tags already',
      () async {
        // Create tags
        final tag1 = await tagRepository.createTag('partial_tag_1');
        final tag2 = await tagRepository.createTag('partial_tag_2');
        final tag3 = await tagRepository.createTag('partial_tag_3');
        final allTagIds = [tag1.id, tag2.id, tag3.id];

        // Create Song Units with varying existing tags
        final songUnit1 = ViewModelTestGenerators.randomSongUnit(
          tagIds: [tag1.id],
        );
        final songUnit2 = ViewModelTestGenerators.randomSongUnit(
          tagIds: [tag1.id, tag2.id],
        );
        final songUnit3 = ViewModelTestGenerators.randomSongUnit();

        await libraryRepository.addSongUnit(songUnit1);
        await libraryRepository.addSongUnit(songUnit2);
        await libraryRepository.addSongUnit(songUnit3);

        final songUnitIds = [songUnit1.id, songUnit2.id, songUnit3.id];

        // Batch add all tags
        await viewModel.batchAddTags(songUnitIds, allTagIds);

        // Verify all Song Units have all tags (no duplicates)
        for (final songUnitId in songUnitIds) {
          final updatedSongUnit = await libraryRepository.getSongUnit(
            songUnitId,
          );
          expect(updatedSongUnit, isNotNull);

          for (final tagId in allTagIds) {
            final count = updatedSongUnit!.tagIds
                .where((id) => id == tagId)
                .length;
            expect(
              count,
              equals(1),
              reason: 'Each tag should appear exactly once',
            );
          }
        }
      },
    );
  });
}
