import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/cache_manager.dart';
import '../models/entry_point_file.dart';
import '../models/library_location.dart';
import '../models/metadata.dart';
import '../models/playback_preferences.dart';
import '../models/song_unit.dart';
import '../models/source_collection.dart';
import '../services/entry_point_file_service.dart';
import '../services/path_resolver.dart';
import '../services/thumbnail_cache.dart';
import '../src/rust/api/song_unit_api.dart' as song_unit_api;

/// Events emitted by the LibraryRepository
sealed class LibraryEvent {
  const LibraryEvent();
}

/// Event emitted when a Song Unit is added
class SongUnitAdded extends LibraryEvent {
  const SongUnitAdded(this.songUnit);
  final SongUnit songUnit;
}

/// Event emitted when a Song Unit is updated
class SongUnitUpdated extends LibraryEvent {
  const SongUnitUpdated(this.songUnit);
  final SongUnit songUnit;
}

/// Event emitted when a Song Unit is deleted
class SongUnitDeleted extends LibraryEvent {
  const SongUnitDeleted(this.songUnitId);
  final String songUnitId;
}

/// Event emitted when a Song Unit is moved to a different library location
class SongUnitMoved extends LibraryEvent {
  const SongUnitMoved(
    this.songUnit,
    this.fromLibraryLocationId,
    this.toLibraryLocationId,
  );
  final SongUnit songUnit;
  final String fromLibraryLocationId;
  final String toLibraryLocationId;
}

/// Exception thrown when a move operation fails
class MoveOperationException implements Exception {
  const MoveOperationException(this.message, {this.code});
  final String message;
  final String? code;

  @override
  String toString() => 'MoveOperationException: $message';
}

/// Repository for managing Song Units in the library
/// Includes caching for performance optimization
class LibraryRepository {
  LibraryRepository();
  final StreamController<LibraryEvent> _eventController =
      StreamController<LibraryEvent>.broadcast();

  // Cache for frequently accessed Song Units
  final CacheManager<String, SongUnit> _cache = CacheManager(
    maxSize: 200,
    ttl: const Duration(minutes: 10),
  );

  /// Stream of library events for change notifications
  Stream<LibraryEvent> get events => _eventController.stream;

  /// Add a new Song Unit to the library
  /// Persists immediately and emits a SongUnitAdded event
  Future<void> addSongUnit(SongUnit songUnit) async {
    await song_unit_api.createSongUnit(
      id: songUnit.id,
      metadataJson: jsonEncode(songUnit.metadata.toJson()),
      sourcesJson: jsonEncode(songUnit.sources.toJson()),
      preferencesJson: jsonEncode(songUnit.preferences.toJson()),
      tagIds: songUnit.tagIds,
      libraryLocationId: songUnit.libraryLocationId,
      isTemporary: songUnit.isTemporary,
      discoveredAt: songUnit.discoveredAt?.millisecondsSinceEpoch,
      originalFilePath: songUnit.originalFilePath,
    );

    // Add to cache
    _cache.put(songUnit.id, songUnit);

    _eventController.add(SongUnitAdded(songUnit));
  }

  /// Update an existing Song Unit
  /// Persists immediately and emits a SongUnitUpdated event
  Future<void> updateSongUnit(SongUnit songUnit) async {
    await song_unit_api.updateSongUnit(
      id: songUnit.id,
      metadataJson: jsonEncode(songUnit.metadata.toJson()),
      sourcesJson: jsonEncode(songUnit.sources.toJson()),
      preferencesJson: jsonEncode(songUnit.preferences.toJson()),
      tagIds: songUnit.tagIds,
      libraryLocationId: songUnit.libraryLocationId,
      isTemporary: songUnit.isTemporary,
      discoveredAt: songUnit.discoveredAt?.millisecondsSinceEpoch,
      originalFilePath: songUnit.originalFilePath,
    );

    // Update cache
    _cache.put(songUnit.id, songUnit);

    _eventController.add(SongUnitUpdated(songUnit));
    ThumbnailCache.instance.schedulePurge();
  }

  /// Delete a Song Unit from the library
  /// Persists immediately and emits a SongUnitDeleted event
  Future<void> deleteSongUnit(String id) async {
    await song_unit_api.deleteSongUnit(id: id);
    // Remove from cache
    _cache.remove(id);
    _eventController.add(SongUnitDeleted(id));
    ThumbnailCache.instance.schedulePurge();
  }

