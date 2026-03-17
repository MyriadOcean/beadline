import 'dart:convert';

import 'package:beadline/models/metadata.dart';
import 'package:beadline/models/playback_preferences.dart';
import 'package:beadline/models/song_unit.dart';
import 'package:beadline/models/source_collection.dart';
import 'package:flutter_test/flutter_test.dart';

import '../models/test_generators.dart';

/// In-memory storage for testing persistence behavior
/// This simulates the database without requiring actual SQLite
class InMemoryStorage {
  final Map<String, Map<String, dynamic>> _songUnits = {};
  final Map<String, Set<String>> _songUnitTags = {};

  void insertSongUnit(Map<String, dynamic> songUnit) {
    final id = songUnit['id'] as String;
    _songUnits[id] = Map.from(songUnit);
  }

  void updateSongUnit(String id, Map<String, dynamic> songUnit) {
    if (_songUnits.containsKey(id)) {
      _songUnits[id] = Map.from(songUnit);
    }
  }

  void deleteSongUnit(String id) {
    _songUnits.remove(id);
    _songUnitTags.remove(id);
  }

  Map<String, dynamic>? getSongUnit(String id) {
    return _songUnits[id];
  }

  List<Map<String, dynamic>> getAllSongUnits() {
    return _songUnits.values.toList();
  }

  List<Map<String, dynamic>> getSongUnitsByHash(String hash) {
    return _songUnits.values.where((su) => su['hash'] == hash).toList();
  }

  List<Map<String, dynamic>> getSongUnitsByStorageLocation(
    String libraryLocationId,
  ) {
    return _songUnits.values
        .where((su) => su['library_location_id'] == libraryLocationId)
        .toList();
  }

  void addTagToSongUnit(String songUnitId, String tagId) {
    _songUnitTags.putIfAbsent(songUnitId, () => {});
    _songUnitTags[songUnitId]!.add(tagId);
  }

  void removeTagFromSongUnit(String songUnitId, String tagId) {
    _songUnitTags[songUnitId]?.remove(tagId);
  }

  Set<String> getTagsForSongUnit(String songUnitId) {
    return _songUnitTags[songUnitId] ?? {};
  }

  void clear() {
    _songUnits.clear();
    _songUnitTags.clear();
  }
}

