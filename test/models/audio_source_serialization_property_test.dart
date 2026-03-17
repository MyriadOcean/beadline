/// Task 1.2: Property test for AudioSource serialization round trip
///
/// **Feature: video-audio-extraction, Property 8: Serialization round trip preserves video-audio links**
/// **Validates: Requirements 4.4, 4.5**
library;

import 'package:beadline/models/source.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_generators.dart';

void main() {
  group('AudioSource Serialization Property Tests (Task 1.2)', () {
    // ========================================================================
    // Feature: video-audio-extraction, Property 8: Serialization round trip preserves video-audio links
    // **Validates: Requirements 4.4, 4.5**
    //
    // For any AudioSource with a non-null linkedVideoSourceId, serializing
    // to JSON and deserializing back SHALL produce an AudioSource with the
    // same linkedVideoSourceId value. This also holds for null values and
    // all other fields.
    // ========================================================================
    test(
      'Property 8: Serialization round trip preserves video-audio links',
      () {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          // Generate a random AudioSource — roughly half with a linked video ID
          final hasLink = i % 2 == 0;
          final original = TestGenerators.randomAudioSource();
          final audioSource = hasLink
              ? original.copyWith(
                  linkedVideoSourceId: TestGenerators.randomString(
                    minLength: 5,
                    maxLength: 40,
                  ),
                )
              : original;

          // Serialize to JSON (includes the 'sourceType' key via toJson())
          final json = audioSource.toJson();

          // Deserialize back
          final deserialized = AudioSource.fromJson(json);

          // linkedVideoSourceId must survive the round trip
          expect(
            deserialized.linkedVideoSourceId,
            equals(audioSource.linkedVideoSourceId),
            reason:
                'Iteration $i: linkedVideoSourceId should survive '
                'serialization round trip '
                '(expected: ${audioSource.linkedVideoSourceId}, '
                'got: ${deserialized.linkedVideoSourceId})',
          );

          // All other fields must also be preserved
          expect(
            deserialized.id,
            equals(audioSource.id),
            reason: 'Iteration $i: id should be preserved',
          );
          expect(
            deserialized.origin,
            equals(audioSource.origin),
            reason: 'Iteration $i: origin should be preserved',
          );
          expect(
            deserialized.priority,
            equals(audioSource.priority),
            reason: 'Iteration $i: priority should be preserved',
          );
          expect(
            deserialized.displayName,
            equals(audioSource.displayName),
            reason: 'Iteration $i: displayName should be preserved',
          );
          expect(
            deserialized.format,
            equals(audioSource.format),
            reason: 'Iteration $i: format should be preserved',
          );
          expect(
            deserialized.duration,
            equals(audioSource.duration),
            reason: 'Iteration $i: duration should be preserved',
          );
          expect(
            deserialized.offset,
            equals(audioSource.offset),
            reason: 'Iteration $i: offset should be preserved',
          );

          // Full equality check
          expect(
            deserialized,
            equals(audioSource),
            reason:
                'Iteration $i: full AudioSource equality should hold '
                'after round trip',
          );
        }
      },
    );
  });
}
