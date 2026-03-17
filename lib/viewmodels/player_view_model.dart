import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:media_kit/media_kit.dart' as mk;

import '../data/playback_state_storage.dart';
import '../models/app_settings.dart';
import '../models/song_unit.dart';
import '../models/source.dart';
import '../models/source_origin.dart';
import '../repositories/library_repository.dart';
import '../services/lrc_parser.dart';
import '../services/platform_media_player.dart';
import '../services/player_engine.dart';

/// ViewModel for player controls and playback state
/// Exposes PlaybackState to views and handles user interactions
class PlayerViewModel extends ChangeNotifier {
  PlayerViewModel({
    required PlayerEngine playerEngine,
    required LibraryRepository libraryRepository,
    required PlaybackStateStorage playbackStateStorage,
  }) : _playerEngine = playerEngine,
       _libraryRepository = libraryRepository,
       _playbackStateStorage = playbackStateStorage {
    _setupListeners();
  }
  final PlayerEngine _playerEngine;
  final LibraryRepository _libraryRepository;
  final PlaybackStateStorage _playbackStateStorage;
  final LrcParser _lrcParser = LrcParser();

  PlaybackState _currentState = const PlaybackState();
  StreamSubscription<PlaybackState>? _stateSubscription;
  StreamSubscription<LibraryEvent>? _librarySubscription;
  String? _error;
  bool _isLoading = false;
  ParsedLyrics? _currentLyrics;

  /// Current playback state
  PlaybackState get currentState => _currentState;

  /// Current Song Unit being played
  SongUnit? get currentSongUnit => _currentState.currentUnit;

  /// Whether playback is active
  bool get isPlaying => _currentState.isPlaying;

  /// Current playback position
  Duration get position => _currentState.position;

  /// Total duration of current track
  Duration get duration => _currentState.duration;

  /// Current audio mode (original or accompaniment)
  AudioMode get audioMode => _currentState.audioMode;

  /// Current playback status
  PlaybackStatus get status => _currentState.status;

  /// Active display source
  Source? get activeDisplaySource => _currentState.activeDisplaySource;

  /// Active audio source
  Source? get activeAudioSource => _currentState.activeAudioSource;

  /// Active hover source (lyrics)
  Source? get activeHoverSource => _currentState.activeHoverSource;

  /// The underlying media_kit Player for video rendering.
  /// Returns null if no real video player is available (e.g. in tests).
  mk.Player? get videoNativePlayer => _playerEngine.videoNativePlayer;

  /// Error message if any
  String? get error => _error;

  /// Whether the player is loading
  bool get isLoading => _isLoading;

  /// Current parsed lyrics
  ParsedLyrics? get currentLyrics => _currentLyrics;

  void _setupListeners() {
    _stateSubscription = _playerEngine.stateStream.listen(
      _onPlaybackStateChanged,
      onError: _onPlaybackError,
    );
    _librarySubscription = _libraryRepository.events.listen(
      _onLibraryEvent,
      onError: _onLibraryError,
    );
  }

  void _onLibraryEvent(LibraryEvent event) {
    switch (event) {
      case SongUnitUpdated(songUnit: final updatedSongUnit):
        // If the currently playing song was updated, reload it
        if (_currentState.currentUnit?.id == updatedSongUnit.id) {
          _handleCurrentSongUpdated(updatedSongUnit);
        }
      case SongUnitDeleted(songUnitId: final deletedId):
        // If the currently playing song was deleted, stop playback
        if (_currentState.currentUnit?.id == deletedId) {
          stop();
        }
      case SongUnitAdded():
        // No action needed for added songs
        break;
      case SongUnitMoved(songUnit: final movedSongUnit):
        // If the currently playing song was moved, update the reference
        if (_currentState.currentUnit?.id == movedSongUnit.id) {
          _handleCurrentSongUpdated(movedSongUnit);
        }
    }
  }

  void _onLibraryError(Object error) {
    debugPrint('Library error in PlayerViewModel: $error');
  }

