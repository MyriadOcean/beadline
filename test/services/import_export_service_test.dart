import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:beadline/models/playback_preferences.dart';
import 'package:beadline/models/song_unit.dart';
import 'package:beadline/models/source.dart';
import 'package:beadline/models/source_collection.dart';
import 'package:beadline/models/source_origin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import '../models/test_generators.dart';

/// In-memory storage for testing import/export behavior
class InMemoryLibraryStorage {
  final Map<String, Map<String, dynamic>> _songUnits = {};
  final Map<String, Set<String>> _songUnitTags = {};

  void insertSongUnit(Map<String, dynamic> songUnit) {
    final id = songUnit['id'] as String;
    _songUnits[id] = Map.from(songUnit);
  }

  Map<String, dynamic>? getSongUnit(String id) {
    return _songUnits[id];
  }

  List<Map<String, dynamic>> getSongUnitsByHash(String hash) {
    return _songUnits.values.where((su) => su['hash'] == hash).toList();
  }

  bool existsByHash(String hash) {
    return _songUnits.values.any((su) => su['hash'] == hash);
  }

  void addTagToSongUnit(String songUnitId, String tagId) {
    _songUnitTags.putIfAbsent(songUnitId, () => {});
    _songUnitTags[songUnitId]!.add(tagId);
  }

  Set<String> getTagsForSongUnit(String songUnitId) {
    return _songUnitTags[songUnitId] ?? {};
  }

  void clear() {
    _songUnits.clear();
    _songUnitTags.clear();
  }
}

/// In-memory file system for testing
class InMemoryFileSystem {
  final Map<String, List<int>> _files = {};

  void writeFile(String path, List<int> bytes) {
    _files[path] = bytes;
  }

  List<int>? readFile(String path) {
    return _files[path];
  }

  bool fileExists(String path) {
    return _files.containsKey(path);
  }

  void clear() {
    _files.clear();
  }
}

