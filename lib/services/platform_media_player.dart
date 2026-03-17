import 'dart:async';
import 'dart:io';

import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart' show VideoController;

import '../models/source.dart';
import '../models/source_origin.dart';

/// Playback status enumeration
enum PlaybackStatus {
  idle,
  loading,
  playing,
  paused,
  stopped,
  completed,
  error,
}

/// Media player state
class MediaPlayerState {
  const MediaPlayerState({
    this.status = PlaybackStatus.idle,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.errorMessage,
  });

  final PlaybackStatus status;
  final Duration position;
  final Duration duration;
  final String? errorMessage;

  MediaPlayerState copyWith({
    PlaybackStatus? status,
    Duration? position,
    Duration? duration,
    String? errorMessage,
  }) {
    return MediaPlayerState(
      status: status ?? this.status,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaPlayerState &&
          status == other.status &&
          position == other.position &&
          duration == other.duration &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode =>
      status.hashCode ^
      position.hashCode ^
      duration.hashCode ^
      errorMessage.hashCode;
}

/// Abstract interface for platform media players
abstract class PlatformMediaPlayer {
  Stream<MediaPlayerState> get stateStream;
  MediaPlayerState get currentState;
  Future<void> load(Source source);
  Future<void> play();
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> seekTo(Duration position);
  Future<void> setVolume(double volume);
  Duration get position;
  Duration get duration;
  bool get isPlaying;
  Future<void> dispose();
}

/// Mock audio player for testing - simulates playback with timers
class MockAudioMediaPlayer implements PlatformMediaPlayer {
  MockAudioMediaPlayer();

  final StreamController<MediaPlayerState> _stateController =
      StreamController<MediaPlayerState>.broadcast();

  MediaPlayerState _currentState = const MediaPlayerState();
  Source? _currentSource;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Timer? _positionTimer;
  bool _isPlaying = false;

  @override
  Stream<MediaPlayerState> get stateStream => _stateController.stream;

  @override
  MediaPlayerState get currentState => _currentState;

  @override
  Duration get position => _position;

  @override
  Duration get duration => _duration;

  @override
  bool get isPlaying => _isPlaying;

  void _updateState(MediaPlayerState newState) {
    if (_currentState != newState) {
      _currentState = newState;
      if (!_stateController.isClosed) {
        _stateController.add(newState);
      }
    }
  }

  @override
  Future<void> load(Source source) async {
    _currentSource = source;
    _updateState(_currentState.copyWith(status: PlaybackStatus.loading));
    _duration = source.getDuration() ?? const Duration(minutes: 3);
    _position = Duration.zero;
    _updateState(
      _currentState.copyWith(
        status: PlaybackStatus.stopped,
        duration: _duration,
        position: _position,
      ),
    );
  }

  @override
  Future<void> play() async {
    if (_currentSource == null) return;
    _isPlaying = true;
    _updateState(_currentState.copyWith(status: PlaybackStatus.playing));
    _startPositionTracking();
  }

  @override
  Future<void> pause() async {
    _isPlaying = false;
    _stopPositionTracking();
    _updateState(_currentState.copyWith(status: PlaybackStatus.paused));
  }

  @override
  Future<void> resume() async {
    if (_currentSource == null) return;
    _isPlaying = true;
    _updateState(_currentState.copyWith(status: PlaybackStatus.playing));
    _startPositionTracking();
  }

  @override
  Future<void> stop() async {
    _isPlaying = false;
    _stopPositionTracking();
    _position = Duration.zero;
    _updateState(
      _currentState.copyWith(
        status: PlaybackStatus.stopped,
        position: Duration.zero,
      ),
    );
  }

  @override
  Future<void> seekTo(Duration position) async {
    _position = position;
    _updateState(_currentState.copyWith(position: position));
  }

  @override
  Future<void> setVolume(double volume) async {}

  void _startPositionTracking() {
    _stopPositionTracking();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_isPlaying && _position < _duration) {
        _position += const Duration(milliseconds: 100);
        _updateState(_currentState.copyWith(position: _position));
        if (_position >= _duration) {
          _isPlaying = false;
          _stopPositionTracking();
          _updateState(
            _currentState.copyWith(status: PlaybackStatus.completed),
          );
        }
      }
    });
  }

  void _stopPositionTracking() {
    _positionTimer?.cancel();
    _positionTimer = null;
  }

  @override
  Future<void> dispose() async {
    _stopPositionTracking();
    if (!_stateController.isClosed) await _stateController.close();
  }
}

