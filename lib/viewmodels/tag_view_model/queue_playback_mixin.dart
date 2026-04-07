import 'package:flutter/foundation.dart';
import '../../models/song_unit.dart';
import '../../models/tag_extensions.dart';
import '../../views/player_control_panel.dart';
import 'tag_view_model_base.dart';

/// Mixin handling active queue loading, playback mode, and navigation
/// (advance, previous, jump, play-and-move convenience methods).
mixin QueuePlaybackMixin on TagViewModelBase {
  // Methods provided by QueueRequestMixin (applied earlier in mixin chain)
  Future<void> ensureQueuePopulated();
  void savePlaybackMode();

  // ==========================================================================
  // Queue Loading
  // ==========================================================================

  /// Public entry point to reload the active queue.
  Future<void> reloadActiveQueue() async {
    try {
      activeQueueIdValue = await settingsRepository.getActiveQueueId();
      final aq = await tagRepository.getTag(activeQueueIdValue);
      if (aq == null) return;
      await loadCurrentQueueSongs();
      await updateCachedValues();
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load active queue: $e');
    }
  }

  /// Alias for queueSongUnits for backward compatibility
  List<SongUnit> get queue => queueSongUnits;

  // ==========================================================================
  // Playback Mode
  // ==========================================================================

  /// Set playback mode
  void setPlaybackMode(PlaybackMode mode) async {
    final aq = await getActiveQueue();
    if (aq?.metadata == null) return;
    final metadata = aq!.metadata!;
    if (metadata.removeAfterPlay &&
        (mode == PlaybackMode.repeatAll || mode == PlaybackMode.repeatOne)) {
      return;
    }
    playbackModeValue = mode;
    savePlaybackMode();
    notifyListeners();
  }

  /// Set whether to remove song from queue after playing
  void setRemoveAfterPlay(bool value) async {
    final aq = await getActiveQueue();
    if (aq?.metadata == null) return;
    final metadata = aq!.metadata!;
    if (value &&
        (playbackModeValue == PlaybackMode.repeatAll ||
            playbackModeValue == PlaybackMode.repeatOne)) {
      playbackModeValue = PlaybackMode.sequential;
    }
    await updateActiveQueue(metadata.copyWith(removeAfterPlay: value));
    await updateCachedValues();
    notifyListeners();
  }

  // ==========================================================================
  // Playback Navigation
  // ==========================================================================

  /// Advance to the next song based on playback mode
  Future<SongUnit?> advanceToNext() async {
    if (currentQueueSongsList.isEmpty) return null;
    final aq = await getActiveQueue();
    if (aq?.metadata == null) return null;
    final metadata = aq!.metadata!;
    var newIndex = metadata.currentIndex;

    switch (playbackModeValue) {
      case PlaybackMode.sequential:
        if (hasNext) {
          newIndex++;
        } else {
          notifyListeners();
          return null;
        }
        break;
      case PlaybackMode.repeatAll:
        newIndex = (newIndex + 1) % currentQueueSongsList.length;
        break;
      case PlaybackMode.repeatOne:
        break;
      case PlaybackMode.random:
        if (currentQueueSongsList.length > 1) {
          do {
            newIndex = random.nextInt(currentQueueSongsList.length);
          } while (newIndex == metadata.currentIndex);
        }
        break;
    }

    await updateActiveQueue(metadata.copyWith(currentIndex: newIndex));
    await updateCachedValues();
    notifyListeners();
    return currentSongUnit;
  }

  /// Move to the previous song in the queue
  Future<void> previous() async {
    if (currentQueueSongsList.isEmpty) return;
    final aq = await getActiveQueue();
    if (aq?.metadata == null) return;
    final metadata = aq!.metadata!;
    var newIndex = metadata.currentIndex;

    switch (playbackModeValue) {
      case PlaybackMode.sequential:
      case PlaybackMode.repeatOne:
        if (hasPrevious) newIndex--;
        break;
      case PlaybackMode.repeatAll:
        newIndex = (newIndex - 1 + currentQueueSongsList.length) %
            currentQueueSongsList.length;
        break;
      case PlaybackMode.random:
        if (currentQueueSongsList.length > 1) {
          do {
            newIndex = random.nextInt(currentQueueSongsList.length);
          } while (newIndex == metadata.currentIndex);
        }
        break;
    }

    await updateActiveQueue(metadata.copyWith(currentIndex: newIndex));
    await updateCachedValues();
    notifyListeners();
  }

  /// Jump to a specific index in the queue
  Future<void> jumpTo(int index) async {
    if (index < 0 || index >= currentQueueSongsList.length) return;
    final aq = await getActiveQueue();
    if (aq?.metadata == null) return;
    await updateActiveQueue(
      aq!.metadata!.copyWith(currentIndex: index),
    );
    await updateCachedValues();
    notifyListeners();
  }

  /// Move to next song (alias)
  Future<void> next() async {
    await advanceToNext();
  }

  /// Update playback position for the active queue
  void updatePlaybackPosition(Duration position, bool isPlaying) async {
    final aq = await getActiveQueue();
    if (aq?.metadata == null) return;
    final metadata = aq!.metadata!;
    await updateActiveQueue(
      metadata.copyWith(
        playbackPositionMs: position.inMilliseconds,
        wasPlaying: isPlaying,
      ),
    );
    await updateCachedValues();
  }

  // ==========================================================================
  // Play-and-Move Convenience
  // ==========================================================================

  /// Move to next song and start playing it (media key convenience)
  Future<void> playAndMoveToNext() async {
    await ensureQueuePopulated();
    final nextSong = await advanceToNext();
    if (nextSong != null && playerViewModel != null) {
      await playerViewModel!.play(nextSong);
    }
  }

  /// Move to previous song and start playing it (media key convenience)
  Future<void> playAndMoveToPrevious() async {
    await ensureQueuePopulated();
    if (currentQueueSongsList.isEmpty) return;

    final aq = await getActiveQueue();
    if (aq?.metadata == null) return;
    final metadata = aq!.metadata!;
    var newIndex = metadata.currentIndex;

    switch (playbackModeValue) {
      case PlaybackMode.sequential:
      case PlaybackMode.repeatOne:
        if (hasPrevious) {
          newIndex--;
        } else {
          return;
        }
        break;
      case PlaybackMode.repeatAll:
        newIndex = (newIndex - 1 + currentQueueSongsList.length) %
            currentQueueSongsList.length;
        break;
      case PlaybackMode.random:
        if (currentQueueSongsList.length > 1) {
          do {
            newIndex = random.nextInt(currentQueueSongsList.length);
          } while (newIndex == metadata.currentIndex);
        }
        break;
    }

    await updateActiveQueue(metadata.copyWith(currentIndex: newIndex));
    await updateCachedValues();
    notifyListeners();

    final previousSong = currentSongUnit;
    if (previousSong != null && playerViewModel != null) {
      await playerViewModel!.play(previousSong);
    }
  }
}
