import 'package:shared_preferences/shared_preferences.dart';

/// Storage service for persisting playback state across app restarts
class PlaybackStateStorage {
  static const _keyCurrentSongId = 'playback_current_song_id';
  static const _keyCurrentPosition = 'playback_current_position_ms';
  static const _keyIsPlaying = 'playback_is_playing';
  static const _keyAudioMode = 'playback_audio_mode';
  static const _keyCurrentQueueId = 'playback_current_queue_id';
  static const _keyRepeatMode = 'playback_repeat_mode';
  static const _keyShuffleEnabled = 'playback_shuffle_enabled';

  /// Save current playback state
  Future<void> savePlaybackState({
    String? currentSongId,
    int? currentPositionMs,
    bool? isPlaying,
    String? audioMode,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (currentSongId != null) {
      await prefs.setString(_keyCurrentSongId, currentSongId);
    }

    if (currentPositionMs != null) {
      await prefs.setInt(_keyCurrentPosition, currentPositionMs);
    }

    if (isPlaying != null) {
      await prefs.setBool(_keyIsPlaying, isPlaying);
    }

    if (audioMode != null) {
      await prefs.setString(_keyAudioMode, audioMode);
    }
  }

  /// Get saved playback state
  Future<Map<String, dynamic>> getPlaybackState() async {
    final prefs = await SharedPreferences.getInstance();

    return {
      'currentSongId': prefs.getString(_keyCurrentSongId),
      'currentPositionMs': prefs.getInt(_keyCurrentPosition),
      'isPlaying': prefs.getBool(_keyIsPlaying) ?? false,
      'audioMode': prefs.getString(_keyAudioMode) ?? 'original',
    };
  }

  /// Clear playback state (when song ends or is stopped)
  Future<void> clearPlaybackState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCurrentSongId);
    await prefs.remove(_keyCurrentPosition);
    await prefs.remove(_keyIsPlaying);
  }

  /// Save queue state
  Future<void> saveQueueState({
    String? currentQueueId,
    String? repeatMode,
    bool? shuffleEnabled,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (currentQueueId != null) {
      await prefs.setString(_keyCurrentQueueId, currentQueueId);
    }

    if (repeatMode != null) {
      await prefs.setString(_keyRepeatMode, repeatMode);
    }

    if (shuffleEnabled != null) {
      await prefs.setBool(_keyShuffleEnabled, shuffleEnabled);
    }
  }

  /// Get saved queue state
  Future<Map<String, dynamic>> getQueueState() async {
    final prefs = await SharedPreferences.getInstance();

    return {
      'currentQueueId': prefs.getString(_keyCurrentQueueId),
      'repeatMode': prefs.getString(_keyRepeatMode) ?? 'off',
      'shuffleEnabled': prefs.getBool(_keyShuffleEnabled) ?? false,
    };
  }
}
