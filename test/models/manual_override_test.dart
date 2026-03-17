import 'package:beadline/models/metadata.dart';
import 'package:beadline/models/song_unit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_generators.dart';

void main() {
  group('Manual Metadata Override Property Tests', () {
    /// Simulate auto-parsed metadata
    Metadata getAutoParsedMetadata() {
      return const Metadata(
        title: 'Auto Title',
        artists: ['Auto Artist'],
        album: 'Auto Album',
        year: 2020,
        duration: Duration(minutes: 3),
      );
    }

    // Feature: song-unit-core, Property 4: Manual metadata override persistence
    // Validates: Requirements 1.4
    test(
      'Property 4: For any Song Unit with auto-parsed metadata, manually setting a field SHALL persist and take precedence',
      () {
        // Run 100 iterations
        for (var i = 0; i < 100; i++) {
          // Create a Song Unit with auto-parsed metadata
          final autoParsedMetadata = getAutoParsedMetadata();
          final songUnit = TestGenerators.randomSongUnit(
            metadata: autoParsedMetadata,
          );

          // Verify initial state has auto-parsed values
          expect(songUnit.metadata.title, equals('Auto Title'));
          expect(songUnit.metadata.artistDisplay, equals('Auto Artist'));

          // Manually override metadata fields
          final manualTitle = 'Manual Title ${TestGenerators.randomString()}';
          final manualArtist = 'Manual Artist ${TestGenerators.randomString()}';
          final manualAlbum = 'Manual Album ${TestGenerators.randomString()}';
          final manualYear = TestGenerators.randomYear();

          final updatedMetadata = songUnit.metadata.copyWith(
            title: manualTitle,
            artists: [manualArtist],
            album: manualAlbum,
            year: manualYear,
          );

          final updatedSongUnit = songUnit.copyWith(metadata: updatedMetadata);

          // Verify manual values persist and take precedence
          expect(
            updatedSongUnit.metadata.title,
            equals(manualTitle),
            reason: 'Manual title should override auto-parsed value',
          );
          expect(
            updatedSongUnit.metadata.artistDisplay,
            equals(manualArtist),
            reason: 'Manual artist should override auto-parsed value',
          );
          expect(
            updatedSongUnit.metadata.album,
            equals(manualAlbum),
            reason: 'Manual album should override auto-parsed value',
          );
          expect(
            updatedSongUnit.metadata.year,
            equals(manualYear),
            reason: 'Manual year should override auto-parsed value',
          );

          // Duration should remain unchanged if not manually set
          expect(
            updatedSongUnit.metadata.duration,
            equals(autoParsedMetadata.duration),
            reason: 'Unchanged fields should retain original values',
          );
        }
      },
    );

    test(
      'Property 4 (partial override): Manually overriding one field should not affect others',
      () {
        for (var i = 0; i < 100; i++) {
          // Create Song Unit with auto-parsed metadata
          final originalMetadata = TestGenerators.randomMetadata();
          final songUnit = TestGenerators.randomSongUnit(
            metadata: originalMetadata,
          );

          // Override only the title
          const newTitle = 'Manually Set Title';
          final updatedMetadata = songUnit.metadata.copyWith(title: newTitle);
          final updatedSongUnit = songUnit.copyWith(metadata: updatedMetadata);

          // Verify only title changed
          expect(updatedSongUnit.metadata.title, equals(newTitle));
          expect(
            updatedSongUnit.metadata.artists,
            equals(originalMetadata.artists),
            reason: 'Artist should remain unchanged',
          );
          expect(
            updatedSongUnit.metadata.album,
            equals(originalMetadata.album),
            reason: 'Album should remain unchanged',
          );
          expect(
            updatedSongUnit.metadata.year,
            equals(originalMetadata.year),
            reason: 'Year should remain unchanged',
          );
          expect(
            updatedSongUnit.metadata.duration,
            equals(originalMetadata.duration),
            reason: 'Duration should remain unchanged',
          );
        }
      },
    );

    test(
      'Property 4 (persistence): Manual overrides should survive serialization',
      () {
        for (var i = 0; i < 100; i++) {
          // Create Song Unit with manually overridden metadata
          const manualMetadata = Metadata(
            title: 'Manual Title',
            artists: ['Manual Artist'],
            album: 'Manual Album',
            year: 2024,
            duration: Duration(minutes: 4),
          );

          final songUnit = TestGenerators.randomSongUnit(
            metadata: manualMetadata,
          );

          // Serialize and deserialize
          final json = songUnit.toJson();
          final deserializedSongUnit = SongUnit.fromJson(json);

          // Verify manual values persist through serialization
          expect(
            deserializedSongUnit.metadata.title,
            equals(manualMetadata.title),
          );
          expect(
            deserializedSongUnit.metadata.artists,
            equals(manualMetadata.artists),
          );
          expect(
            deserializedSongUnit.metadata.album,
            equals(manualMetadata.album),
          );
          expect(
            deserializedSongUnit.metadata.year,
            equals(manualMetadata.year),
          );
          expect(
            deserializedSongUnit.metadata.duration,
            equals(manualMetadata.duration),
          );
        }
      },
    );

    test(
      'Property 4 (immutability): Original Song Unit should remain unchanged after override',
      () {
        for (var i = 0; i < 100; i++) {
          // Create original Song Unit
          final originalMetadata = TestGenerators.randomMetadata();
          final originalSongUnit = TestGenerators.randomSongUnit(
            metadata: originalMetadata,
          );

          // Create updated version with manual override
          final updatedMetadata = originalSongUnit.metadata.copyWith(
            title: 'New Title',
          );
          final updatedSongUnit = originalSongUnit.copyWith(
            metadata: updatedMetadata,
          );

          // Verify original is unchanged (immutability)
          expect(
            originalSongUnit.metadata.title,
            equals(originalMetadata.title),
            reason: 'Original Song Unit should remain unchanged',
          );
          expect(
            updatedSongUnit.metadata.title,
            equals('New Title'),
            reason: 'Updated Song Unit should have new value',
          );
        }
      },
    );

    test(
      'Property 4 (edge case): Setting metadata to same value should be idempotent',
      () {
        final metadata = TestGenerators.randomMetadata();
        final songUnit = TestGenerators.randomSongUnit(metadata: metadata);

        // "Override" with same values
        final sameMetadata = songUnit.metadata.copyWith(
          title: metadata.title,
          artists: metadata.artists,
          album: metadata.album,
          year: metadata.year,
          duration: metadata.duration,
        );

        final updatedSongUnit = songUnit.copyWith(metadata: sameMetadata);

        // Should be equal
        expect(updatedSongUnit.metadata, equals(songUnit.metadata));
      },
    );
  });
}