  /// Get a Song Unit by ID
  /// Uses cache for frequently accessed items
  Future<SongUnit?> getSongUnit(String id) async {
    // Check cache first
    final cached = _cache.get(id);
    if (cached != null) return cached;

    final ffi = await song_unit_api.getSongUnit(id: id);
    if (ffi == null) return null;

    final songUnit = _songUnitFromFfi(ffi);
    // Add to cache
    _cache.put(id, songUnit);
    return songUnit;
  }

  /// Get all Song Units in the library
  Future<List<SongUnit>> getAllSongUnits() async {
    final ffiUnits = await song_unit_api.getAllSongUnits();
    return ffiUnits.map(_songUnitFromFfi).toList();
  }

  /// Get Song Units by hash (for deduplication)
  Future<List<SongUnit>> getSongUnitsByHash(String hash) async {
    final ffiUnits = await song_unit_api.getSongUnitsByHash(hash: hash);
    return ffiUnits.map(_songUnitFromFfi).toList();
  }

  /// Get Song Units by library location ID
  /// Returns all Song Units associated with the specified library location
  Future<List<SongUnit>> getByLibraryLocation(String libraryLocationId) async {
    final ffiUnits = await song_unit_api.getSongUnitsByLibraryLocation(
      locationId: libraryLocationId,
    );
    final songUnits = ffiUnits.map(_songUnitFromFfi).toList();
    for (final su in songUnits) {
      _cache.put(su.id, su);
    }
    return songUnits;
  }

  /// Alias for backward compatibility
  Future<List<SongUnit>> getByStorageLocation(String storageLocationId) =>
      getByLibraryLocation(storageLocationId);

  /// Get Song Units that are not associated with any library location
  /// These are typically Song Units in centralized mode
  Future<List<SongUnit>> getSongUnitsWithoutLibraryLocation() async {
    final all = await getAllSongUnits();
    return all.where((su) => su.libraryLocationId == null).toList();
  }

  /// Alias for backward compatibility
  Future<List<SongUnit>> getSongUnitsWithoutStorageLocation() =>
      getSongUnitsWithoutLibraryLocation();

  /// Get Song Units aggregated from multiple library locations
  /// Returns all Song Units from the specified library locations combined
  /// If libraryLocationIds is empty, returns all Song Units (equivalent to getAllSongUnits)
  Future<List<SongUnit>> getAggregatedFromLibraryLocations(
    List<String> libraryLocationIds,
  ) async {
    if (libraryLocationIds.isEmpty) {
      return getAllSongUnits();
    }

    final songUnits = <SongUnit>[];
    final seenIds = <String>{};

    for (final locationId in libraryLocationIds) {
      final locationSongUnits = await getByLibraryLocation(locationId);
      for (final songUnit in locationSongUnits) {
        // Avoid duplicates (shouldn't happen, but be safe)
        if (!seenIds.contains(songUnit.id)) {
          seenIds.add(songUnit.id);
          songUnits.add(songUnit);
        }
      }
    }

    return songUnits;
  }

  /// Alias for backward compatibility
  Future<List<SongUnit>> getAggregatedFromStorageLocations(
    List<String> storageLocationIds,
  ) => getAggregatedFromLibraryLocations(storageLocationIds);

  /// Check if a Song Unit with the given hash already exists
  Future<bool> existsByHash(String hash) async {
    final units = await song_unit_api.getSongUnitsByHash(hash: hash);
    return units.isNotEmpty;
  }

  /// Convert an FFI Song Unit to a domain SongUnit
  SongUnit _songUnitFromFfi(song_unit_api.FfiSongUnit ffi) {
    final metadataJson =
        jsonDecode(ffi.metadataJson) as Map<String, dynamic>;
    final sourcesJson =
        jsonDecode(ffi.sourcesJson) as Map<String, dynamic>;
    final preferencesJson =
        jsonDecode(ffi.preferencesJson) as Map<String, dynamic>;

    return SongUnit(
      id: ffi.id,
      metadata: Metadata.fromJson(metadataJson),
      sources: SourceCollection.fromJson(sourcesJson),
      tagIds: ffi.tagIds,
      preferences: PlaybackPreferences.fromJson(preferencesJson),
      libraryLocationId: ffi.libraryLocationId,
      isTemporary: ffi.isTemporary,
      discoveredAt: ffi.discoveredAt != null
          ? DateTime.fromMillisecondsSinceEpoch(ffi.discoveredAt!)
          : null,
      originalFilePath: ffi.originalFilePath,
    );
  }

