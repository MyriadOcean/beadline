/// Property test for video mute routing invariant
///
/// **Feature: video-audio-extraction, Property 6: Video mute routing invariant**
/// **Validates: Requirements 3.1, 3.2, 3.3, 3.4**
///
/// For any playback state where both a video DisplaySource and an AudioSource
/// are active, the video player SHALL be muted (volume = 0) if and only if
/// the active AudioSource's linkedVideoSourceId does NOT equal the active
/// video DisplaySource's id. Conversely, the video player SHALL be unmuted
/// (volume > 0) if and only if the active audio IS the linked audio of the
/// active video.
library;

import 'dart:async';

import 'package:beadline/models/playback_preferences.dart';
import 'package:beadline/models/song_unit.dart';
import 'package:beadline/models/source.dart';
import 'package:beadline/models/source_collection.dart';
import 'package:beadline/services/platform_media_player.dart';
import 'package:beadline/services/player_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../models/test_generators.dart';

/// A mock media player that tracks volume changes for verification.
class _VolumeTrackingMockPlayer implements PlatformMediaPlayer {
  _VolumeTrackingMockPlayer();

  final StreamController<MediaPlayerState> _stateController =
      StreamController<MediaPlayerState>.broadcast();

  MediaPlayerState _currentState = const MediaPlayerState();
  double _volume = 1;
  bool _isPlaying = false;

  /// The last volume set on this player.
  double get lastVolume => _volume;

  @override
  Stream<MediaPlayerState> get stateStream => _stateController.stream;

  @override
  MediaPlayerState get currentState => _currentState;

  @override
  Duration get position => _currentState.position;

  @override
  Duration get duration => _currentState.duration;

  @override
  bool get isPlaying => _isPlaying;

  void _updateState(MediaPlayerState newState) {
    _currentState = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  @override
  Future<void> load(Source source) async {
    final dur = source.getDuration() ?? const Duration(minutes: 3);
    _updateState(
      _currentState.copyWith(
        status: PlaybackStatus.stopped,
        duration: dur,
        position: Duration.zero,
      ),
    );
  }

  @override
  Future<void> play() async {
    _isPlaying = true;
    _updateState(_currentState.copyWith(status: PlaybackStatus.playing));
  }

  @override
  Future<void> pause() async {
    _isPlaying = false;
    _updateState(_currentState.copyWith(status: PlaybackStatus.paused));
  }

  @override
  Future<void> resume() async {
    _isPlaying = true;
    _updateState(_currentState.copyWith(status: PlaybackStatus.playing));
  }

  @override
  Future<void> stop() async {
    _isPlaying = false;
    _updateState(
      _currentState.copyWith(
        status: PlaybackStatus.stopped,
        position: Duration.zero,
      ),
    );
  }

  @override
  Future<void> seekTo(Duration position) async {
    _updateState(_currentState.copyWith(position: position));
  }

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume;
  }

  @override
  Future<void> dispose() async {
    await _stateController.close();
  }
}

