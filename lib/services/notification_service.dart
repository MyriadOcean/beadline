import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

/// Service for managing media playback notifications and media session
/// via audio_service (Android, iOS, Linux MPRIS, macOS).
///
/// Replaces the old custom MethodChannel + native MediaPlaybackService approach.
/// audio_service handles:
///   - Android foreground service + notification
///   - iOS lock screen / control center
///   - Linux MPRIS (via audio_service_mpris)
///   - macOS Now Playing info
class NotificationService {
  NotificationService();

  BeadlineAudioHandler? _audioHandler;

  /// Callbacks for notification button actions
  Future<void> Function()? onPlayPause;
  Future<void> Function()? onPlay;
  Future<void> Function()? onPause;
  Future<void> Function()? onPrevious;
  Future<void> Function()? onNext;
  Future<void> Function()? onStop;
  Future<void> Function(int position)? onSeek;

  /// Initialize audio_service. Must be called once at app startup.
  Future<void> initialize() async {
    _audioHandler = await AudioService.init(
      builder: () => BeadlineAudioHandler(this),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.example.beadline.playback',
        androidNotificationChannelName: 'Music Playback',
        androidNotificationOngoing: true,
      ),
    );

    // Configure audio session for music playback
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (e) {
      debugPrint('NotificationService: Failed to configure audio session: $e');
    }
  }

  /// Show a media playback notification
  Future<void> showNotification({
    required String title,
    required String artist,
    required bool isPlaying,
    String? thumbnailPath,
    int? position,
    int? duration,
  }) async {
    final handler = _audioHandler;
    if (handler == null) return;

    // Update the media item (metadata shown in notification)
    handler.mediaItem.add(MediaItem(
      id: 'current',
      title: title,
      artist: artist,
      duration: duration != null && duration > 0
          ? Duration(milliseconds: duration)
          : null,
      artUri: thumbnailPath != null ? Uri.file(thumbnailPath) : null,
    ));

    // Update playback state
    handler.playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (isPlaying) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: AudioProcessingState.ready,
      playing: isPlaying,
      updatePosition: position != null
          ? Duration(milliseconds: position)
          : Duration.zero,
      updateTime: DateTime.now(),
    ));
  }

  /// Hide the media playback notification
  Future<void> hideNotification() async {
    final handler = _audioHandler;
    if (handler == null) return;

    handler.playbackState.add(PlaybackState(
      controls: [],
    ));
  }

  /// Request audio focus (handled automatically by audio_session on Android)
  Future<void> requestAudioFocus() async {
    try {
      final session = await AudioSession.instance;
      await session.setActive(true);
    } catch (e) {
      debugPrint('NotificationService: Failed to request audio focus: $e');
    }
  }
}

/// AudioHandler implementation that bridges audio_service callbacks
/// to the NotificationService's Dart callbacks.
///
/// audio_service requires an AudioHandler subclass. This handler doesn't
/// manage actual playback — it just forwards media button events to the
/// NotificationService callbacks, which in turn drive PlayerEngine.
class BeadlineAudioHandler extends BaseAudioHandler with SeekHandler {
  BeadlineAudioHandler(this._notificationService);

  final NotificationService _notificationService;

  @override
  Future<void> play() async {
    await _notificationService.onPlay?.call();
  }

  @override
  Future<void> pause() async {
    await _notificationService.onPause?.call();
  }

  @override
  Future<void> stop() async {
    await _notificationService.onStop?.call();
  }

  @override
  Future<void> skipToPrevious() async {
    await _notificationService.onPrevious?.call();
  }

  @override
  Future<void> skipToNext() async {
    await _notificationService.onNext?.call();
  }

  @override
  Future<void> seek(Duration position) async {
    await _notificationService.onSeek?.call(position.inMilliseconds);
  }
}