  /// Get Song Units with pagination (for lazy loading)
  Future<List<SongUnit>> getSongUnitsPaginated({
    required int page,
    int pageSize = 50,
  }) async {
    final ffiUnits = await song_unit_api.getSongUnitsPaginated(
      offset: BigInt.from(page * pageSize),
      limit: BigInt.from(pageSize),
    );
    final songUnits = ffiUnits.map(_songUnitFromFfi).toList();
    for (final su in songUnits) {
      _cache.put(su.id, su);
    }
    return songUnits;
  }

  /// Get total count of Song Units
  Future<int> getSongUnitCount() async {
    final count = await song_unit_api.getSongUnitCount();
    return count.toInt();
  }

  /// Clear the cache (useful after bulk operations)
  void clearCache() {
    _cache.clear();
  }

  /// Move a Song Unit from one library location to another.
  ///
  /// This operation:
  /// 1. Reads the entry point file from the source location
  /// 2. Updates all relative paths to resolve correctly from the new location
  /// 3. Writes the entry point file to the destination location
  /// 4. Deletes the old entry point file
  /// 5. Updates the libraryLocationId in the database
  ///
  /// Parameters:
  /// - [songUnitId]: The ID of the Song Unit to move
  /// - [sourceLocation]: The library location where the Song Unit currently resides
  /// - [destinationLocation]: The library location to move the Song Unit to
  /// - [entryPointFileService]: Service for reading/writing entry point files
  /// - [pathResolver]: Service for resolving paths
  /// - [sourceEntryPointPath]: The current path of the entry point file (optional, will be searched if not provided)
  /// - [destinationDirectory]: The directory in the destination location to place the entry point file (optional, defaults to root)
  ///
  /// Returns the updated SongUnit with the new libraryLocationId.
  ///
  /// Throws [MoveOperationException] if the operation fails.
  Future<SongUnit> moveSongUnit({
    required String songUnitId,
    required LibraryLocation sourceLocation,
    required LibraryLocation destinationLocation,
    required EntryPointFileService entryPointFileService,
    required PathResolver pathResolver,
    String? sourceEntryPointPath,
    String? destinationDirectory,
  }) async {
    // Get the Song Unit from the database
    final songUnit = await getSongUnit(songUnitId);
    if (songUnit == null) {
      throw const MoveOperationException(
        'Song Unit not found',
        code: 'NOT_FOUND',
      );
    }

    // Verify the Song Unit is in the source location
    if (songUnit.libraryLocationId != sourceLocation.id) {
      throw const MoveOperationException(
        'Song Unit is not in the specified source location',
        code: 'WRONG_SOURCE_LOCATION',
      );
    }

    // Find the source entry point file if not provided
    final sourcePath =
        sourceEntryPointPath ??
        await _findEntryPointFile(
          songUnitId,
          sourceLocation,
          entryPointFileService,
        );

    if (sourcePath == null) {
      throw const MoveOperationException(
        'Entry point file not found in source location',
        code: 'ENTRY_POINT_NOT_FOUND',
      );
    }

    // Read the entry point file
    EntryPointFile entryPoint;
    try {
      entryPoint = await entryPointFileService.readEntryPoint(sourcePath);
    } catch (e) {
      throw MoveOperationException(
        'Failed to read entry point file: $e',
        code: 'READ_ERROR',
      );
    }

    // Determine destination path
    final destDir = destinationDirectory ?? destinationLocation.rootPath;
    final filename = p.basename(sourcePath);
    final destPath = p.join(destDir, filename);

    // Update relative paths in the entry point file
    final updatedSources = _updateSourcePaths(
      entryPoint.sources,
      sourcePath,
      destPath,
      pathResolver,
    );

    final updatedEntryPoint = entryPoint.copyWith(
      sources: updatedSources,
      modifiedAt: DateTime.now().toUtc(),
    );

    // Write the entry point file to the destination
    try {
      final destFile = File(destPath);
      await destFile.parent.create(recursive: true);

      const encoder = JsonEncoder.withIndent('  ');
      final jsonString = encoder.convert(updatedEntryPoint.toJson());
      await destFile.writeAsString(jsonString);
    } catch (e) {
      throw MoveOperationException(
        'Failed to write entry point file to destination: $e',
        code: 'WRITE_ERROR',
      );
    }

    // Delete the old entry point file
    try {
      final sourceFile = File(sourcePath);
      if (sourceFile.existsSync()) {
        await sourceFile.delete();
      }
    } catch (e) {
      // Log warning but don't fail the operation
      // The file might have been moved/deleted already
    }

    // Update the Song Unit in the database with the new library location ID
    final updatedSongUnit = songUnit.copyWith(
      libraryLocationId: destinationLocation.id,
    );
    await updateSongUnit(updatedSongUnit);

    // Emit move event
    _eventController.add(
      SongUnitMoved(updatedSongUnit, sourceLocation.id, destinationLocation.id),
    );

    return updatedSongUnit;
  }