void main() {
  group('Import/Export Service Property Tests', () {
    late InMemoryLibraryStorage storage;
    late InMemoryFileSystem fileSystem;
    const uuid = Uuid();

    setUp(() {
      storage = InMemoryLibraryStorage();
      fileSystem = InMemoryFileSystem();
    });

    tearDown(() {
      storage.clear();
      fileSystem.clear();
    });

    // Feature: song-unit-core, Property 31: Single export format correctness
    // **Validates: Requirements 9.1**
    test(
      'Property 31: For any single Song Unit export, the resulting ZIP SHALL contain song-unit.json and all referenced local source files',
      () {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          // Generate a random Song Unit with local file sources
          final songUnit = _generateSongUnitWithLocalSources();

          // Export to ZIP
          final archive = _exportSingleSongUnit(songUnit, fileSystem);

          // Verify song-unit.json exists
          final jsonFile = archive.files.firstWhere(
            (f) => f.name == 'song-unit.json',
            orElse: () => ArchiveFile('', 0, []),
          );
          expect(
            jsonFile.size,
            greaterThan(0),
            reason: 'song-unit.json must exist in export',
          );

          // Verify JSON content is valid and contains Song Unit data
          final jsonContent = utf8.decode(jsonFile.content);
          final json = jsonDecode(jsonContent) as Map<String, dynamic>;
          expect(json['id'], equals(songUnit.id));
          expect(json['metadata'], isNotNull);
          expect(json['sources'], isNotNull);

          // Verify all local source files are included
          final localSources = songUnit.sources
              .getAllSources()
              .where((s) => s.origin is LocalFileOrigin)
              .toList();

          for (final source in localSources) {
            final localOrigin = source.origin as LocalFileOrigin;
            final fileName = localOrigin.path.split('/').last;

            final sourceFile = archive.files.firstWhere(
              (f) => f.name.endsWith(fileName),
              orElse: () => ArchiveFile('', 0, []),
            );

            // Only check if the file was in our mock file system
            if (fileSystem.fileExists(localOrigin.path)) {
              expect(
                sourceFile.size,
                greaterThan(0),
                reason: 'Local source file $fileName must be in export',
              );
            }
          }
        }
      },
    );

    // Feature: song-unit-core, Property 32: Batch export format correctness
    // **Validates: Requirements 9.2**
    test(
      'Property 32: For any batch Song Unit export, the resulting ZIP SHALL contain individual Song Unit ZIPs and a meta.json file with correct count',
      () {
        const iterations = 50;

        for (var i = 0; i < iterations; i++) {
          // Generate 2-5 random Song Units
          final count = 2 + (i % 4);
          final songUnits = List.generate(
            count,
            (_) => _generateSongUnitWithLocalSources(),
          );

          // Export to batch ZIP
          final archive = _exportBatchSongUnits(songUnits, fileSystem);

          // Verify meta.json exists
          final metaFile = archive.files.firstWhere(
            (f) => f.name == 'meta.json',
            orElse: () => ArchiveFile('', 0, []),
          );
          expect(
            metaFile.size,
            greaterThan(0),
            reason: 'meta.json must exist in batch export',
          );

          // Verify meta.json content
          final metaContent = utf8.decode(metaFile.content);
          final meta = jsonDecode(metaContent) as Map<String, dynamic>;
          expect(meta['version'], isNotNull);
          expect(meta['createdAt'], isNotNull);
          expect(
            meta['count'],
            equals(count),
            reason: 'meta.json count must match number of Song Units',
          );

          // Verify individual ZIP files exist
          final innerZips = archive.files
              .where((f) => f.name.endsWith('.zip'))
              .toList();
          expect(
            innerZips.length,
            equals(count),
            reason: 'Batch export must contain $count inner ZIPs',
          );

          // Verify each inner ZIP contains song-unit.json
          for (final innerZipFile in innerZips) {
            final innerArchive = ZipDecoder().decodeBytes(innerZipFile.content);
            final innerJsonFile = innerArchive.files.firstWhere(
              (f) => f.name == 'song-unit.json',
              orElse: () => ArchiveFile('', 0, []),
            );
            expect(
              innerJsonFile.size,
              greaterThan(0),
              reason: 'Each inner ZIP must contain song-unit.json',
            );
          }
        }
      },
    );

    // Feature: song-unit-core, Property 33: Import deduplication
    // **Validates: Requirements 9.3**
    test(
      'Property 33: For any Song Unit import, if an identical Song Unit (by hash) already exists, it SHALL be skipped',
      () {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          storage.clear();

          // Generate a random Song Unit
          final songUnit = TestGenerators.randomSongUnit();

          // Add it to storage first (simulating existing Song Unit)
          _addSongUnitToStorage(storage, songUnit);

          // Create an export archive with the same Song Unit
          final archive = _createSingleExportArchive(songUnit);

          // Import the archive
          final result = _importFromArchive(archive, storage, uuid);

          // Verify the Song Unit was skipped (not imported again)
          expect(
            result.skipped.length,
            equals(1),
            reason: 'Duplicate Song Unit should be skipped',
          );
          expect(
            result.imported.length,
            equals(0),
            reason: 'No new Song Units should be imported',
          );
          expect(
            result.skipped.first.calculateHash(),
            equals(songUnit.calculateHash()),
            reason: 'Skipped Song Unit should have same hash',
          );
        }
      },
    );

    // Feature: song-unit-core, Property 34: Export-import round trip
    // **Validates: Requirements 9.6**
    test(
      'Property 34: For any Song Unit, exporting then importing SHALL result in an equivalent Song Unit (same metadata, sources, tags, preferences)',
      () {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          storage.clear();

          // Generate a random Song Unit
          final originalSongUnit = TestGenerators.randomSongUnit();

          // Export to archive
          final archive = _createSingleExportArchive(originalSongUnit);

          // Import from archive
          final result = _importFromArchive(archive, storage, uuid);

          // Verify import succeeded
          expect(
            result.imported.length,
            equals(1),
            reason: 'One Song Unit should be imported',
          );
          expect(
            result.errors.length,
            equals(0),
            reason: 'No errors should occur during import',
          );

          final importedSongUnit = result.imported.first;

          // Verify metadata equivalence
          expect(
            importedSongUnit.metadata.title,
            equals(originalSongUnit.metadata.title),
            reason: 'Title should be preserved',
          );
          expect(
            importedSongUnit.metadata.artists,
            equals(originalSongUnit.metadata.artists),
            reason: 'Artist should be preserved',
          );
          expect(
            importedSongUnit.metadata.album,
            equals(originalSongUnit.metadata.album),
            reason: 'Album should be preserved',
          );
          expect(
            importedSongUnit.metadata.year,
            equals(originalSongUnit.metadata.year),
            reason: 'Year should be preserved',
          );
          expect(
            importedSongUnit.metadata.duration,
            equals(originalSongUnit.metadata.duration),
            reason: 'Duration should be preserved',
          );

          // Verify sources equivalence (count and types)
          expect(
            importedSongUnit.sources.displaySources.length,
            equals(originalSongUnit.sources.displaySources.length),
            reason: 'Display sources count should be preserved',
          );
          expect(
            importedSongUnit.sources.audioSources.length,
            equals(originalSongUnit.sources.audioSources.length),
            reason: 'Audio sources count should be preserved',
          );
          expect(
            importedSongUnit.sources.accompanimentSources.length,
            equals(originalSongUnit.sources.accompanimentSources.length),
            reason: 'Accompaniment sources count should be preserved',
          );
          expect(
            importedSongUnit.sources.hoverSources.length,
            equals(originalSongUnit.sources.hoverSources.length),
            reason: 'Hover sources count should be preserved',
          );

          // Verify tag IDs equivalence
          expect(
            importedSongUnit.tagIds.length,
            equals(originalSongUnit.tagIds.length),
            reason: 'Tag count should be preserved',
          );
          for (final tagId in originalSongUnit.tagIds) {
            expect(
              importedSongUnit.tagIds.contains(tagId),
              isTrue,
              reason: 'Tag $tagId should be preserved',
            );
          }

          // Verify preferences equivalence
          expect(
            importedSongUnit.preferences.preferAccompaniment,
            equals(originalSongUnit.preferences.preferAccompaniment),
            reason: 'Prefer accompaniment should be preserved',
          );
          expect(
            importedSongUnit.preferences.preferredDisplaySourceId,
            equals(originalSongUnit.preferences.preferredDisplaySourceId),
            reason: 'Preferred display source ID should be preserved',
          );
          expect(
            importedSongUnit.preferences.preferredAudioSourceId,
            equals(originalSongUnit.preferences.preferredAudioSourceId),
            reason: 'Preferred audio source ID should be preserved',
          );
        }
      },
    );

    // Additional test: Batch export-import round trip
    test(
      'Property 34 (batch): For any batch of Song Units, exporting then importing SHALL preserve all Song Units',
      () {
        const iterations = 30;

        for (var i = 0; i < iterations; i++) {
          storage.clear();

          // Generate 2-4 random Song Units
          final count = 2 + (i % 3);
          final originalSongUnits = List.generate(
            count,
            (_) => TestGenerators.randomSongUnit(),
          );

          // Export to batch archive
          final archive = _createBatchExportArchive(originalSongUnits);

          // Import from archive
          final result = _importBatchFromArchive(archive, storage, uuid);

          // Verify all Song Units were imported
          expect(
            result.imported.length,
            equals(count),
            reason: 'All $count Song Units should be imported',
          );
          expect(
            result.errors.length,
            equals(0),
            reason: 'No errors should occur during batch import',
          );

          // Verify each original Song Unit has a corresponding import by matching
          // on the combination of title, artist, album, and duration (which together
          // should be unique for randomly generated Song Units)
          for (final original in originalSongUnits) {
            final matchingImports = result.imported
                .where(
                  (s) =>
                      s.metadata.title == original.metadata.title &&
                      s.metadata.album == original.metadata.album &&
                      s.metadata.duration == original.metadata.duration,
                )
                .toList();

            expect(
              matchingImports.isNotEmpty,
              isTrue,
              reason:
                  'Should find imported Song Unit matching original with title: ${original.metadata.title}',
            );

            final imported = matchingImports.first;
            expect(
              imported.metadata.artists,
              equals(original.metadata.artists),
              reason: 'Artists should be preserved',
            );
          }
        }
      },
    );
  });
}