  /// Handle when the currently playing song unit is updated
  Future<void> _handleCurrentSongUpdated(SongUnit updatedSongUnit) async {
    final currentSongUnit = _currentState.currentUnit;

    // Check if the song unit actually changed in a way that affects playback
    // Skip reload if only metadata or tags changed (not sources or preferences)
    if (currentSongUnit != null &&
        !_needsPlaybackReload(currentSongUnit, updatedSongUnit)) {
      // Just update the reference without reloading playback
      _currentState = _currentState.copyWith(currentUnit: updatedSongUnit);
      notifyListeners();
      return;
    }

    final currentPosition = _currentState.position;
    final wasPlaying = _currentState.isPlaying;

    // Check if the song still has playable sources
    final hasAudio = updatedSongUnit.sources.audioSources.isNotEmpty;
    final hasDisplay = updatedSongUnit.sources.displaySources.isNotEmpty;

    if (!hasAudio && !hasDisplay) {
      // No playable sources left, stop playback
      await stop();
      _error = 'Song sources were removed';
      notifyListeners();
      return;
    }

    // Reload the song with updated sources
    try {
      await _playerEngine.play(updatedSongUnit);
      // Seek back to the previous position
      await _playerEngine.seekTo(currentPosition);
      // Resume if was playing
      if (!wasPlaying) {
        await _playerEngine.pause();
      }
    } catch (e) {
      _error = 'Failed to reload updated song: $e';
      notifyListeners();
    }
  }

  /// Check if the song unit changes require reloading playback
  /// Returns true if sources or playback preferences changed in a way that affects current playback
  bool _needsPlaybackReload(SongUnit current, SongUnit updated) {
    // If sources are identical, no reload needed
    // (preference changes are handled by updateSourceSelection directly)
    if (current.sources == updated.sources) {
      return false;
    }

    // Check what's currently active
    final currentAudioMode = _currentState.audioMode;
    final activeAudioSource = _currentState.activeAudioSource;
    final activeDisplaySource = _currentState.activeDisplaySource;
    final activeHoverSource = _currentState.activeHoverSource;

    // Check if the currently active audio source changed
    if (currentAudioMode == AudioMode.original) {
      // Check if audio sources changed
      if (current.sources.audioSources != updated.sources.audioSources) {
        // Check if the specific active source is still available
        // Only compare by ID to avoid object identity issues
        if (activeAudioSource != null) {
          final stillExists = updated.sources.audioSources.any(
            (s) => s.id == activeAudioSource.id,
          );
          if (!stillExists) {
            return true;
          }
        }
      }
    } else {
      // Accompaniment mode - check if accompaniment sources changed
      if (current.sources.accompanimentSources !=
          updated.sources.accompanimentSources) {
        if (activeAudioSource != null) {
          // Only compare by ID to avoid object identity issues
          final stillExists = updated.sources.accompanimentSources.any(
            (s) => s.id == activeAudioSource.id,
          );
          if (!stillExists) {
            return true;
          }
        }
      }
    }

    // Check if the currently active display source changed
    if (current.sources.displaySources != updated.sources.displaySources) {
      if (activeDisplaySource != null) {
        // Only compare by ID to avoid object identity issues
        final stillExists = updated.sources.displaySources.any(
          (s) => s.id == activeDisplaySource.id,
        );
        if (!stillExists) {
          return true;
        }
      }
    }

    // Check if the currently active hover source changed
    if (current.sources.hoverSources != updated.sources.hoverSources) {
      if (activeHoverSource != null) {
        // Only compare by ID to avoid object identity issues
        final stillExists = updated.sources.hoverSources.any(
          (s) => s.id == activeHoverSource.id,
        );
        if (!stillExists) {
          return true;
        }
      }
    }

    // Other changes (metadata, tags, non-active source property changes) don't require reload
    return false;
  }

  /// Callback for when playback completes (song ends)
  /// Set this from the UI to handle auto-advance to next song
  void Function()? onPlaybackCompleted;