  /// Find the entry point file for a Song Unit in a library location
  Future<String?> _findEntryPointFile(
    String songUnitId,
    LibraryLocation location,
    EntryPointFileService entryPointFileService,
  ) async {
    final directory = Directory(location.rootPath);
    if (!directory.existsSync()) {
      return null;
    }

    // Recursively search for entry point files
    await for (final entity in directory.list(recursive: true)) {
      if (entity is File) {
        final filename = p.basename(entity.path);
        if ((filename.startsWith(EntryPointFile.filePrefix) ||
                filename.startsWith(EntryPointFile.legacyFilePrefix)) &&
            filename.endsWith(EntryPointFile.fileExtension)) {
          try {
            final entryPoint = await entryPointFileService.readEntryPoint(
              entity.path,
            );
            if (entryPoint.songUnitId == songUnitId) {
              return entity.path;
            }
          } catch (e) {
            // Skip invalid entry point files
            continue;
          }
        }
      }
    }

    return null;
  }

  /// Update source paths when moving an entry point file
  /// Converts paths to resolve correctly from the new location
  List<SourceReference> _updateSourcePaths(
    List<SourceReference> sources,
    String oldEntryPointPath,
    String newEntryPointPath,
    PathResolver pathResolver,
  ) {
    final oldDir = p.dirname(oldEntryPointPath);

    return sources.map((source) {
      // Only update local file paths
      if (source.originType != 'localFile') {
        return source;
      }

      final originalPath = source.path;

      // If it's already an absolute path, keep it as-is
      if (p.isAbsolute(originalPath)) {
        return source;
      }

      // Resolve the relative path to absolute using the old entry point location
      String absolutePath;
      if (originalPath.startsWith('./')) {
        // Relative to entry point directory
        absolutePath = p.normalize(p.join(oldDir, originalPath.substring(2)));
      } else if (originalPath.startsWith('@storage/')) {
        // Relative to storage root - this will need to be recalculated
        // For now, resolve it and then convert back to the appropriate format
        absolutePath = pathResolver.resolveFromEntryPoint(
          originalPath,
          oldEntryPointPath,
        );
      } else {
        // Bare relative path
        absolutePath = p.normalize(p.join(oldDir, originalPath));
      }

      // Convert back to a relative path from the new entry point location
      final newRelativePath = pathResolver.toSerializablePath(
        absolutePath,
        newEntryPointPath,
      );

      return source.copyWith(path: newRelativePath);
    }).toList();
  }

  // ==========================================================================
  // Temporary Song Unit helpers
  // ==========================================================================

  /// Check if a temporary Song Unit already exists for a given file path
  Future<bool> hasTemporarySongUnitForPath(String filePath) async {
    return song_unit_api.hasTemporarySongUnitForPath(filePath: filePath);
  }

  /// Get all temporary Song Units
  Future<List<SongUnit>> getTemporarySongUnits() async {
    final ffiUnits = await song_unit_api.getTemporarySongUnits();
    return ffiUnits.map(_songUnitFromFfi).toList();
  }

  /// Delete all temporary Song Units
  Future<void> deleteAllTemporarySongUnits() async {
    await song_unit_api.deleteAllTemporarySongUnits();
    clearCache();
  }

  /// Delete a temporary Song Unit by its original file path
  Future<void> deleteTemporarySongUnitByPath(String filePath) async {
    await song_unit_api.deleteTemporarySongUnitByPath(filePath: filePath);
  }

  /// Dispose of resources
  void dispose() {
    _eventController.close();
    _cache.clear();
  }
}
