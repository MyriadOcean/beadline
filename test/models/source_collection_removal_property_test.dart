/// Task 6.3: Property test for manual audio removal preserving video source
///
/// **Feature: video-audio-extraction, Property 7: Manual audio removal preserves video source**
/// **Validates: Requirements 4.3**
library;

import 'package:beadline/models/source.dart';
import 'package:beadline/models/source_collection.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_generators.dart';

void main() {
  group('SourceCollection Removal Property Tests (Task 6.3)', () {
    // ========================================================================
    // Feature: video-audio-extraction, Property 7: Manual audio removal
    // preserves video source
    // **Validates: Requirements 4.3**
    //
    // For any SourceCollection containing a video DisplaySource and its linked
    // AudioSource, removing the AudioSource SHALL leave the displaySources
    // list unchanged.
    // ========================================================================
    test(
      'Property 7: Manual audio removal preserves video source',
      () {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          // 1. Generate a random video DisplaySource
          final videoSource = TestGenerators.randomDisplaySource().copyWith(
            displayType: DisplayType.video,
          );

          // 2. Create a linked AudioSource referencing the video
          final linkedAudio = TestGenerators.randomAudioSource().copyWith(
            linkedVideoSourceId: videoSource.id,
          );

          // 3. Generate additional random sources for variety
          final extraDisplaySources = List.generate(
            TestGenerators.randomInt(0, 3),
            (_) => TestGenerators.randomDisplaySource(),
          );
          final extraAudioSources = List.generate(
            TestGenerators.randomInt(0, 3),
            (_) => TestGenerators.randomAudioSource(),
          );

          // 4. Build the original SourceCollection
          final allDisplaySources = [videoSource, ...extraDisplaySources];
          final allAudioSources = [linkedAudio, ...extraAudioSources];

          final original = SourceCollection(
            displaySources: allDisplaySources,
            audioSources: allAudioSources,
            accompanimentSources: List.generate(
              TestGenerators.randomInt(0, 2),
              (_) => TestGenerators.randomAccompanimentSource(),
            ),
            hoverSources: List.generate(
              TestGenerators.randomInt(0, 2),
              (_) => TestGenerators.randomHoverSource(),
            ),
          );

          // 5. Remove the linked AudioSource (filter it out)
          final updatedAudioSources = original.audioSources
              .where((a) => a.id != linkedAudio.id)
              .toList();

          final afterRemoval = original.copyWith(
            audioSources: updatedAudioSources,
          );

          // 6. Verify displaySources are identical to the original
          expect(
            afterRemoval.displaySources.length,
            equals(original.displaySources.length),
            reason:
                'Iteration $i: displaySources length should be unchanged '
                'after removing a linked AudioSource',
          );

          for (var j = 0; j < original.displaySources.length; j++) {
            expect(
              afterRemoval.displaySources[j],
              equals(original.displaySources[j]),
              reason:
                  'Iteration $i: displaySources[$j] should be unchanged '
                  'after removing a linked AudioSource',
            );
          }

          // 7. Verify the video DisplaySource is still present
          final videoStillPresent = afterRemoval.displaySources.any(
            (d) => d.id == videoSource.id,
          );
          expect(
            videoStillPresent,
            isTrue,
            reason:
                'Iteration $i: the video DisplaySource should still be '
                'present after removing its linked AudioSource',
          );

          // 8. Verify the linked AudioSource was actually removed
          final linkedAudioRemoved = !afterRemoval.audioSources.any(
            (a) => a.id == linkedAudio.id,
          );
          expect(
            linkedAudioRemoved,
            isTrue,
            reason:
                'Iteration $i: the linked AudioSource should have been '
                'removed from audioSources',
          );

          // 9. Verify other lists are also unchanged
          expect(
            afterRemoval.accompanimentSources,
            equals(original.accompanimentSources),
            reason:
                'Iteration $i: accompanimentSources should be unchanged',
          );
          expect(
            afterRemoval.hoverSources,
            equals(original.hoverSources),
            reason:
                'Iteration $i: hoverSources should be unchanged',
          );
        }
      },
    );
  });
}