/// Unified media_kit player implementation.
///
/// Used for both audio-only and video playback. Wraps a single [mk.Player]
/// and exposes it via [nativePlayer] so that the UI layer can attach a
/// [VideoController] for rendering without creating a second player instance.
class MediaKitPlayer implements PlatformMediaPlayer {
  MediaKitPlayer() {
    _setupListeners();
  }

  final mk.Player _player = mk.Player();
  final StreamController<MediaPlayerState> _stateController =
      StreamController<MediaPlayerState>.broadcast();

  MediaPlayerState _currentState = const MediaPlayerState();
  Source? _currentSource;
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<bool>? _completedSubscription;
  String? _pendingMediaPath;
  Duration? _pendingSeekPosition;
  bool _isLoadingWithSeek = false;

  /// The underlying media_kit [mk.Player].
  ///
  /// Use this to create a [VideoController] for rendering video frames.
  /// Do NOT call open/play/pause/stop/seek on this directly — go through
  /// the [PlatformMediaPlayer] interface instead.
  mk.Player get nativePlayer => _player;

  @override
  Stream<MediaPlayerState> get stateStream => _stateController.stream;

  @override
  MediaPlayerState get currentState => _currentState;

  @override
  Duration get position => _currentState.position;

  @override
  Duration get duration => _currentState.duration;

  @override
  bool get isPlaying => _currentState.status == PlaybackStatus.playing;

  void _updateState(MediaPlayerState newState) {
    if (_currentState != newState) {
      _currentState = newState;
      if (!_stateController.isClosed) {
        _stateController.add(newState);
      }
    }
  }

  void _setupListeners() {
    _playingSubscription = _player.stream.playing.listen((playing) {
      if (playing) {
        _updateState(_currentState.copyWith(status: PlaybackStatus.playing));
      } else if (_currentState.status == PlaybackStatus.playing) {
        _updateState(_currentState.copyWith(status: PlaybackStatus.paused));
      }
    });

    _positionSubscription = _player.stream.position.listen((pos) {
      if (!_isLoadingWithSeek) {
        _updateState(_currentState.copyWith(position: pos));
      }
    });

    _durationSubscription = _player.stream.duration.listen((dur) {
      if (dur != Duration.zero) {
        _updateState(_currentState.copyWith(duration: dur));
      }
    });

    _completedSubscription = _player.stream.completed.listen((completed) {
      if (completed) {
        _updateState(_currentState.copyWith(status: PlaybackStatus.completed));
      }
    });
  }

  @override
  Future<void> load(Source source) async {
    _currentSource = source;
    _pendingSeekPosition = null;
    _isLoadingWithSeek = false;
    _updateState(_currentState.copyWith(status: PlaybackStatus.loading));

    try {
      final origin = source.origin;

      if (origin is LocalFileOrigin) {
        final file = File(origin.path);
        if (!file.existsSync()) {
          _updateState(
            _currentState.copyWith(
              status: PlaybackStatus.error,
              errorMessage: 'File not found: ${origin.path}',
            ),
          );
          return;
        }
        _pendingMediaPath = origin.path;
      } else if (origin is UrlOrigin) {
        final url = origin.url;
        if (url.isEmpty) {
          _updateState(
            _currentState.copyWith(
              status: PlaybackStatus.error,
              errorMessage: 'URL is empty',
            ),
          );
          return;
        }
        try {
          final uri = Uri.parse(url);
          if (!uri.hasScheme ||
              (!uri.isScheme('http') && !uri.isScheme('https'))) {
            _updateState(
              _currentState.copyWith(
                status: PlaybackStatus.error,
                errorMessage:
                    'Invalid URL scheme. Only http and https are supported.',
              ),
            );
            return;
          }
        } catch (e) {
          _updateState(
            _currentState.copyWith(
              status: PlaybackStatus.error,
              errorMessage: 'Invalid URL format: $url',
            ),
          );
          return;
        }
        _pendingMediaPath = url;
      } else if (origin is ApiOrigin) {
        _updateState(
          _currentState.copyWith(
            status: PlaybackStatus.error,
            errorMessage: 'API sources not yet supported',
          ),
        );
        return;
      }

      final sourceDuration = source.getDuration();
      _updateState(
        _currentState.copyWith(
          status: PlaybackStatus.stopped,
          duration: sourceDuration ?? Duration.zero,
          position: Duration.zero,
        ),
      );
    } catch (e) {
      _updateState(
        _currentState.copyWith(
          status: PlaybackStatus.error,
          errorMessage: 'Failed to load: $e',
        ),
      );
    }
  }

