import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../data/playback_state_storage.dart';
import '../models/playlist_metadata.dart';
import '../models/song_unit.dart';
import '../models/tag.dart';
import '../repositories/library_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/tag_repository.dart'
    show
        TagRepository,
        TagEvent,
        TagCreated,
        TagUpdated,
        TagDeleted,
        AliasAdded,
        AliasRemoved;
import '../services/platform_media_player.dart' show PlaybackStatus;
import '../src/rust/api/tag_api.dart' as rust_tag;
import '../src/rust/frb_generated.dart' show RustLib;
import '../views/player_control_panel.dart';
import 'player_view_model.dart';

/// Represents an item in the queue display: either a song or a group header
class QueueDisplayItem {
  const QueueDisplayItem.song({
    required this.songUnit,
    required this.flatIndex,
    this.playlistItemId,
    this.groupId,
  }) : type = QueueDisplayItemType.song,
       groupName = null,
       songCount = 0,
       isLocked = false,
       groupSongs = null,
       subItems = null;

  const QueueDisplayItem.group({
    required this.groupName,
    required this.groupId,
    required this.songCount,
    required this.isLocked,
    this.groupSongs,
    this.subItems,
  }) : type = QueueDisplayItemType.group,
       songUnit = null,
       flatIndex = -1,
       playlistItemId = null;

  final QueueDisplayItemType type;
  final SongUnit? songUnit;
  final int flatIndex;
  final String? groupName;
  final String? groupId;
  final int songCount;
  final bool isLocked;

  /// The PlaylistItem ID for this song in the active queue (for drag-drop operations)
  final String? playlistItemId;

  /// For group items: the resolved songs inside this group (for card display)
  final List<SongUnit>? groupSongs;

  /// For group items: nested display items (songs and sub-groups) preserving hierarchy
  final List<QueueDisplayItem>? subItems;

  bool get isSong => type == QueueDisplayItemType.song;
  bool get isGroup => type == QueueDisplayItemType.group;
}

enum QueueDisplayItemType { song, group }

/// Unified ViewModel for tag and collection management
/// Handles tag CRUD operations, tag-SongUnit associations, and collection operations
/// Collections (playlists, queues, groups) are all tags with PlaylistMetadata
class TagViewModel extends ChangeNotifier {
  TagViewModel({
    required TagRepository tagRepository,
    required LibraryRepository libraryRepository,
    required SettingsRepository settingsRepository,
    required PlaybackStateStorage playbackStateStorage,
  }) : _tagRepository = tagRepository,
       _libraryRepository = libraryRepository,
       _settingsRepository = settingsRepository,
       _playbackStateStorage = playbackStateStorage {
    _setupListeners();
    _loadActiveQueue();
  }
  final TagRepository _tagRepository;
  final LibraryRepository _libraryRepository;
  final SettingsRepository _settingsRepository;
  final PlaybackStateStorage _playbackStateStorage;
  final Random _random = Random();
  final Uuid _uuid = const Uuid();

  // Reference to PlayerViewModel for playing songs (set after initialization)
  PlayerViewModel? _playerViewModel;

  // Tag state
  List<Tag> _allTags = [];
  List<Tag> _builtInTags = [];
  List<Tag> _userTags = [];
  List<Tag> _automaticTags = [];

  // Active queue state
  String _activeQueueId = 'default';
  List<SongUnit> _currentQueueSongs = [];
  List<QueueDisplayItem> _queueDisplayItems = [];
  int _cachedCurrentIndex = -1;
  bool _cachedRemoveAfterPlay = false;
  PlaybackMode _playbackMode = PlaybackMode.sequential;

  // Common state
  bool _isLoading = false;
  String? _error;
  bool _suppressEvents = false;
  StreamSubscription<TagEvent>? _eventSubscription;
  StreamSubscription<LibraryEvent>? _librarySubscription;
  Timer? _saveDebounceTimer;

  /// All tags
  List<Tag> get allTags => List.unmodifiable(_allTags);

  /// Built-in tags only
  List<Tag> get builtInTags => List.unmodifiable(_builtInTags);

  /// User-created tags only
  List<Tag> get userTags => List.unmodifiable(_userTags);

  /// Automatic tags only
  List<Tag> get automaticTags => List.unmodifiable(_automaticTags);

  /// Whether tags are loading
  bool get isLoading => _isLoading;

  /// Error message if any
  String? get error => _error;

  // ============================================================================
  // Active Queue Getters
  // ============================================================================

  /// Get the active queue ID
  String get activeQueueId => _activeQueueId;

  /// Get the currently active queue tag
  Future<Tag?> get activeQueue async => _getActiveQueue();

  /// Current playback queue (songs in active queue)
  List<SongUnit> get queueSongUnits => List.unmodifiable(_currentQueueSongs);

  /// Queue display items (songs + group headers for UI rendering)
  List<QueueDisplayItem> get queueDisplayItems =>
      List.unmodifiable(_queueDisplayItems);

  /// Current index in the queue (-1 if nothing playing)
  int get currentIndex => _cachedCurrentIndex;

  /// Currently playing Song Unit
  SongUnit? get currentSongUnit =>
      _cachedCurrentIndex >= 0 &&
          _cachedCurrentIndex < _currentQueueSongs.length
      ? _currentQueueSongs[_cachedCurrentIndex]
      : null;

  /// Whether there's a next song in the queue
  bool get hasNext => _cachedCurrentIndex < _currentQueueSongs.length - 1;

  /// Whether there's a previous song in the queue
  bool get hasPrevious => _cachedCurrentIndex > 0;

  /// Number of songs in the queue
  int get queueLength => _currentQueueSongs.length;

  /// Whether the queue is empty
  bool get isEmpty => _currentQueueSongs.isEmpty;

  /// Current playback mode
  PlaybackMode get playbackMode => _playbackMode;

  /// Whether to remove song from queue after playing (from active queue)
  bool get removeAfterPlay => _cachedRemoveAfterPlay;

  void _setupListeners() {
    _eventSubscription = _tagRepository.events.listen(
      _onTagEvent,
      onError: _onTagError,
    );
    _librarySubscription = _libraryRepository.events.listen(
      _onLibraryEvent,
      onError: _onLibraryError,
    );
  }

  /// Public entry point to reload the active queue (e.g. after first-launch queue creation).
  Future<void> reloadActiveQueue() => _loadActiveQueue();

  /// Load active queue from settings and load its songs
  Future<void> _loadActiveQueue() async {
    try {
      _activeQueueId = await _settingsRepository.getActiveQueueId();

      // Queue may not exist yet on first launch (created after language selection)
      final activeQueue = await _tagRepository.getTag(_activeQueueId);
      if (activeQueue == null) return;

      await _loadCurrentQueueSongs();
      await _updateCachedValues();
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load active queue: $e');
    }
  }

  /// Load songs for the current active queue
  /// Resolves both direct song unit items and collection references (groups)
  /// Also builds the display items list for UI rendering
  Future<void> _loadCurrentQueueSongs() async {
    final activeQueue = await _getActiveQueue();
    if (activeQueue == null || activeQueue.playlistMetadata == null) {
      _currentQueueSongs = [];
      _queueDisplayItems = [];
      return;
    }

    final metadata = activeQueue.playlistMetadata!;
    
    final songUnits = <SongUnit>[];
    final displayItems = <QueueDisplayItem>[];

    for (final item in metadata.items) {
      if (item.type == PlaylistItemType.songUnit) {
        final songUnitId = item.targetId;

        // Check if this is a temporary song unit
        if (songUnitId.startsWith('temp_') &&
            metadata.temporarySongUnits != null) {
          final tempData = metadata.temporarySongUnits![songUnitId];
          if (tempData != null) {
            try {
              final songUnit = SongUnit.fromJson(tempData);
              displayItems.add(
                QueueDisplayItem.song(
                  songUnit: songUnit,
                  flatIndex: songUnits.length,
                  playlistItemId: item.id,
                ),
              );
              songUnits.add(songUnit);
              continue;
            } catch (e) {
              debugPrint(
                'Failed to deserialize temporary song unit $songUnitId: $e',
              );
            }
          }
        }

        // Try to load from library
        final songUnit = await _libraryRepository.getSongUnit(songUnitId);
        if (songUnit != null) {
          displayItems.add(
            QueueDisplayItem.song(
              songUnit: songUnit,
              flatIndex: songUnits.length,
              playlistItemId: item.id,
            ),
          );
          songUnits.add(songUnit);
        }
      } else if (item.type == PlaylistItemType.collectionReference) {
        // Build nested display items recursively (preserves sub-group hierarchy)
        final groupDisplayItem = await _buildGroupDisplayItem(
          item.targetId,
          songUnits,
          temporarySongUnits: metadata.temporarySongUnits,
        );
        if (groupDisplayItem != null) {
          displayItems.add(groupDisplayItem);
          // Also add flat song entries under the group for playback indexing
          _addFlatSongsFromGroup(groupDisplayItem, displayItems, item.targetId);
        }
      }
    }
    _currentQueueSongs = songUnits;
    _queueDisplayItems = displayItems;
  }

  /// Recursively build a QueueDisplayItem.group with nested subItems
  /// that preserves the hierarchy of sub-groups.
  /// [flatSongList] is the shared flat list — songs are appended as encountered.
  Future<QueueDisplayItem?> _buildGroupDisplayItem(
    String groupId,
    List<SongUnit> flatSongList, {
    int depth = 0,
    Map<String, Map<String, dynamic>>? temporarySongUnits,
  }) async {
    if (depth > 10) {
      debugPrint('Max depth exceeded for group $groupId');
      return null;
    }

    final groupTag = await _tagRepository.getCollectionTag(groupId);
    if (groupTag == null) return null;
    final groupMetadata = groupTag.playlistMetadata;
    if (groupMetadata == null) return null;

    final subItems = <QueueDisplayItem>[];
    final allSongs = <SongUnit>[]; // flat songs for legacy groupSongs field

    for (final item in groupMetadata.items) {
      if (item.type == PlaylistItemType.songUnit) {
        SongUnit? songUnit;
        // Check temporary song units
        if (item.targetId.startsWith('temp_') && temporarySongUnits != null) {
          final tempData = temporarySongUnits[item.targetId];
          if (tempData != null) {
            try {
              songUnit = SongUnit.fromJson(tempData);
            } catch (e) {
              debugPrint(
                'Failed to deserialize temporary song unit ${item.targetId}: $e',
              );
            }
          }
        }
        songUnit ??= await _libraryRepository.getSongUnit(item.targetId);
        if (songUnit != null) {
          subItems.add(
            QueueDisplayItem.song(
              songUnit: songUnit,
              flatIndex: flatSongList.length,
              playlistItemId: item.id,
              groupId: groupId,
            ),
          );
          flatSongList.add(songUnit);
          allSongs.add(songUnit);
        }
      } else if (item.type == PlaylistItemType.collectionReference) {
        // Recurse into sub-group
        final subGroup = await _buildGroupDisplayItem(
          item.targetId,
          flatSongList,
          depth: depth + 1,
          temporarySongUnits: temporarySongUnits,
        );
        if (subGroup != null) {
          subItems.add(subGroup);
          // Collect all songs from sub-group for legacy groupSongs
          if (subGroup.groupSongs != null) {
            allSongs.addAll(subGroup.groupSongs!);
          }
        }
      }
    }

    return QueueDisplayItem.group(
      groupName: groupTag.name,
      groupId: groupId,
      songCount: allSongs.length,
      isLocked: groupTag.isLocked,
      groupSongs: allSongs,
      subItems: subItems,
    );
  }

  /// Add flat song display items from a group's subItems into the top-level
  /// displayItems list (needed for flatIndex-based playback lookups).
  void _addFlatSongsFromGroup(
    QueueDisplayItem group,
    List<QueueDisplayItem> displayItems,
    String topGroupId,
  ) {
    final subs = group.subItems ?? [];
    for (final sub in subs) {
      if (sub.isSong) {
        // Keep the actual groupId (the sub-group that directly contains this song)
        // so removeFromQueue can find the correct collection to remove from
        displayItems.add(
          QueueDisplayItem.song(
            songUnit: sub.songUnit!,
            flatIndex: sub.flatIndex,
            playlistItemId: sub.playlistItemId,
            groupId: sub.groupId,
          ),
        );
      } else if (sub.isGroup) {
        // Recursively add songs from nested sub-groups
        _addFlatSongsFromGroup(sub, displayItems, topGroupId);
      }
    }
  }

  /// Get the active queue tag
  Future<Tag?> _getActiveQueue() async {
    return _tagRepository.getCollectionTag(_activeQueueId);
  }

  /// Update the active queue's metadata
  Future<void> _updateActiveQueue(PlaylistMetadata updatedMetadata) async {
    final updated = updatedMetadata.copyWith(updatedAt: DateTime.now());
    await _tagRepository.updateCollectionMetadata(_activeQueueId, updated);
  }

  /// Update cached values from active queue
  Future<void> _updateCachedValues() async {
    final activeQueue = await _getActiveQueue();
    if (activeQueue?.playlistMetadata != null) {
      _cachedCurrentIndex = activeQueue!.playlistMetadata!.currentIndex;
      _cachedRemoveAfterPlay = activeQueue.playlistMetadata!.removeAfterPlay;
    } else {
      _cachedCurrentIndex = -1;
      _cachedRemoveAfterPlay = false;
    }
  }

  void _onTagEvent(TagEvent event) {
    if (_suppressEvents) return;
    switch (event) {
      case TagCreated(tag: final tag):
        _allTags = [..._allTags, tag];
        _categorizeTag(tag);
        notifyListeners();
      case TagUpdated(tag: final tag):
        final index = _allTags.indexWhere((t) => t.id == tag.id);
        if (index != -1) {
          _allTags = [
            ..._allTags.sublist(0, index),
            tag,
            ..._allTags.sublist(index + 1),
          ];
          _recategorizeTags();
          notifyListeners();
        }
      case TagDeleted(tagId: final id):
        _allTags = _allTags.where((t) => t.id != id).toList();
        _recategorizeTags();
        notifyListeners();
      case AliasAdded():
        // Refresh tags to get updated alias info
        loadTags();
      case AliasRemoved():
        // Refresh tags to get updated alias info
        loadTags();
    }
  }