  void _onPlaybackStateChanged(PlaybackState state) {
    final previousHoverSource = _currentState.activeHoverSource;
    final previousSongUnit = _currentState.currentUnit;
    final previousStatus = _currentState.status;

    // Removed excessive debug log that was flooding the console
    // debugPrint('PlayerViewModel: State changed - song: ${state.currentUnit?.metadata.title}, position: ${state.position.inMilliseconds}ms, isPlaying: ${state.isPlaying}, status: ${state.status}');

    _currentState = state;
    _isLoading = state.status == PlaybackStatus.loading;
    _error = state.errorMessage;

    // Save playback state for persistence
    _savePlaybackState();

    // Load lyrics if hover source changed OR if song unit changed
    // (song unit change means we need to reload lyrics even if hover source ID is same)
    final hoverSourceChanged =
        state.activeHoverSource?.id != previousHoverSource?.id;
    final songUnitChanged = state.currentUnit?.id != previousSongUnit?.id;

    if (hoverSourceChanged || songUnitChanged) {
      _loadLyrics(state.activeHoverSource);
    }

    // Detect playback completion (song ended)
    if (previousStatus != PlaybackStatus.completed &&
        state.status == PlaybackStatus.completed) {
      debugPrint('PlayerViewModel: Playback completed, notifying callback');
      // Notify callback for auto-advance
      onPlaybackCompleted?.call();
    }

    notifyListeners();
  }

  /// Load lyrics from the hover source
  Future<void> _loadLyrics(Source? hoverSource) async {
    if (hoverSource == null) {
      _currentLyrics = null;
      notifyListeners();
      return;
    }

    try {
      final content = await _loadLyricsContent(hoverSource);
      if (content != null) {
        _currentLyrics = _lrcParser.parse(content);
      } else {
        _currentLyrics = null;
      }
    } catch (e) {
      debugPrint('Failed to load lyrics: $e');
      _currentLyrics = null;
    }
    notifyListeners();
  }

  /// Load lyrics content from source origin
  Future<String?> _loadLyricsContent(Source source) async {
    final origin = source.origin;

    switch (origin) {
      case LocalFileOrigin(path: final path):
        final file = File(path);
        if (file.existsSync()) {
          return file.readAsString();
        }
        return null;

      case UrlOrigin(url: final url):
        try {
          final response = await http.get(Uri.parse(url));
          if (response.statusCode == 200) {
            return response.body;
          }
        } catch (e) {
          debugPrint('Failed to fetch lyrics from URL: $e');
        }
        return null;

      case ApiOrigin():
        // API sources would need specific provider handling
        return null;
    }
  }

  void _onPlaybackError(Object error) {
    _error = error.toString();
    _isLoading = false;
    notifyListeners();
  }