  @override
  Future<void> play() async {
    if (_currentSource == null || _pendingMediaPath == null) return;
    if (_currentState.status == PlaybackStatus.error) return;

    if (_player.state.duration != Duration.zero) {
      // Already loaded, just resume
      await resume();
      return;
    }

    _updateState(_currentState.copyWith(status: PlaybackStatus.loading));
    try {
      await _player.open(mk.Media(_pendingMediaPath!));
      if (_pendingSeekPosition != null) {
        await _player.seek(_pendingSeekPosition!);
        _pendingSeekPosition = null;
        _isLoadingWithSeek = false;
      }
    } catch (e) {
      _updateState(
        _currentState.copyWith(
          status: PlaybackStatus.error,
          errorMessage: 'Failed to play: $e',
        ),
      );
    }
  }

  /// Open the media file and immediately pause.
  /// This makes the first video frame available and allows seeking,
  /// without producing any audible output.
  /// If [seekPosition] is provided, seeks to that position after opening.
  Future<void> openPaused({Duration? seekPosition}) async {
    if (_currentSource == null || _pendingMediaPath == null) return;
    if (_currentState.status == PlaybackStatus.error) return;

    try {
      await _player.open(mk.Media(_pendingMediaPath!), play: false);

      // Wait for the player to be ready (duration becomes available)
      if (seekPosition != null && seekPosition > Duration.zero) {
        var attempts = 0;
        while (attempts < 30) {
          if (_player.state.duration != Duration.zero) break;
          await Future.delayed(const Duration(milliseconds: 50));
          attempts++;
        }
        await _player.seek(seekPosition);
      }

      _updateState(_currentState.copyWith(status: PlaybackStatus.paused));
    } catch (e) {
      _updateState(
        _currentState.copyWith(
          status: PlaybackStatus.error,
          errorMessage: 'Failed to openPaused: $e',
        ),
      );
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (e) {
      _updateState(
        _currentState.copyWith(
          status: PlaybackStatus.error,
          errorMessage: 'Failed to pause: $e',
        ),
      );
    }
  }

  @override
  Future<void> resume() async {
    if (_currentSource == null) return;
    if (_currentState.status == PlaybackStatus.error) return;
    try {
      await _player.play();
    } catch (e) {
      _updateState(
        _currentState.copyWith(
          status: PlaybackStatus.error,
          errorMessage: 'Failed to resume: $e',
        ),
      );
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
      _pendingSeekPosition = null;
      _isLoadingWithSeek = false;
      _updateState(
        _currentState.copyWith(
          status: PlaybackStatus.stopped,
          position: Duration.zero,
        ),
      );
    } catch (e) {
      _updateState(
        _currentState.copyWith(
          status: PlaybackStatus.error,
          errorMessage: 'Failed to stop: $e',
        ),
      );
    }
  }

  @override
  Future<void> seekTo(Duration position) async {
    try {
      if (_player.state.duration == Duration.zero) {
        _pendingSeekPosition = position;
        _isLoadingWithSeek = true;
        _updateState(_currentState.copyWith(position: position));
        return;
      }

      await _player.seek(position);
      _updateState(_currentState.copyWith(position: position));
      _pendingSeekPosition = null;
      _isLoadingWithSeek = false;
    } catch (e) {
      _updateState(
        _currentState.copyWith(
          status: PlaybackStatus.error,
          errorMessage: 'Failed to seek: $e',
        ),
      );
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    final clampedVolume = volume.clamp(0.0, 1.0);
    try {
      await _player.setVolume(clampedVolume * 100);
    } catch (e) {
      _updateState(
        _currentState.copyWith(
          status: PlaybackStatus.error,
          errorMessage: 'Failed to set volume: $e',
        ),
      );
    }
  }

  @override
  Future<void> dispose() async {
    await _playingSubscription?.cancel();
    await _positionSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _completedSubscription?.cancel();
    await _player.dispose();
    if (!_stateController.isClosed) await _stateController.close();
  }
}

/// Factory for creating media players
class MediaPlayerFactory {
  static PlatformMediaPlayer createPlayer(SourceType sourceType) {
    switch (sourceType) {
      case SourceType.display:
      case SourceType.audio:
      case SourceType.accompaniment:
        return MediaKitPlayer();
      case SourceType.hover:
        throw ArgumentError('Hover sources do not require a media player');
    }
  }
}
