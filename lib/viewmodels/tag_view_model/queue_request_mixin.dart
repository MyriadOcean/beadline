import 'package:flutter/foundation.dart';
import '../../models/playlist_metadata.dart';
import '../../models/song_unit.dart';
import '../../models/tag.dart';
import '../../services/platform_media_player.dart' show PlaybackStatus;
import '../../views/player_control_panel.dart';
import '../player_view_model.dart';
import 'tag_view_model_base.dart';

/// Mixin handling song requests, queue convenience methods, queue switch,
/// duplicate, and playback mode persistence.
mixin QueueRequestMixin on TagViewModelBase {
  // ==========================================================================
  // Song Requests
  // ==========================================================================

  /// Request a song (add to end of active queue)
  Future<bool> requestSong(String songUnitId) async {
    try {
      errorValue = null;
      final songUnit = await libraryRepository.getSongUnit(songUnitId);
      if (songUnit == null) {
        errorValue = 'Song Unit not found';
        notifyListeners();
        return false;
      }
      return await requestSongWithUnit(songUnit);
    } catch (e) {
      errorValue = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Request a song with a SongUnit object (for temporary song units)
  Future<bool> requestSongWithUnit(SongUnit songUnit) async {
    try {
      errorValue = null;
      final aq = await getActiveQueue();
      if (aq?.playlistMetadata == null) return false;
      final metadata = aq!.playlistMetadata!;
      final wasEmpty = currentQueueSongsList.isEmpty;

      final newItem = PlaylistItem(
        id: uuid.v4(),
        type: PlaylistItemType.songUnit,
        targetId: songUnit.id,
        order: metadata.items.length,
      );

      final temporarySongUnits = <String, Map<String, dynamic>>{};
      if (metadata.temporarySongUnits != null) {
        temporarySongUnits.addAll(metadata.temporarySongUnits!);
      }
      if (songUnit.id.startsWith('temp_')) {
        temporarySongUnits[songUnit.id] = songUnit.toJson();
      }

      final newIndex = metadata.currentIndex < 0 ? 0 : metadata.currentIndex;

      await updateActiveQueue(
        metadata.copyWith(
          items: [...metadata.items, newItem],
          currentIndex: newIndex,
          temporarySongUnits:
              temporarySongUnits.isNotEmpty ? temporarySongUnits : null,
        ),
      );

      await loadCurrentQueueSongs();
      await updateCachedValues();
      notifyListeners();
      return wasEmpty;
    } catch (e) {
      errorValue = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Batch request multiple songs at once
  Future<bool> requestSongsBatch(List<SongUnit> songUnits) async {
    if (songUnits.isEmpty) return false;
    try {
      errorValue = null;
      final aq = await getActiveQueue();
      if (aq?.playlistMetadata == null) return false;
      final metadata = aq!.playlistMetadata!;
      final wasEmpty = currentQueueSongsList.isEmpty;

      final newItems = <PlaylistItem>[];
      final temporarySongUnits = <String, Map<String, dynamic>>{};
      if (metadata.temporarySongUnits != null) {
        temporarySongUnits.addAll(metadata.temporarySongUnits!);
      }

      for (var i = 0; i < songUnits.length; i++) {
        final songUnit = songUnits[i];
        newItems.add(
          PlaylistItem(
            id: uuid.v4(),
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

      await updateActiveQueue(
        metadata.copyWith(
          items: [...metadata.items, ...newItems],
          currentIndex: newIndex,
          temporarySongUnits:
              temporarySongUnits.isNotEmpty ? temporarySongUnits : null,
        ),
      );

      await loadCurrentQueueSongs();
      await updateCachedValues();
      notifyListeners();
      return wasEmpty;
    } catch (e) {
      errorValue = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Request a priority song (insert after current song)
  Future<void> requestPrioritySong(String songUnitId) async {
    try {
      errorValue = null;
      final songUnit = await libraryRepository.getSongUnit(songUnitId);
      if (songUnit == null) {
        errorValue = 'Song Unit not found';
        notifyListeners();
        return;
      }

      final aq = await getActiveQueue();
      if (aq?.playlistMetadata == null) return;
      final metadata = aq!.playlistMetadata!;

      if (currentQueueSongsList.isEmpty || metadata.currentIndex < 0) {
        final newItem = PlaylistItem(
          id: uuid.v4(),
          type: PlaylistItemType.songUnit,
          targetId: songUnit.id,
          order: 0,
        );
        await updateActiveQueue(
          metadata.copyWith(items: [newItem], currentIndex: 0),
        );
      } else {
        final insertIndex = metadata.currentIndex + 1;
        final newItem = PlaylistItem(
          id: uuid.v4(),
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
        await updateActiveQueue(metadata.copyWith(items: updatedItems));
      }

      await loadCurrentQueueSongs();
      await updateCachedValues();
      notifyListeners();
    } catch (e) {
      errorValue = e.toString();
      notifyListeners();
    }
  }

  // ==========================================================================
  // Queue Convenience Methods
  // ==========================================================================

  /// Ensure the queue is populated for next/previous navigation
  Future<void> ensureQueuePopulated() async {
    if (currentQueueSongsList.isNotEmpty) return;
    await loadCurrentQueueSongs();
    await updateCachedValues();
    if (currentQueueSongsList.isNotEmpty) return;

    final currentSong = playerViewModel?.currentSongUnit;
    if (currentSong == null) return;

    final allSongs = await libraryRepository.getAllSongUnits();
    if (allSongs.isEmpty) {
      await requestSongWithUnit(currentSong);
      return;
    }

    await requestSongsBatch(allSongs);

    final idx = currentQueueSongsList.indexWhere(
      (s) => s.id == currentSong.id,
    );
    if (idx >= 0) {
      final aq = await getActiveQueue();
      if (aq?.playlistMetadata != null) {
        await updateActiveQueue(
          aq!.playlistMetadata!.copyWith(currentIndex: idx),
        );
        await updateCachedValues();
      }
    }
  }

  // ==========================================================================
  // Playback Mode Persistence
  // ==========================================================================

  /// Save playback mode to storage
  void savePlaybackMode() {
    final modeStr = playbackModeValue.toString().split('.').last;
    playbackStateStorage.saveQueueState(
      currentQueueId: activeQueueIdValue,
      repeatMode: modeStr,
      shuffleEnabled: false,
    );
  }

  /// Restore playback mode from storage
  Future<void> restorePlaybackMode() async {
    try {
      final state = await playbackStateStorage.getQueueState();
      final modeStr = state['repeatMode'] as String? ?? 'sequential';
      switch (modeStr) {
        case 'sequential':
          playbackModeValue = PlaybackMode.sequential;
          break;
        case 'repeatAll':
          playbackModeValue = PlaybackMode.repeatAll;
          break;
        case 'repeatOne':
          playbackModeValue = PlaybackMode.repeatOne;
          break;
        case 'random':
          playbackModeValue = PlaybackMode.random;
          break;
        default:
          playbackModeValue = PlaybackMode.sequential;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to restore playback mode: $e');
    }
  }

  // ==========================================================================
  // Queue Switch & Duplicate
  // ==========================================================================

  /// Get all available queues
  Future<List<Tag>> get allQueues async {
    final collections = await tagRepository.getCollections(
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
      if (queueId == activeQueueIdValue) return;

      final targetQueue = await tagRepository.getCollectionTag(queueId);
      if (targetQueue == null || !targetQueue.isCollection) {
        errorValue = 'Queue not found';
        notifyListeners();
        return;
      }

      final currentQueue = await getActiveQueue();
      if (currentQueue?.playlistMetadata != null) {
        final currentPosition = playerVM.position.inMilliseconds;
        final isPlaying = playerVM.isPlaying;
        await updateActiveQueue(
          currentQueue!.playlistMetadata!.copyWith(
            playbackPositionMs: currentPosition,
            wasPlaying: isPlaying,
          ),
        );
      }

      activeQueueIdValue = queueId;
      await settingsRepository.setActiveQueueId(queueId);
      await loadCurrentQueueSongs();
      await updateCachedValues();
      notifyListeners();

      final targetMetadata = targetQueue.playlistMetadata;
      if (targetMetadata != null &&
          targetMetadata.currentIndex >= 0 &&
          targetMetadata.currentIndex < currentQueueSongsList.length) {
        final songToPlay = currentQueueSongsList[targetMetadata.currentIndex];
        await playerVM.play(songToPlay);

        var attempts = 0;
        while (attempts < 20 &&
            playerVM.status != PlaybackStatus.playing &&
            playerVM.status != PlaybackStatus.paused) {
          await Future.delayed(const Duration(milliseconds: 50));
          attempts++;
        }

        if (targetMetadata.playbackPositionMs > 0) {
          await playerVM.seekTo(
            Duration(milliseconds: targetMetadata.playbackPositionMs),
          );
        }

        if (!targetMetadata.wasPlaying) {
          await playerVM.pause();
        }
      } else {
        await playerVM.stop();
      }
    } catch (e) {
      errorValue = e.toString();
      notifyListeners();
    }
  }

  /// Duplicate a queue
  Future<void> duplicateQueue(String queueId) async {
    try {
      final sourceQueue = await tagRepository.getCollectionTag(queueId);
      if (sourceQueue == null || !sourceQueue.isCollection) {
        errorValue = 'Queue not found';
        notifyListeners();
        return;
      }
      final metadata = sourceQueue.playlistMetadata!;
      final newTag = await tagRepository.createCollection(
        '${sourceQueue.name} (Copy)',
      );
      final newMetadata = metadata.copyWith(
        currentIndex: -1,
        playbackPositionMs: 0,
        wasPlaying: false,
        temporarySongUnits: metadata.temporarySongUnits != null
            ? Map.from(metadata.temporarySongUnits!)
            : null,
      );
      final updatedTag = newTag.copyWith(playlistMetadata: newMetadata);
      await tagRepository.updateTag(updatedTag);
      notifyListeners();
    } catch (e) {
      errorValue = e.toString();
      notifyListeners();
    }
  }
}