void main() {
  group('PlayerEngine Property Tests - Video Mute Routing', () {
    // ========================================================================
    // Feature: video-audio-extraction, Property 6: Video mute routing invariant
    // **Validates: Requirements 3.1, 3.2, 3.3, 3.4**
    // ========================================================================
    test(
      'Property 6: Video mute routing invariant — video unmuted iff active '
      'audio is linked to active video',
      () async {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          final audioPlayer = _VolumeTrackingMockPlayer();
          final videoPlayer = _VolumeTrackingMockPlayer();
          final engine = PlayerEngine(
            audioPlayer: audioPlayer,
            videoPlayer: videoPlayer,
          );

          // Generate a video DisplaySource
          final videoDisplay = DisplaySource(
            id: 'video-$i',
            origin: TestGenerators.randomSourceOrigin(),
            priority: 0,
            displayName: 'Video $i',
            displayType: DisplayType.video,
            duration: TestGenerators.randomDuration(),
          );

          // Decide the scenario for this iteration:
          // 0: Audio linked to this video (should unmute video)
          // 1: Audio linked to a DIFFERENT video (should mute video)
          // 2: Audio with null linkedVideoSourceId (should mute video)
          // 3: Non-video display source (image) with linked audio (should mute)
          final scenario = i % 4;

          late AudioSource audioSource;
          late DisplaySource activeDisplay;
          late bool expectVideoUnmuted;

          switch (scenario) {
            case 0:
              // Audio IS linked to the active video → unmute video
              audioSource = AudioSource(
                id: 'audio-$i',
                origin: videoDisplay.origin,
                priority: 0,
                format: AudioFormat
                    .values[TestGenerators.randomInt(0, AudioFormat.values.length - 1)],
                duration: TestGenerators.randomDuration(),
                linkedVideoSourceId: videoDisplay.id,
              );
              activeDisplay = videoDisplay;
              expectVideoUnmuted = true;

            case 1:
              // Audio linked to a DIFFERENT video → mute video
              audioSource = AudioSource(
                id: 'audio-$i',
                origin: TestGenerators.randomSourceOrigin(),
                priority: 0,
                format: AudioFormat
                    .values[TestGenerators.randomInt(0, AudioFormat.values.length - 1)],
                duration: TestGenerators.randomDuration(),
                linkedVideoSourceId: 'other-video-$i',
              );
              activeDisplay = videoDisplay;
              expectVideoUnmuted = false;

            case 2:
              // Audio with null linkedVideoSourceId → mute video
              audioSource = AudioSource(
                id: 'audio-$i',
                origin: TestGenerators.randomSourceOrigin(),
                priority: 0,
                format: AudioFormat
                    .values[TestGenerators.randomInt(0, AudioFormat.values.length - 1)],
                duration: TestGenerators.randomDuration(),
              );
              activeDisplay = videoDisplay;
              expectVideoUnmuted = false;

            case 3:
              // Image display source (not video) → mute video even if linked
              audioSource = AudioSource(
                id: 'audio-$i',
                origin: TestGenerators.randomSourceOrigin(),
                priority: 0,
                format: AudioFormat
                    .values[TestGenerators.randomInt(0, AudioFormat.values.length - 1)],
                duration: TestGenerators.randomDuration(),
                linkedVideoSourceId: 'image-display-$i',
              );
              activeDisplay = DisplaySource(
                id: 'image-display-$i',
                origin: TestGenerators.randomSourceOrigin(),
                priority: 0,
                displayType: DisplayType.image,
                duration: TestGenerators.randomDuration(),
              );
              expectVideoUnmuted = false;
          }

          final sources = SourceCollection(
            displaySources: [activeDisplay],
            audioSources: [audioSource],
          );

          final songUnit = SongUnit(
            id: 'unit-$i',
            metadata: TestGenerators.randomMetadata(),
            sources: sources,
            preferences: PlaybackPreferences.defaults(),
          );

          // Play triggers _updateVideoMuteState
          await engine.play(songUnit);

          // Verify the invariant
          if (expectVideoUnmuted) {
            expect(
              videoPlayer.lastVolume,
              equals(1.0),
              reason:
                  'Iteration $i (scenario $scenario): Video player should be '
                  'UNMUTED (volume=1.0) when active audio is linked to '
                  'active video',
            );
            expect(
              audioPlayer.lastVolume,
              equals(0.0),
              reason:
                  'Iteration $i (scenario $scenario): Audio player should be '
                  'MUTED (volume=0.0) when video audio is active',
            );
          } else {
            expect(
              videoPlayer.lastVolume,
              equals(0.0),
              reason:
                  'Iteration $i (scenario $scenario): Video player should be '
                  'MUTED (volume=0.0) when active audio is NOT linked to '
                  'active video',
            );
            expect(
              audioPlayer.lastVolume,
              equals(1.0),
              reason:
                  'Iteration $i (scenario $scenario): Audio player should be '
                  'UNMUTED (volume=1.0) when video audio is not active',
            );
          }

          await engine.dispose();
        }
      },
    );

    test(
      'Property 6: Video mute routing invariant — switching audio source '
      'updates mute state correctly',
      () async {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          final audioPlayer = _VolumeTrackingMockPlayer();
          final videoPlayer = _VolumeTrackingMockPlayer();
          final engine = PlayerEngine(
            audioPlayer: audioPlayer,
            videoPlayer: videoPlayer,
          );

          // Create a video display source
          final videoDisplay = DisplaySource(
            id: 'video-switch-$i',
            origin: TestGenerators.randomSourceOrigin(),
            priority: 0,
            displayType: DisplayType.video,
            duration: TestGenerators.randomDuration(),
          );

          // Create linked audio (from video) and unlinked audio
          final linkedAudio = AudioSource(
            id: 'linked-audio-$i',
            origin: videoDisplay.origin,
            priority: 1,
            format: AudioFormat.mp3,
            duration: TestGenerators.randomDuration(),
            linkedVideoSourceId: videoDisplay.id,
          );

          final unlinkedAudio = AudioSource(
            id: 'unlinked-audio-$i',
            origin: TestGenerators.randomSourceOrigin(),
            priority: 0,
            format: AudioFormat.mp3,
            duration: TestGenerators.randomDuration(),
          );

          final sources = SourceCollection(
            displaySources: [videoDisplay],
            audioSources: [unlinkedAudio, linkedAudio],
          );

          final songUnit = SongUnit(
            id: 'unit-switch-$i',
            metadata: TestGenerators.randomMetadata(),
            sources: sources,
            preferences: PlaybackPreferences.defaults(),
          );

          // Play — unlinked audio has priority 0, so it's selected first
          await engine.play(songUnit);

          // Verify: unlinked audio active → video muted
          expect(
            videoPlayer.lastVolume,
            equals(0.0),
            reason:
                'Iteration $i: After play with unlinked audio, video should '
                'be muted',
          );
          expect(
            audioPlayer.lastVolume,
            equals(1.0),
            reason:
                'Iteration $i: After play with unlinked audio, audio player '
                'should be unmuted',
          );

          // Switch to linked audio → video should unmute
          await engine.switchAudioSource(linkedAudio);

          expect(
            videoPlayer.lastVolume,
            equals(1.0),
            reason:
                'Iteration $i: After switching to linked audio, video should '
                'be unmuted',
          );
          expect(
            audioPlayer.lastVolume,
            equals(0.0),
            reason:
                'Iteration $i: After switching to linked audio, audio player '
                'should be muted',
          );

          // Switch back to unlinked audio → video should mute again
          await engine.switchAudioSource(unlinkedAudio);

          expect(
            videoPlayer.lastVolume,
            equals(0.0),
            reason:
                'Iteration $i: After switching back to unlinked audio, video '
                'should be muted',
          );
          expect(
            audioPlayer.lastVolume,
            equals(1.0),
            reason:
                'Iteration $i: After switching back to unlinked audio, audio '
                'player should be unmuted',
          );

          await engine.dispose();
        }
      },
    );

    test(
      'Property 6: Video mute routing invariant — switching to accompaniment '
      'always mutes video',
      () async {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          final audioPlayer = _VolumeTrackingMockPlayer();
          final videoPlayer = _VolumeTrackingMockPlayer();
          final engine = PlayerEngine(
            audioPlayer: audioPlayer,
            videoPlayer: videoPlayer,
          );

          final videoDisplay = DisplaySource(
            id: 'video-acc-$i',
            origin: TestGenerators.randomSourceOrigin(),
            priority: 0,
            displayType: DisplayType.video,
            duration: TestGenerators.randomDuration(),
          );

          // Start with linked audio (video unmuted)
          final linkedAudio = AudioSource(
            id: 'linked-acc-$i',
            origin: videoDisplay.origin,
            priority: 0,
            format: AudioFormat.mp3,
            duration: TestGenerators.randomDuration(),
            linkedVideoSourceId: videoDisplay.id,
          );

          final accompaniment = AccompanimentSource(
            id: 'accompaniment-$i',
            origin: TestGenerators.randomSourceOrigin(),
            priority: 0,
            format: AudioFormat.mp3,
            duration: TestGenerators.randomDuration(),
          );

          final sources = SourceCollection(
            displaySources: [videoDisplay],
            audioSources: [linkedAudio],
            accompanimentSources: [accompaniment],
          );

          final songUnit = SongUnit(
            id: 'unit-acc-$i',
            metadata: TestGenerators.randomMetadata(),
            sources: sources,
            preferences: PlaybackPreferences.defaults(),
          );

          // Play with linked audio → video unmuted
          await engine.play(songUnit);
          expect(
            videoPlayer.lastVolume,
            equals(1.0),
            reason:
                'Iteration $i: Video should be unmuted with linked audio',
          );

          // Switch to accompaniment → video should mute
          await engine.switchToAccompaniment();

          expect(
            videoPlayer.lastVolume,
            equals(0.0),
            reason:
                'Iteration $i: Video should be muted after switching to '
                'accompaniment (accompaniment is never linked to video)',
          );
          expect(
            audioPlayer.lastVolume,
            equals(1.0),
            reason:
                'Iteration $i: Audio player should be unmuted for '
                'accompaniment playback',
          );

          // Switch back to original → video should unmute again
          await engine.switchToOriginal();

          expect(
            videoPlayer.lastVolume,
            equals(1.0),
            reason:
                'Iteration $i: Video should be unmuted after switching back '
                'to linked original audio',
          );

          await engine.dispose();
        }
      },
    );
  });
}