void main() {
  // Feature: song-unit-core, Property 29: Immediate persistence
  // **Validates: Requirements 8.1**
  group('Library Repository Property Tests', () {
    late InMemoryStorage storage;

    setUp(() {
      storage = InMemoryStorage();
    });

    tearDown(() {
      storage.clear();
    });

    test(
      'Property 29: For any Song Unit creation or modification, changes SHALL be immediately retrievable',
      () {
        // Run 100 iterations with random Song Units
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          // Generate a random Song Unit
          final songUnit = TestGenerators.randomSongUnit();

          // Add the Song Unit
          _addSongUnit(storage, songUnit);

          // Immediately retrieve it
          final retrieved = _getSongUnit(storage, songUnit.id);

          // Verify it was persisted
          expect(
            retrieved,
            isNotNull,
            reason: 'Song Unit should be immediately retrievable after add',
          );
          expect(retrieved!.id, equals(songUnit.id));
          expect(retrieved.metadata.title, equals(songUnit.metadata.title));
          expect(retrieved.metadata.artists, equals(songUnit.metadata.artists));
          expect(retrieved.metadata.album, equals(songUnit.metadata.album));
          expect(retrieved.metadata.year, equals(songUnit.metadata.year));
          expect(
            retrieved.metadata.duration,
            equals(songUnit.metadata.duration),
          );

          // Modify the Song Unit
          final updatedMetadata = songUnit.metadata.copyWith(
            title: 'Updated_${TestGenerators.randomString()}',
            artists: ['Updated_${TestGenerators.randomString()}'],
          );
          final updatedSongUnit = songUnit.copyWith(metadata: updatedMetadata);

          // Update the Song Unit
          _updateSongUnit(storage, updatedSongUnit);

          // Immediately retrieve it again
          final retrievedAfterUpdate = _getSongUnit(
            storage,
            updatedSongUnit.id,
          );

          // Verify the update was persisted
          expect(
            retrievedAfterUpdate,
            isNotNull,
            reason: 'Song Unit should be immediately retrievable after update',
          );
          expect(
            retrievedAfterUpdate!.metadata.title,
            equals(updatedMetadata.title),
          );
          expect(
            retrievedAfterUpdate.metadata.artists,
            equals(updatedMetadata.artists),
          );

          // Delete the Song Unit
          _deleteSongUnit(storage, songUnit.id);

          // Verify it's no longer retrievable
          final retrievedAfterDelete = _getSongUnit(storage, songUnit.id);
          expect(
            retrievedAfterDelete,
            isNull,
            reason: 'Song Unit should not be retrievable after delete',
          );
        }
      },
    );

    test(
      'Property 29 (add): Adding a Song Unit makes it immediately retrievable',
      () {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          final songUnit = TestGenerators.randomSongUnit();

          _addSongUnit(storage, songUnit);
          final retrieved = _getSongUnit(storage, songUnit.id);

          expect(retrieved, isNotNull);
          expect(retrieved!.id, equals(songUnit.id));
          expect(retrieved.metadata, equals(songUnit.metadata));
        }
      },
    );

    test(
      'Property 29 (update): Updating a Song Unit makes changes immediately retrievable',
      () {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          final songUnit = TestGenerators.randomSongUnit();
          _addSongUnit(storage, songUnit);

          // Update with new metadata
          final newTitle = 'NewTitle_${TestGenerators.randomString()}';
          final updated = songUnit.copyWith(
            metadata: songUnit.metadata.copyWith(title: newTitle),
          );

          _updateSongUnit(storage, updated);
          final retrieved = _getSongUnit(storage, songUnit.id);

          expect(retrieved, isNotNull);
          expect(retrieved!.metadata.title, equals(newTitle));
        }
      },
    );

    test(
      'Property 29 (delete): Deleting a Song Unit removes it immediately',
      () {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          final songUnit = TestGenerators.randomSongUnit();
          _addSongUnit(storage, songUnit);

          // Verify it exists
          var retrieved = _getSongUnit(storage, songUnit.id);
          expect(retrieved, isNotNull);

          // Delete it
          _deleteSongUnit(storage, songUnit.id);

          // Verify it's gone
          retrieved = _getSongUnit(storage, songUnit.id);
          expect(retrieved, isNull);
        }
      },
    );

    test(
      'Property 29 (getAllSongUnits): All added Song Units are retrievable',
      () {
        // Add multiple Song Units
        final songUnits = <SongUnit>[];
        for (var i = 0; i < 10; i++) {
          final songUnit = TestGenerators.randomSongUnit();
          songUnits.add(songUnit);
          _addSongUnit(storage, songUnit);
        }

        // Retrieve all
        final allRetrieved = _getAllSongUnits(storage);

        // Verify all are present
        expect(allRetrieved.length, equals(songUnits.length));
        for (final songUnit in songUnits) {
          expect(
            allRetrieved.any((s) => s.id == songUnit.id),
            isTrue,
            reason:
                'Song Unit ${songUnit.id} should be in getAllSongUnits result',
          );
        }
      },
    );

    test(
      'Property 29 (hash deduplication): Song Units with same hash can be detected',
      () {
        // Create a Song Unit
        final songUnit = TestGenerators.randomSongUnit();
        _addSongUnit(storage, songUnit);

        // Calculate its hash
        final hash = songUnit.calculateHash();

        // Retrieve by hash
        final byHash = _getSongUnitsByHash(storage, hash);

        expect(byHash.length, equals(1));
        expect(byHash.first.id, equals(songUnit.id));
      },
    );

    test(
      'Property 29 (sources persistence): Source collection is correctly persisted',
      () {
        const iterations = 50;

        for (var i = 0; i < iterations; i++) {
          final songUnit = TestGenerators.randomSongUnit();
          _addSongUnit(storage, songUnit);

          final retrieved = _getSongUnit(storage, songUnit.id);

          expect(retrieved, isNotNull);
          expect(
            retrieved!.sources.displaySources.length,
            equals(songUnit.sources.displaySources.length),
          );
          expect(
            retrieved.sources.audioSources.length,
            equals(songUnit.sources.audioSources.length),
          );
          expect(
            retrieved.sources.accompanimentSources.length,
            equals(songUnit.sources.accompanimentSources.length),
          );
          expect(
            retrieved.sources.hoverSources.length,
            equals(songUnit.sources.hoverSources.length),
          );
        }
      },
    );
  });

  // **Feature: storage-locations, Property 10: Storage Location Filtering**
  // **Validates: Requirements 7.3**
  group('Storage Location Filtering Property Tests', () {
    late InMemoryStorage storage;

    setUp(() {
      storage = InMemoryStorage();
    });

    tearDown(() {
      storage.clear();
    });

    test(
      'Property 10: For any storage location filter, filtered results SHALL contain only Song Units from that location',
      () {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          storage.clear();

          // Generate random storage locations
          final locations = TestGenerators.randomStorageLocations(minCount: 2);

          // Create Song Units distributed across storage locations
          final songUnitsByLocation = <String, List<SongUnit>>{};
          for (final location in locations) {
            songUnitsByLocation[location.id] = [];

            // Add 1-5 Song Units per location
            final count = TestGenerators.randomInt(1, 5);
            for (var j = 0; j < count; j++) {
              final songUnit = TestGenerators.randomSongUnitWithLibraryLocation(
                libraryLocationId: location.id,
              );
              songUnitsByLocation[location.id]!.add(songUnit);
              _addSongUnit(storage, songUnit);
            }
          }

          // Test filtering for each location
          for (final location in locations) {
            final filtered = _getSongUnitsByStorageLocation(
              storage,
              location.id,
            );
            final expected = songUnitsByLocation[location.id]!;

            // Verify count matches
            expect(
              filtered.length,
              equals(expected.length),
              reason:
                  'Filtered count should match expected for location ${location.id}',
            );

            // Verify all filtered Song Units belong to the correct location
            for (final songUnit in filtered) {
              expect(
                songUnit.libraryLocationId,
                equals(location.id),
                reason:
                    'All filtered Song Units should have the correct storage location ID',
              );
            }

            // Verify all expected Song Units are in the filtered results
            for (final expectedSongUnit in expected) {
              expect(
                filtered.any((s) => s.id == expectedSongUnit.id),
                isTrue,
                reason:
                    'Expected Song Unit ${expectedSongUnit.id} should be in filtered results',
              );
            }
          }
        }
      },
    );

    test(
      'Property 10 (exclusion): Filtering by one location SHALL NOT include Song Units from other locations',
      () {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          storage.clear();

          // Create exactly 2 storage locations
          final location1 = TestGenerators.randomStorageLocation(
            isDefault: true,
          );
          final location2 = TestGenerators.randomStorageLocation(
            isDefault: false,
          );

          // Add Song Units to each location
          final songUnitsLoc1 = <SongUnit>[];
          final songUnitsLoc2 = <SongUnit>[];

          for (var j = 0; j < 3; j++) {
            final su1 = TestGenerators.randomSongUnitWithLibraryLocation(
              libraryLocationId: location1.id,
            );
            songUnitsLoc1.add(su1);
            _addSongUnit(storage, su1);

            final su2 = TestGenerators.randomSongUnitWithLibraryLocation(
              libraryLocationId: location2.id,
            );
            songUnitsLoc2.add(su2);
            _addSongUnit(storage, su2);
          }

          // Filter by location1
          final filteredLoc1 = _getSongUnitsByStorageLocation(
            storage,
            location1.id,
          );

          // Verify no Song Units from location2 are included
          for (final songUnit in filteredLoc1) {
            expect(
              songUnit.libraryLocationId,
              isNot(equals(location2.id)),
              reason:
                  'Filtered results for location1 should not include Song Units from location2',
            );
          }

          // Filter by location2
          final filteredLoc2 = _getSongUnitsByStorageLocation(
            storage,
            location2.id,
          );

          // Verify no Song Units from location1 are included
          for (final songUnit in filteredLoc2) {
            expect(
              songUnit.libraryLocationId,
              isNot(equals(location1.id)),
              reason:
                  'Filtered results for location2 should not include Song Units from location1',
            );
          }
        }
      },
    );

    test(
      'Property 10 (empty filter): Filtering by non-existent location SHALL return empty results',
      () {
        const iterations = 50;

        for (var i = 0; i < iterations; i++) {
          storage.clear();

          // Add some Song Units with a known location
          final location = TestGenerators.randomStorageLocation();
          for (var j = 0; j < 3; j++) {
            final songUnit = TestGenerators.randomSongUnitWithLibraryLocation(
              libraryLocationId: location.id,
            );
            _addSongUnit(storage, songUnit);
          }

          // Filter by a non-existent location
          final nonExistentLocationId = TestGenerators.randomString();
          final filtered = _getSongUnitsByStorageLocation(
            storage,
            nonExistentLocationId,
          );

          expect(
            filtered.isEmpty,
            isTrue,
            reason:
                'Filtering by non-existent location should return empty results',
          );
        }
      },
    );
  });

  // **Feature: storage-locations, Property 12: Storage Location Association**
  // **Validates: Requirements 7.2**
  group('Storage Location Association Property Tests', () {
    late InMemoryStorage storage;

    setUp(() {
      storage = InMemoryStorage();
    });

    tearDown(() {
      storage.clear();
    });

    test(
      'Property 12: For any Song Unit, the libraryLocationId SHALL determine its storage location association',
      () {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          storage.clear();

          // Generate multiple storage locations
          final locations = TestGenerators.randomStorageLocations(
            minCount: 2,
            maxCount: 4,
          );

          // For each location, create Song Units associated with it
          for (final location in locations) {
            // Create a Song Unit with this storage location ID
            // Note: The sources could theoretically reference files from other locations,
            // but the Song Unit's association is determined by libraryLocationId
            final songUnit = TestGenerators.randomSongUnitWithLibraryLocation(
              libraryLocationId: location.id,
            );

            _addSongUnit(storage, songUnit);

            // Verify the Song Unit is associated with the correct location
            final retrieved = _getSongUnit(storage, songUnit.id);
            expect(retrieved, isNotNull);
            expect(
              retrieved!.libraryLocationId,
              equals(location.id),
              reason:
                  'Song Unit should be associated with the storage location specified by libraryLocationId',
            );

            // Verify it appears in the filtered results for this location
            final filtered = _getSongUnitsByStorageLocation(
              storage,
              location.id,
            );
            expect(
              filtered.any((s) => s.id == songUnit.id),
              isTrue,
              reason:
                  'Song Unit should appear in filtered results for its associated storage location',
            );
          }
        }
      },
    );

    test(
      'Property 12 (persistence): Storage location association SHALL be preserved through persistence',
      () {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          storage.clear();

          final location = TestGenerators.randomStorageLocation();
          final songUnit = TestGenerators.randomSongUnitWithLibraryLocation(
            libraryLocationId: location.id,
          );

          // Add the Song Unit
          _addSongUnit(storage, songUnit);

          // Retrieve and verify association is preserved
          final retrieved = _getSongUnit(storage, songUnit.id);
          expect(retrieved, isNotNull);
          expect(
            retrieved!.libraryLocationId,
            equals(location.id),
            reason:
                'Storage location association should be preserved after persistence',
          );
        }
      },
    );

    test(
      'Property 12 (update): Storage location association SHALL be updatable',
      () {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          storage.clear();

          final location1 = TestGenerators.randomStorageLocation(
            isDefault: true,
          );
          final location2 = TestGenerators.randomStorageLocation(
            isDefault: false,
          );

          // Create Song Unit with location1
          final songUnit = TestGenerators.randomSongUnitWithLibraryLocation(
            libraryLocationId: location1.id,
          );
          _addSongUnit(storage, songUnit);

          // Verify initial association
          var retrieved = _getSongUnit(storage, songUnit.id);
          expect(retrieved!.libraryLocationId, equals(location1.id));

          // Update to location2
          final updatedSongUnit = songUnit.copyWith(
            libraryLocationId: location2.id,
          );
          _updateSongUnit(storage, updatedSongUnit);

          // Verify updated association
          retrieved = _getSongUnit(storage, songUnit.id);
          expect(
            retrieved!.libraryLocationId,
            equals(location2.id),
            reason: 'Storage location association should be updatable',
          );

          // Verify it no longer appears in location1 filter
          final filteredLoc1 = _getSongUnitsByStorageLocation(
            storage,
            location1.id,
          );
          expect(
            filteredLoc1.any((s) => s.id == songUnit.id),
            isFalse,
            reason:
                'Song Unit should not appear in old location filter after update',
          );

          // Verify it appears in location2 filter
          final filteredLoc2 = _getSongUnitsByStorageLocation(
            storage,
            location2.id,
          );
          expect(
            filteredLoc2.any((s) => s.id == songUnit.id),
            isTrue,
            reason:
                'Song Unit should appear in new location filter after update',
          );
        }
      },
    );

    test(
      'Property 12 (null association): Song Units without storage location SHALL have null libraryLocationId',
      () {
        const iterations = 50;

        for (var i = 0; i < iterations; i++) {
          storage.clear();

          // Create Song Unit without storage location (centralized mode)
          final songUnit = TestGenerators.randomSongUnitWithLibraryLocation();
          _addSongUnit(storage, songUnit);

          // Verify null association is preserved
          final retrieved = _getSongUnit(storage, songUnit.id);
          expect(retrieved, isNotNull);
          expect(
            retrieved!.libraryLocationId,
            isNull,
            reason:
                'Song Unit without storage location should have null libraryLocationId',
          );
        }
      },
    );
  });
}

