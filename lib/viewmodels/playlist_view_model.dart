import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/playback_state_storage.dart';
import '../models/song_unit.dart';
import '../models/tag_extensions.dart';
import '../repositories/library_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/tag_repository.dart';
import '../services/platform_media_player.dart';
import '../views/player_control_panel.dart';
import 'player_view_model.dart';

/// ViewModel for playlist management with unified tag-based collections
/// Handles playlist creation, song requests, and queue management
/// Collections are tags with TagMetadata, active queues have currentIndex >= 0
class PlaylistViewModel extends ChangeNotifier {
  PlaylistViewModel({
    required LibraryRepository libraryRepository,
    required TagRepository tagRepository,
    required SettingsRepository settingsRepository,
    required PlaybackStateStorage playbackStateStorage,
  }) : _libraryRepository = libraryRepository,
       _tagRepository = tagRepository,
       _settingsRepository = settingsRepository,
       _playbackStateStorage = playbackStateStorage {
    _setupListeners();
    _loadActiveQueue();
  }
  final LibraryRepository _libraryRepository;
  final TagRepository _tagRepository;
  final SettingsRepository _settingsRepository;
  final PlaybackStateStorage _playbackStateStorage;
  final Random _random = Random();
  final Uuid _uuid = const Uuid();

  // Reference to PlayerViewModel for playing songs (set after initialization)
  PlayerViewModel? _playerViewModel;

  String _activeQueueId = 'default';
  List<SongUnit> _currentQueueSongs = [];
  bool _isLoading = false;
  String? _error;
  PlaybackMode _playbackMode = PlaybackMode.sequential;
  StreamSubscription<LibraryEvent>? _librarySubscription;
  Timer? _saveDebounceTimer;

  /// Load active queue from settings and load its songs
  Future<void> _loadActiveQueue() async {
    try {
      _activeQueueId = await _settingsRepository.getActiveQueueId();

      // Queue may not exist yet on first launch (created after language selection)
      final activeQueue = await _tagRepository.getTag(_activeQueueId);
      if (activeQueue == null) return;

      await _loadCurrentQueueSongs();
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load active queue: $e');
    }
  }

  /// Load songs for the current active queue
  Future<void> _loadCurrentQueueSongs() async {
    final activeQueue = await _getActiveQueue();
    if (activeQueue == null || activeQueue.metadata == null) {
      _currentQueueSongs = [];
      return;
    }

    final metadata = activeQueue.metadata!;
    final songUnits = <SongUnit>[];

    for (final item in metadata.items) {
      if (item.itemType != TagItemType.songUnit) continue;

      final songUnit = await _libraryRepository.getSongUnit(item.targetId);
      if (songUnit != null) {
        songUnits.add(songUnit);
      }
    }
    _currentQueueSongs = songUnits;
  }

  /// Get the active queue tag
  Future<Tag?> _getActiveQueue() async {
    return _tagRepository.getCollectionTag(_activeQueueId);
  }

  /// Update the active queue's metadata
  Future<void> _updateActiveQueue(TagMetadata updatedMetadata) async {
    final activeQueue = await _getActiveQueue();
    if (activeQueue == null) return;

    final updatedTag = activeQueue.copyWith(
      metadata: updatedMetadata.copyWith(updatedAt: DateTime.now().toIso8601String()),
    );

    await _tagRepository.updateTag(updatedTag);
  }

  /// Get all available collections (queues)
  Future<List<Tag>> get allQueues async {
    final collections = await _tagRepository.getCollections();
    return collections;
  }

  /// Get the currently active queue tag
  Future<Tag?> get activeQueue async {
    return _getActiveQueue();
  }

  /// Get the active queue ID
  String get activeQueueId => _activeQueueId;

  /// Current playback queue (songs in active queue)
  List<SongUnit> get queue => List.unmodifiable(_currentQueueSongs);

  /// Current index in the queue (-1 if nothing playing)
  int get currentIndex {
    // This is synchronous, so we need to cache the value
    // The actual value is updated via _loadCurrentQueueSongs
    return _cachedCurrentIndex;
  }