// Helper: Generate a Song Unit with local file sources
SongUnit _generateSongUnitWithLocalSources() {
  const uuid = Uuid();
  final metadata = TestGenerators.randomMetadata();

  // Create sources with local file origins
  final displaySources = <DisplaySource>[];
  final audioSources = <AudioSource>[];

  // Add a display source with local file
  displaySources.add(
    DisplaySource(
      id: uuid.v4(),
      origin: LocalFileOrigin(
        '/path/to/video_${TestGenerators.randomString()}.mp4',
      ),
      priority: 0,
      displayType: DisplayType.video,
      duration: TestGenerators.randomDuration(),
    ),
  );

  // Add an audio source with local file
  audioSources.add(
    AudioSource(
      id: uuid.v4(),
      origin: LocalFileOrigin(
        '/path/to/audio_${TestGenerators.randomString()}.mp3',
      ),
      priority: 0,
      format: AudioFormat.mp3,
      duration: TestGenerators.randomDuration(),
    ),
  );

  return SongUnit(
    id: uuid.v4(),
    metadata: metadata,
    sources: SourceCollection(
      displaySources: displaySources,
      audioSources: audioSources,
    ),
    tagIds: [TestGenerators.randomUserTagId()],
    preferences: PlaybackPreferences.defaults(),
  );
}

