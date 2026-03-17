import 'package:beadline/models/playback_preferences.dart';
import 'package:beadline/models/song_unit.dart';
import 'package:beadline/models/source.dart';
import 'package:beadline/models/source_collection.dart';
import 'package:beadline/services/player_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../models/test_generators.dart';

void main() {
  group('PlayerEngine Property Tests', () {
    late PlayerEngine engine;

    setUp(() {
      engine = PlayerEngine();
    });

    tearDown(() async {
      await engine.dispose();
    });

    // Feature: song-unit-core, Property 6: Audio-accompaniment mutual exclusion
    // *For any* Song Unit with both Audio and Accompaniment sources,
    // at most one SHALL be active for playback at any given time
    // **Validates: Requirements 2.3**
    group('Property 6: Audio-accompaniment mutual exclusion', () {
      test('only one audio type is active at a time', () async {
        // Run 100 iterations with random data
        for (var i = 0; i < 100; i++) {
          final engine = PlayerEngine();

          // Generate a SongUnit with both audio and accompaniment sources
          final audioSources = List.generate(
            TestGenerators.randomInt(1, 3),
            (idx) => TestGenerators.randomAudioSource(priority: idx),
          );
          final accompanimentSources = List.generate(
            TestGenerators.randomInt(1, 3),
            (idx) => TestGenerators.randomAccompanimentSource(priority: idx),
          );

          final sources = SourceCollection(
            audioSources: audioSources,
            accompanimentSources: accompanimentSources,
            displaySources: [TestGenerators.randomDisplaySource()],
          );

          final songUnit = SongUnit(
            id: 'test-$i',
            metadata: TestGenerators.randomMetadata(),
            sources: sources,
            preferences: PlaybackPreferences.defaults(),
          );

          // Play the song unit
          await engine.play(songUnit);

          // Verify mutual exclusion - active source is either audio OR accompaniment
          expect(
            engine.isAudioAccompanimentMutuallyExclusive(),
            isTrue,
            reason: 'Audio and accompaniment should be mutually exclusive',
          );

          // Switch to accompaniment
          await engine.switchToAccompaniment();
          expect(
            engine.isAudioAccompanimentMutuallyExclusive(),
            isTrue,
            reason:
                'After switching to accompaniment, mutual exclusion should hold',
          );

          // Verify active source is accompaniment type
          final activeAfterSwitch = engine.currentState.activeAudioSource;
          expect(
            activeAfterSwitch is AccompanimentSource,
            isTrue,
            reason: 'Active source should be AccompanimentSource after switch',
          );

          // Switch back to original
          await engine.switchToOriginal();
          expect(
            engine.isAudioAccompanimentMutuallyExclusive(),
            isTrue,
            reason:
                'After switching back to original, mutual exclusion should hold',
          );

          // Verify active source is audio type
          final activeAfterOriginal = engine.currentState.activeAudioSource;
          expect(
            activeAfterOriginal is AudioSource,
            isTrue,
            reason:
                'Active source should be AudioSource after switching to original',
          );

          await engine.dispose();
        }
      });
    });

    // Feature: song-unit-core, Property 7: Source priority ordering preservation
    // *For any* Song Unit with multiple sources of the same type,
    // the user-defined priority order SHALL be maintained and SHALL determine selection order
    // **Validates: Requirements 2.5, 2.6**
    group('Property 7: Source priority ordering preservation', () {
      test('sources are returned in priority order', () async {
        for (var i = 0; i < 100; i++) {
          final engine = PlayerEngine();

          // Generate sources with random priorities
          final numSources = TestGenerators.randomInt(2, 5);
          final priorities = List.generate(
            numSources,
            (_) => TestGenerators.randomInt(0, 100),
          );

          final audioSources = List.generate(
            numSources,
            (idx) =>
                TestGenerators.randomAudioSource(priority: priorities[idx]),
          );

          final displaySources = List.generate(
            numSources,
            (idx) =>
                TestGenerators.randomDisplaySource(priority: priorities[idx]),
          );

          final sources = SourceCollection(
            audioSources: audioSources,
            displaySources: displaySources,
          );

          final songUnit = SongUnit(
            id: 'test-$i',
            metadata: TestGenerators.randomMetadata(),
            sources: sources,
            preferences: PlaybackPreferences.defaults(),
          );

          await engine.play(songUnit);

          // Get sources by priority
          final sortedAudio = engine.getSourcesByPriority(SourceType.audio);
          final sortedDisplay = engine.getSourcesByPriority(SourceType.display);

          // Verify audio sources are sorted by priority
          for (var j = 0; j < sortedAudio.length - 1; j++) {
            expect(
              sortedAudio[j].priority <= sortedAudio[j + 1].priority,
              isTrue,
              reason: 'Audio sources should be sorted by priority (ascending)',
            );
          }

          // Verify display sources are sorted by priority
          for (var j = 0; j < sortedDisplay.length - 1; j++) {
            expect(
              sortedDisplay[j].priority <= sortedDisplay[j + 1].priority,
              isTrue,
              reason:
                  'Display sources should be sorted by priority (ascending)',
            );
          }

          await engine.dispose();
        }
      });
    });

    // Feature: song-unit-core, Property 8: Priority-based source selection
    // *For any* Song Unit with multiple sources of a given type,
    // playback SHALL select the source with the highest priority (lowest priority number)
    // **Validates: Requirements 3.1, 3.2, 3.3**
    group('Property 8: Priority-based source selection', () {
      test('highest priority source is selected for playback', () async {
        for (var i = 0; i < 100; i++) {
          final engine = PlayerEngine();

          // Generate sources with distinct priorities
          final audioSources = [
            TestGenerators.randomAudioSource(priority: 5),
            TestGenerators.randomAudioSource(priority: 1), // Highest priority
            TestGenerators.randomAudioSource(priority: 10),
          ];

          final displaySources = [
            TestGenerators.randomDisplaySource(priority: 3),
            TestGenerators.randomDisplaySource(priority: 0), // Highest priority
            TestGenerators.randomDisplaySource(priority: 7),
          ];

          final hoverSources = [
            TestGenerators.randomHoverSource(priority: 2),
            TestGenerators.randomHoverSource(priority: 8),
            TestGenerators.randomHoverSource(priority: 0), // Highest priority
          ];

          final sources = SourceCollection(
            audioSources: audioSources,
            displaySources: displaySources,
            hoverSources: hoverSources,
          );

          final songUnit = SongUnit(
            id: 'test-$i',
            metadata: TestGenerators.randomMetadata(),
            sources: sources,
            preferences: PlaybackPreferences.defaults(),
          );

          await engine.play(songUnit);

          // Verify highest priority audio source is selected (priority 1)
          expect(
            engine.currentState.activeAudioSource?.priority,
            equals(1),
            reason:
                'Audio source with lowest priority number should be selected',
          );

          // Verify highest priority display source is selected (priority 0)
          expect(
            engine.currentState.activeDisplaySource?.priority,
            equals(0),
            reason:
                'Display source with lowest priority number should be selected',
          );

          // Verify highest priority hover source is selected (priority 0)
          expect(
            engine.currentState.activeHoverSource?.priority,
            equals(0),
            reason:
                'Hover source with lowest priority number should be selected',
          );

          await engine.dispose();
        }
      });
    });

    // Feature: song-unit-core, Property 9: Audio duration authority
    // *For any* Song Unit with sources of inconsistent durations,
    // the Audio Source duration SHALL be used as the authoritative duration for the Song Unit
    // **Validates: Requirements 3.4**
    group('Property 9: Audio duration authority', () {
      test('audio source duration is used as authoritative', () async {
        for (var i = 0; i < 100; i++) {
          final engine = PlayerEngine();

          // Generate sources with different durations
          final audioDuration = Duration(
            seconds: TestGenerators.randomInt(100, 300),
          );
          final displayDuration = Duration(
            seconds: TestGenerators.randomInt(50, 400),
          );
          final accompanimentDuration = Duration(
            seconds: TestGenerators.randomInt(80, 350),
          );

          final audioSource = AudioSource(
            id: 'audio-$i',
            origin: TestGenerators.randomSourceOrigin(),
            priority: 0,
            format: AudioFormat.mp3,
            duration: audioDuration,
          );

          final displaySource = DisplaySource(
            id: 'display-$i',
            origin: TestGenerators.randomSourceOrigin(),
            priority: 0,
            displayType: DisplayType.video,
            duration: displayDuration,
          );

          final accompanimentSource = AccompanimentSource(
            id: 'accompaniment-$i',
            origin: TestGenerators.randomSourceOrigin(),
            priority: 0,
            format: AudioFormat.mp3,
            duration: accompanimentDuration,
          );

          final sources = SourceCollection(
            audioSources: [audioSource],
            displaySources: [displaySource],
            accompanimentSources: [accompanimentSource],
          );

          final songUnit = SongUnit(
            id: 'test-$i',
            metadata: TestGenerators.randomMetadata(),
            sources: sources,
            preferences: PlaybackPreferences.defaults(),
          );

          await engine.play(songUnit);

          // Verify audio duration is used as authoritative
          expect(
            engine.currentState.duration,
            equals(audioDuration),
            reason: 'Audio source duration should be authoritative',
          );

          // Verify that audio duration is used regardless of display/accompaniment durations
          // (We only check that audio is authoritative, not that others are different)

          await engine.dispose();
        }
      });

      test('fallback to other sources when audio has no duration', () async {
        for (var i = 0; i < 100; i++) {
          final engine = PlayerEngine();

          final accompanimentDuration = Duration(
            seconds: TestGenerators.randomInt(100, 300),
          );

          // Audio source without duration
          final audioSource = AudioSource(
            id: 'audio-$i',
            origin: TestGenerators.randomSourceOrigin(),
            priority: 0,
            format: AudioFormat.mp3,
          );

          final accompanimentSource = AccompanimentSource(
            id: 'accompaniment-$i',
            origin: TestGenerators.randomSourceOrigin(),
            priority: 0,
            format: AudioFormat.mp3,
            duration: accompanimentDuration,
          );

          final sources = SourceCollection(
            audioSources: [audioSource],
            accompanimentSources: [accompanimentSource],
          );

          final songUnit = SongUnit(
            id: 'test-$i',
            metadata: TestGenerators.randomMetadata(),
            sources: sources,
            preferences: PlaybackPreferences.defaults(),
          );

          await engine.play(songUnit);

          // When audio has no duration, fallback to accompaniment
          expect(
            engine.currentState.duration,
            equals(accompanimentDuration),
            reason:
                'Should fallback to accompaniment duration when audio has none',
          );

          await engine.dispose();
        }
      });
    });

    // Feature: song-unit-core, Property 10: Playback position preservation during source switching
    // *For any* source switch operation (original ↔ accompaniment, video ↔ image) during playback,
    // the playback position SHALL be maintained within a tolerance of 100ms
    // **Validates: Requirements 3.5, 3.6**
    group('Property 10: Playback position preservation during source switching', () {
      test(
        'position is preserved when switching audio to accompaniment',
        () async {
          for (var i = 0; i < 100; i++) {
            final engine = PlayerEngine();

            final audioSource = TestGenerators.randomAudioSource(priority: 0);
            final accompanimentSource =
                TestGenerators.randomAccompanimentSource(priority: 0);

            final sources = SourceCollection(
              audioSources: [audioSource],
              accompanimentSources: [accompanimentSource],
              displaySources: [TestGenerators.randomDisplaySource()],
            );

            final songUnit = SongUnit(
              id: 'test-$i',
              metadata: TestGenerators.randomMetadata(),
              sources: sources,
              preferences: PlaybackPreferences.defaults(),
            );

            await engine.play(songUnit);

            // Seek to a random position
            final seekPosition = Duration(
              seconds: TestGenerators.randomInt(10, 100),
            );
            await engine.seekTo(seekPosition);

            // Record position before switch
            final positionBeforeSwitch = engine.currentState.position;

            // Switch to accompaniment
            await engine.switchToAccompaniment();

            // Record position after switch
            final positionAfterSwitch = engine.currentState.position;

            // Verify position is preserved within 100ms tolerance
            final difference = (positionAfterSwitch - positionBeforeSwitch)
                .abs();
            expect(
              difference.inMilliseconds <= 100,
              isTrue,
              reason:
                  'Position should be preserved within 100ms tolerance during audio switch. '
                  'Before: ${positionBeforeSwitch.inMilliseconds}ms, '
                  'After: ${positionAfterSwitch.inMilliseconds}ms, '
                  'Difference: ${difference.inMilliseconds}ms',
            );

            await engine.dispose();
          }
        },
      );

      test(
        'position is preserved when switching accompaniment to original',
        () async {
          for (var i = 0; i < 100; i++) {
            final engine = PlayerEngine();

            final audioSource = TestGenerators.randomAudioSource(priority: 0);
            final accompanimentSource =
                TestGenerators.randomAccompanimentSource(priority: 0);

            final sources = SourceCollection(
              audioSources: [audioSource],
              accompanimentSources: [accompanimentSource],
              displaySources: [TestGenerators.randomDisplaySource()],
            );

            final songUnit = SongUnit(
              id: 'test-$i',
              metadata: TestGenerators.randomMetadata(),
              sources: sources,
              preferences: PlaybackPreferences.defaults(),
            );

            await engine.play(songUnit);
            await engine.switchToAccompaniment();

            // Seek to a random position
            final seekPosition = Duration(
              seconds: TestGenerators.randomInt(10, 100),
            );
            await engine.seekTo(seekPosition);

            // Record position before switch
            final positionBeforeSwitch = engine.currentState.position;

            // Switch back to original
            await engine.switchToOriginal();

            // Record position after switch
            final positionAfterSwitch = engine.currentState.position;

            // Verify position is preserved within 100ms tolerance
            final difference = (positionAfterSwitch - positionBeforeSwitch)
                .abs();
            expect(
              difference.inMilliseconds <= 100,
              isTrue,
              reason:
                  'Position should be preserved within 100ms tolerance during switch to original. '
                  'Before: ${positionBeforeSwitch.inMilliseconds}ms, '
                  'After: ${positionAfterSwitch.inMilliseconds}ms, '
                  'Difference: ${difference.inMilliseconds}ms',
            );

            await engine.dispose();
          }
        },
      );

      test('position is preserved when switching display sources', () async {
        for (var i = 0; i < 100; i++) {
          final engine = PlayerEngine();

          final displaySource1 = TestGenerators.randomDisplaySource(
            priority: 0,
          );
          final displaySource2 = TestGenerators.randomDisplaySource(
            priority: 1,
          );

          final sources = SourceCollection(
            audioSources: [TestGenerators.randomAudioSource()],
            displaySources: [displaySource1, displaySource2],
          );

          final songUnit = SongUnit(
            id: 'test-$i',
            metadata: TestGenerators.randomMetadata(),
            sources: sources,
            preferences: PlaybackPreferences.defaults(),
          );

          await engine.play(songUnit);

          // Seek to a random position
          final seekPosition = Duration(
            seconds: TestGenerators.randomInt(10, 100),
          );
          await engine.seekTo(seekPosition);

          // Record position before switch
          final positionBeforeSwitch = engine.currentState.position;

          // Switch display source
          await engine.switchDisplaySource(displaySource2);

          // Record position after switch
          final positionAfterSwitch = engine.currentState.position;

          // Verify position is preserved within 100ms tolerance
          final difference = (positionAfterSwitch - positionBeforeSwitch).abs();
          expect(
            difference.inMilliseconds <= 100,
            isTrue,
            reason:
                'Position should be preserved within 100ms tolerance during display switch. '
                'Before: ${positionBeforeSwitch.inMilliseconds}ms, '
                'After: ${positionAfterSwitch.inMilliseconds}ms, '
                'Difference: ${difference.inMilliseconds}ms',
          );

          await engine.dispose();
        }
      });
    });
  });
}
