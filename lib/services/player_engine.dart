import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart' as mk;

import '../models/app_settings.dart';
import '../models/song_unit.dart';
import '../models/source.dart';
import '../models/source_collection.dart';
import 'notification_service.dart';
import 'platform_media_player.dart';
import 'thumbnail_cache.dart';

/// Audio mode for playback
enum AudioMode { original, accompaniment }

/// Playback state for the player engine
class PlaybackState {
  const PlaybackState({
    this.currentUnit,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.activeDisplaySource,
    this.activeAudioSource,
    this.activeHoverSource,
    this.audioMode = AudioMode.original,
    this.status = PlaybackStatus.idle,
    this.errorMessage,
  });
  final SongUnit? currentUnit;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final Source? activeDisplaySource;
  final Source? activeAudioSource;
  final Source? activeHoverSource;
  final AudioMode audioMode;
  final PlaybackStatus status;
  final String? errorMessage;

  PlaybackState copyWith({
    SongUnit? currentUnit,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    Source? activeDisplaySource,
    Source? activeAudioSource,
    Source? activeHoverSource,
    AudioMode? audioMode,
    PlaybackStatus? status,
    String? errorMessage,
  }) {
    return PlaybackState(
      currentUnit: currentUnit ?? this.currentUnit,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      activeDisplaySource: activeDisplaySource ?? this.activeDisplaySource,
      activeAudioSource: activeAudioSource ?? this.activeAudioSource,
      activeHoverSource: activeHoverSource ?? this.activeHoverSource,
      audioMode: audioMode ?? this.audioMode,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Player Engine - manages playback of Song Units
/// Handles source selection, audio/accompaniment switching, and output routing
class PlayerEngine {
  /// Creates a PlayerEngine with the given media players.
  /// If not provided, uses MockAudioMediaPlayer for both audio and video (for testing).
  /// For production, use PlayerEngine.withRealPlayers() or inject real players.
  PlayerEngine({
    PlatformMediaPlayer? audioPlayer,
    PlatformMediaPlayer? videoPlayer,
    NotificationService? notificationService,
  }) : _audioPlayer = audioPlayer ?? MockAudioMediaPlayer(),
       _videoPlayer = videoPlayer ?? MockAudioMediaPlayer(),
       _notificationService = notificationService {
    _setupListeners();
  }

  /// Creates a PlayerEngine with real media_kit players for production use.
  factory PlayerEngine.withRealPlayers({
    NotificationService? notificationService,
  }) {
    return PlayerEngine(
      audioPlayer: MediaKitPlayer(),
      videoPlayer: MediaKitPlayer(),
      notificationService: notificationService,
    );
  }
  final PlatformMediaPlayer _audioPlayer;
  final PlatformMediaPlayer _videoPlayer;
  final NotificationService? _notificationService;

  /// The underlying media_kit Player for video rendering.
  /// Returns null if the video player is not a MediaKitPlayer (e.g. in tests).
  mk.Player? get videoNativePlayer {
    final vp = _videoPlayer;
    return vp is MediaKitPlayer ? vp.nativePlayer : null;
  }

  final StreamController<PlaybackState> _stateController =
      StreamController<PlaybackState>.broadcast();

  PlaybackState _currentState = const PlaybackState();
  SongUnit? _currentUnit;
  StreamSubscription<MediaPlayerState>? _audioSubscription;
  StreamSubscription<MediaPlayerState>? _videoSubscription;

  /// Whether the active audio source is the video's linked extracted audio.
  /// When true, video plays with its native audio and the separate audio player is suppressed.
  bool _isVideoAudioActive = false;

  /// Current display mode for filtering display sources
  DisplayMode _displayMode = DisplayMode.enabled;

  /// Current audio source offset (for accompaniment offset handling)
  /// This is used to convert between file position and logical timeline position
  Duration _currentAudioOffset = Duration.zero;

  /// Flag to ignore position updates during audio source transitions
  /// This prevents the UI from showing incorrect positions during the switch
  bool _isTransitioningAudioSource = false;

  /// The target logical position during audio source transition
  Duration? _transitionTargetPosition;

  /// Stream of playback state updates
  Stream<PlaybackState> get stateStream => _stateController.stream;

  /// Current playback state
  PlaybackState get currentState => _currentState;

  /// Current playback position
  Duration get currentPosition => _currentState.position;

  /// Total duration (audio source is authoritative)
  Duration get duration => _currentState.duration;

  /// Determine if the active audio source is the video's linked audio.
  /// If so, unmute video player and suppress the separate audio player.
  /// Otherwise, mute video player and play audio normally.
  void _updateVideoMuteState() {
    final activeAudio = _currentState.activeAudioSource;
    final activeDisplay = _currentState.activeDisplaySource;

    if (activeAudio is AudioSource &&
        activeDisplay is DisplaySource &&
        activeDisplay.displayType == DisplayType.video &&
        activeAudio.linkedVideoSourceId != null &&
        activeAudio.linkedVideoSourceId == activeDisplay.id) {
      // Video's own audio is selected — unmute video, suppress audio player
      _videoPlayer.setVolume(1);
      _audioPlayer.setVolume(0);
      _isVideoAudioActive = true;
    } else {
      // Different audio source — mute video, play audio normally
      _videoPlayer.setVolume(0);
      _audioPlayer.setVolume(1);
      _isVideoAudioActive = false;
    }
  }

  void _setupListeners() {
    _audioSubscription = _audioPlayer.stateStream.listen(_onAudioStateChanged);
    _videoSubscription = _videoPlayer.stateStream.listen(_onVideoStateChanged);
  }

  void _onAudioStateChanged(MediaPlayerState state) {
    // Audio source is authoritative for position
    // Only update duration if the audio player has a valid duration
    // (not the default fallback), otherwise keep the resolved duration
    final newDuration =
        (state.duration != Duration.zero &&
            state.duration != const Duration(minutes: 3))
        ? state.duration
        : _currentState.duration;

    // During audio source transitions, use the target position instead of
    // converting the file position (which might be from the old source)
    Duration logicalPosition;
    if (_isTransitioningAudioSource && _transitionTargetPosition != null) {
      logicalPosition = _transitionTargetPosition!;

      // Check if the transition is complete (player is playing and position is reasonable)
      if (state.status == PlaybackStatus.playing) {
        // End the transition once playback starts
        _isTransitioningAudioSource = false;
        _transitionTargetPosition = null;
        // Now use the actual converted position
        logicalPosition = state.position + _currentAudioOffset;
      }
    } else {
      // Convert file position to logical timeline position by adding offset
      // File position = logical position - offset
      // Therefore: logical position = file position + offset
      logicalPosition = state.position + _currentAudioOffset;
    }

    _updateState(
      _currentState.copyWith(
        position: logicalPosition,
        duration: newDuration,
        isPlaying: state.status == PlaybackStatus.playing,
        status: state.status,
        errorMessage: state.errorMessage,
      ),
    );
  }

  void _onVideoStateChanged(MediaPlayerState state) {
    // Video state updates don't affect position/duration (audio is authoritative)
    // But we track video status for display purposes
  }

  void _updateState(
    PlaybackState newState, {
    bool forceNotificationUpdate = false,
  }) {
    _currentState = newState;
    _stateController.add(newState);

    // Always update notification on state changes (removed throttling for background updates)
    // The notification service itself can handle throttling if needed
    _updateNotification().catchError((error) {
      // Silently catch notification errors to not affect playback
      debugPrint('PlayerEngine: Notification update error: $error');
    });
  }

  /// Update the notification based on current playback state
  Future<void> _updateNotification() async {
    if (_notificationService == null) return;

    final unit = _currentState.currentUnit;
    if (unit == null) {
      // No song playing, hide notification
      debugPrint('PlayerEngine: Hiding notification (no song playing)');
      await _notificationService.hideNotification();
      return;
    }

    // Show notification with current song info
    final title = unit.metadata.title.isNotEmpty
        ? unit.metadata.title
        : 'Unknown Title';
    final artist = unit.metadata.artists.isNotEmpty
        ? unit.metadata.artists.join(', ')
        : 'Unknown Artist';

    // debugPrint('PlayerEngine: Updating notification - title: $title, isPlaying: ${_currentState.isPlaying}, position: ${_currentState.position.inMilliseconds}ms');

    // Get thumbnail path if available
    String? thumbnailPath;
    if (unit.metadata.thumbnailSourceId != null) {
      try {
        thumbnailPath = await ThumbnailCache.instance.getThumbnail(
          unit.metadata.thumbnailSourceId!,
        );
      } catch (e) {
        debugPrint(
          'PlayerEngine: Failed to get thumbnail for notification: $e',
        );
      }
    }

    // Get position and duration in milliseconds
    final position = _currentState.position.inMilliseconds;
    final duration = _currentState.duration.inMilliseconds;

    await _notificationService.showNotification(
      title: title,
      artist: artist,
      isPlaying: _currentState.isPlaying,
      thumbnailPath: thumbnailPath,
      position: position > 0 ? position : null,
      duration: duration > 0 ? duration : null,
    );

    // debugPrint('PlayerEngine: Notification updated successfully');
  }

  /// Set display mode for filtering display sources
  void setDisplayMode(DisplayMode mode) {
    _displayMode = mode;
    // If currently playing, reload display source with new mode
    if (_currentUnit != null) {
      _reloadDisplaySource();
    }
  }

  /// Reload display source with current display mode
  Future<void> _reloadDisplaySource() async {
    if (_currentUnit == null) return;

    final displaySource = await _tryLoadDisplaySourceWithFallback(
      _currentUnit!.sources,
      _currentUnit!.preferences.preferredDisplaySourceId,
    );

    _updateState(_currentState.copyWith(activeDisplaySource: displaySource));

    // Stop current video if display source changed
    await _videoPlayer.stop();

    // Play new display source if available
    if (displaySource != null) {
      final videoOffset = displaySource.offset;
      final currentPosition = _currentState.position;
      final videoPosition = currentPosition - videoOffset;

      if (videoPosition > Duration.zero) {
        await _videoPlayer.seekTo(videoPosition);
      }
      await _videoPlayer.play();
    }
  }

  /// Play a Song Unit
  /// Selects sources based on priority and user preferences
  /// If a source fails to load, tries the next available source by priority
  Future<void> play(SongUnit unit) async {
    debugPrint('PlayerEngine: play() called for song: ${unit.metadata.title}');
    
    // Stop any currently playing media before starting new song
    // This ensures clean state transition and prevents audio overlap
    if (_currentUnit != null) {
      debugPrint('PlayerEngine: Stopping previous playback before switching songs');
      await _audioPlayer.stop();
      await _videoPlayer.stop();
    }
    
    _currentUnit = unit;

    // Reset audio offset when starting a new song
    // (will be set by the selected audio/accompaniment source)
    _currentAudioOffset = Duration.zero;

    // Select sources based on priority and preferences, with fallback on failure
    final hoverSource = _selectHoverSource(
      unit.sources,
      unit.preferences.preferredHoverSourceId,
    );

    // Try to load audio source with fallback
    // This will set _currentAudioOffset based on the selected source
    final audioSource = await _tryLoadAudioSourceWithFallback(
      unit.sources,
      AudioMode.original,
      unit.preferences.preferredAudioSourceId,
    );

    // Try to load display source with fallback
    final displaySource = await _tryLoadDisplaySourceWithFallback(
      unit.sources,
      unit.preferences.preferredDisplaySourceId,
    );

    // Check if there's any playable source
    if (audioSource == null && displaySource == null) {
      debugPrint('PlayerEngine: No playable sources found');
      _updateState(
        PlaybackState(
          currentUnit: unit,
          activeDisplaySource: displaySource,
          activeAudioSource: audioSource,
          activeHoverSource: hoverSource,
          status: PlaybackStatus.error,
          errorMessage: 'No playable audio or video source found',
        ),
      );
      return;
    }

    // Determine duration from audio source (authoritative)
    final duration = _resolveDuration(unit.sources, audioSource);

    debugPrint('PlayerEngine: Sources loaded, updating state to loading');
    _updateState(
      PlaybackState(
        currentUnit: unit,
        activeDisplaySource: displaySource,
        activeAudioSource: audioSource,
        activeHoverSource: hoverSource,
        duration: duration,
        status: PlaybackStatus.loading,
      ),
    );

    // Determine mute state BEFORE starting playback to avoid any audio burst.
    // When the active audio is the video's linked track, we let the video
    // handle audio and suppress the separate audio player entirely.
    _updateVideoMuteState();

    // Play audio source — but only if it's not the video's linked track
    // (in that case the video player handles audio)
    if (audioSource != null && !_isVideoAudioActive) {
      debugPrint('PlayerEngine: Starting audio playback');
      await _audioPlayer.play();
    }

    // Play display source (already loaded in _tryLoadDisplaySourceWithFallback)
    if (displaySource != null) {
      // Apply video offset: negative offset means video starts ahead
      // e.g., offset = -7000ms means when audio is at 0, video should be at 7000ms
      final videoOffset = displaySource.offset;
      if (videoOffset != Duration.zero) {
        final videoStartPosition = -videoOffset; // Negate: -(-7000) = 7000
        if (videoStartPosition > Duration.zero) {
          await _videoPlayer.seekTo(videoStartPosition);
        }
      }
      debugPrint('PlayerEngine: Starting video playback');
      await _videoPlayer.play();
    }

    debugPrint('PlayerEngine: play() completed');
  }

  /// Load a Song Unit without starting playback.
  /// Selects sources and resolves duration, but leaves players paused.
  /// If [seekPosition] is provided, seeks both players to the correct position.
  /// Use this for restoring state on app startup so no audio is emitted.
  Future<void> loadOnly(SongUnit unit, {Duration? seekPosition}) async {
    debugPrint('PlayerEngine: loadOnly() called for song: ${unit.metadata.title}');
    _currentUnit = unit;
    _currentAudioOffset = Duration.zero;

    final hoverSource = _selectHoverSource(
      unit.sources,
      unit.preferences.preferredHoverSourceId,
    );

    final audioSource = await _tryLoadAudioSourceWithFallback(
      unit.sources,
      AudioMode.original,
      unit.preferences.preferredAudioSourceId,
    );

    final displaySource = await _tryLoadDisplaySourceWithFallback(
      unit.sources,
      unit.preferences.preferredDisplaySourceId,
    );

    if (audioSource == null && displaySource == null) {
      debugPrint('PlayerEngine: No playable sources found');
      _updateState(
        PlaybackState(
          currentUnit: unit,
          activeDisplaySource: displaySource,
          activeAudioSource: audioSource,
          activeHoverSource: hoverSource,
          status: PlaybackStatus.error,
          errorMessage: 'No playable audio or video source found',
        ),
      );
      return;
    }

    final duration = _resolveDuration(unit.sources, audioSource);

    _updateVideoMuteState();

    // Calculate seek positions for each player
    Duration? audioSeek;
    Duration? videoSeek;
    if (seekPosition != null && seekPosition > Duration.zero) {
      // Audio file position = logical position - audio offset
      final audioFilePos = seekPosition - _currentAudioOffset;
      audioSeek = audioFilePos >= Duration.zero ? audioFilePos : Duration.zero;

      // Video position = logical position - video offset
      if (displaySource != null) {
        final videoOffset = displaySource.offset;
        final videoPos = seekPosition - videoOffset;
        videoSeek = videoPos >= Duration.zero ? videoPos : Duration.zero;
      } else {
        videoSeek = seekPosition;
      }
    }

    // Open media in players without starting playback, with seek positions
    final audioPlayer = _audioPlayer;
    if (audioSource != null && !_isVideoAudioActive && audioPlayer is MediaKitPlayer) {
      await audioPlayer.openPaused(seekPosition: audioSeek);
    }

    final videoPlayer = _videoPlayer;
    if (displaySource != null && videoPlayer is MediaKitPlayer) {
      await videoPlayer.openPaused(seekPosition: videoSeek);
    }

    _updateState(
      PlaybackState(
        currentUnit: unit,
        activeDisplaySource: displaySource,
        activeAudioSource: audioSource,
        activeHoverSource: hoverSource,
        duration: duration,
        position: seekPosition ?? Duration.zero,
        status: PlaybackStatus.paused,
      ),
    );

    debugPrint('PlayerEngine: loadOnly() completed (paused)');
  }

  /// Try to load an audio source, falling back to next priority source on failure
  Future<Source?> _tryLoadAudioSourceWithFallback(
    SourceCollection sources,
    AudioMode mode,
    String? preferredId,
  ) async {
    if (mode == AudioMode.accompaniment) {
      return _tryLoadAccompanimentSourceWithFallback(sources, preferredId);
    }

    if (sources.audioSources.isEmpty) return null;

    // Get sources sorted by priority
    final sortedSources = List<AudioSource>.from(sources.audioSources)
      ..sort((a, b) => a.priority.compareTo(b.priority));

    // If preferred ID is set, try it first
    if (preferredId != null) {
      final preferred = sortedSources
          .where((s) => s.id == preferredId)
          .firstOrNull;
      if (preferred != null) {
        // Move preferred to front
        sortedSources
          ..remove(preferred)
          ..insert(0, preferred);
      }
    }

    // Try each source until one works
    for (final source in sortedSources) {
      await _audioPlayer.load(source);
      if (_audioPlayer.currentState.status != PlaybackStatus.error) {
        // Set the audio offset for this source
        _currentAudioOffset = source.offset;
        return source;
      }
      // Log the failure and try next
      // ignore: avoid_print
      print('Audio source failed to load: ${source.id}, trying next...');
    }

    return null;
  }

  /// Try to load an accompaniment source, falling back to next priority source on failure
  Future<AccompanimentSource?> _tryLoadAccompanimentSourceWithFallback(
    SourceCollection sources,
    String? preferredId,
  ) async {
    if (sources.accompanimentSources.isEmpty) return null;

    // Get sources sorted by priority
    final sortedSources = List<AccompanimentSource>.from(
      sources.accompanimentSources,
    )..sort((a, b) => a.priority.compareTo(b.priority));

    // If preferred ID is set, try it first
    if (preferredId != null) {
      final preferred = sortedSources
          .where((s) => s.id == preferredId)
          .firstOrNull;
      if (preferred != null) {
        // Move preferred to front
        sortedSources
          ..remove(preferred)
          ..insert(0, preferred);
      }
    }

    // Try each source until one works
    for (final source in sortedSources) {
      await _audioPlayer.load(source);
      if (_audioPlayer.currentState.status != PlaybackStatus.error) {
        return source;
      }
      // Log the failure and try next
      // ignore: avoid_print
      print(
        'Accompaniment source failed to load: ${source.id}, trying next...',
      );
    }

    return null;
  }

  /// Try to load a display source, falling back to next priority source on failure
  Future<DisplaySource?> _tryLoadDisplaySourceWithFallback(
    SourceCollection sources,
    String? preferredId,
  ) async {
    if (sources.displaySources.isEmpty) return null;

    // Filter sources based on display mode
    var availableSources = sources.displaySources;
    if (_displayMode == DisplayMode.imageOnly) {
      // In image-only mode, filter out video sources
      availableSources = availableSources
          .where((s) => s.displayType == DisplayType.image)
          .toList();
      if (availableSources.isEmpty) return null;
    } else if (_displayMode == DisplayMode.disabled) {
      // In disabled mode, return null (no display source)
      return null;
    }

    // Get sources sorted by priority
    final sortedSources = List<DisplaySource>.from(availableSources)
      ..sort((a, b) => a.priority.compareTo(b.priority));

    // If preferred ID is set, try it first
    if (preferredId != null) {
      final preferred = sortedSources
          .where((s) => s.id == preferredId)
          .firstOrNull;
      if (preferred != null) {
        // Move preferred to front
        sortedSources
          ..remove(preferred)
          ..insert(0, preferred);
      }
    }

    // Try each source until one works
    for (final source in sortedSources) {
      await _videoPlayer.load(source);
      if (_videoPlayer.currentState.status != PlaybackStatus.error) {
        return source;
      }
      // Log the failure and try next
      // ignore: avoid_print
      print('Display source failed to load: ${source.id}, trying next...');
    }

    return null;
  }

  /// Pause playback
  Future<void> pause() async {
    await _audioPlayer.pause();
    await _videoPlayer.pause();
    _updateState(
      _currentState.copyWith(isPlaying: false, status: PlaybackStatus.paused),
      forceNotificationUpdate: true,
    );
  }

  /// Resume playback
  Future<void> resume() async {
    await _audioPlayer.resume();
    await _videoPlayer.resume();
    _updateState(
      _currentState.copyWith(isPlaying: true, status: PlaybackStatus.playing),
      forceNotificationUpdate: true,
    );
  }

  /// Stop playback
  Future<void> stop() async {
    await _audioPlayer.stop();
    await _videoPlayer.stop();
    _updateState(
      _currentState.copyWith(
        isPlaying: false,
        position: Duration.zero,
        status: PlaybackStatus.stopped,
      ),
      forceNotificationUpdate: true,
    );
  }

  /// Seek to a specific position (logical timeline position)
  /// Applies offset for video/display sources and audio sources
  Future<void> seekTo(Duration position) async {
    // Convert logical position to audio file position
    // File position = logical position - offset
    final audioFilePosition = position - _currentAudioOffset;
    if (audioFilePosition >= Duration.zero) {
      await _audioPlayer.seekTo(audioFilePosition);
    } else {
      await _audioPlayer.seekTo(Duration.zero);
    }

    // Apply video offset when seeking
    final displaySource = _currentState.activeDisplaySource;
    if (displaySource != null && displaySource is DisplaySource) {
      final videoOffset = displaySource.offset;
      // Video position = audio position - offset
      // e.g., if offset = -7000ms and audio is at 5000ms, video should be at 5000 - (-7000) = 12000ms
      final videoPosition = position - videoOffset;
      if (videoPosition >= Duration.zero) {
        await _videoPlayer.seekTo(videoPosition);
      } else {
        // Video hasn't started yet (audio position is before video should start)
        await _videoPlayer.seekTo(Duration.zero);
      }
    } else {
      await _videoPlayer.seekTo(position);
    }

    _updateState(
      _currentState.copyWith(position: position),
      forceNotificationUpdate: true,
    );
  }

  /// Switch to accompaniment audio
  /// Maintains playback position during switch with smooth transition
  /// Falls back to next available accompaniment source if the preferred one fails
  Future<void> switchToAccompaniment() async {
    if (_currentUnit == null) return;

    // Get the current logical position (timeline position)
    final currentLogicalPosition = _currentState.position;
    final wasPlaying = _audioPlayer.isPlaying || _isVideoAudioActive;

    // Try to load accompaniment source with fallback
    final accompanimentSource = await _tryLoadAccompanimentSourceWithFallback(
      _currentUnit!.sources,
      _currentUnit!.preferences.preferredAccompanimentSourceId,
    );
    if (accompanimentSource == null) {
      _updateState(
        _currentState.copyWith(
          status: PlaybackStatus.error,
          errorMessage: 'No valid accompaniment source available',
        ),
      );
      return;
    }

    // Clear any previous error since we're successfully switching
    _updateState(_currentState.copyWith());

    // Get the accompaniment offset
    final accompanimentOffset = accompanimentSource.offset;

    // Start transition - ignore position updates until playback resumes
    _isTransitioningAudioSource = true;
    _transitionTargetPosition = currentLogicalPosition;

    // Update state immediately to prevent UI blink - preserve position
    _updateState(
      _currentState.copyWith(
        activeAudioSource: accompanimentSource,
        audioMode: AudioMode.accompaniment,
        position: currentLogicalPosition, // Preserve position during transition
      ),
      forceNotificationUpdate: true,
    );

    // Set the current audio offset for position conversion
    _currentAudioOffset = accompanimentOffset;

    // Calculate file position from logical position
    // File position = logical position - offset
    // e.g., if offset = -7000ms and logical position is 5000ms,
    // file position should be 5000 - (-7000) = 12000ms
    final filePosition = currentLogicalPosition - accompanimentOffset;
    if (filePosition >= Duration.zero) {
      await _audioPlayer.seekTo(filePosition);
    } else {
      await _audioPlayer.seekTo(Duration.zero);
    }

    // Update video mute state (accompaniment is never linked to video)
    _updateVideoMuteState();

    // Resume if was playing
    if (wasPlaying) {
      await _audioPlayer.play();
    } else {
      // If not playing, end transition immediately
      _isTransitioningAudioSource = false;
      _transitionTargetPosition = null;
    }
  }

  /// Switch to original audio
  /// Maintains playback position during switch with smooth transition
  /// Falls back to next available audio source if the preferred one fails
  Future<void> switchToOriginal() async {
    if (_currentUnit == null) return;

    // Get the current logical position (timeline position)
    final currentLogicalPosition = _currentState.position;
    final wasPlaying = _audioPlayer.isPlaying || _isVideoAudioActive;

    // Try to load audio source with fallback
    final audioSource = await _tryLoadAudioSourceWithFallback(
      _currentUnit!.sources,
      AudioMode.original,
      _currentUnit!.preferences.preferredAudioSourceId,
    );
    if (audioSource == null) {
      _updateState(
        _currentState.copyWith(
          status: PlaybackStatus.error,
          errorMessage: 'No valid audio source available',
        ),
      );
      return;
    }

    // Clear any previous error since we're successfully switching
    _updateState(_currentState.copyWith());

    // Start transition - ignore position updates until playback resumes
    _isTransitioningAudioSource = true;
    _transitionTargetPosition = currentLogicalPosition;

    // Update state immediately to prevent UI blink - preserve position
    _updateState(
      _currentState.copyWith(
        activeAudioSource: audioSource,
        audioMode: AudioMode.original,
        position: currentLogicalPosition, // Preserve position during transition
      ),
      forceNotificationUpdate: true,
    );

    // Set audio offset from the selected source
    // _currentAudioOffset was already set in _tryLoadAudioSourceWithFallback

    // Calculate file position from logical position
    // File position = logical position - offset
    final filePosition = currentLogicalPosition - _currentAudioOffset;
    if (filePosition >= Duration.zero) {
      await _audioPlayer.seekTo(filePosition);
    } else {
      await _audioPlayer.seekTo(Duration.zero);
    }

    // Update video mute state based on new active audio source
    _updateVideoMuteState();

    if (_isVideoAudioActive) {
      // The selected original audio is the video's linked track:
      // Stop the separate audio player — video handles audio now.
      await _audioPlayer.stop();
      _isTransitioningAudioSource = false;
      _transitionTargetPosition = null;
    } else {
      // Resume if was playing
      if (wasPlaying) {
        await _audioPlayer.play();
      } else {
        _isTransitioningAudioSource = false;
        _transitionTargetPosition = null;
      }
    }
  }

  /// Switch to a specific accompaniment source during playback
  /// Maintains playback position during switch with smooth transition
  Future<void> switchAccompanimentSource(AccompanimentSource source) async {
    if (_currentUnit == null) return;

    // Get the current logical position (timeline position)
    final currentLogicalPosition = _currentState.position;
    final wasPlaying = _audioPlayer.isPlaying || _isVideoAudioActive;

    // Start transition - ignore position updates until playback resumes
    _isTransitioningAudioSource = true;
    _transitionTargetPosition = currentLogicalPosition;

    // Update state immediately to prevent UI blink - preserve position
    _updateState(
      _currentState.copyWith(
        activeAudioSource: source,
        audioMode: AudioMode.accompaniment,
        position: currentLogicalPosition, // Preserve position during transition
      ),
      forceNotificationUpdate: true,
    );

    // Pause instead of stop for smoother transition
    if (wasPlaying) {
      await _audioPlayer.pause();
    }

    // Load the new accompaniment source
    await _audioPlayer.load(source);

    // Get the accompaniment offset
    final accompanimentOffset = source.offset;

    // Set the current audio offset for position conversion
    _currentAudioOffset = accompanimentOffset;

    // Calculate file position from logical position
    // File position = logical position - offset
    final filePosition = currentLogicalPosition - accompanimentOffset;
    if (filePosition >= Duration.zero) {
      await _audioPlayer.seekTo(filePosition);
    } else {
      await _audioPlayer.seekTo(Duration.zero);
    }

    // Resume if was playing
    if (wasPlaying) {
      await _audioPlayer.play();
    } else {
      // If not playing, end transition immediately
      _isTransitioningAudioSource = false;
      _transitionTargetPosition = null;
    }
  }

  /// Switch to a specific audio source during playback
  /// Maintains playback position during switch with smooth transition
  Future<void> switchAudioSource(AudioSource source) async {
    if (_currentUnit == null) return;

    // Get the current logical position (timeline position)
    final currentLogicalPosition = _currentState.position;
    final wasPlaying = _audioPlayer.isPlaying || _isVideoAudioActive;

    // Start transition - ignore position updates until playback resumes
    _isTransitioningAudioSource = true;
    _transitionTargetPosition = currentLogicalPosition;

    // Update state immediately to prevent UI blink - preserve position
    _updateState(
      _currentState.copyWith(
        activeAudioSource: source,
        audioMode: AudioMode.original,
        position: currentLogicalPosition, // Preserve position during transition
      ),
      forceNotificationUpdate: true,
    );

    // Update video mute state based on new active audio source
    _updateVideoMuteState();

    if (_isVideoAudioActive) {
      // Switching TO the video's linked audio track:
      // Stop the separate audio player — video handles audio now.
      await _audioPlayer.stop();

      // Seek video to correct position
      final displaySource = _currentState.activeDisplaySource;
      if (displaySource != null && displaySource is DisplaySource) {
        final videoOffset = displaySource.offset;
        final videoPosition = currentLogicalPosition - videoOffset;
        if (videoPosition >= Duration.zero) {
          await _videoPlayer.seekTo(videoPosition);
        }
      }

      // End transition immediately — video is already playing
      _isTransitioningAudioSource = false;
      _transitionTargetPosition = null;
    } else {
      // Switching TO a separate audio source:
      // Pause audio player for smoother transition
      if (_audioPlayer.isPlaying) {
        await _audioPlayer.pause();
      }

      // Load the new audio source
      await _audioPlayer.load(source);

      // Set the audio offset for this source
      _currentAudioOffset = source.offset;

      // Calculate file position from logical position
      final filePosition = currentLogicalPosition - _currentAudioOffset;
      if (filePosition >= Duration.zero) {
        await _audioPlayer.seekTo(filePosition);
      } else {
        await _audioPlayer.seekTo(Duration.zero);
      }

      // Resume if was playing
      if (wasPlaying) {
        await _audioPlayer.play();
      } else {
        _isTransitioningAudioSource = false;
        _transitionTargetPosition = null;
      }
    }
  }

  /// Switch hover source (lyrics) during playback
  Future<void> switchHoverSource(HoverSource source) async {
    _updateState(_currentState.copyWith(activeHoverSource: source));
  }

  /// Update the current song unit reference without reloading playback
  /// Used when metadata changes but sources remain the same
  void updateCurrentUnit(SongUnit unit) {
    if (_currentUnit?.id == unit.id) {
      _currentUnit = unit;
      _updateState(_currentState.copyWith(currentUnit: unit));
    }
  }

  /// Switch display source during playback
  /// Maintains playback position during switch, applying offset
  Future<void> switchDisplaySource(DisplaySource source) async {
    if (_currentUnit == null) return;

    final audioPosition = _audioPlayer.position;
    final wasPlaying = _videoPlayer.isPlaying;

    // Stop current video
    await _videoPlayer.stop();

    // Load new display source
    await _videoPlayer.load(source);

    // Apply offset when seeking to current position
    final videoOffset = source.offset;
    final videoPosition = audioPosition - videoOffset;
    if (videoPosition >= Duration.zero) {
      await _videoPlayer.seekTo(videoPosition);
    } else {
      await _videoPlayer.seekTo(Duration.zero);
    }

    if (wasPlaying) {
      await _videoPlayer.play();
    }

    _updateState(
      _currentState.copyWith(
        activeDisplaySource: source,
        position: audioPosition,
      ),
      forceNotificationUpdate: true,
    );

    // Update video mute state based on new display source
    _updateVideoMuteState();
  }

  /// Select display source based on priority and user preference
  /// If preferredId is set and exists, use it; otherwise use highest priority
  /// Filters out video sources when in image-only mode
  DisplaySource? _selectDisplaySource(
    SourceCollection sources, [
    String? preferredId,
  ]) {
    if (sources.displaySources.isEmpty) return null;

    // Filter sources based on display mode
    var availableSources = sources.displaySources;
    if (_displayMode == DisplayMode.imageOnly) {
      // In image-only mode, filter out video sources
      availableSources = availableSources
          .where((s) => s.displayType == DisplayType.image)
          .toList();
      if (availableSources.isEmpty) return null;
    } else if (_displayMode == DisplayMode.disabled) {
      // In disabled mode, return null (no display source)
      return null;
    }

    // If preferred ID is set, try to find it in available sources
    if (preferredId != null) {
      final preferred = availableSources
          .where((s) => s.id == preferredId)
          .firstOrNull;
      if (preferred != null) return preferred;
    }

    // Fall back to priority-based selection from available sources
    final sorted = List<DisplaySource>.from(availableSources)
      ..sort((a, b) => a.priority.compareTo(b.priority));

    return sorted.first;
  }

  /// Select accompaniment source based on priority and user preference
  AccompanimentSource? _selectAccompanimentSource(
    SourceCollection sources, [
    String? preferredId,
  ]) {
    if (sources.accompanimentSources.isEmpty) return null;

    // If preferred ID is set, try to find it
    if (preferredId != null) {
      final preferred = sources.accompanimentSources
          .where((s) => s.id == preferredId)
          .firstOrNull;
      if (preferred != null) return preferred;
    }

    // Fall back to priority-based selection
    final sorted = List<AccompanimentSource>.from(sources.accompanimentSources)
      ..sort((a, b) => a.priority.compareTo(b.priority));

    return sorted.first;
  }

  /// Select hover source (lyrics) based on priority and user preference
  HoverSource? _selectHoverSource(
    SourceCollection sources, [
    String? preferredId,
  ]) {
    if (sources.hoverSources.isEmpty) return null;

    // If preferred ID is set, try to find it
    if (preferredId != null) {
      final preferred = sources.hoverSources
          .where((s) => s.id == preferredId)
          .firstOrNull;
      if (preferred != null) return preferred;
    }

    // Fall back to priority-based selection
    final sorted = List<HoverSource>.from(sources.hoverSources)
      ..sort((a, b) => a.priority.compareTo(b.priority));

    return sorted.first;
  }

  /// Resolve duration - audio source is authoritative
  /// Falls back to other sources if audio duration is not available
  Duration _resolveDuration(SourceCollection sources, Source? audioSource) {
    // Audio source duration is authoritative
    if (audioSource != null) {
      final audioDuration = audioSource.getDuration();
      if (audioDuration != null) {
        return audioDuration;
      }
    }

    // Fallback to accompaniment source
    final accompaniment = _selectAccompanimentSource(sources);
    if (accompaniment != null) {
      final accDuration = accompaniment.getDuration();
      if (accDuration != null) {
        return accDuration;
      }
    }

    // Fallback to display source
    final display = _selectDisplaySource(sources);
    if (display != null) {
      final displayDuration = display.getDuration();
      if (displayDuration != null) {
        return displayDuration;
      }
    }

    // Default duration
    return const Duration(minutes: 3);
  }

  /// Get sources sorted by priority for a given type
  List<Source> getSourcesByPriority(SourceType type) {
    if (_currentUnit == null) return [];

    List<Source> sources;
    switch (type) {
      case SourceType.display:
        sources = List.from(_currentUnit!.sources.displaySources);
        break;
      case SourceType.audio:
        sources = List.from(_currentUnit!.sources.audioSources);
        break;
      case SourceType.accompaniment:
        sources = List.from(_currentUnit!.sources.accompanimentSources);
        break;
      case SourceType.hover:
        sources = List.from(_currentUnit!.sources.hoverSources);
        break;
    }

    sources.sort((a, b) => a.priority.compareTo(b.priority));
    return sources;
  }

  /// Check if audio and accompaniment are mutually exclusive
  /// Returns true if only one is active at a time
  bool isAudioAccompanimentMutuallyExclusive() {
    final activeSource = _currentState.activeAudioSource;
    if (activeSource == null) return true;

    // Check that active source is either audio OR accompaniment, not both
    final isAudio = activeSource is AudioSource;
    final isAccompaniment = activeSource is AccompanimentSource;

    return isAudio != isAccompaniment; // XOR - exactly one should be true
  }

  /// Release resources
  Future<void> dispose() async {
    await _audioSubscription?.cancel();
    await _videoSubscription?.cancel();
    await _audioPlayer.dispose();
    await _videoPlayer.dispose();
    await _stateController.close();
  }
}