  void _onLibraryError(Object error) {
    _error = error.toString();
    notifyListeners();
  }

  void _onTagError(Object error) {
    _error = error.toString();
    notifyListeners();
  }

  void _onLibraryEvent(LibraryEvent event) async {
    switch (event) {
      case SongUnitUpdated(songUnit: final songUnit):
        // Update the song unit in the current queue if it exists
        final index = _currentQueueSongs.indexWhere((s) => s.id == songUnit.id);
        if (index != -1) {
          _currentQueueSongs = [
            ..._currentQueueSongs.sublist(0, index),
            songUnit,
            ..._currentQueueSongs.sublist(index + 1),
          ];
          // Also rebuild display items so UI shows updated metadata/sources
          _updateDisplayItemsForSongUnit(songUnit);
          notifyListeners();
        }
      case SongUnitDeleted(songUnitId: final id):
        // Remove the song unit from the current queue if it exists
        final index = _currentQueueSongs.indexWhere((s) => s.id == id);
        if (index != -1) {
          _currentQueueSongs = _currentQueueSongs
              .where((s) => s.id != id)
              .toList();

          // Update the active queue
          final activeQueue = await _getActiveQueue();
          if (activeQueue?.playlistMetadata != null) {
            final metadata = activeQueue!.playlistMetadata!;
            var newIndex = metadata.currentIndex;
            // Adjust current index if needed
            if (index < newIndex) {
              newIndex--;
            } else if (index == newIndex) {
              // Current song was deleted, stay at same index (next song)
              if (newIndex >= _currentQueueSongs.length) {
                newIndex = _currentQueueSongs.length - 1;
              }
            }

            // Update items list
            final updatedItems = metadata.items
                .where((item) => item.targetId != id)
                .toList();

            await _updateActiveQueue(
              metadata.copyWith(items: updatedItems, currentIndex: newIndex),
            );
          }
          notifyListeners();
        }
      case SongUnitAdded():
        // No action needed for added songs
        break;
      case SongUnitMoved(songUnit: final songUnit):
        // Update the song unit in the current queue if it exists (storage location changed)
        final index = _currentQueueSongs.indexWhere((s) => s.id == songUnit.id);
        if (index != -1) {
          _currentQueueSongs = [
            ..._currentQueueSongs.sublist(0, index),
            songUnit,
            ..._currentQueueSongs.sublist(index + 1),
          ];
          _updateDisplayItemsForSongUnit(songUnit);
          notifyListeners();
        }
    }
  }

  /// Update all display items that reference the given song unit with fresh data.
  /// This handles both top-level song items and songs nested inside groups.
  void _updateDisplayItemsForSongUnit(SongUnit songUnit) {
    _queueDisplayItems = _queueDisplayItems.map((item) {
      if (item.isSong && item.songUnit?.id == songUnit.id) {
        return QueueDisplayItem.song(
          songUnit: songUnit,
          flatIndex: item.flatIndex,
          playlistItemId: item.playlistItemId,
          groupId: item.groupId,
        );
      }
      if (item.isGroup) {
        return _updateGroupDisplayItem(item, songUnit);
      }
      return item;
    }).toList();
  }

  /// Recursively update a group display item's nested songs and groupSongs.
  QueueDisplayItem _updateGroupDisplayItem(
    QueueDisplayItem group,
    SongUnit songUnit,
  ) {
    final updatedSubItems = group.subItems?.map((sub) {
      if (sub.isSong && sub.songUnit?.id == songUnit.id) {
        return QueueDisplayItem.song(
          songUnit: songUnit,
          flatIndex: sub.flatIndex,
          playlistItemId: sub.playlistItemId,
          groupId: sub.groupId,
        );
      }
      if (sub.isGroup) {
        return _updateGroupDisplayItem(sub, songUnit);
      }
      return sub;
    }).toList();

    final updatedGroupSongs = group.groupSongs?.map(
      (s) => s.id == songUnit.id ? songUnit : s,
    ).toList();

    return QueueDisplayItem.group(
      groupName: group.groupName,
      groupId: group.groupId,
      songCount: group.songCount,
      isLocked: group.isLocked,
      groupSongs: updatedGroupSongs,
      subItems: updatedSubItems,
    );
  }

  // ============================================================================
  // Tag Operations (work on all tags)
  // ============================================================================

  void _categorizeTag(Tag tag) {
    switch (tag.type) {
      case TagType.builtIn:
        _builtInTags = [..._builtInTags, tag];
      case TagType.user:
        _userTags = [..._userTags, tag];
      case TagType.automatic:
        _automaticTags = [..._automaticTags, tag];
    }
  }

  void _recategorizeTags() {
    _builtInTags = _allTags.where((t) => t.type == TagType.builtIn).toList();
    _userTags = _allTags.where((t) => t.type == TagType.user).toList();
    _automaticTags = _allTags
        .where((t) => t.type == TagType.automatic)
        .toList();
  }

