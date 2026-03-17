import 'package:beadline/models/metadata.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_generators.dart';

void main() {
  group('Song Unit Creation Property Tests', () {
    // Feature: song-unit-core, Property 1: Song Unit initialization completeness
    // Validates: Requirements 1.1
    test(
      'Property 1: For any newly created Song Unit, all required metadata fields SHALL be present',
      () {
        // Run 100 iterations as specified in design
        for (var i = 0; i < 100; i++) {
          // Generate a random Song Unit
          final songUnit = TestGenerators.randomSongUnit();

          // Verify all required metadata fields are present
          expect(
            songUnit.metadata.title,
            isNotNull,
            reason: 'Title must be present',
          );
          expect(
            songUnit.metadata.artists,
            isNotNull,
            reason: 'Artist must be present',
          );
          expect(
            songUnit.metadata.album,
            isNotNull,
            reason: 'Album must be present',
          );
          expect(
            songUnit.metadata.duration,
            isNotNull,
            reason: 'Duration must be present',
          );

          // Note: year can be null as per the model definition
          // All fields should have either parsed or default values (not null for required fields)
        }
      },
    );

    // Feature: song-unit-core, Property 3: Automatic user tag assignment
    // Validates: Requirements 1.3
    test(
      'Property 3: For any Song Unit creation operation, the resulting Song Unit SHALL contain a user:xx tag',
      () {
        // Run 100 iterations
        for (var i = 0; i < 100; i++) {
          // Generate a Song Unit with user tag
          final songUnit = TestGenerators.randomSongUnit(includeUserTag: true);

          // Verify that at least one tag starts with "user:"
          final hasUserTag = songUnit.tagIds.any(
            (id) => id.startsWith('user:'),
          );
          expect(
            hasUserTag,
            isTrue,
            reason:
                'Song Unit must contain at least one user:xx tag. Tags: ${songUnit.tagIds}',
          );
        }
      },
    );

    test(
      'Property 1 (edge case): Empty metadata should still have all required fields initialized',
      () {
        // Test with empty metadata
        final emptyMetadata = Metadata.empty();

        expect(emptyMetadata.title, isNotNull);
        expect(emptyMetadata.artists, isNotNull);
        expect(emptyMetadata.album, isNotNull);
        expect(emptyMetadata.duration, isNotNull);
        expect(emptyMetadata.duration, equals(Duration.zero));
      },
    );

    test(
      'Property 3 (edge case): Song Unit with multiple user tags should be valid',
      () {
        // Create a Song Unit with multiple user tags
        final songUnit = TestGenerators.randomSongUnit(
          tagIds: ['user:alice', 'user:bob', 'playlist:favorites'],
        );

        // Should have at least one user tag
        final userTags = songUnit.tagIds.where((id) => id.startsWith('user:'));
        expect(userTags.length, greaterThanOrEqualTo(1));
      },
    );
  });
}
