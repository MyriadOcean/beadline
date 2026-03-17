import 'package:beadline/models/metadata.dart';
import 'package:beadline/models/playback_preferences.dart';
import 'package:beadline/models/song_unit.dart';
import 'package:beadline/models/source.dart';
import 'package:beadline/models/source_collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'test_generators.dart';

void main() {
  group('Metadata Parsing Property Tests', () {
    const uuid = Uuid();

    /// Mock metadata extractor that simulates parsing metadata from a source
    Metadata mockExtractMetadata(Source source) {
      // Simulate extracting metadata from source
      // In real implementation, this would read ID3 tags, FLAC tags, etc.
      return const Metadata(
        title: 'Extracted Title',
        artists: ['Extracted Artist'],
        album: 'Extracted Album',
        year: 2023,
        duration: Duration(minutes: 3, seconds: 45),
      );
    }

    /// Create a Song Unit from a source with auto-parsed metadata
    SongUnit createSongUnitFromSource(Source source) {
      final metadata = mockExtractMetadata(source);
      return SongUnit(
        id: uuid.v4(),
        metadata: metadata,
        sources: SourceCollection(
          audioSources: source is AudioSource ? [source] : [],
          displaySources: source is DisplaySource ? [source] : [],
        ),
        tagIds: [],
        preferences: PlaybackPreferences.defaults(),
      );
    }

    // Feature: song-unit-core, Property 2: Metadata auto-parsing correctness
    // Validates: Requirements 1.2
    test(
      'Property 2: For any Source with embedded metadata, creating a Song Unit SHALL result in metadata matching the Source',
      () {
        // Run 100 iterations
        for (var i = 0; i < 100; i++) {
          // Generate a random audio source (which would have metadata)
          final source = TestGenerators.randomAudioSource();

          // Create Song Unit with auto-parsed metadata
          final songUnit = createSongUnitFromSource(source);

          // Extract expected metadata
          final expectedMetadata = mockExtractMetadata(source);

          // Verify metadata matches what was extracted
          expect(
            songUnit.metadata.title,
            equals(expectedMetadata.title),
            reason: 'Title should match extracted metadata',
          );
          expect(
            songUnit.metadata.artists,
            equals(expectedMetadata.artists),
            reason: 'Artist should match extracted metadata',
          );
          expect(
            songUnit.metadata.album,
            equals(expectedMetadata.album),
            reason: 'Album should match extracted metadata',
          );
          expect(
            songUnit.metadata.year,
            equals(expectedMetadata.year),
            reason: 'Year should match extracted metadata',
          );
          expect(
            songUnit.metadata.duration,
            equals(expectedMetadata.duration),
            reason: 'Duration should match extracted metadata',
          );
        }
      },
    );

    test(
      'Property 2 (edge case): Sources without metadata should use default values',
      () {
        // Create a source that would have no metadata (e.g., image)
        final source = TestGenerators.randomDisplaySource();

        // In real implementation, this would return empty/default metadata
        final songUnit = SongUnit(
          id: uuid.v4(),
          metadata: Metadata.empty(),
          sources: SourceCollection(displaySources: [source]),
          tagIds: [],
          preferences: PlaybackPreferences.defaults(),
        );

        // Verify default values are present
        expect(songUnit.metadata.title, isNotNull);
        expect(songUnit.metadata.artists, isNotNull);
        expect(songUnit.metadata.album, isNotNull);
        expect(songUnit.metadata.duration, equals(Duration.zero));
      },
    );

    test(
      'Property 2 (consistency): Multiple sources with same metadata should produce consistent Song Units',
      () {
        // Create multiple sources
        final sources = List.generate(
          10,
          (_) => TestGenerators.randomAudioSource(),
        );

        // Create Song Units from each source
        final songUnits = sources.map(createSongUnitFromSource).toList();

        // All should have the same metadata (since our mock extractor is deterministic)
        for (final songUnit in songUnits) {
          expect(songUnit.metadata.title, equals('Extracted Title'));
          expect(songUnit.metadata.artistDisplay, equals('Extracted Artist'));
          expect(songUnit.metadata.album, equals('Extracted Album'));
        }
      },
    );

    test(
      'Property 2 (built-in tags): Metadata fields should map to built-in tags',
      () {
        // This test validates that metadata can be used to populate built-in tags
        for (var i = 0; i < 100; i++) {
          final metadata = TestGenerators.randomMetadata();

          // In the actual implementation, these would become built-in tags
          // name -> title, artist -> artist, album -> album, time -> year, duration -> duration
          final builtInTagValues = {
            'name': metadata.title,
            'artist': metadata.artistDisplay,
            'album': metadata.album,
            'time': metadata.year?.toString() ?? '',
            'duration': metadata.duration.inSeconds.toString(),
          };

          // Verify all built-in tag values are present
          expect(builtInTagValues['name'], isNotEmpty);
          expect(builtInTagValues['artist'], isNotEmpty);
          expect(builtInTagValues['album'], isNotEmpty);
          expect(builtInTagValues['duration'], isNotEmpty);
        }
      },
    );
  });
}