  /// Play a Song Unit by ID
  Future<void> playSongUnit(String songUnitId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final songUnit = await _libraryRepository.getSongUnit(songUnitId);
      if (songUnit == null) {
        _error = 'Song Unit not found';
        _isLoading = false;
        notifyListeners();
        return;
      }

      await _playerEngine.play(songUnit);
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Play a Song Unit directly
  Future<void> play(SongUnit songUnit) async {
    try {
      debugPrint(
        'PlayerViewModel: play() called for song: ${songUnit.metadata.title}',
      );
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _playerEngine.play(songUnit);
      debugPrint(
        'PlayerViewModel: play() completed for song: ${songUnit.metadata.title}',
      );
    } catch (e) {
      debugPrint('PlayerViewModel: play() error: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Pause playback
  Future<void> pause() async {
    try {
      _error = null;
      await _playerEngine.pause();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Resume playback
  Future<void> resume() async {
    try {
      _error = null;
      await _playerEngine.resume();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Stop playback
  Future<void> stop() async {
    try {
      _error = null;
      await _playerEngine.stop();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Seek to a specific position
  Future<void> seekTo(Duration position) async {
    try {
      _error = null;
      await _playerEngine.seekTo(position);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Toggle play/pause
  /// If nothing is playing but a song unit is provided, start playing it
  Future<void> togglePlayPause({SongUnit? songUnit}) async {
    if (isPlaying) {
      await pause();
    } else if (currentSongUnit != null) {
      // Check if the song has completed - need to replay from beginning
      if (status == PlaybackStatus.completed) {
        await play(currentSongUnit!);
      } else {
        // Song was paused, resume it
        await resume();
      }
    } else if (songUnit != null) {
      // Nothing playing, but we have a song unit to play
      await play(songUnit);
    }
    // If nothing playing and no song unit provided, do nothing
  }

  /// Switch to accompaniment audio
  Future<void> switchToAccompaniment() async {
    try {
      _error = null;
      await _playerEngine.switchToAccompaniment();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Switch to original audio
  Future<void> switchToOriginal() async {
    try {
      _error = null;
      await _playerEngine.switchToOriginal();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Toggle between original and accompaniment audio
  Future<void> toggleAudioMode() async {
    if (audioMode == AudioMode.original) {
      await switchToAccompaniment();
    } else {
      await switchToOriginal();
    }
  }

  /// Switch display source during playback
  Future<void> switchDisplaySource(DisplaySource source) async {
    try {
      _error = null;
      await _playerEngine.switchDisplaySource(source);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Get available display sources sorted by priority
  List<Source> getDisplaySources() {
    return _playerEngine.getSourcesByPriority(SourceType.display);
  }

  /// Get available audio sources sorted by priority
  List<Source> getAudioSources() {
    return _playerEngine.getSourcesByPriority(SourceType.audio);
  }

  /// Get available accompaniment sources sorted by priority
  List<Source> getAccompanimentSources() {
    return _playerEngine.getSourcesByPriority(SourceType.accompaniment);
  }

  /// Get available hover sources (lyrics) sorted by priority
  List<Source> getHoverSources() {
    return _playerEngine.getSourcesByPriority(SourceType.hover);
  }

  /// Clear any error state
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Update source selection for the current song unit
  ///
  /// This allows users to select which audio, accompaniment, lyrics, or display
  /// source to use when multiple are available.
  Future<void> updateSourceSelection({
    String? audioSourceId,
    String? accompanimentSourceId,
    String? hoverSourceId,
    String? displaySourceId,
  }) async {
    final songUnit = _currentState.currentUnit;
    if (songUnit == null) return;

    try {
      _error = null;

      // Update preferences in the song unit
      final updatedPreferences = songUnit.preferences.copyWith(
        preferredAudioSourceId: audioSourceId,
        preferredAccompanimentSourceId: accompanimentSourceId,
        preferredHoverSourceId: hoverSourceId,
        preferredDisplaySourceId: displaySourceId,
      );

      final updatedSongUnit = songUnit.copyWith(
        preferences: updatedPreferences,
      );

      // Switch sources using dedicated methods that preserve position
      // instead of doing a full reload

      // Handle accompaniment source change
      if (accompanimentSourceId != null &&
          accompanimentSourceId !=
              songUnit.preferences.preferredAccompanimentSourceId) {
        final newAccompanimentSource = updatedSongUnit
            .sources
            .accompanimentSources
            .where((s) => s.id == accompanimentSourceId)
            .firstOrNull;
        if (newAccompanimentSource != null &&
            _currentState.audioMode == AudioMode.accompaniment) {
          await _playerEngine.switchAccompanimentSource(newAccompanimentSource);
        }
      }

      // Handle audio source change
      if (audioSourceId != null &&
          audioSourceId != songUnit.preferences.preferredAudioSourceId) {
        final newAudioSource = updatedSongUnit.sources.audioSources
            .where((s) => s.id == audioSourceId)
            .firstOrNull;
        if (newAudioSource != null &&
            _currentState.audioMode == AudioMode.original) {
          await _playerEngine.switchAudioSource(newAudioSource);
        }
      }

      // Handle display source change
      if (displaySourceId != null &&
          displaySourceId != songUnit.preferences.preferredDisplaySourceId) {
        final newDisplaySource = updatedSongUnit.sources.displaySources
            .where((s) => s.id == displaySourceId)
            .firstOrNull;
        if (newDisplaySource != null) {
          await _playerEngine.switchDisplaySource(newDisplaySource);
        }
      }

      // Handle hover source change
      if (hoverSourceId != null &&
          hoverSourceId != songUnit.preferences.preferredHoverSourceId) {
        final newHoverSource = updatedSongUnit.sources.hoverSources
            .where((s) => s.id == hoverSourceId)
            .firstOrNull;
        if (newHoverSource != null) {
          await _playerEngine.switchHoverSource(newHoverSource);
          // Reload lyrics for the new hover source
          await _loadLyrics(newHoverSource);
        }
      }

      // Update the engine's current unit reference without reloading
      _playerEngine.updateCurrentUnit(updatedSongUnit);

      // Save to repository (this will trigger _onLibraryEvent, but we've already
      // handled the source switches above, so _needsPlaybackReload will return false)
      await _libraryRepository.updateSongUnit(updatedSongUnit);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Set display mode for filtering display sources
  void setDisplayMode(DisplayMode mode) {
    _playerEngine.setDisplayMode(mode);
  }

  /// Save current playback state to storage
  void _savePlaybackState() {
    final songUnit = _currentState.currentUnit;
    if (songUnit != null) {
      // Removed excessive debug log that was flooding the console
      // debugPrint('PlayerViewModel: Saving playback state - songId: ${songUnit.id}, position: ${_currentState.position.inMilliseconds}ms, isPlaying: ${_currentState.isPlaying}');
      _playbackStateStorage.savePlaybackState(
        currentSongId: songUnit.id,
        currentPositionMs: _currentState.position.inMilliseconds,
        isPlaying: _currentState.isPlaying,
        audioMode: _currentState.audioMode == AudioMode.original
            ? 'original'
            : 'accompaniment',
      );
    } else {
      // No song playing, clear state
      _playbackStateStorage.clearPlaybackState();
    }
  }

  /// Force save playback state immediately (called on app lifecycle changes)
  void savePlaybackStateNow() {
    _savePlaybackState();
  }

  /// Restore playback state from storage
  /// Returns the song ID if state was restored, null otherwise
  /// Always restores in paused state — never starts playback
  Future<String?> restorePlaybackState() async {
    try {
      final state = await _playbackStateStorage.getPlaybackState();
      final songId = state['currentSongId'] as String?;

      if (songId != null) {
        final positionMs = state['currentPositionMs'] as int? ?? 0;
        final audioModeStr = state['audioMode'] as String? ?? 'original';

        debugPrint(
          'PlayerViewModel: Restoring playback state - songId: $songId, position: ${positionMs}ms, audioMode: $audioModeStr',
        );

        // Load the song unit
        final songUnit = await _libraryRepository.getSongUnit(songId);
        if (songUnit == null) {
          debugPrint(
            'PlayerViewModel: Song $songId no longer exists, clearing state',
          );
          await _playbackStateStorage.clearPlaybackState();
          return null;
        }

        // Load sources without starting playback, seeking to saved position
        _isLoading = true;
        _error = null;
        notifyListeners();

        final seekPosition = positionMs > 0
            ? Duration(milliseconds: positionMs)
            : null;

        await _playerEngine.loadOnly(songUnit, seekPosition: seekPosition);

        _isLoading = false;

        // Restore audio mode if needed
        if (audioModeStr == 'accompaniment' &&
            audioMode == AudioMode.original) {
          debugPrint('PlayerViewModel: Switching to accompaniment mode');
          await switchToAccompaniment();
        }

        notifyListeners();

        debugPrint('PlayerViewModel: Playback state restored (paused)');
        return songId;
      } else {
        debugPrint('PlayerViewModel: No saved playback state found');
      }
    } catch (e, stackTrace) {
      debugPrint('PlayerViewModel: Failed to restore playback state: $e');
      debugPrint('Stack trace: $stackTrace');
    }
    return null;
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _librarySubscription?.cancel();
    super.dispose();
  }
}