// Helper functions that mirror LibraryRepository logic for testing
void _addSongUnit(InMemoryStorage storage, SongUnit songUnit) {
  final now = DateTime.now().millisecondsSinceEpoch;
  final hash = songUnit.calculateHash();

  storage.insertSongUnit({
    'id': songUnit.id,
    'metadata_json': jsonEncode(songUnit.metadata.toJson()),
    'sources_json': jsonEncode(songUnit.sources.toJson()),
    'preferences_json': jsonEncode(songUnit.preferences.toJson()),
    'hash': hash,
    'library_location_id': songUnit.libraryLocationId,
    'created_at': now,
    'updated_at': now,
  });

  for (final tagId in songUnit.tagIds) {
    storage.addTagToSongUnit(songUnit.id, tagId);
  }
}

void _updateSongUnit(InMemoryStorage storage, SongUnit songUnit) {
  final now = DateTime.now().millisecondsSinceEpoch;
  final hash = songUnit.calculateHash();

  storage.updateSongUnit(songUnit.id, {
    'id': songUnit.id,
    'metadata_json': jsonEncode(songUnit.metadata.toJson()),
    'sources_json': jsonEncode(songUnit.sources.toJson()),
    'preferences_json': jsonEncode(songUnit.preferences.toJson()),
    'hash': hash,
    'library_location_id': songUnit.libraryLocationId,
    'updated_at': now,
  });
}