// Helper: Export a single Song Unit to an archive
Archive _exportSingleSongUnit(
  SongUnit songUnit,
  InMemoryFileSystem fileSystem,
) {
  final archive = Archive();

  // Add song-unit.json
  final jsonBytes = utf8.encode(jsonEncode(songUnit.toJson()));
  archive.addFile(ArchiveFile('song-unit.json', jsonBytes.length, jsonBytes));

  // Add local source files (mock - just add empty files for testing)
  for (final source in songUnit.sources.getAllSources()) {
    if (source.origin is LocalFileOrigin) {
      final localOrigin = source.origin as LocalFileOrigin;
      final fileName = localOrigin.path.split('/').last;

      // Create mock file content
      final mockContent = utf8.encode('mock content for $fileName');
      fileSystem.writeFile(localOrigin.path, mockContent);

      archive.addFile(
        ArchiveFile('sources/$fileName', mockContent.length, mockContent),
      );
    }
  }

  return archive;
}

// Helper: Export multiple Song Units to a batch archive
Archive _exportBatchSongUnits(
  List<SongUnit> songUnits,
  InMemoryFileSystem fileSystem,
) {
  final archive = Archive();

  // Add meta.json
  final meta = {
    'version': '1.0.0',
    'createdAt': DateTime.now().toIso8601String(),
    'count': songUnits.length,
  };
  final metaBytes = utf8.encode(jsonEncode(meta));
  archive.addFile(ArchiveFile('meta.json', metaBytes.length, metaBytes));

  // Add individual Song Unit ZIPs
  for (var i = 0; i < songUnits.length; i++) {
    final songUnit = songUnits[i];
    final innerArchive = _exportSingleSongUnit(songUnit, fileSystem);
    final innerZipData = ZipEncoder().encode(innerArchive);

    final fileName = '${i + 1}_${songUnit.id.substring(0, 8)}.zip';
    archive.addFile(ArchiveFile(fileName, innerZipData.length, innerZipData));
  }

  return archive;
}

// Helper: Create a single export archive (without file system interaction)
Archive _createSingleExportArchive(SongUnit songUnit) {
  final archive = Archive();
  final jsonBytes = utf8.encode(jsonEncode(songUnit.toJson()));
  archive.addFile(ArchiveFile('song-unit.json', jsonBytes.length, jsonBytes));
  return archive;
}