  /// Load all tags from the repository
  Future<void> loadTags() async {
    try {
      final isInitialLoad = _allTags.isEmpty;
      if (isInitialLoad) {
        _isLoading = true;
        notifyListeners();
      }
      _error = null;

      _allTags = await _tagRepository.getAllTags();
      _recategorizeTags();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Silent version of loadTags — refreshes in-memory cache without
  /// triggering intermediate notifyListeners. Used by move/reorder methods
  /// that call notifyListeners once at the end to avoid UI blinking.
  Future<void> _loadTagsSilent() async {
    _allTags = await _tagRepository.getAllTags();
    _recategorizeTags();
  }

  /// Create a new user tag
  Future<Tag?> createTag(String name, {String? parentId}) async {
    try {
      _error = null;
      final tag = await _tagRepository.createTag(name, parentId: parentId);
      // Mirror to Rust tag system for search (nameless user tag)
      _syncCreateTagToRust(tag);
      return tag;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Rename a tag
  Future<void> renameTag(String tagId, String newName) async {
    try {
      _error = null;
      final tag = await _tagRepository.getTag(tagId);
      if (tag == null) {
        _error = 'Tag not found';
        notifyListeners();
        return;
      }
      final updatedTag = tag.copyWith(name: newName);
      await _tagRepository.updateTag(updatedTag);
      // Mirror rename to Rust — delete old + create new is simplest
      _syncDeleteTagFromRust(tagId);
      _syncCreateTagToRust(updatedTag);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Delete a tag
  Future<void> deleteTag(String tagId) async {
    try {
      _error = null;
      await _tagRepository.deleteTag(tagId);
      // Mirror to Rust tag system
      _syncDeleteTagFromRust(tagId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Add an alias for a tag
  Future<void> addAlias(String primaryTagId, String aliasName) async {
    try {
      _error = null;
      await _tagRepository.addAlias(primaryTagId, aliasName);
      // Mirror to Rust tag system
      _syncAddAliasToRust(primaryTagId, aliasName);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Remove an alias from a tag
  Future<void> removeAlias(String primaryTagId, String aliasName) async {
    try {
      _error = null;
      await _tagRepository.removeAlias(primaryTagId, aliasName);
      // Mirror to Rust tag system
      _syncRemoveAliasFromRust(aliasName);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Add a tag to a Song Unit
  Future<void> addTagToSongUnit(String songUnitId, String tagId) async {
    try {
      _error = null;
      final songUnit = await _libraryRepository.getSongUnit(songUnitId);
      if (songUnit == null) {
        _error = 'Song Unit not found';
        notifyListeners();
        return;
      }

      // Check if tag is already associated (idempotent)
      if (songUnit.tagIds.contains(tagId)) {
        return;
      }

      final updatedSongUnit = songUnit.copyWith(
        tagIds: [...songUnit.tagIds, tagId],
      );
      await _libraryRepository.updateSongUnit(updatedSongUnit);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Remove a tag from a Song Unit
  Future<void> removeTagFromSongUnit(String songUnitId, String tagId) async {
    try {
      _error = null;
      final songUnit = await _libraryRepository.getSongUnit(songUnitId);
      if (songUnit == null) {
        _error = 'Song Unit not found';
        notifyListeners();
        return;
      }

      final updatedSongUnit = songUnit.copyWith(
        tagIds: songUnit.tagIds.where((id) => id != tagId).toList(),
      );
      await _libraryRepository.updateSongUnit(updatedSongUnit);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Batch add tags to multiple Song Units (atomic operation)
  Future<void> batchAddTags(
    List<String> songUnitIds,
    List<String> tagIds,
  ) async {
    try {
      _error = null;
      _isLoading = true;
      notifyListeners();

      // Collect all updates first
      final updates = <Future<void>>[];

      for (final songUnitId in songUnitIds) {
        final songUnit = await _libraryRepository.getSongUnit(songUnitId);
        if (songUnit == null) continue;

        // Add only tags that aren't already associated
        final newTagIds = tagIds.where(
          (tagId) => !songUnit.tagIds.contains(tagId),
        );

        if (newTagIds.isNotEmpty) {
          final updatedSongUnit = songUnit.copyWith(
            tagIds: [...songUnit.tagIds, ...newTagIds],
          );
          updates.add(_libraryRepository.updateSongUnit(updatedSongUnit));
        }
      }

      // Execute all updates
      await Future.wait(updates);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow; // Rethrow for atomicity - caller should handle rollback
    }
  }

  /// Batch remove tags from multiple Song Units (atomic operation)
  Future<void> batchRemoveTags(
    List<String> songUnitIds,
    List<String> tagIds,
  ) async {
    try {
      _error = null;
      _isLoading = true;
      notifyListeners();

      final updates = <Future<void>>[];

      for (final songUnitId in songUnitIds) {
        final songUnit = await _libraryRepository.getSongUnit(songUnitId);
        if (songUnit == null) continue;

        final updatedTagIds = songUnit.tagIds
            .where((tagId) => !tagIds.contains(tagId))
            .toList();

        if (updatedTagIds.length != songUnit.tagIds.length) {
          final updatedSongUnit = songUnit.copyWith(tagIds: updatedTagIds);
          updates.add(_libraryRepository.updateSongUnit(updatedSongUnit));
        }
      }

      await Future.wait(updates);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Get a tag by ID (from cache)
  Tag? getTagById(String id) {
    try {
      return _allTags.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Get a tag by ID from the repository (async, always fresh)
  Future<Tag?> getTagAsync(String id) async {
    return _tagRepository.getTag(id);
  }

  /// Get a tag by name
  Tag? getTagByName(String name) {
    try {
      return _allTags.firstWhere(
        (t) => t.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Get child tags of a parent
  List<Tag> getChildTags(String parentId) {
    return _allTags.where((t) => t.parentId == parentId).toList();
  }

  /// Get root tags (tags without parents)
  List<Tag> getRootTags() {
    return _allTags.where((t) => t.parentId == null).toList();
  }

  /// Clear any error state
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Get tags for the Tag Panel display (only pure user-created tags)
  /// Filters out built-in tags, automatic tags, group tags, and collections
  /// (playlists/queues). Only pure tags without PlaylistMetadata are shown.
  /// Requirements: 19.1, 19.2, 19.3, 19.4
  List<Tag> getTagPanelTags() {
    return _allTags
        .where(
          (tag) =>
              tag.type == TagType.user && !tag.isGroup && !tag.isCollection,
        )
        .toList();
  }

  // ============================================================================
  // Collection Operations (work on any collection: playlist/queue/group)
  // ============================================================================

  /// Create a collection (playlist, queue, or group)
  /// @param isGroup: if true, collection is only visible through parent
  /// @param isQueue: if true, collection appears in Queue Management (not Playlists)
  /// @param parentId: required for groups, optional for playlists
  Future<Tag> createCollection(
    String name, {
    String? parentId,
    bool isGroup = false,
    bool isQueue = false,
  }) async {
    try {
      _error = null;
      final tag = await _tagRepository.createCollection(
        name,
        parentId: parentId,
        isGroup: isGroup,
        isQueue: isQueue,
      );
      return tag;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Create a nested group inside an existing group/collection and add a reference to it.
  /// Returns the created group tag.
  Future<Tag?> createNestedGroup(String parentCollectionId, String name) async {
    try {
      _error = null;
      final parentTag = await _tagRepository.getCollectionTag(parentCollectionId);
      if (parentTag == null || !parentTag.isCollection) {
        _error = 'Parent collection not found';
        notifyListeners();
        return null;
      }

      final group = await _tagRepository.createCollection(
        name,
        parentId: parentCollectionId,
        isGroup: true,
      );

      final metadata = parentTag.playlistMetadata!;
      final nextOrder = metadata.items.isEmpty
          ? 0
          : metadata.items.map((i) => i.order).reduce((a, b) => a > b ? a : b) +
                1;

      await _tagRepository.addItemToCollection(
        parentCollectionId,
        PlaylistItem(
          id: _uuid.v4(),
          type: PlaylistItemType.collectionReference,
          targetId: group.id,
          order: nextOrder,
        ),
      );

      // Refresh in-memory tag cache so playlist panel sees the new group
      await loadTags();

      await _loadCurrentQueueSongs();
      await _updateCachedValues();
      notifyListeners();
      return group;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Reorder playlists in the sidebar by updating their displayOrder values.
  /// [playlistIds] is the new ordered list of playlist tag IDs.
  Future<void> reorderPlaylists(List<String> playlistIds) async {
    try {
      _error = null;
      for (var i = 0; i < playlistIds.length; i++) {
        final tag = await _tagRepository.getCollectionTag(playlistIds[i]);
        if (tag != null && tag.isCollection) {
          final updated = tag.copyWith(
            playlistMetadata: tag.playlistMetadata?.copyWith(displayOrder: i),
          );
          await _tagRepository.updateTag(updated);
        }
      }
      await loadTags();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Get all collections, optionally filtered
  /// @param includeGroups: if false, only returns playlists and queues
  /// @param includeQueues: if false, only returns playlists and groups
  Future<List<Tag>> getCollections({
    bool includeGroups = true,
    bool includeQueues = true,
  }) async {
    try {
      final collections = await _tagRepository.getCollections(
        includeGroups: includeGroups,
      );

      if (!includeQueues) {
        // Filter out queues (collections with currentIndex >= 0)
        return collections.where((c) => !c.isActiveQueue).toList();
      }

      return collections;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  /// Add a song unit to any collection
  Future<void> addSongUnitToCollection(
    String collectionId,
    String songUnitId,
  ) async {
    try {
      _error = null;

      // Get the collection tag with full metadata
      final collectionTag = await _tagRepository.getCollectionTag(collectionId);
      if (collectionTag == null || !collectionTag.isCollection) {
        _error = 'Collection not found';
        notifyListeners();
        return;
      }

      // Get the Song Unit
      final songUnit = await _libraryRepository.getSongUnit(songUnitId);
      if (songUnit == null) {
        _error = 'Song Unit not found';
        notifyListeners();
        return;
      }

      // Create a playlist item
      final metadata =
          collectionTag.playlistMetadata ?? PlaylistMetadata.empty();
      final nextOrder = metadata.items.isEmpty
          ? 0
          : metadata.items.map((i) => i.order).reduce((a, b) => a > b ? a : b) +
                1;

      final item = PlaylistItem(
        id: _uuid.v4(),
        type: PlaylistItemType.songUnit,
        targetId: songUnitId,
        order: nextOrder,
      );

      await _tagRepository.addItemToPlaylist(collectionId, item);

      // Reload queue if this is the active queue
      if (collectionId == _activeQueueId) {
        await _loadCurrentQueueSongs();
        await _updateCachedValues();
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Add a collection reference to any collection
  Future<void> addCollectionReference(String parentId, String targetId) async {
    try {
      _error = null;

      // Check for circular references
      if (await wouldCreateCircularReference(parentId, targetId)) {
        _error = 'Cannot add collection: would create circular reference';
        notifyListeners();
        return;
      }

      final parentTag = await _tagRepository.getCollectionTag(parentId);
      if (parentTag == null || !parentTag.isCollection) {
        _error = 'Parent collection not found';
        notifyListeners();
        return;
      }

      final metadata = parentTag.playlistMetadata ?? PlaylistMetadata.empty();
      final nextOrder = metadata.items.isEmpty
          ? 0
          : metadata.items.map((i) => i.order).reduce((a, b) => a > b ? a : b) +
                1;

      final item = PlaylistItem(
        id: _uuid.v4(),
        type: PlaylistItemType.collectionReference,
        targetId: targetId,
        order: nextOrder,
      );

      await _tagRepository.addItemToPlaylist(parentId, item);

      // Reload queue if this is the active queue
      if (parentId == _activeQueueId) {
        await _loadCurrentQueueSongs();
        await _updateCachedValues();
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Remove an item from any collection
  Future<void> removeFromCollection(String collectionId, String itemId) async {
    try {
      _error = null;
      await _tagRepository.removeItemFromPlaylist(collectionId, itemId);

      // Reload queue if this is the active queue
      if (collectionId == _activeQueueId) {
        await _loadCurrentQueueSongs();
        await _updateCachedValues();
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Reorder items in any collection
  Future<void> reorderCollection(
    String collectionId,
    int oldIndex,
    int newIndex,
  ) async {
    if (oldIndex == newIndex) return;

    try {
      _error = null;
      _suppressEvents = true;

      final collection = await _tagRepository.getCollectionTag(collectionId);
      if (collection == null || !collection.isCollection) {
        _error = 'Collection not found';
        _suppressEvents = false;
        notifyListeners();
        return;
      }

      final metadata = collection.playlistMetadata!;
      final items = List<PlaylistItem>.from(metadata.items);

      // Perform the reorder
      final item = items.removeAt(oldIndex);
      items.insert(newIndex, item);

      // Update order values
      for (var i = 0; i < items.length; i++) {
        items[i] = items[i].copyWith(order: i);
      }

      // Update the collection
      final updatedTag = collection.copyWith(
        playlistMetadata: metadata.copyWith(items: items),
      );
      await _tagRepository.updateTag(updatedTag);
      await _loadTagsSilent();

      // Reload queue if this is the active queue
      if (collectionId == _activeQueueId) {
        await _loadCurrentQueueSongs();
        await _updateCachedValues();
      }

      _suppressEvents = false;
      notifyListeners();
    } catch (e) {
      _suppressEvents = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Toggle lock state of any collection
  Future<void> toggleLock(String collectionId) async {
    try {
      _error = null;
      final tag = await _tagRepository.getCollectionTag(collectionId);
      if (tag == null || !tag.isCollection) {
        _error = 'Collection not found';
        notifyListeners();
        return;
      }

      final metadata = tag.playlistMetadata ?? PlaylistMetadata.empty();
      await _tagRepository.setPlaylistLock(collectionId, !metadata.isLocked);

      // Reload queue display items so group header lock icons update
      await _loadCurrentQueueSongs();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Shuffle any collection (respects locked sub-collections)
  ///
  /// Locked sub-collections (groups referenced via collectionReference whose
  /// target tag has isLocked == true) are treated as atomic blocks:
  /// - Their internal item order is preserved
  /// - They are shuffled as units among the other items
  /// Unlocked items are shuffled independently.
  /// Unlocked groups have their internal songs shuffled too.
  Future<void> shuffle(String collectionId) async {
    try {
      _error = null;
      
      final collection = await _tagRepository.getCollectionTag(collectionId);
      if (collection == null || !collection.isCollection) {
        _error = 'Collection not found';
        notifyListeners();
        return;
      }

      final metadata = collection.playlistMetadata!;
      if (metadata.items.length <= 1) {
        return;
      }

      // Separate items into locked groups and unlocked items
      final unlockedItems = <PlaylistItem>[];
      final lockedGroups = <List<PlaylistItem>>[];

      for (final item in metadata.items) {
        if (item.type == PlaylistItemType.collectionReference) {
          final refTag = await _tagRepository.getCollectionTag(item.targetId);
          if (refTag != null && refTag.isCollection) {
            if (refTag.isLocked) {
              // Locked group - treat as atomic block, preserve internal order
              // Recurse to propagate lock to all nested sub-groups
              lockedGroups.add([item]);
              await _shuffleGroupInternal(item.targetId, parentLocked: true);
            } else {
              // Unlocked group - shuffle its internal songs recursively
              await _shuffleGroupInternal(item.targetId);
              unlockedItems.add(item);
            }
            continue;
          }
        }
        unlockedItems.add(item);
      }
      
      // Shuffle unlocked items
      unlockedItems.shuffle(_random);

      // Shuffle the order of locked groups (but not their contents)
      lockedGroups.shuffle(_random);

      // Interleave unlocked items and locked groups
      final shuffledItems = <PlaylistItem>[];
      var unlockedIndex = 0;
      var lockedGroupIndex = 0;

      while (unlockedIndex < unlockedItems.length ||
          lockedGroupIndex < lockedGroups.length) {
        // Add some unlocked items
        final unlockedBatch = _random.nextInt(3) + 1; // 1-3 items
        for (
          var i = 0;
          i < unlockedBatch && unlockedIndex < unlockedItems.length;
          i++
        ) {
          shuffledItems.add(unlockedItems[unlockedIndex++]);
        }

        // Add a locked group
        if (lockedGroupIndex < lockedGroups.length) {
          shuffledItems.addAll(lockedGroups[lockedGroupIndex++]);
        }
      }

      // Update order values
      for (var i = 0; i < shuffledItems.length; i++) {
        shuffledItems[i] = shuffledItems[i].copyWith(order: i);
      }

      // Update the collection using updateCollectionMetadata (not updateTag!)
      // updateTag() does NOT persist the items list
      await _tagRepository.updateCollectionMetadata(
        collectionId,
        metadata.copyWith(items: shuffledItems),
      );

      // Reload queue if this is the active queue
      if (collectionId == _activeQueueId) {
        await _loadCurrentQueueSongs();
        await _updateCachedValues();
      }

      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint('TagViewModel: shuffle() - caught exception: $e');
      debugPrint('TagViewModel: shuffle() - exception stack trace: $stackTrace');
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Shuffle the internal songs of an unlocked group.
  /// Recursively shuffles nested sub-groups that are also unlocked.
  /// Locked sub-groups are treated as atomic blocks (internal order preserved)
  /// but still shuffled among the other items in their parent.
  /// If [parentLocked] is true, the group inherits the lock — skip shuffling.
  Future<void> _shuffleGroupInternal(
    String groupId, {
    bool parentLocked = false,
  }) async {
    final groupTag = await _tagRepository.getCollectionTag(groupId);
    if (groupTag == null || !groupTag.isCollection) return;
    final meta = groupTag.playlistMetadata;
    if (meta == null || meta.items.length <= 1) {
      // Even with <=1 items, recurse into sub-groups
      if (meta != null) {
        for (final item in meta.items) {
          if (item.type == PlaylistItemType.collectionReference) {
            await _shuffleGroupInternal(
              item.targetId,
              parentLocked: parentLocked || groupTag.isLocked,
            );
          }
        }
      }
      return;
    }

    // If this group is locked (directly or inherited), don't shuffle its items.
    // But still recurse into sub-groups to propagate the lock.
    if (parentLocked || groupTag.isLocked) {
      for (final item in meta.items) {
        if (item.type == PlaylistItemType.collectionReference) {
          await _shuffleGroupInternal(item.targetId, parentLocked: true);
        }
      }
      return;
    }

    // Unlocked group: separate locked sub-groups from unlocked items
    final unlockedItems = <PlaylistItem>[];
    final lockedGroups = <List<PlaylistItem>>[];

    for (final item in meta.items) {
      if (item.type == PlaylistItemType.collectionReference) {
        final refTag = await _tagRepository.getCollectionTag(item.targetId);
        if (refTag != null && refTag.isCollection) {
          if (refTag.isLocked) {
            // Locked sub-group: atomic block, but recurse to propagate lock
            lockedGroups.add([item]);
            await _shuffleGroupInternal(item.targetId, parentLocked: true);
          } else {
            // Unlocked sub-group: shuffle its internals recursively
            await _shuffleGroupInternal(item.targetId);
            unlockedItems.add(item);
          }
          continue;
        }
      }
      unlockedItems.add(item);
    }

    // Shuffle unlocked items
    unlockedItems.shuffle(_random);
    lockedGroups.shuffle(_random);

    // Interleave
    final shuffled = <PlaylistItem>[];
    var ui = 0;
    var li = 0;
    while (ui < unlockedItems.length || li < lockedGroups.length) {
      final batch = _random.nextInt(3) + 1;
      for (var i = 0; i < batch && ui < unlockedItems.length; i++) {
        shuffled.add(unlockedItems[ui++]);
      }
      if (li < lockedGroups.length) {
        shuffled.addAll(lockedGroups[li++]);
      }
    }

    for (var i = 0; i < shuffled.length; i++) {
      shuffled[i] = shuffled[i].copyWith(order: i);
    }
    
    // Use updateCollectionMetadata to persist the shuffled items
    await _tagRepository.updateCollectionMetadata(
      groupId,
      meta.copyWith(items: shuffled),
    );
  }

  /// Deduplicate any collection
  Future<int> deduplicate(String collectionId) async {
    try {
      _error = null;

      final collection = await _tagRepository.getCollectionTag(collectionId);
      if (collection == null || !collection.isCollection) {
        _error = 'Collection not found';
        notifyListeners();
        return 0;
      }

      final metadata = collection.playlistMetadata!;
      if (metadata.items.length <= 1) return 0;

      final originalLength = metadata.items.length;
      final seenTargetIds = <String>{};
      final deduplicated = <PlaylistItem>[];

      for (final item in metadata.items) {
        if (!seenTargetIds.contains(item.targetId)) {
          seenTargetIds.add(item.targetId);
          deduplicated.add(item);
        }
      }

      final removedCount = originalLength - deduplicated.length;

      if (removedCount > 0) {
        // Update order values
        for (var i = 0; i < deduplicated.length; i++) {
          deduplicated[i] = deduplicated[i].copyWith(order: i);
        }

        // Update the collection
        final updatedTag = collection.copyWith(
          playlistMetadata: metadata.copyWith(items: deduplicated),
        );
        await _tagRepository.updateTag(updatedTag);

        // Reload queue if this is the active queue
        if (collectionId == _activeQueueId) {
          await _loadCurrentQueueSongs();
          await _updateCachedValues();
        }

        notifyListeners();
      }

      return removedCount;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return 0;
    }
  }

  /// Clear all items from any collection
  /// For queues, this also recursively removes nested groups that are only referenced here
  Future<void> clearCollection(String collectionId) async {
    try {
      _error = null;

      final collection = await _tagRepository.getCollectionTag(collectionId);
      if (collection == null || !collection.isCollection) {
        _error = 'Collection not found';
        notifyListeners();
        return;
      }

      final metadata = collection.playlistMetadata!;
      
      // If this is a queue, recursively collect and delete groups that are only referenced here
      if (metadata.isQueue) {
        await _recursivelyDeleteQueueOnlyGroups(collectionId, metadata.items);
        // Reload tags after deleting groups
        await loadTags();
      }

      // Use updateCollectionMetadata to properly persist the cleared items
      final clearedMetadata = metadata.copyWith(items: [], currentIndex: -1);
      await _tagRepository.updateCollectionMetadata(collectionId, clearedMetadata);

      // Reload queue if this is the active queue
      if (collectionId == _activeQueueId) {
        _currentQueueSongs = [];
        _queueDisplayItems = [];
        await _updateCachedValues();
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Recursively delete groups that are only referenced in the queue
  Future<void> _recursivelyDeleteQueueOnlyGroups(
    String queueId,
    List<PlaylistItem> items,
  ) async {
    for (final item in items) {
      if (item.type == PlaylistItemType.collectionReference) {
        final groupId = item.targetId;
        final groupTag = await _tagRepository.getCollectionTag(groupId);
        
        if (groupTag != null && groupTag.isGroup) {
          // Recursively process nested groups first
          final groupMetadata = groupTag.playlistMetadata;
          if (groupMetadata != null && groupMetadata.items.isNotEmpty) {
            await _recursivelyDeleteQueueOnlyGroups(groupId, groupMetadata.items);
          }
          
          // Check if this group is only referenced in this queue
          final isOnlyReferencedHere = await _isGroupOnlyReferencedInCollection(groupId, queueId);
          if (isOnlyReferencedHere) {
            debugPrint('Deleting queue-only group: ${groupTag.name} ($groupId)');
            await _tagRepository.deleteTag(groupId);
          }
        }
      }
    }
  }

  /// Check if a group is only referenced in a specific collection
  Future<bool> _isGroupOnlyReferencedInCollection(
    String groupId,
    String collectionId,
  ) async {
    // Get all collections (playlists and queues)
    final allCollections = _allTags.where((t) => t.isCollection).toList();
    
    var referenceCount = 0;
    for (final collection in allCollections) {
      if (collection.playlistMetadata == null) continue;
      
      final hasReference = await _collectionReferencesGroup(
        collection.id,
        groupId,
        collection.playlistMetadata!.items,
      );
      
      if (hasReference) {
        referenceCount++;
        // If referenced in more than one collection, it's not queue-only
        if (referenceCount > 1) return false;
      }
    }
    
    // Group is only referenced if count is exactly 1 (the current collection)
    return referenceCount == 1;
  }

  /// Recursively check if a collection references a group
  Future<bool> _collectionReferencesGroup(
    String collectionId,
    String groupId,
    List<PlaylistItem> items,
  ) async {
    for (final item in items) {
      if (item.type == PlaylistItemType.collectionReference) {
        if (item.targetId == groupId) return true;
        
        // Check nested groups
        final nestedGroup = await _tagRepository.getCollectionTag(item.targetId);
        if (nestedGroup?.playlistMetadata != null) {
          final hasReference = await _collectionReferencesGroup(
            item.targetId,
            groupId,
            nestedGroup!.playlistMetadata!.items,
          );
          if (hasReference) return true;
        }
      }
    }
    return false;
  }

  // ============================================================================
  // Drag-and-Drop Grouping Operations (Requirement 17)
  // ============================================================================

  /// Find a PlaylistItem by its ID within a collection.
  /// Returns null if the item is not found.
  Future<PlaylistItem?> _findPlaylistItem(
    String collectionId,
    String itemId,
  ) async {
    final tag = await _tagRepository.getCollectionTag(collectionId);
    if (tag == null || !tag.isCollection) return null;
    final items = tag.playlistMetadata?.items ?? [];
    try {
      return items.firstWhere((i) => i.id == itemId);
    } catch (_) {
      return null;
    }
  }

  /// Find which collection contains a given PlaylistItem ID.
  /// Searches the [parentCollectionId] and all its child groups recursively.
  /// Returns the collection ID that directly contains the item, or null.
  Future<String?> _findContainingCollection(
    String parentCollectionId,
    String itemId, {
    int depth = 0,
  }) async {
    if (depth > 10) return null;
    // Check the parent collection itself
    final parentItem = await _findPlaylistItem(parentCollectionId, itemId);
    if (parentItem != null) return parentCollectionId;

    // Check child groups recursively
    final parentTag = await _tagRepository.getCollectionTag(parentCollectionId);
    if (parentTag == null || !parentTag.isCollection) return null;
    final items = parentTag.playlistMetadata?.items ?? [];
    for (final item in items) {
      if (item.type == PlaylistItemType.collectionReference) {
        final refTag = await _tagRepository.getCollectionTag(item.targetId);
        if (refTag != null && refTag.isGroup) {
          final found = await _findContainingCollection(
            item.targetId,
            itemId,
            depth: depth + 1,
          );
          if (found != null) return found;
        }
      }
    }
    return null;
  }

  /// Check if a group tag is referenced by any collection other than [excludeCollectionId].
  Future<bool> _isReferencedByOtherCollections(
    String groupId, {
    required String excludeCollectionId,
  }) async {
    final allTags = await _tagRepository.getAllTags();
    for (final tag in allTags) {
      if (tag.id == excludeCollectionId) continue;
      if (!tag.isCollection) continue;
      final items = tag.playlistMetadata?.items ?? [];
      for (final item in items) {
        if (item.type == PlaylistItemType.collectionReference &&
            item.targetId == groupId) {
          return true;
        }
      }
    }
    return false;
  }

  /// Move a song unit into a group.
  ///
  /// [collectionId] - The top-level collection (queue/playlist) that contains the item
  /// [songUnitItemId] - The PlaylistItem ID of the song unit to move
  /// [targetGroupId] - The group collection ID to move the item into
  /// [insertIndex] - Optional position within the group (null = append)
  ///
  /// Requirements: 17.2, 17.4, 17.5
  Future<void> moveSongUnitToGroup(
    String collectionId,
    String songUnitItemId,
    String targetGroupId, {
    int? insertIndex,
  }) async {
    try {
      _error = null;
      _suppressEvents = true;

      // 1. Find the item and its targetId BEFORE removing it
      var sourceCollectionId = await _findContainingCollection(
        collectionId,
        songUnitItemId,
      );
      PlaylistItem? item;

      if (sourceCollectionId != null) {
        item = await _findPlaylistItem(sourceCollectionId, songUnitItemId);
      }

      // Fallback: if the playlistItemId wasn't found (possibly stale after a
      // previous move that rebuilt the queue), scan all items in the collection
      // tree to find a matching songUnit PlaylistItem by its targetId.
      if (item == null) {
        debugPrint(
          'moveSongUnitToGroup: item "$songUnitItemId" not found by PlaylistItem ID — '
          'scanning by targetId as fallback',
        );
        final result = await _findPlaylistItemByTargetId(
          collectionId,
          songUnitItemId,
        );
        if (result != null) {
          sourceCollectionId = result.$1;
          item = result.$2;
          debugPrint(
            'moveSongUnitToGroup: found item by targetId in "$sourceCollectionId"',
          );
        }
      }

      if (sourceCollectionId == null ||
          item == null ||
          item.type != PlaylistItemType.songUnit) {
        debugPrint(
          'moveSongUnitToGroup: item "$songUnitItemId" not found in "$collectionId" or child groups',
        );
        _error = 'Item not found in collection';
        _suppressEvents = false;
        notifyListeners();
        return;
      }

      final targetId = item.targetId;
      final actualItemId = item.id;

      // 2. Remove item from its current location
      await _tagRepository.removeItemFromCollection(
        sourceCollectionId,
        actualItemId,
      );

      // 3. Determine the insert order — read FRESH from DB after the remove
      final groupTag = await _tagRepository.getCollectionTag(targetGroupId);
      final groupItems = groupTag?.playlistMetadata?.items ?? [];
      int order;
      if (insertIndex != null &&
          insertIndex >= 0 &&
          insertIndex <= groupItems.length) {
        order = insertIndex;
      } else {
        order = groupItems.length;
      }

      // 4. Add to target group at specified position
      await _tagRepository.addItemToCollection(
        targetGroupId,
        PlaylistItem(
          id: _uuid.v4(),
          type: PlaylistItemType.songUnit,
          targetId: targetId,
          order: order,
        ),
      );

      // 5. Recompute display orders for both affected collections
      await _recomputeDisplayOrders(sourceCollectionId);
      await _recomputeDisplayOrders(targetGroupId);

      // 6. Refresh in-memory tag cache so UI reads fresh data
      await _loadTagsSilent();

      // 7. Reload queue if active queue is affected
      if (collectionId == _activeQueueId) {
        await _loadCurrentQueueSongs();
        await _updateCachedValues();
      }

      _suppressEvents = false;
      notifyListeners();
    } catch (e) {
      _suppressEvents = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Fallback: find a PlaylistItem by scanning for a matching targetId or
  /// by treating [itemIdOrTargetId] as a potential targetId (song unit ID).
  /// Recursively searches child groups.
  /// Returns (collectionId, PlaylistItem) or null.
  Future<(String, PlaylistItem)?> _findPlaylistItemByTargetId(
    String parentCollectionId,
    String itemIdOrTargetId, {
    int depth = 0,
  }) async {
    if (depth > 10) return null;
    // Check parent collection
    final parentTag = await _tagRepository.getCollectionTag(parentCollectionId);
    if (parentTag == null || !parentTag.isCollection) return null;
    final parentItems = parentTag.playlistMetadata?.items ?? [];

    // First try: treat itemIdOrTargetId as a targetId (song unit ID)
    for (final pi in parentItems) {
      if (pi.type == PlaylistItemType.songUnit &&
          pi.targetId == itemIdOrTargetId) {
        return (parentCollectionId, pi);
      }
    }

    // Check child groups recursively
    for (final pi in parentItems) {
      if (pi.type == PlaylistItemType.collectionReference) {
        final groupTag = await _tagRepository.getCollectionTag(pi.targetId);
        if (groupTag != null && groupTag.isGroup) {
          final result = await _findPlaylistItemByTargetId(
            pi.targetId,
            itemIdOrTargetId,
            depth: depth + 1,
          );
          if (result != null) return result;
        }
      }
    }

    return null;
  }

  /// Move a song unit out of a group to the top-level collection.
  ///
  /// [groupId] - The group collection ID that currently contains the item
  /// [songUnitItemId] - The PlaylistItem ID of the song unit to move out
  /// [parentCollectionId] - The top-level collection to move the item into
  /// [insertIndex] - Position in the parent collection to insert at
  ///
  /// Requirements: 17.3, 17.5
  Future<void> moveSongUnitOutOfGroup(
    String groupId,
    String songUnitItemId,
    String parentCollectionId, {
    required int insertIndex,
  }) async {
    try {
      _error = null;
      _suppressEvents = true;

      // 1. Find the item and its targetId BEFORE removing it
      var item = await _findPlaylistItem(groupId, songUnitItemId);
      var actualGroupId = groupId;

      // Fallback: if not found by playlistItemId, try scanning by targetId
      if (item == null || item.type != PlaylistItemType.songUnit) {
        debugPrint(
          'moveSongUnitOutOfGroup: item "$songUnitItemId" not found in group "$groupId" — '
          'trying fallback by targetId',
        );
        final result = await _findPlaylistItemByTargetId(
          groupId,
          songUnitItemId,
        );
        if (result != null) {
          actualGroupId = result.$1;
          item = result.$2;
        }
        // Also try searching from the parent collection
        if (item == null || item.type != PlaylistItemType.songUnit) {
          final parentResult = await _findPlaylistItemByTargetId(
            parentCollectionId,
            songUnitItemId,
          );
          if (parentResult != null) {
            actualGroupId = parentResult.$1;
            item = parentResult.$2;
          }
        }
      }

      if (item == null || item.type != PlaylistItemType.songUnit) {
        _error = 'Item not found in group or not a song unit';
        _suppressEvents = false;
        notifyListeners();
        return;
      }

      final targetId = item.targetId;
      final actualItemId = item.id;

      // 2. Remove from group
      await _tagRepository.removeItemFromCollection(
        actualGroupId,
        actualItemId,
      );

      // 3. Add to parent collection at drop position
      await _tagRepository.addItemToCollection(
        parentCollectionId,
        PlaylistItem(
          id: _uuid.v4(),
          type: PlaylistItemType.songUnit,
          targetId: targetId,
          order: insertIndex,
        ),
      );

      // 4. Recompute display orders
      await _recomputeDisplayOrders(actualGroupId);
      await _recomputeDisplayOrders(parentCollectionId);

      // 5. Refresh in-memory tag cache so UI reads fresh data
      await _loadTagsSilent();

      // 6. Reload queue if active queue is affected
      if (parentCollectionId == _activeQueueId) {
        await _loadCurrentQueueSongs();
        await _updateCachedValues();
      }

      _suppressEvents = false;
      notifyListeners();
    } catch (e) {
      _suppressEvents = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Move an entire group to a new position within its parent collection.
  ///
  /// [parentCollectionId] - The collection containing the group reference
  /// [groupItemId] - The PlaylistItem ID of the group reference to move
  /// [newIndex] - The new position index for the group
  ///
  /// Requirements: 17.7
  Future<void> moveGroup(
    String parentCollectionId,
    String groupItemId,
    int newIndex,
  ) async {
    try {
      _error = null;
      _suppressEvents = true;

      // Find which collection actually contains this group item
      // (it may be nested inside a child group, not directly in parentCollectionId)
      final actualParentId = await _findContainingCollection(
        parentCollectionId,
        groupItemId,
      );
      if (actualParentId == null) {
        _error = 'Group item not found in collection';
        _suppressEvents = false;
        notifyListeners();
        return;
      }

      final collection = await _tagRepository.getCollectionTag(actualParentId);
      if (collection == null || !collection.isCollection) {
        _error = 'Collection not found';
        _suppressEvents = false;
        notifyListeners();
        return;
      }

      final metadata = collection.playlistMetadata!;
      final items = List<PlaylistItem>.from(metadata.items);

      // Find the current index of the group item
      final currentIndex = items.indexWhere((i) => i.id == groupItemId);
      if (currentIndex == -1) {
        _error = 'Group item not found in collection';
        _suppressEvents = false;
        notifyListeners();
        return;
      }

      // Clamp newIndex to valid range
      final clampedIndex = newIndex.clamp(0, items.length - 1);
      if (currentIndex == clampedIndex) {
        _suppressEvents = false;
        return;
      }

      // Perform the move
      final item = items.removeAt(currentIndex);
      items.insert(clampedIndex, item);

      // Reorder using the repository
      final reorderedIds = items.map((i) => i.id).toList();
      await _tagRepository.reorderCollectionItems(actualParentId, reorderedIds);

      // Refresh in-memory tag cache so UI reads fresh data
      await _loadTagsSilent();

      // Reload queue if active queue is affected
      if (parentCollectionId == _activeQueueId ||
          actualParentId == _activeQueueId) {
        await _loadCurrentQueueSongs();
        await _updateCachedValues();
      }

      _suppressEvents = false;
      notifyListeners();
    } catch (e) {
      _suppressEvents = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Move a group into another group (nesting it).
  ///
  /// Removes the group's collectionReference from its current parent and adds
  /// it as a collectionReference inside [targetGroupId].
  Future<void> moveGroupIntoGroup(
    String rootCollectionId,
    String groupItemId,
    String targetGroupId,
  ) async {
    try {
      _error = null;
      _suppressEvents = true;

      // Find which collection currently contains this group item
      final sourceParentId = await _findContainingCollection(
        rootCollectionId,
        groupItemId,
      );
      if (sourceParentId == null) {
        _error = 'Group item not found';
        _suppressEvents = false;
        notifyListeners();
        return;
      }

      final item = await _findPlaylistItem(sourceParentId, groupItemId);
      if (item == null || item.type != PlaylistItemType.collectionReference) {
        _error = 'Group reference not found';
        _suppressEvents = false;
        notifyListeners();
        return;
      }

      final groupId = item.targetId;

      // Don't move a group into itself
      if (groupId == targetGroupId) return;

      // Remove from current parent
      await _tagRepository.removeItemFromCollection(sourceParentId, item.id);

      // Add as collectionReference in target group
      final targetTag = await _tagRepository.getCollectionTag(targetGroupId);
      final targetItems = targetTag?.playlistMetadata?.items ?? [];
      await _tagRepository.addItemToCollection(
        targetGroupId,
        PlaylistItem(
          id: _uuid.v4(),
          type: PlaylistItemType.collectionReference,
          targetId: groupId,
          order: targetItems.length,
        ),
      );

      await _recomputeDisplayOrders(sourceParentId);
      await _recomputeDisplayOrders(targetGroupId);
      await _loadTagsSilent();

      if (rootCollectionId == _activeQueueId) {
        await _loadCurrentQueueSongs();
        await _updateCachedValues();
      }

      _suppressEvents = false;
      notifyListeners();
    } catch (e) {
      _suppressEvents = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Move a group out of its current parent to a target collection at a given index.
  ///
  /// Removes the group's collectionReference from its current parent and inserts
  /// it into [targetCollectionId] at [insertIndex].
  Future<void> moveGroupOutToCollection(
    String rootCollectionId,
    String groupItemId,
    String targetCollectionId,
    int insertIndex,
  ) async {
    try {
      _error = null;
      _suppressEvents = true;

      // Find which collection currently contains this group item
      final sourceParentId = await _findContainingCollection(
        rootCollectionId,
        groupItemId,
      );
      if (sourceParentId == null) {
        _error = 'Group item not found';
        _suppressEvents = false;
        notifyListeners();
        return;
      }

      // Already in the target — just reorder
      if (sourceParentId == targetCollectionId) {
        _suppressEvents = false;
        await moveGroup(rootCollectionId, groupItemId, insertIndex);
        return;
      }

      final item = await _findPlaylistItem(sourceParentId, groupItemId);
      if (item == null || item.type != PlaylistItemType.collectionReference) {
        _error = 'Group reference not found';
        _suppressEvents = false;
        notifyListeners();
        return;
      }

      final groupId = item.targetId;

      // Remove from current parent
      await _tagRepository.removeItemFromCollection(sourceParentId, item.id);

      // Add to target collection at specified index
      await _tagRepository.addItemToCollection(
        targetCollectionId,
        PlaylistItem(
          id: _uuid.v4(),
          type: PlaylistItemType.collectionReference,
          targetId: groupId,
          order: insertIndex,
        ),
      );

      await _recomputeDisplayOrders(sourceParentId);
      await _recomputeDisplayOrders(targetCollectionId);
      await _loadTagsSilent();

      if (rootCollectionId == _activeQueueId) {
        await _loadCurrentQueueSongs();
        await _updateCachedValues();
      }

      _suppressEvents = false;
      notifyListeners();
    } catch (e) {
      _suppressEvents = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Recompute display orders for all items in a collection.
  ///
  /// Sorts items by their current order and reassigns sequential order values
  /// starting from 0. This ensures consistent ordering after move operations.
  Future<void> _recomputeDisplayOrders(String collectionId) async {
    final tag = await _tagRepository.getCollectionTag(collectionId);
    if (tag == null || !tag.isCollection) return;

    final metadata = tag.playlistMetadata;
    if (metadata == null || metadata.items.isEmpty) return;

    final sortedItems = List<PlaylistItem>.from(metadata.items)
      ..sort((a, b) => a.order.compareTo(b.order));

    final reorderedIds = sortedItems.map((i) => i.id).toList();
    await _tagRepository.reorderCollectionItems(collectionId, reorderedIds);
  }

  /// Dissolve a group: move all songs from the group to the parent collection,
  /// then remove the group reference. Songs and nested sub-group references
  /// are inserted at the group's position (only the outermost group is removed).
  Future<void> dissolveGroup(String parentCollectionId, String groupId) async {
    try {
      _error = null;
      _suppressEvents = true;

      // Resolve the actual parent: if the group isn't a direct child of
      // parentCollectionId, use the group tag's own parentId instead.
      final actualParentId = await _resolveParentForGroup(
        parentCollectionId,
        groupId,
      );
      if (actualParentId == null) {
        _suppressEvents = false;
        return;
      }

      final parent = await _tagRepository.getCollectionTag(actualParentId);
      if (parent == null || !parent.isCollection) {
        _suppressEvents = false;
        return;
      }

      final parentMeta = parent.playlistMetadata!;
      final items = List<PlaylistItem>.from(parentMeta.items);

      // Find the group reference item
      final groupRefIndex = items.indexWhere(
        (i) =>
            i.type == PlaylistItemType.collectionReference &&
            i.targetId == groupId,
      );
      if (groupRefIndex == -1) {
        _suppressEvents = false;
        return;
      }

      // Get ALL of the group's items (songs AND nested sub-group references)
      final groupTag = await _tagRepository.getCollectionTag(groupId);
      if (groupTag == null || groupTag.playlistMetadata == null) {
        _suppressEvents = false;
        return;
      }

      final groupItems = groupTag.playlistMetadata!.items;

      // Remove the group reference
      items.removeAt(groupRefIndex);

      // Insert all group items (songs + collectionReferences) at the same position
      for (var i = 0; i < groupItems.length; i++) {
        items.insert(
          groupRefIndex + i,
          PlaylistItem(
            id: _uuid.v4(),
            type: groupItems[i].type,
            targetId: groupItems[i].targetId,
            order: groupRefIndex + i,
            inheritLock: groupItems[i].inheritLock,
          ),
        );
      }

      // Reorder all items
      for (var i = 0; i < items.length; i++) {
        items[i] = items[i].copyWith(order: i);
      }

      // Save updated parent
      final updatedMetadata = parentMeta.copyWith(
        items: items,
        updatedAt: DateTime.now(),
      );
      await _tagRepository.updateCollectionMetadata(actualParentId, updatedMetadata);

      // Delete the group tag only if no other collection references it
      if (!await _isReferencedByOtherCollections(
        groupId,
        excludeCollectionId: actualParentId,
      )) {
        await _tagRepository.deleteTag(groupId);
      }

      // Refresh in-memory tag cache so UI reads fresh data
      await _loadTagsSilent();

      // Reload queue if active queue or any ancestor is affected
      await _loadCurrentQueueSongs();
      await _updateCachedValues();

      _suppressEvents = false;
      notifyListeners();
    } catch (e) {
      _suppressEvents = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Remove a group and all its songs from a parent collection.
  /// Finds the collectionReference item by target group ID and removes it.
  /// Only deletes the group tag if no other collection references it.
  Future<void> removeGroupFromQueue(
    String parentCollectionId,
    String groupId,
  ) async {
    try {
      _error = null;
      _suppressEvents = true;

      // Resolve the actual parent: if the group isn't a direct child of
      // parentCollectionId, use the group tag's own parentId instead.
      final actualParentId = await _resolveParentForGroup(
        parentCollectionId,
        groupId,
      );
      if (actualParentId == null) {
        _error = 'Group reference not found in any parent';
        _suppressEvents = false;
        notifyListeners();
        return;
      }

      final parent = await _tagRepository.getCollectionTag(actualParentId);
      if (parent == null || !parent.isCollection) {
        _suppressEvents = false;
        return;
      }

      final parentMeta = parent.playlistMetadata!;

      // Find the collectionReference item that points to this group
      final refItem = parentMeta.items.firstWhere(
        (i) =>
            i.type == PlaylistItemType.collectionReference &&
            i.targetId == groupId,
        orElse: () => throw StateError('Group reference not found'),
      );

      // Remove the reference from parent
      await _tagRepository.removeItemFromCollection(actualParentId, refItem.id);

      // Only delete the group tag if no other collection references it
      if (!await _isReferencedByOtherCollections(
        groupId,
        excludeCollectionId: actualParentId,
      )) {
        await _tagRepository.deleteTag(groupId);
      }

      // Refresh in-memory tag cache so UI reads fresh data
      await _loadTagsSilent();

      // Reload queue
      await _loadCurrentQueueSongs();
      await _updateCachedValues();

      _suppressEvents = false;
      notifyListeners();
    } catch (e) {
      _suppressEvents = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Resolve the actual parent collection for a group.
  /// If [parentCollectionId] directly contains a collectionReference to [groupId],
  /// returns [parentCollectionId]. Otherwise falls back to the group tag's parentId.
  Future<String?> _resolveParentForGroup(
    String parentCollectionId,
    String groupId,
  ) async {
    // First check if the group is a direct child of the given parent
    final parent = await _tagRepository.getCollectionTag(parentCollectionId);
    if (parent != null && parent.playlistMetadata != null) {
      final hasRef = parent.playlistMetadata!.items.any(
        (i) =>
            i.type == PlaylistItemType.collectionReference &&
            i.targetId == groupId,
      );
      if (hasRef) return parentCollectionId;
    }

    // Fall back to the group tag's own parentId
    final groupTag = await _tagRepository.getCollectionTag(groupId);
    if (groupTag?.parentId != null) {
      // Verify the parentId actually contains the reference
      final realParent = await _tagRepository.getCollectionTag(groupTag!.parentId!);
      if (realParent != null && realParent.playlistMetadata != null) {
        final hasRef = realParent.playlistMetadata!.items.any(
          (i) =>
              i.type == PlaylistItemType.collectionReference &&
              i.targetId == groupId,
        );
        if (hasRef) return groupTag.parentId;
      }
    }

    return null;
  }

  /// Resolve collection content (expand references recursively)
  Future<List<SongUnit>> resolveContent(
    String collectionId, {
    int depth = 0,
    Map<String, Map<String, dynamic>>? temporarySongUnits,
  }) async {
    // Prevent infinite recursion
    if (depth > 10) {
      debugPrint('Max collection nesting depth reached');
      return [];
    }

    final tag = await _tagRepository.getCollectionTag(collectionId);
    if (tag == null || !tag.isCollection) return [];

    final metadata = tag.playlistMetadata;
    if (metadata == null) return [];

    final result = <SongUnit>[];

    for (final item in metadata.items) {
      switch (item.type) {
        case PlaylistItemType.songUnit:
          // Check temporary song units first
          if (item.targetId.startsWith('temp_') && temporarySongUnits != null) {
            final tempData = temporarySongUnits[item.targetId];
            if (tempData != null) {
              try {
                result.add(SongUnit.fromJson(tempData));
                continue;
              } catch (e) {
                debugPrint(
                  'Failed to deserialize temporary song unit ${item.targetId}: $e',
                );
              }
            }
          }
          final songUnit = await _libraryRepository.getSongUnit(item.targetId);
          if (songUnit != null) {
            result.add(songUnit);
          }
          break;

        case PlaylistItemType.collectionReference:
          // Recursively resolve referenced collection
          final nestedSongs = await resolveContent(
            item.targetId,
            depth: depth + 1,
            temporarySongUnits: temporarySongUnits,
          );
          result.addAll(nestedSongs);
          break;
      }
    }

    return result;
  }

  /// Check if adding a reference would create a circular reference
  Future<bool> wouldCreateCircularReference(
    String parentId,
    String targetId,
  ) async {
    // If parent and target are the same, it's circular
    if (parentId == targetId) return true;

    // Check if target already references parent (directly or indirectly)
    final visited = <String>{};
    return _checkCircularReference(targetId, parentId, visited);
  }

  /// Recursively check for circular references
  Future<bool> _checkCircularReference(
    String currentId,
    String searchForId,
    Set<String> visited,
  ) async {
    if (visited.contains(currentId)) return false;
    visited.add(currentId);

    final tag = await _tagRepository.getCollectionTag(currentId);
    if (tag == null || !tag.isCollection) return false;

    final metadata = tag.playlistMetadata;
    if (metadata == null) return false;

    for (final item in metadata.items) {
      if (item.type == PlaylistItemType.collectionReference) {
        if (item.targetId == searchForId) return true;
        if (await _checkCircularReference(
          item.targetId,
          searchForId,
          visited,
        )) {
          return true;
        }
      }
    }

    return false;
  }

  // ============================================================================
  // Active Queue Operations (special handling for the currently playing queue)
  // ============================================================================

  /// Add a collection (playlist/tag) to the active queue as a group.
  ///
  /// Creates a new group in the queue containing all song units from the
  /// source collection. The group inherits the source collection's lock state.
  /// After creation, the group's lock state is independent from the source.
  ///
  /// [collectionId] - The source collection to add to the queue
  /// [overrideLock] - If provided, overrides the inherited lock state
  ///
  /// Requirements: 8.2, 8.3, 8.4, 8.5
  Future<Tag?> addCollectionToQueue(
    String collectionId, {
    bool? overrideLock,
  }) async {
    try {
      _error = null;

      // Get the source collection
      final sourceCollection = await _tagRepository.getCollectionTag(collectionId);
      if (sourceCollection == null || !sourceCollection.isCollection) {
        _error = 'Collection not found';
        notifyListeners();
        return null;
      }

      // Get the source collection's items directly (not resolved)
      final sourceItems = await _tagRepository.getCollectionItems(collectionId);
      if (sourceItems.isEmpty) {
        _error = 'Collection is empty';
        notifyListeners();
        return null;
      }

      // Determine lock state: use override if provided, otherwise inherit from source
      final lockState = overrideLock ?? sourceCollection.isLocked;

      // Create a new group under the active queue (distinct collection ID)
      final group = await _tagRepository.createCollection(
        sourceCollection.name,
        parentId: _activeQueueId,
        isGroup: true,
      );

      // Copy lock state from source playlist
      if (lockState) {
        await _tagRepository.setCollectionLock(group.id, true);
      }

      // Deep copy all items (including nested groups) into the new group
      final copiedCount = await _deepCopyCollectionItems(
        sourceItems: sourceItems,
        targetCollectionId: group.id,
      );

      // If no items were actually added, clean up the empty group
      if (copiedCount == 0) {
        await _tagRepository.deleteTag(group.id);
        _error = 'Collection is empty';
        notifyListeners();
        return null;
      }

      // Add a reference to the group in the active queue
      final activeQueue = await _getActiveQueue();
      if (activeQueue?.playlistMetadata == null) return null;

      final metadata = activeQueue!.playlistMetadata!;
      final nextOrder = metadata.items.isEmpty
          ? 0
          : metadata.items.map((i) => i.order).reduce((a, b) => a > b ? a : b) +
                1;

      final groupRef = PlaylistItem(
        id: _uuid.v4(),
        type: PlaylistItemType.collectionReference,
        targetId: group.id,
        order: nextOrder,
      );

      await _tagRepository.addItemToCollection(_activeQueueId, groupRef);

      // Reload queue songs
      await _loadCurrentQueueSongs();
      await _updateCachedValues();
      notifyListeners();

      // Return the created group (re-fetch to get updated metadata)
      return await _tagRepository.getCollectionTag(group.id);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Recursively deep-copy items from a source collection into a target collection.
  /// Handles songUnit items and nested collectionReference items (groups).
  /// Returns the total number of song units copied.
  Future<int> _deepCopyCollectionItems({
    required List<PlaylistItem> sourceItems,
    required String targetCollectionId,
    int depth = 0,
  }) async {
    if (depth > 10) return 0; // Prevent infinite recursion

    var orderCounter = 0;
    var songCount = 0;

    for (final item in sourceItems) {
      if (item.type == PlaylistItemType.songUnit) {
        final songUnit = await _libraryRepository.getSongUnit(item.targetId);
        if (songUnit == null) continue;

        await _tagRepository.addItemToCollection(
          targetCollectionId,
          PlaylistItem(
            id: _uuid.v4(),
            type: PlaylistItemType.songUnit,
            targetId: item.targetId,
            order: orderCounter++,
          ),
        );
        songCount++;
      } else if (item.type == PlaylistItemType.collectionReference) {
        final refTag = await _tagRepository.getCollectionTag(item.targetId);
        if (refTag == null) continue;

        final subGroup = await _tagRepository.createCollection(
          refTag.name,
          parentId: targetCollectionId,
          isGroup: true,
        );

        if (refTag.isLocked) {
          await _tagRepository.setCollectionLock(subGroup.id, true);
        }

        // Recursively copy items from the referenced collection
        final refItems = await _tagRepository.getCollectionItems(item.targetId);
        final subCopied = await _deepCopyCollectionItems(
          sourceItems: refItems,
          targetCollectionId: subGroup.id,
          depth: depth + 1,
        );

        if (subCopied == 0) {
          await _tagRepository.deleteTag(subGroup.id);
          continue;
        }

        await _tagRepository.addItemToCollection(
          targetCollectionId,
          PlaylistItem(
            id: _uuid.v4(),
            type: PlaylistItemType.collectionReference,
            targetId: subGroup.id,
            order: orderCounter++,
          ),
        );
        songCount += subCopied;
      }
    }

    return songCount;
  }

  /// Add items from a collection directly to the queue without wrapping in an outer group.
  /// Song units become top-level queue items; collectionReferences get deep-copied as sub-groups.
  /// Returns the number of items added.
  Future<int> addCollectionItemsToQueue(String collectionId) async {
    try {
      _error = null;

      final sourceCollection = await _tagRepository.getCollectionTag(collectionId);
      if (sourceCollection == null || !sourceCollection.isCollection) {
        _error = 'Collection not found';
        notifyListeners();
        return 0;
      }

      final sourceItems = await _tagRepository.getCollectionItems(collectionId);
      if (sourceItems.isEmpty) {
        _error = 'Collection is empty';
        notifyListeners();
        return 0;
      }

      final activeQueue = await _getActiveQueue();
      if (activeQueue?.playlistMetadata == null) return 0;

      final metadata = activeQueue!.playlistMetadata!;
      var nextOrder = metadata.items.isEmpty
          ? 0
          : metadata.items.map((i) => i.order).reduce((a, b) => a > b ? a : b) +
                1;

      var addedCount = 0;

      for (final item in sourceItems) {
        if (item.type == PlaylistItemType.songUnit) {
          final songUnit = await _libraryRepository.getSongUnit(item.targetId);
          if (songUnit == null) continue;

          await _tagRepository.addItemToCollection(
            _activeQueueId,
            PlaylistItem(
              id: _uuid.v4(),
              type: PlaylistItemType.songUnit,
              targetId: item.targetId,
              order: nextOrder++,
            ),
          );
          addedCount++;
        } else if (item.type == PlaylistItemType.collectionReference) {
          // Deep-copy the sub-group recursively (preserves nested groups)
          final refTag = await _tagRepository.getCollectionTag(item.targetId);
          if (refTag == null) continue;

          final subGroup = await _tagRepository.createCollection(
            refTag.name,
            parentId: _activeQueueId,
            isGroup: true,
          );

          if (refTag.isLocked) {
            await _tagRepository.setCollectionLock(subGroup.id, true);
          }

          final refItems = await _tagRepository.getCollectionItems(
            item.targetId,
          );
          final subCopied = await _deepCopyCollectionItems(
            sourceItems: refItems,
            targetCollectionId: subGroup.id,
          );

          if (subCopied == 0) {
            await _tagRepository.deleteTag(subGroup.id);
            continue;
          }

          await _tagRepository.addItemToCollection(
            _activeQueueId,
            PlaylistItem(
              id: _uuid.v4(),
              type: PlaylistItemType.collectionReference,
              targetId: subGroup.id,
              order: nextOrder++,
            ),
          );
          addedCount += subCopied;
        }
      }

      if (addedCount > 0) {
        await _loadCurrentQueueSongs();
        await _updateCachedValues();
        notifyListeners();
      }

      return addedCount;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return 0;
    }
  }

  /// Get all available queues (collections marked as queues, excluding groups)
  Future<List<Tag>> get allQueues async {
    final collections = await _tagRepository.getCollections(
      includeGroups: false,
    );
    return collections.where((c) => c.isQueueCollection).toList();
  }

  /// Switch to a different queue (saves/restores playback state)
  Future<void> switchQueue(
    String queueId, {
    required PlayerViewModel playerVM,
  }) async {
    try {
      if (queueId == _activeQueueId) {
        return; // Already on this queue
      }

      final targetQueue = await _tagRepository.getCollectionTag(queueId);
      if (targetQueue == null || !targetQueue.isCollection) {
        _error = 'Queue not found';
        notifyListeners();
        return;
      }

      // Save current queue's playback state
      final currentQueue = await _getActiveQueue();
      if (currentQueue?.playlistMetadata != null) {
        final currentPosition = playerVM.position.inMilliseconds;
        final isPlaying = playerVM.isPlaying;

        await _updateActiveQueue(
          currentQueue!.playlistMetadata!.copyWith(
            playbackPositionMs: currentPosition,
            wasPlaying: isPlaying,
          ),
        );
      }

      // Switch to target queue
      _activeQueueId = queueId;
      await _settingsRepository.setActiveQueueId(queueId);
      await _loadCurrentQueueSongs();
      await _updateCachedValues();
      notifyListeners();

      // Restore target queue's playback state
      final targetMetadata = targetQueue.playlistMetadata;
      if (targetMetadata != null &&
          targetMetadata.currentIndex >= 0 &&
          targetMetadata.currentIndex < _currentQueueSongs.length) {
        final songToPlay = _currentQueueSongs[targetMetadata.currentIndex];

        // Start playing the song
        await playerVM.play(songToPlay);

        // Wait for the player to be ready
        var attempts = 0;
        while (attempts < 20 &&
            playerVM.status != PlaybackStatus.playing &&
            playerVM.status != PlaybackStatus.paused) {
          await Future.delayed(const Duration(milliseconds: 50));
          attempts++;
        }

        // Restore playback position
        if (targetMetadata.playbackPositionMs > 0) {
          await playerVM.seekTo(
            Duration(milliseconds: targetMetadata.playbackPositionMs),
          );
        }

        // If the queue wasn't playing when we left it, pause
        if (!targetMetadata.wasPlaying) {
          await playerVM.pause();
        }
      } else {
        // No song to play, stop playback
        await playerVM.stop();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Duplicate a queue
  Future<void> duplicateQueue(String queueId) async {
    try {
      final sourceQueue = await _tagRepository.getCollectionTag(queueId);
      if (sourceQueue == null || !sourceQueue.isCollection) {
        _error = 'Queue not found';
        notifyListeners();
        return;
      }

      final metadata = sourceQueue.playlistMetadata!;

      // Create new collection with copied metadata
      final newTag = await _tagRepository.createCollection(
        '${sourceQueue.name} (Copy)',
      );

      // Update with copied items and reset playback state
      final newMetadata = metadata.copyWith(
        currentIndex: -1,
        playbackPositionMs: 0,
        wasPlaying: false,
        temporarySongUnits: metadata.temporarySongUnits != null
            ? Map.from(metadata.temporarySongUnits!)
            : null,
      );

      final updatedTag = newTag.copyWith(playlistMetadata: newMetadata);
      await _tagRepository.updateTag(updatedTag);

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Request a song (add to end of active queue)
  /// Returns true if this was the first song added to an empty queue
  Future<bool> requestSong(String songUnitId) async {
    try {
      _error = null;
      final songUnit = await _libraryRepository.getSongUnit(songUnitId);
      if (songUnit == null) {
        _error = 'Song Unit not found';
        notifyListeners();
        return false;
      }

      return await requestSongWithUnit(songUnit);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Request a song with a SongUnit object (for temporary song units not in library)
  /// Returns true if this was the first song added to an empty queue
  Future<bool> requestSongWithUnit(SongUnit songUnit) async {
    try {
      _error = null;
      final activeQueue = await _getActiveQueue();
      if (activeQueue?.playlistMetadata == null) return false;

      final metadata = activeQueue!.playlistMetadata!;
      final wasEmpty = _currentQueueSongs.isEmpty;

      // Create new playlist item
      final newItem = PlaylistItem(
        id: _uuid.v4(),
        type: PlaylistItemType.songUnit,
        targetId: songUnit.id,
        order: metadata.items.length,
      );

      // Separate temporary song units
      final temporarySongUnits = <String, Map<String, dynamic>>{};
      if (metadata.temporarySongUnits != null) {
        temporarySongUnits.addAll(metadata.temporarySongUnits!);
      }
      if (songUnit.id.startsWith('temp_')) {
        temporarySongUnits[songUnit.id] = songUnit.toJson();
      }

      final newIndex = metadata.currentIndex < 0 ? 0 : metadata.currentIndex;

      await _updateActiveQueue(
        metadata.copyWith(
          items: [...metadata.items, newItem],
          currentIndex: newIndex,
          temporarySongUnits: temporarySongUnits.isNotEmpty
              ? temporarySongUnits
              : null,
        ),
      );

      await _loadCurrentQueueSongs();
      await _updateCachedValues();
      notifyListeners();
      return wasEmpty;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Batch request multiple songs at once (single DB write + single notify)
  /// Returns true if the queue was empty before adding.
  Future<bool> requestSongsBatch(List<SongUnit> songUnits) async {
    if (songUnits.isEmpty) return false;
    try {
      _error = null;
      final activeQueue = await _getActiveQueue();
      if (activeQueue?.playlistMetadata == null) return false;

      final metadata = activeQueue!.playlistMetadata!;
      final wasEmpty = _currentQueueSongs.isEmpty;

      // Build all new items at once
      final newItems = <PlaylistItem>[];
      final temporarySongUnits = <String, Map<String, dynamic>>{};
      if (metadata.temporarySongUnits != null) {
        temporarySongUnits.addAll(metadata.temporarySongUnits!);
      }

      for (var i = 0; i < songUnits.length; i++) {
        final songUnit = songUnits[i];
        newItems.add(
          PlaylistItem(
            id: _uuid.v4(),
            type: PlaylistItemType.songUnit,
            targetId: songUnit.id,
            order: metadata.items.length + i,
          ),
        );
        if (songUnit.id.startsWith('temp_')) {
          temporarySongUnits[songUnit.id] = songUnit.toJson();
        }
      }

      final newIndex = metadata.currentIndex < 0 ? 0 : metadata.currentIndex;

      await _updateActiveQueue(
        metadata.copyWith(
          items: [...metadata.items, ...newItems],
          currentIndex: newIndex,
          temporarySongUnits: temporarySongUnits.isNotEmpty
              ? temporarySongUnits
              : null,
        ),
      );

      await _loadCurrentQueueSongs();
      await _updateCachedValues();
      notifyListeners();
      return wasEmpty;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Request a priority song (insert after current song in active queue)
  Future<void> requestPrioritySong(String songUnitId) async {
    try {
      _error = null;
      final songUnit = await _libraryRepository.getSongUnit(songUnitId);
      if (songUnit == null) {
        _error = 'Song Unit not found';
        notifyListeners();
        return;
      }

      final activeQueue = await _getActiveQueue();
      if (activeQueue?.playlistMetadata == null) return;

      final metadata = activeQueue!.playlistMetadata!;

      if (_currentQueueSongs.isEmpty || metadata.currentIndex < 0) {
        // Queue is empty, just add to the beginning
        final newItem = PlaylistItem(
          id: _uuid.v4(),
          type: PlaylistItemType.songUnit,
          targetId: songUnit.id,
          order: 0,
        );

        await _updateActiveQueue(
          metadata.copyWith(items: [newItem], currentIndex: 0),
        );
      } else {
        // Insert after current song
        final insertIndex = metadata.currentIndex + 1;

        // Create new item and reorder
        final newItem = PlaylistItem(
          id: _uuid.v4(),
          type: PlaylistItemType.songUnit,
          targetId: songUnit.id,
          order: insertIndex,
        );

        final updatedItems = [
          ...metadata.items.sublist(0, insertIndex),
          newItem,
          ...metadata.items
              .sublist(insertIndex)
              .map((item) => item.copyWith(order: item.order + 1)),
        ];

        await _updateActiveQueue(metadata.copyWith(items: updatedItems));
      }

      await _loadCurrentQueueSongs();
      await _updateCachedValues();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ============================================================================
  // Playback Control
  // ============================================================================

  /// Set playback mode
  void setPlaybackMode(PlaybackMode mode) async {
    final activeQueue = await _getActiveQueue();
    if (activeQueue?.playlistMetadata == null) return;

    final metadata = activeQueue!.playlistMetadata!;

    // Disable repeat modes when remove after play is enabled
    if (metadata.removeAfterPlay &&
        (mode == PlaybackMode.repeatAll || mode == PlaybackMode.repeatOne)) {
      return;
    }
    _playbackMode = mode;

    // Save playback mode to storage
    _savePlaybackMode();

    notifyListeners();
  }

  /// Set whether to remove song from queue after playing
  void setRemoveAfterPlay(bool value) async {
    final activeQueue = await _getActiveQueue();
    if (activeQueue?.playlistMetadata == null) return;

    final metadata = activeQueue!.playlistMetadata!;

    // Disable repeat modes when remove after play is enabled
    if (value &&
        (_playbackMode == PlaybackMode.repeatAll ||
            _playbackMode == PlaybackMode.repeatOne)) {
      _playbackMode = PlaybackMode.sequential;
    }

    await _updateActiveQueue(metadata.copyWith(removeAfterPlay: value));
    await _updateCachedValues();
    notifyListeners();
  }

  /// Advance to the next song based on playback mode
  /// Returns the next song to play, or null if no more songs
  Future<SongUnit?> advanceToNext() async {
    if (_currentQueueSongs.isEmpty) {
      return null;
    }

    final activeQueue = await _getActiveQueue();
    if (activeQueue?.playlistMetadata == null) return null;

    final metadata = activeQueue!.playlistMetadata!;
    var newIndex = metadata.currentIndex;

    switch (_playbackMode) {
      case PlaybackMode.sequential:
        if (hasNext) {
          newIndex++;
        } else {
          // End of queue in sequential mode
          notifyListeners();
          return null;
        }
        break;
      case PlaybackMode.repeatAll:
        newIndex = (newIndex + 1) % _currentQueueSongs.length;
        break;
      case PlaybackMode.repeatOne:
        // Stay at current index, replay same song
        break;
      case PlaybackMode.random:
        if (_currentQueueSongs.length > 1) {
          do {
            newIndex = _random.nextInt(_currentQueueSongs.length);
          } while (newIndex == metadata.currentIndex);
        }
        break;
    }

    await _updateActiveQueue(metadata.copyWith(currentIndex: newIndex));
    await _updateCachedValues();
    notifyListeners();
    return currentSongUnit;
  }

  /// Move to the previous song in the queue
  Future<void> previous() async {
    if (_currentQueueSongs.isEmpty) return;

    final activeQueue = await _getActiveQueue();
    if (activeQueue?.playlistMetadata == null) return;

    final metadata = activeQueue!.playlistMetadata!;
    var newIndex = metadata.currentIndex;

    switch (_playbackMode) {
      case PlaybackMode.sequential:
      case PlaybackMode.repeatOne:
        if (hasPrevious) {
          newIndex--;
        }
        break;
      case PlaybackMode.repeatAll:
        newIndex =
            (newIndex - 1 + _currentQueueSongs.length) %
            _currentQueueSongs.length;
        break;
      case PlaybackMode.random:
        if (_currentQueueSongs.length > 1) {
          do {
            newIndex = _random.nextInt(_currentQueueSongs.length);
          } while (newIndex == metadata.currentIndex);
        }
        break;
    }

    await _updateActiveQueue(metadata.copyWith(currentIndex: newIndex));
    await _updateCachedValues();
    notifyListeners();
  }

  /// Jump to a specific index in the queue
  Future<void> jumpTo(int index) async {
    if (index < 0 || index >= _currentQueueSongs.length) return;

    final activeQueue = await _getActiveQueue();
    if (activeQueue?.playlistMetadata == null) return;

    await _updateActiveQueue(
      activeQueue!.playlistMetadata!.copyWith(currentIndex: index),
    );
    await _updateCachedValues();
    notifyListeners();
  }

  /// Update playback position for the active queue
  /// Should be called periodically during playback
  void updatePlaybackPosition(Duration position, bool isPlaying) async {
    final activeQueue = await _getActiveQueue();
    if (activeQueue?.playlistMetadata == null) return;

    final metadata = activeQueue!.playlistMetadata!;
    await _updateActiveQueue(
      metadata.copyWith(
        playbackPositionMs: position.inMilliseconds,
        wasPlaying: isPlaying,
      ),
    );

    await _updateCachedValues();
  }

  // ============================================================================
  // Utility
  // ============================================================================

  /// Set the PlayerViewModel reference for playing songs
  /// This should be called after both ViewModels are initialized
  void setPlayerViewModel(PlayerViewModel playerViewModel) {
    _playerViewModel = playerViewModel;
  }

  /// Save playback mode to storage
  void _savePlaybackMode() {
    final modeStr = _playbackMode.toString().split('.').last;
    _playbackStateStorage.saveQueueState(
      currentQueueId: activeQueueId,
      repeatMode: modeStr,
      shuffleEnabled: false,
    );
  }

  /// Restore playback mode from storage
  Future<void> restorePlaybackMode() async {
    try {
      final state = await _playbackStateStorage.getQueueState();
      final modeStr = state['repeatMode'] as String? ?? 'sequential';

      // Convert string back to enum
      switch (modeStr) {
        case 'sequential':
          _playbackMode = PlaybackMode.sequential;
          break;
        case 'repeatAll':
          _playbackMode = PlaybackMode.repeatAll;
          break;
        case 'repeatOne':
          _playbackMode = PlaybackMode.repeatOne;
          break;
        case 'random':
          _playbackMode = PlaybackMode.random;
          break;
        default:
          _playbackMode = PlaybackMode.sequential;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Failed to restore playback mode: $e');
    }
  }

  // ============================================================================
  // Queue Convenience Methods (delegate to generic collection operations)
  // ============================================================================

  /// Alias for queueSongUnits for backward compatibility
  List<SongUnit> get queue => queueSongUnits;

  /// Move to the next song in the queue based on playback mode
  Future<void> next() async {
    await advanceToNext();
  }

  /// Ensure the queue is populated. If the in-memory queue is empty,
  /// Ensure the queue has songs. If the in-memory queue is empty, reload from
  /// DB (an async requestSong may have completed after our cache was last read).
  /// If still empty and a song is currently playing, auto-populate the queue
  /// with all library songs so next/previous can navigate.
  Future<void> _ensureQueuePopulated() async {
    if (_currentQueueSongs.isNotEmpty) return;

    await _loadCurrentQueueSongs();
    await _updateCachedValues();
    if (_currentQueueSongs.isNotEmpty) return;

    // Queue is genuinely empty — auto-populate from library if something is playing
    final currentSong = _playerViewModel?.currentSongUnit;
    if (currentSong == null) return;

    final allSongs = await _libraryRepository.getAllSongUnits();
    if (allSongs.isEmpty) {
      await requestSongWithUnit(currentSong);
      return;
    }

    await requestSongsBatch(allSongs);

    // Set the current index to the playing song
    final currentIndex = _currentQueueSongs.indexWhere(
      (s) => s.id == currentSong.id,
    );
    if (currentIndex >= 0) {
      final activeQueue = await _getActiveQueue();
      if (activeQueue?.playlistMetadata != null) {
        await _updateActiveQueue(
          activeQueue!.playlistMetadata!.copyWith(currentIndex: currentIndex),
        );
        await _updateCachedValues();
      }
    }
  }

  /// Move to next song and start playing it.
  /// Convenience method for notification / media key buttons.
  Future<void> playAndMoveToNext() async {
    await _ensureQueuePopulated();
    final nextSong = await advanceToNext();
    if (nextSong != null && _playerViewModel != null) {
      await _playerViewModel!.play(nextSong);
    }
  }

  /// Move to previous song and start playing it.
  /// Convenience method for notification / media key buttons.
  Future<void> playAndMoveToPrevious() async {
    await _ensureQueuePopulated();
    if (_currentQueueSongs.isEmpty) return;

    final activeQueue = await _getActiveQueue();
    if (activeQueue?.playlistMetadata == null) return;

    final metadata = activeQueue!.playlistMetadata!;
    var newIndex = metadata.currentIndex;

    switch (_playbackMode) {
      case PlaybackMode.sequential:
      case PlaybackMode.repeatOne:
        if (hasPrevious) {
          newIndex--;
        } else {
          return;
        }
        break;
      case PlaybackMode.repeatAll:
        newIndex =
            (newIndex - 1 + _currentQueueSongs.length) %
            _currentQueueSongs.length;
        break;
      case PlaybackMode.random:
        if (_currentQueueSongs.length > 1) {
          do {
            newIndex = _random.nextInt(_currentQueueSongs.length);
          } while (newIndex == metadata.currentIndex);
        }
        break;
    }

    await _updateActiveQueue(metadata.copyWith(currentIndex: newIndex));
    await _updateCachedValues();
    notifyListeners();

    final previousSong = currentSongUnit;
    if (previousSong != null && _playerViewModel != null) {
      await _playerViewModel!.play(previousSong);
    }
  }

  /// Remove a song from the active queue by index
  /// Returns true if the currently playing song was removed
  Future<bool> removeFromQueue(int index) async {
    if (index < 0 || index >= _currentQueueSongs.length) {
      return false;
    }

    final activeQueue = await _getActiveQueue();
    if (activeQueue?.playlistMetadata == null) return false;

    final metadata = activeQueue!.playlistMetadata!;
    final wasCurrentlyPlaying = index == metadata.currentIndex;

    // Find the display item for this flat index to get the PlaylistItem ID
    final displayItem = _queueDisplayItems
        .where((d) => d.isSong && d.flatIndex == index)
        .firstOrNull;

    if (displayItem != null && displayItem.playlistItemId != null) {
      if (displayItem.groupId != null) {
        // Song is inside a group — remove from the group collection
        await _tagRepository.removeItemFromCollection(
          displayItem.groupId!,
          displayItem.playlistItemId!,
        );
      } else {
        // Top-level song — remove from the active queue directly
        await _tagRepository.removeItemFromCollection(
          _activeQueueId,
          displayItem.playlistItemId!,
        );
      }
    } else {
      // Fallback: find the top-level songUnit item by targetId
      final songUnit = _currentQueueSongs[index];
      final topLevelItem = metadata.items.firstWhere(
        (i) => i.type == PlaylistItemType.songUnit && i.targetId == songUnit.id,
        orElse: () => throw StateError('Song not found in queue metadata'),
      );
      await _tagRepository.removeItemFromCollection(
        _activeQueueId,
        topLevelItem.id,
      );
    }

    // Adjust currentIndex
    var newIndex = metadata.currentIndex;
    if (index < newIndex) {
      newIndex--;
    } else if (index == newIndex) {
      if (newIndex >= _currentQueueSongs.length - 1) {
        newIndex = _currentQueueSongs.length - 2;
      }
    }
    if (newIndex < -1) newIndex = -1;

    // Update currentIndex on the active queue
    final refreshedQueue = await _getActiveQueue();
    if (refreshedQueue?.playlistMetadata != null) {
      await _updateActiveQueue(
        refreshedQueue!.playlistMetadata!.copyWith(currentIndex: newIndex),
      );
    }

    await _loadCurrentQueueSongs();
    await _updateCachedValues();
    notifyListeners();
    return wasCurrentlyPlaying;
  }

  /// Reorder a song in the active queue
  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _currentQueueSongs.length) return;
    if (newIndex < 0 || newIndex >= _currentQueueSongs.length) return;
    if (oldIndex == newIndex) return;

    final activeQueue = await _getActiveQueue();
    if (activeQueue?.playlistMetadata == null) return;

    final metadata = activeQueue!.playlistMetadata!;

    // Find the PlaylistItem that corresponds to the song at oldIndex.
    // We need to map flatIndex -> the top-level songUnit PlaylistItem,
    // skipping over collectionReference items (groups) and their nested songs.
    final topLevelSongItems = <PlaylistItem>[];
    for (final item in metadata.items) {
      if (item.type == PlaylistItemType.songUnit) {
        topLevelSongItems.add(item);
      }
    }

    if (oldIndex >= topLevelSongItems.length ||
        newIndex >= topLevelSongItems.length) {
      // Indices out of range for top-level songs — fall back to full reload
      await _loadCurrentQueueSongs();
      await _updateCachedValues();
      notifyListeners();
      return;
    }

    final movedItem = topLevelSongItems[oldIndex];

    // Remove the moved item from the full items list, then re-insert it
    // at the position corresponding to newIndex among top-level songs.
    final allItems = List<PlaylistItem>.from(metadata.items)..remove(movedItem);

    // Find where to insert: locate the top-level songUnit item that is now
    // at newIndex (after removal) and insert before/after it.
    final remainingSongItems = allItems
        .where((i) => i.type == PlaylistItemType.songUnit)
        .toList();

    int insertPos;
    if (newIndex >= remainingSongItems.length) {
      // Moving to end
      insertPos = allItems.length;
    } else {
      final targetItem = remainingSongItems[newIndex];
      insertPos = allItems.indexOf(targetItem);
      if (oldIndex > newIndex) {
        // Moving up — insert before the target
      } else {
        // Moving down — insert after the target
        insertPos++;
      }
    }

    allItems.insert(insertPos, movedItem);

    // Re-number order values
    for (var i = 0; i < allItems.length; i++) {
      allItems[i] = allItems[i].copyWith(order: i);
    }

    // Update currentIndex based on flat song indices
    final newQueue = List<SongUnit>.from(_currentQueueSongs);
    final songUnit = newQueue.removeAt(oldIndex);
    newQueue.insert(newIndex, songUnit);
    _currentQueueSongs = newQueue;

    var newCurrentIndex = metadata.currentIndex;
    if (newCurrentIndex == oldIndex) {
      newCurrentIndex = newIndex;
    } else if (oldIndex < newCurrentIndex && newIndex >= newCurrentIndex) {
      newCurrentIndex--;
    } else if (oldIndex > newCurrentIndex && newIndex <= newCurrentIndex) {
      newCurrentIndex++;
    }

    await _updateActiveQueue(
      metadata.copyWith(items: allItems, currentIndex: newCurrentIndex),
    );

    await _loadCurrentQueueSongs();
    await _updateCachedValues();
    notifyListeners();
  }

  /// Clear the active queue
  Future<void> clearQueue() async {
    await clearCollection(_activeQueueId);
  }

  /// Deduplicate the active queue
  /// Returns the number of duplicates removed
  Future<int> deduplicateQueue() async {
    if (_currentQueueSongs.length <= 1) return 0;

    final activeQueue = await _getActiveQueue();
    if (activeQueue?.playlistMetadata == null) return 0;

    final metadata = activeQueue!.playlistMetadata!;
    final currentSong = currentSongUnit;
    final originalLength = _currentQueueSongs.length;

    final seenIds = <String>{};
    final deduplicated = <SongUnit>[];

    for (final song in _currentQueueSongs) {
      if (!seenIds.contains(song.id)) {
        seenIds.add(song.id);
        deduplicated.add(song);
      }
    }

    _currentQueueSongs = deduplicated;

    var newIndex = metadata.currentIndex;
    if (currentSong != null) {
      newIndex = _currentQueueSongs.indexWhere((s) => s.id == currentSong.id);
      if (newIndex == -1 && _currentQueueSongs.isNotEmpty) {
        newIndex = 0;
      }
    } else if (newIndex >= _currentQueueSongs.length) {
      newIndex = _currentQueueSongs.length - 1;
    }

    final removedCount = originalLength - _currentQueueSongs.length;

    if (removedCount > 0) {
      final newItems = _currentQueueSongs.asMap().entries.map((entry) {
        return PlaylistItem(
          id: _uuid.v4(),
          type: PlaylistItemType.songUnit,
          targetId: entry.value.id,
          order: entry.key,
        );
      }).toList();

      await _updateActiveQueue(
        metadata.copyWith(items: newItems, currentIndex: newIndex),
      );

      await _updateCachedValues();
      notifyListeners();
    }

    return removedCount;
  }

  /// Create a new playlist (creates a collection tag)
  Future<void> createPlaylist(String name) async {
    try {
      _error = null;
      await _tagRepository.createCollection(name);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Add a Song Unit to a playlist by playlist name or ID
  Future<void> addToPlaylist(String playlistId, String songUnitId) async {
    await addSongUnitToCollection(playlistId, songUnitId);
  }

  // ============================================================================
  // Selection State (Requirement 18.1, 18.7)
  // ============================================================================

  final Set<String> _selectedItemIds = {};
  bool _selectionModeActive = false;

  /// Unmodifiable view of currently selected item IDs
  Set<String> get selectedItemIds => Set.unmodifiable(_selectedItemIds);

  /// Whether selection mode is active (button toggled on)
  bool get hasSelection => _selectionModeActive;

  /// Number of currently selected items
  int get selectionCount => _selectedItemIds.length;

  /// Enter selection mode without selecting anything
  void enterSelectionMode() {
    _selectionModeActive = true;
    notifyListeners();
  }

  /// Toggle selection state of an item
  void toggleSelection(String itemId) {
    _selectionModeActive = true;
    if (_selectedItemIds.contains(itemId)) {
      _selectedItemIds.remove(itemId);
    } else {
      _selectedItemIds.add(itemId);
    }
    notifyListeners();
  }

  /// Clear all selections and exit selection mode
  void clearSelection() {
    _selectedItemIds.clear();
    _selectionModeActive = false;
    notifyListeners();
  }

  /// Check if a specific item is selected
  bool isSelected(String itemId) => _selectedItemIds.contains(itemId);

  // ============================================================================
  // Bulk Move Operations (Requirement 18.3, 18.4, 18.5, 18.6)
  // ============================================================================

  /// Collect selected PlaylistItems from all groups within a collection.
  ///
  /// Iterates through the top-level items of [collectionId], finds groups
  /// (collectionReference items pointing to group tags), and returns any
  /// PlaylistItems inside those groups whose IDs are in [_selectedItemIds].
  Future<List<PlaylistItem>> _collectSelectedItemsFromGroups(
    String collectionId,
  ) async {
    final result = <PlaylistItem>[];
    final parentTag = await _tagRepository.getCollectionTag(collectionId);
    if (parentTag == null || !parentTag.isCollection) return result;

    final items = parentTag.playlistMetadata?.items ?? [];
    for (final item in items) {
      if (item.type == PlaylistItemType.collectionReference) {
        final refTag = await _tagRepository.getCollectionTag(item.targetId);
        if (refTag != null && refTag.isGroup) {
          final groupItems = await _tagRepository.getCollectionItems(
            item.targetId,
          );
          for (final gi in groupItems) {
            if (_selectedItemIds.contains(gi.id)) {
              result.add(gi);
            }
          }
        }
      }
    }
    return result;
  }

  /// Remove a PlaylistItem from its current location (top-level or group).
  ///
  /// Searches [collectionId] and all its child groups for [itemId],
  /// then removes it from whichever collection contains it.
  Future<void> _removeItemFromCurrentLocation(
    String collectionId,
    String itemId,
  ) async {
    final containingId = await _findContainingCollection(collectionId, itemId);
    if (containingId != null) {
      await _tagRepository.removeItemFromCollection(containingId, itemId);
    }
  }

  /// Bulk move selected song units into a target group.
  ///
  /// Collects all selected items from both the top-level collection and
  /// any groups within it, preserves their relative order, removes them
  /// from their current locations, and adds them to [targetGroupId].
  /// Clears selection after the move.
  ///
  /// Requirements: 18.3, 18.5, 18.6
  Future<void> bulkMoveToGroup(
    String collectionId,
    String targetGroupId,
  ) async {
    if (_selectedItemIds.isEmpty) return;

    try {
      _error = null;

      // 1. Collect selected items from top-level
      final allItems = await _tagRepository.getCollectionItems(collectionId);
      final selectedItems = allItems
          .where((item) => _selectedItemIds.contains(item.id))
          .toList();

      // Also check items inside groups
      final groupItems = await _collectSelectedItemsFromGroups(collectionId);
      selectedItems.addAll(groupItems);

      if (selectedItems.isEmpty) {
        _selectedItemIds.clear();
        _selectionModeActive = false;
        notifyListeners();
        return;
      }

      // 2. Sort by current order to preserve relative ordering
      selectedItems.sort((a, b) => a.order.compareTo(b.order));

      // 3. Remove all selected items from their current locations
      for (final item in selectedItems) {
        await _removeItemFromCurrentLocation(collectionId, item.id);
      }

      // 4. Add to target group in preserved order
      final existingGroupItems = await _tagRepository.getCollectionItems(
        targetGroupId,
      );
      var insertOrder = existingGroupItems.isEmpty
          ? 0
          : existingGroupItems.map((i) => i.order).reduce(max) + 1;

      for (final item in selectedItems) {
        await _tagRepository.addItemToCollection(
          targetGroupId,
          PlaylistItem(
            id: _uuid.v4(),
            type: PlaylistItemType.songUnit,
            targetId: item.targetId,
            order: insertOrder++,
          ),
        );
      }

      // 5. Clear selection
      _selectedItemIds.clear();
      _selectionModeActive = false;

      // 6. Recompute display orders
      await _recomputeDisplayOrders(collectionId);
      await _recomputeDisplayOrders(targetGroupId);

      // 7. Reload queue if active queue is affected
      if (collectionId == _activeQueueId) {
        await _loadCurrentQueueSongs();
        await _updateCachedValues();
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Bulk move selected song units out of groups to the top-level collection.
  ///
  /// Collects all selected items from groups within [collectionId],
  /// preserves their relative order, removes them from their groups,
  /// and adds them to the top-level collection at the end.
  /// Clears selection after the move.
  ///
  /// Requirements: 18.4, 18.5, 18.6
  Future<void> bulkRemoveFromGroup(String collectionId) async {
    if (_selectedItemIds.isEmpty) return;

    try {
      _error = null;

      // 1. Collect selected items from all groups, preserving order
      final selectedItems = await _collectSelectedItemsFromGroups(collectionId);
      selectedItems.sort((a, b) => a.order.compareTo(b.order));

      if (selectedItems.isEmpty) {
        _selectedItemIds.clear();
        _selectionModeActive = false;
        notifyListeners();
        return;
      }

      // 2. Remove from their groups
      for (final item in selectedItems) {
        await _removeItemFromCurrentLocation(collectionId, item.id);
      }

      // 3. Add to top-level collection at the end
      final topLevelItems = await _tagRepository.getCollectionItems(
        collectionId,
      );
      var insertOrder = topLevelItems.isEmpty
          ? 0
          : topLevelItems.map((i) => i.order).reduce(max) + 1;

      for (final item in selectedItems) {
        await _tagRepository.addItemToCollection(
          collectionId,
          PlaylistItem(
            id: _uuid.v4(),
            type: PlaylistItemType.songUnit,
            targetId: item.targetId,
            order: insertOrder++,
          ),
        );
      }

      // 4. Clear selection
      _selectedItemIds.clear();
      _selectionModeActive = false;

      // 5. Recompute display orders
      await _recomputeDisplayOrders(collectionId);

      // 6. Reload queue if active queue is affected
      if (collectionId == _activeQueueId) {
        await _loadCurrentQueueSongs();
        await _updateCachedValues();
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ============================================================================
  // Rust FRB Sync Helpers
  // ============================================================================
  // These methods mirror Dart tag operations to the Rust beadline-tags crate
  // so the Rust search/query/suggestion engine stays in sync.
  // Failures are logged but don't block the Dart-side operation.

  /// Whether the Rust bridge is available (initialized).
  bool get _rustAvailable {
    try {
      // Accessing .instance.api throws if not initialized
      RustLib.instance.api;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Mirror a tag creation to Rust. User tags are nameless (key=null).
  void _syncCreateTagToRust(Tag tag) {
    // Only sync pure tags, not collections/playlists/queues
    if (tag.isCollection) return;
    if (!_rustAvailable) return;

    final String? key;
    if (tag.type == TagType.builtIn) {
      key = tag.name; // Built-in tags are named: key=name
    } else {
      key = null; // User/automatic tags are nameless
    }

    rust_tag
        .createTag(key: key, value: tag.name, parentId: tag.parentId)
        .then((_) {})
        .catchError((Object e) {
          debugPrint('Rust sync: createTag failed for "${tag.name}": $e');
        });
  }

  /// Mirror a tag deletion to Rust.
  void _syncDeleteTagFromRust(String tagId) {
    if (!_rustAvailable) return;

    rust_tag.deleteTag(id: tagId).catchError((e) {
      debugPrint('Rust sync: deleteTag failed for "$tagId": $e');
    });
  }

  /// Mirror an alias addition to Rust.
  void _syncAddAliasToRust(String tagId, String alias) {
    if (!_rustAvailable) return;

    rust_tag.addAlias(tagId: tagId, alias: alias).catchError((e) {
      debugPrint('Rust sync: addAlias failed for "$tagId" / "$alias": $e');
    });
  }

  /// Mirror an alias removal from Rust.
  void _syncRemoveAliasFromRust(String alias) {
    if (!_rustAvailable) return;

    rust_tag.removeAlias(alias: alias).catchError((e) {
      debugPrint('Rust sync: removeAlias failed for "$alias": $e');
    });
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _librarySubscription?.cancel();
    _saveDebounceTimer?.cancel();
    super.dispose();
  }
}