void _deleteSongUnit(InMemoryStorage storage, String id) {
  storage.deleteSongUnit(id);
}

SongUnit? _getSongUnit(InMemoryStorage storage, String id) {
  final row = storage.getSongUnit(id);
  if (row == null) return null;
  return _songUnitFromRow(row, storage.getTagsForSongUnit(id).toList());
}

List<SongUnit> _getAllSongUnits(InMemoryStorage storage) {
  final rows = storage.getAllSongUnits();
  return rows
      .map(
        (row) => _songUnitFromRow(
          row,
          storage.getTagsForSongUnit(row['id'] as String).toList(),
        ),
      )
      .toList();
}

List<SongUnit> _getSongUnitsByHash(InMemoryStorage storage, String hash) {
  final rows = storage.getSongUnitsByHash(hash);
  return rows
      .map(
        (row) => _songUnitFromRow(
          row,
          storage.getTagsForSongUnit(row['id'] as String).toList(),
        ),
      )
      .toList();
}

List<SongUnit> _getSongUnitsByStorageLocation(
  InMemoryStorage storage,
  String libraryLocationId,
) {
  final rows = storage.getSongUnitsByStorageLocation(libraryLocationId);
  return rows
      .map(
        (row) => _songUnitFromRow(
          row,
          storage.getTagsForSongUnit(row['id'] as String).toList(),
        ),
      )
      .toList();
}

SongUnit _songUnitFromRow(Map<String, dynamic> row, List<String> tagIds) {
  final id = row['id'] as String;
  final metadataJson =
      jsonDecode(row['metadata_json'] as String) as Map<String, dynamic>;
  final sourcesJson =
      jsonDecode(row['sources_json'] as String) as Map<String, dynamic>;
  final preferencesJson =
      jsonDecode(row['preferences_json'] as String) as Map<String, dynamic>;
  final libraryLocationId = row['library_location_id'] as String?;

  return SongUnit(
    id: id,
    metadata: Metadata.fromJson(metadataJson),
    sources: SourceCollection.fromJson(sourcesJson),
    tagIds: tagIds,
    preferences: PlaybackPreferences.fromJson(preferencesJson),
    libraryLocationId: libraryLocationId,
  );
}