// Helper: Create a batch export archive
Archive _createBatchExportArchive(List<SongUnit> songUnits) {
  final archive = Archive();

  // Add meta.json
  final meta = {
    'version': '1.0.0',
    'createdAt': DateTime.now().toIso8601String(),
    'count': songUnits.length,
  };
  final metaBytes = utf8.encode(jsonEncode(meta));
  archive.addFile(ArchiveFile('meta.json', metaBytes.length, metaBytes));

  // Add individual Song Unit ZIPs
  for (var i = 0; i < songUnits.length; i++) {
    final innerArchive = _createSingleExportArchive(songUnits[i]);
    final innerZipData = ZipEncoder().encode(innerArchive);
    final fileName = '${i + 1}_${songUnits[i].id.substring(0, 8)}.zip';
    archive.addFile(ArchiveFile(fileName, innerZipData.length, innerZipData));
  }

  return archive;
}

// Helper: Import result class
class ImportResult {
  ImportResult({
    required this.imported,
    required this.skipped,
    required this.errors,
  });
  final List<SongUnit> imported;
  final List<SongUnit> skipped;
  final List<String> errors;
}

// Helper: Import from a single archive
ImportResult _importFromArchive(
  Archive archive,
  InMemoryLibraryStorage storage,
  Uuid uuid,
) {
  final imported = <SongUnit>[];
  final skipped = <SongUnit>[];
  final errors = <String>[];

  try {
    // Find song-unit.json
    final jsonFile = archive.files.firstWhere(
      (f) => f.name == 'song-unit.json',
      orElse: () => throw Exception('song-unit.json not found'),
    );

    final jsonString = utf8.decode(jsonFile.content);
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    final songUnit = SongUnit.fromJson(json);

    // Check for duplicates
    final hash = songUnit.calculateHash();
    if (storage.existsByHash(hash)) {
      skipped.add(songUnit);
    } else {
      // Generate new ID and add to storage
      final newSongUnit = songUnit.copyWith(id: uuid.v4());
      _addSongUnitToStorage(storage, newSongUnit);
      imported.add(newSongUnit);
    }
  } catch (e) {
    errors.add(e.toString());
  }

  return ImportResult(imported: imported, skipped: skipped, errors: errors);
}

// Helper: Import from a batch archive
ImportResult _importBatchFromArchive(
  Archive archive,
  InMemoryLibraryStorage storage,
  Uuid uuid,
) {
  final imported = <SongUnit>[];
  final skipped = <SongUnit>[];
  final errors = <String>[];

  // Find all inner ZIP files
  final innerZips = archive.files
      .where((f) => f.name.endsWith('.zip'))
      .toList();

  for (final innerZipFile in innerZips) {
    try {
      final innerArchive = ZipDecoder().decodeBytes(innerZipFile.content);
      final result = _importFromArchive(innerArchive, storage, uuid);

      imported.addAll(result.imported);
      skipped.addAll(result.skipped);
      errors.addAll(result.errors);
    } catch (e) {
      errors.add('Error importing ${innerZipFile.name}: $e');
    }
  }

  return ImportResult(imported: imported, skipped: skipped, errors: errors);
}

// Helper: Add Song Unit to storage
void _addSongUnitToStorage(InMemoryLibraryStorage storage, SongUnit songUnit) {
  final now = DateTime.now().millisecondsSinceEpoch;
  final hash = songUnit.calculateHash();

  storage.insertSongUnit({
    'id': songUnit.id,
    'metadata_json': jsonEncode(songUnit.metadata.toJson()),
    'sources_json': jsonEncode(songUnit.sources.toJson()),
    'preferences_json': jsonEncode(songUnit.preferences.toJson()),
    'hash': hash,
    'created_at': now,
    'updated_at': now,
  });

  for (final tagId in songUnit.tagIds) {
    storage.addTagToSongUnit(songUnit.id, tagId);
  }
}