  int _cachedCurrentIndex = -1;

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

  /// Whether the playlist is loading
  bool get isLoading => _isLoading;

  /// Error message if any
  String? get error => _error;

  /// Current playback mode
  PlaybackMode get playbackMode => _playbackMode;

  /// Whether to remove song from queue after playing (from active queue)
  bool get removeAfterPlay {
    // This is synchronous, so we need to cache the value
    return _cachedRemoveAfterPlay;
  }

  bool _cachedRemoveAfterPlay = false;

  /// Update cached values from active queue
  Future<void> _updateCachedValues() async {
    final activeQueue = await _getActiveQueue();
    if (activeQueue?.metadata != null) {
      _cachedCurrentIndex = activeQueue!.metadata!.currentIndex;
      _cachedRemoveAfterPlay = activeQueue.metadata!.removeAfterPlay;
    } else {
      _cachedCurrentIndex = -1;
      _cachedRemoveAfterPlay = false;
    }
  }

  void _setupListeners() {
    _librarySubscription = _libraryRepository.events.listen(
      _onLibraryEvent,
      onError: _onLibraryError,
    );
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
          if (activeQueue?.metadata != null) {
            final metadata = activeQueue!.metadata!;
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
          notifyListeners();
        }
    }
  }

  void _onLibraryError(Object error) {
    _error = error.toString();
    notifyListeners();
  }

  /// Update playback position for the active queue
  /// Should be called periodically during playback
  void updatePlaybackPosition(Duration position, bool isPlaying) async {
    final activeQueue = await _getActiveQueue();
    if (activeQueue?.metadata == null) return;

    final metadata = activeQueue!.metadata!;
    await _updateActiveQueue(
      metadata.copyWith(
        playbackPositionMs: position.inMilliseconds,
        wasPlaying: isPlaying,
      ),
    );

    await _updateCachedValues();
  }

  // ============================================================================
  // Queue Management Methods
  // ============================================================================

  /// Create a new queue (collection)
  Future<void> createQueue(String name) async {
    try {
      await _tagRepository.createCollection(name);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Rename a queue
  Future<void> renameQueue(String queueId, String newName) async {
    try {
      final queue = await _tagRepository.getTag(queueId);
      if (queue == null) {
        _error = 'Queue not found';
        notifyListeners();
        return;
      }

      final updatedTag = queue.copyWith(name: newName);
      await _tagRepository.updateTag(updatedTag);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Delete a queue (cannot delete if it's the only queue or currently active)
  Future<bool> deleteQueue(String queueId) async {
    try {
      final allQueues = await this.allQueues;

      // Cannot delete the only queue
      if (allQueues.length <= 1) {
        _error = 'Cannot delete the only queue';
        notifyListeners();
        return false;
      }

      // Cannot delete the active queue
      if (queueId == _activeQueueId) {
        _error =
            'Cannot delete the active queue. Switch to another queue first.';
        notifyListeners();
        return false;
      }

      await _tagRepository.deleteTag(queueId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Switch to a different queue
  /// This will save current playback state and restore the target queue's state
  Future<void> switchQueue(
    String queueId, {
    required PlayerViewModel playerVM,
  }) async {
    try {
      if (queueId == _activeQueueId) {
        return; // Already on this queue
      }

      final targetQueue = await _tagRepository.getTag(queueId);
      if (targetQueue == null || !targetQueue.isCollection) {
        _error = 'Queue not found';
        notifyListeners();
        return;
      }

      // Save current queue's playback state
      final currentQueue = await _getActiveQueue();
      if (currentQueue?.metadata != null) {
        final currentPosition = playerVM.position.inMilliseconds;
        final isPlaying = playerVM.isPlaying;

        await _updateActiveQueue(
          currentQueue!.metadata!.copyWith(
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
      final targetMetadata = targetQueue.metadata;
      if (targetMetadata != null &&
          targetMetadata.currentIndex >= 0 &&
          targetMetadata.currentIndex < _currentQueueSongs.length) {
        final songToPlay = _currentQueueSongs[targetMetadata.currentIndex];

        // Start playing the song
        await playerVM.play(songToPlay);

        // Wait for the player to be ready (status should be playing or paused)
        // We need to wait for the audio source to be loaded before seeking
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

      final metadata = sourceQueue.metadata!;

      // Create new collection with copied metadata
      final newTag = await _tagRepository.createCollection(
        '${sourceQueue.name} (Copy)',
      );

      // Update with copied items and reset playback state
      final newMetadata = metadata.copyWith(
        currentIndex: -1, // Reset playback position
        playbackPositionMs: 0,
        wasPlaying: false,
      );

      final updatedTag = newTag.copyWith(metadata: newMetadata);
      await _tagRepository.updateTag(updatedTag);

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ============================================================================
  // Playlist Methods (Tag-based playlists with new system)
  // ============================================================================

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

  /// Add a Song Unit to a playlist
  Future<void> addToPlaylist(String playlistId, String songUnitId) async {
    try {
      _error = null;

      // Get the playlist tag
      final playlistTag = await _tagRepository.getCollectionTag(playlistId);
      if (playlistTag == null || !playlistTag.isCollection) {
        _error = 'Playlist not found';
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
      final metadata = playlistTag.metadata ?? TagMetadataExtensions.empty();
      final nextOrder = metadata.items.isEmpty
          ? 0
          : metadata.items.map((i) => i.order).reduce((a, b) => a > b ? a : b) +
                1;

      final item = TagItem(
        id: _uuid.v4(),
        itemType: TagItemType.songUnit,
        targetId: songUnitId,
        order: nextOrder,
        inheritLock: true,
        );

      await _tagRepository.addItemToPlaylist(playlistId, item);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Remove a Song Unit from a playlist
  Future<void> removeFromPlaylist(String playlistId, String itemId) async {
    try {
      _error = null;
      await _tagRepository.removeItemFromPlaylist(playlistId, itemId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Add a collection reference to another collection
  Future<void> addPlaylistReference(
    String parentPlaylistId,
    String targetPlaylistId,
  ) async {
    try {
      _error = null;

      // Check for circular references
      if (await _wouldCreateCircularReference(
        parentPlaylistId,
        targetPlaylistId,
      )) {
        _error = 'Cannot add playlist: would create circular reference';
        notifyListeners();
        return;
      }

      final parentTag = await _tagRepository.getCollectionTag(parentPlaylistId);
      if (parentTag == null || !parentTag.isCollection) {
        _error = 'Parent playlist not found';
        notifyListeners();
        return;
      }

      final metadata = parentTag.metadata ?? TagMetadataExtensions.empty();
      final nextOrder = metadata.items.isEmpty
          ? 0
          : metadata.items.map((i) => i.order).reduce((a, b) => a > b ? a : b) +
                1;

      final item = TagItem(
        id: _uuid.v4(),
        itemType: TagItemType.tagReference,
        targetId: targetPlaylistId,
        order: nextOrder,
        inheritLock: true,
        );

      await _tagRepository.addItemToPlaylist(parentPlaylistId, item);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Check if adding a playlist reference would create a circular reference
  Future<bool> _wouldCreateCircularReference(
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
    if (tag == null || !tag.isPlaylist) return false;

    final metadata = tag.metadata;
    if (metadata == null) return false;

    for (final item in metadata.items) {
      if (item.itemType == TagItemType.tagReference) {
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

  /// Toggle playlist lock state
  Future<void> togglePlaylistLock(String playlistId) async {
    try {
      _error = null;
      final tag = await _tagRepository.getCollectionTag(playlistId);
      if (tag == null || !tag.isCollection) {
        _error = 'Playlist not found';
        notifyListeners();
        return;
      }

      final metadata = tag.metadata ?? TagMetadataExtensions.empty();
      await _tagRepository.setPlaylistLock(playlistId, !metadata.isLocked);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Resolve playlist content (expand references and nested playlists)
  Future<List<SongUnit>> resolvePlaylistContent(
    String playlistId, {
    int depth = 0,
  }) async {
    // Prevent infinite recursion
    if (depth > 5) {
      debugPrint('Max playlist nesting depth reached');
      return [];
    }

    final tag = await _tagRepository.getCollectionTag(playlistId);
    if (tag == null || !tag.isCollection) return [];

    final metadata = tag.metadata;
    if (metadata == null) return [];

    final result = <SongUnit>[];

    for (final item in metadata.items) {
      switch (item.itemType) {
        case TagItemType.songUnit:
          final songUnit = await _libraryRepository.getSongUnit(item.targetId);
          if (songUnit != null) {
            result.add(songUnit);
          }
          break;

        case TagItemType.tagReference:
          // Recursively resolve referenced collection
          final nestedSongs = await resolvePlaylistContent(
            item.targetId,
            depth: depth + 1,
          );
          result.addAll(nestedSongs);
          break;
      }
    }

    return result;
  }

  /// Load a playlist into the active queue with lock support
  Future<void> loadPlaylist(String playlistId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final playlistTag = await _tagRepository.getTag(playlistId);
      if (playlistTag == null || !playlistTag.isCollection) {
        _error = 'Playlist not found';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final activeQueue = await _getActiveQueue();
      if (activeQueue?.metadata == null) {
        _isLoading = false;
        return;
      }

      // Resolve playlist content
      _currentQueueSongs = await resolvePlaylistContent(playlistId);

      // Convert songs to playlist items
      final items = _currentQueueSongs.asMap().entries.map((entry) {
        return TagItem(
          id: _uuid.v4(),
          itemType: TagItemType.songUnit,
          targetId: entry.value.id,
          order: entry.key,
          inheritLock: true,
          );
      }).toList();

      await _updateActiveQueue(
        activeQueue!.metadata!.copyWith(
          items: items,
          currentIndex: _currentQueueSongs.isNotEmpty ? 0 : -1,
        ),
      );

      await _updateCachedValues();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
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
      if (activeQueue?.metadata == null) return false;

      final metadata = activeQueue!.metadata!;
      final wasEmpty = _currentQueueSongs.isEmpty;
      _currentQueueSongs = [..._currentQueueSongs, songUnit];

      // Create new playlist item
      final newItem = TagItem(
        id: _uuid.v4(),
        itemType: TagItemType.songUnit,
        targetId: songUnit.id,
        order: metadata.items.length,
        inheritLock: true,
        );

      final newIndex = metadata.currentIndex < 0 ? 0 : metadata.currentIndex;

      await _updateActiveQueue(
        metadata.copyWith(
          items: [...metadata.items, newItem],
          currentIndex: newIndex,
        ),
      );

      await _updateCachedValues();
      notifyListeners();
      return wasEmpty;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Request a priority song (insert immediately after current song)
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
      if (activeQueue?.metadata == null) return;

      final metadata = activeQueue!.metadata!;

      if (_currentQueueSongs.isEmpty || metadata.currentIndex < 0) {
        // Queue is empty, just add to the beginning
        _currentQueueSongs = [songUnit];

        final newItem = TagItem(
          id: _uuid.v4(),
          itemType: TagItemType.songUnit,
          targetId: songUnit.id,
          order: 0,
          inheritLock: true,
          );

        await _updateActiveQueue(
          metadata.copyWith(items: [newItem], currentIndex: 0),
        );
      } else {
        // Insert after current song
        final insertIndex = metadata.currentIndex + 1;
        _currentQueueSongs = [
          ..._currentQueueSongs.sublist(0, insertIndex),
          songUnit,
          ..._currentQueueSongs.sublist(insertIndex),
        ];

        // Create new item and reorder
        final newItem = TagItem(
          id: _uuid.v4(),
          itemType: TagItemType.songUnit,
          targetId: songUnit.id,
          order: insertIndex,
          inheritLock: true,
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

      await _updateCachedValues();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Set playback mode
  void setPlaybackMode(PlaybackMode mode) async {
    final activeQueue = await _getActiveQueue();
    if (activeQueue?.metadata == null) return;

    final metadata = activeQueue!.metadata!;

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
      shuffleEnabled:
          false, // We don't have a shuffle mode, only random playback
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

  /// Set whether to remove song from queue after playing
  void setRemoveAfterPlay(bool value) async {
    final activeQueue = await _getActiveQueue();
    if (activeQueue?.metadata == null) return;

    final metadata = activeQueue!.metadata!;

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

  /// Shuffle the queue (randomize order) with lock support
  /// Locked playlists stay together as groups
  Future<void> shuffleQueue() async {
    if (_currentQueueSongs.length <= 1) return;

    final activeQueue = await _getActiveQueue();
    if (activeQueue?.metadata == null) return;

    final metadata = activeQueue!.metadata!;

    // Save current song if playing
    final currentSong = currentSongUnit;

    // Group songs by their playlist source and lock state
    final groups = await _groupSongsByPlaylist();

    // Shuffle unlocked songs and locked groups separately
    final shuffledSongs = <SongUnit>[];
    final unlockedSongs = <SongUnit>[];
    final lockedGroups = <List<SongUnit>>[];

    for (final group in groups) {
      if (group.isLocked) {
        lockedGroups.add(group.songs);
      } else {
        unlockedSongs.addAll(group.songs);
      }
    }

    // Shuffle unlocked songs
    unlockedSongs.shuffle(_random);

    // Shuffle the order of locked groups (but not their contents)
    lockedGroups.shuffle(_random);

    // Interleave unlocked songs and locked groups
    var unlockedIndex = 0;
    var lockedGroupIndex = 0;

    while (unlockedIndex < unlockedSongs.length ||
        lockedGroupIndex < lockedGroups.length) {
      // Add some unlocked songs
      final unlockedBatch = _random.nextInt(3) + 1; // 1-3 songs
      for (
        var i = 0;
        i < unlockedBatch && unlockedIndex < unlockedSongs.length;
        i++
      ) {
        shuffledSongs.add(unlockedSongs[unlockedIndex++]);
      }

      // Add a locked group
      if (lockedGroupIndex < lockedGroups.length) {
        shuffledSongs.addAll(lockedGroups[lockedGroupIndex++]);
      }
    }

    _currentQueueSongs = shuffledSongs;

    // Restore current index to the current song's new position
    var newIndex = metadata.currentIndex;
    if (currentSong != null) {
      newIndex = _currentQueueSongs.indexWhere((s) => s.id == currentSong.id);
    }

    // Rebuild items list
    final newItems = _currentQueueSongs.asMap().entries.map((entry) {
      return TagItem(
        id: _uuid.v4(),
        itemType: TagItemType.songUnit,
        targetId: entry.value.id,
        order: entry.key,
        inheritLock: true,
        );
    }).toList();

    await _updateActiveQueue(
      metadata.copyWith(items: newItems, currentIndex: newIndex),
    );

    await _updateCachedValues();
    notifyListeners();
  }

  /// Group songs by their playlist source and lock state
  Future<List<_SongGroup>> _groupSongsByPlaylist() async {
    final groups = <_SongGroup>[];
    final processedSongs = <String>{};

    // Get all collection tags
    final collectionTags = await _tagRepository.getCollections();

    // Group songs by locked playlists
    for (final collectionTag in collectionTags) {
      final metadata = collectionTag.metadata;
      if (metadata == null || !metadata.isLocked) continue;

      final playlistSongs = <SongUnit>[];
      for (final song in _currentQueueSongs) {
        if (processedSongs.contains(song.id)) continue;

        // Check if this song belongs to this playlist
        if (await _songBelongsToPlaylist(song.id, collectionTag.id)) {
          playlistSongs.add(song);
          processedSongs.add(song.id);
        }
      }

      if (playlistSongs.isNotEmpty) {
        groups.add(
          _SongGroup(
            playlistId: collectionTag.id,
            isLocked: true,
            songs: playlistSongs,
          ),
        );
      }
    }

    // Add remaining unlocked songs as individual groups
    for (final song in _currentQueueSongs) {
      if (!processedSongs.contains(song.id)) {
        groups.add(
          _SongGroup(playlistId: null, isLocked: false, songs: [song]),
        );
      }
    }

    return groups;
  }

  /// Check if a song belongs to a playlist
  Future<bool> _songBelongsToPlaylist(
    String songUnitId,
    String playlistId,
  ) async {
    final tag = await _tagRepository.getCollectionTag(playlistId);
    if (tag == null || !tag.isCollection) return false;

    final metadata = tag.metadata;
    if (metadata == null) return false;

    for (final item in metadata.items) {
      if (item.itemType == TagItemType.songUnit &&
          item.targetId == songUnitId) {
        return true;
      }
    }

    return false;
  }

  /// Deduplicate the queue (remove duplicate songs, keep first occurrence)
  /// Returns the number of duplicates removed
  Future<int> deduplicateQueue() async {
    if (_currentQueueSongs.length <= 1) return 0;

    final activeQueue = await _getActiveQueue();
    if (activeQueue?.metadata == null) return 0;

    final metadata = activeQueue!.metadata!;

    // Save current song if playing
    final currentSong = currentSongUnit;
    final originalLength = _currentQueueSongs.length;

    // Use a Set to track seen IDs and LinkedHashMap to preserve order
    final seenIds = <String>{};
    final deduplicated = <SongUnit>[];

    for (final song in _currentQueueSongs) {
      if (!seenIds.contains(song.id)) {
        seenIds.add(song.id);
        deduplicated.add(song);
      }
    }

    _currentQueueSongs = deduplicated;

    // Restore current index to the current song's new position
    var newIndex = metadata.currentIndex;
    if (currentSong != null) {
      newIndex = _currentQueueSongs.indexWhere((s) => s.id == currentSong.id);
      // If current song was removed (shouldn't happen since we keep first occurrence)
      if (newIndex == -1 && _currentQueueSongs.isNotEmpty) {
        newIndex = 0;
      }
    } else if (newIndex >= _currentQueueSongs.length) {
      newIndex = _currentQueueSongs.length - 1;
    }

    final removedCount = originalLength - _currentQueueSongs.length;

    if (removedCount > 0) {
      // Rebuild items list
      final newItems = _currentQueueSongs.asMap().entries.map((entry) {
        return TagItem(
          id: _uuid.v4(),
          itemType: TagItemType.songUnit,
          targetId: entry.value.id,
          order: entry.key,
          inheritLock: true,
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

  /// Move to the next song in the queue based on playback mode
  void next() {
    advanceToNext();
  }

  /// Move to next song and start playing it
  /// This is a convenience method for notification buttons
  Future<void> playAndMoveToNext() async {
    final nextSong = await advanceToNext();
    if (nextSong != null && _playerViewModel != null) {
      await _playerViewModel!.play(nextSong);
    }
  }

  /// Advance to the next song based on playback mode
  /// Returns the next song to play, or null if no more songs
  Future<SongUnit?> advanceToNext() async {
    if (_currentQueueSongs.isEmpty) {
      return null;
    }

    final activeQueue = await _getActiveQueue();
    if (activeQueue?.metadata == null) return null;

    final metadata = activeQueue!.metadata!;
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
    if (activeQueue?.metadata == null) return;

    final metadata = activeQueue!.metadata!;
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

  /// Move to previous song and start playing it
  /// This is a convenience method for notification buttons
  Future<void> playAndMoveToPrevious() async {
    if (_currentQueueSongs.isEmpty) return;

    final activeQueue = await _getActiveQueue();
    if (activeQueue?.metadata == null) return;

    final metadata = activeQueue!.metadata!;
    var newIndex = metadata.currentIndex;

    switch (_playbackMode) {
      case PlaybackMode.sequential:
      case PlaybackMode.repeatOne:
        if (hasPrevious) {
          newIndex--;
        } else {
          return; // No previous song
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

    // Play the new song
    final previousSong = currentSongUnit;
    if (previousSong != null && _playerViewModel != null) {
      await _playerViewModel!.play(previousSong);
    }
  }

  /// Jump to a specific index in the queue
  Future<void> jumpTo(int index) async {
    if (index < 0 || index >= _currentQueueSongs.length) return;

    final activeQueue = await _getActiveQueue();
    if (activeQueue?.metadata == null) return;

    await _updateActiveQueue(
      activeQueue!.metadata!.copyWith(currentIndex: index),
    );
    await _updateCachedValues();
    notifyListeners();
  }

  /// Remove a song from the queue by index
  /// Returns true if the currently playing song was removed
  Future<bool> removeFromQueue(int index) async {
    if (index < 0 || index >= _currentQueueSongs.length) {
      return false;
    }

    final activeQueue = await _getActiveQueue();
    if (activeQueue?.metadata == null) return false;

    final metadata = activeQueue!.metadata!;
    final wasCurrentlyPlaying = index == metadata.currentIndex;

    _currentQueueSongs = [
      ..._currentQueueSongs.sublist(0, index),
      ..._currentQueueSongs.sublist(index + 1),
    ];

    // Adjust current index if needed
    var newIndex = metadata.currentIndex;
    if (index < newIndex) {
      newIndex--;
    } else if (index == newIndex) {
      if (newIndex >= _currentQueueSongs.length) {
        newIndex = _currentQueueSongs.length - 1;
      }
    }

    // Rebuild items list
    final newItems = _currentQueueSongs.asMap().entries.map((entry) {
      return TagItem(
        id: _uuid.v4(),
        itemType: TagItemType.songUnit,
        targetId: entry.value.id,
        order: entry.key,
        inheritLock: true,
        );
    }).toList();

    await _updateActiveQueue(
      metadata.copyWith(items: newItems, currentIndex: newIndex),
    );

    await _updateCachedValues();
    notifyListeners();
    return wasCurrentlyPlaying;
  }

  /// Reorder a song in the queue
  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _currentQueueSongs.length) return;
    if (newIndex < 0 || newIndex >= _currentQueueSongs.length) return;
    if (oldIndex == newIndex) return;

    final activeQueue = await _getActiveQueue();
    if (activeQueue?.metadata == null) return;

    final metadata = activeQueue!.metadata!;

    final songUnit = _currentQueueSongs[oldIndex];
    final newQueue = List<SongUnit>.from(_currentQueueSongs);
    newQueue.removeAt(oldIndex);
    newQueue.insert(newIndex, songUnit);
    _currentQueueSongs = newQueue;

    // Adjust current index
    var newCurrentIndex = metadata.currentIndex;
    if (newCurrentIndex == oldIndex) {
      newCurrentIndex = newIndex;
    } else if (oldIndex < newCurrentIndex && newIndex >= newCurrentIndex) {
      newCurrentIndex--;
    } else if (oldIndex > newCurrentIndex && newIndex <= newCurrentIndex) {
      newCurrentIndex++;
    }

    // Rebuild items list
    final newItems = _currentQueueSongs.asMap().entries.map((entry) {
      return TagItem(
        id: _uuid.v4(),
        itemType: TagItemType.songUnit,
        targetId: entry.value.id,
        order: entry.key,
        inheritLock: true,
        );
    }).toList();

    await _updateActiveQueue(
      metadata.copyWith(items: newItems, currentIndex: newCurrentIndex),
    );

    await _updateCachedValues();
    notifyListeners();
  }

  /// Clear the queue
  Future<void> clearQueue() async {
    final activeQueue = await _getActiveQueue();
    if (activeQueue?.metadata == null) return;

    _currentQueueSongs = [];
    await _updateActiveQueue(
      activeQueue!.metadata!.copyWith(items: [], currentIndex: -1),
    );

    await _updateCachedValues();
    notifyListeners();
  }

  /// Clear any error state
  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _librarySubscription?.cancel();
    _saveDebounceTimer?.cancel();
    super.dispose();
  }
}

/// Helper class for grouping songs by playlist
class _SongGroup {
  const _SongGroup({
    required this.playlistId,
    required this.isLocked,
    required this.songs,
  });

  final String? playlistId;
  final bool isLocked;
  final List<SongUnit> songs;
}
