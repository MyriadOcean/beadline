import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/configuration_mode.dart';
import '../models/entry_point_file.dart';
import '../models/library_location.dart';
import '../models/song_unit.dart';
import '../models/source_origin.dart';
import '../models/tag_extensions.dart';
import '../repositories/library_repository.dart';
import '../repositories/tag_repository.dart';
import 'entry_point_file_service.dart';

/// Progress callback for migration operations
typedef MigrationProgressCallback =
    void Function(int current, int total, String message);

/// Service for migrating configuration files between centralized and in-place modes
class ConfigurationMigrationService {
  ConfigurationMigrationService(
    this._libraryRepository,
    this._entryPointFileService, {
    TagRepository? tagRepository,
  }) : _tagRepository = tagRepository;
  final LibraryRepository _libraryRepository;
  final EntryPointFileService _entryPointFileService;
  final TagRepository? _tagRepository;

  /// Get the centralized config directory path
  Future<String> getCentralizedConfigPath() async {
    final appDir = await getApplicationDocumentsDirectory();
    return p.join(appDir.path, 'Beadline', 'entry_points');
  }

  /// Migrate entry point files from one mode to another
  ///
  /// Returns true if migration was successful
  Future<bool> migrateEntryPoints({
    required ConfigurationMode fromMode,
    required ConfigurationMode toMode,
    required List<LibraryLocation> libraryLocations,
    MigrationProgressCallback? onProgress,
  }) async {
    if (fromMode == toMode) return true;

    try {
      // Ensure PathResolver has current locations
      _entryPointFileService.updateLocations(libraryLocations);

      final songUnits = await _libraryRepository.getAllSongUnits();
      final total = songUnits.length;
      var current = 0;

      for (final songUnit in songUnits) {
        current++;
        onProgress?.call(
          current,
          total,
          'Migrating: ${songUnit.metadata.title}',
        );

        await _migrateSongUnitEntryPoint(
          songUnit: songUnit,
          fromMode: fromMode,
          toMode: toMode,
          libraryLocations: libraryLocations,
        );
      }

      onProgress?.call(total, total, 'Migration complete');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Migrate a single song unit's entry point file
  Future<void> _migrateSongUnitEntryPoint({
    required SongUnit songUnit,
    required ConfigurationMode fromMode,
    required ConfigurationMode toMode,
    required List<LibraryLocation> libraryLocations,
  }) async {
    // Find the source entry point file
    final sourceEntryPointPath = await _findEntryPointFile(
      songUnit: songUnit,
      mode: fromMode,
      libraryLocations: libraryLocations,
    );

    if (sourceEntryPointPath == null) {
      // No entry point file exists, create one in the new location
      await _createEntryPointFile(
        songUnit: songUnit,
        mode: toMode,
        libraryLocations: libraryLocations,
      );
      return;
    }

    // Read the existing entry point file
    final entryPoint = await _entryPointFileService.readEntryPoint(
      sourceEntryPointPath,
    );

    // Determine the destination path
    final destPath = await _getDestinationPath(
      songUnit: songUnit,
      mode: toMode,
      libraryLocations: libraryLocations,
    );

    // Write to the new location
    await _writeEntryPointFile(entryPoint, destPath);

    // Delete the old file
    final sourceFile = File(sourceEntryPointPath);
    if (sourceFile.existsSync()) {
      await sourceFile.delete();
    }

    // Clean up empty directories in centralized mode
    if (fromMode == ConfigurationMode.centralized) {
      await _cleanupEmptyDirectories(p.dirname(sourceEntryPointPath));
    }
  }

  /// Find the entry point file for a song unit based on the configuration mode
  Future<String?> _findEntryPointFile({
    required SongUnit songUnit,
    required ConfigurationMode mode,
    required List<LibraryLocation> libraryLocations,
  }) async {
    final filename = _entryPointFileService.generateFilename(
      songUnit.metadata.title,
    );

    if (mode == ConfigurationMode.centralized) {
      final centralizedPath = await getCentralizedConfigPath();
      final filePath = p.join(centralizedPath, filename);
      if (File(filePath).existsSync()) {
        return filePath;
      }
    } else {
      // In-place mode: search in library locations
      for (final location in libraryLocations) {
        final filePath = await _searchInDirectory(
          Directory(location.rootPath),
          songUnit.id,
        );
        if (filePath != null) {
          return filePath;
        }
      }
    }

    return null;
  }

  /// Search for an entry point file in a directory recursively
  Future<String?> _searchInDirectory(
    Directory directory,
    String songUnitId,
  ) async {
    if (!directory.existsSync()) return null;

    await for (final entity in directory.list(recursive: true)) {
      if (entity is File) {
        final filename = p.basename(entity.path);
        if ((filename.startsWith(EntryPointFile.filePrefix) ||
                filename.startsWith(EntryPointFile.legacyFilePrefix)) &&
            filename.endsWith(EntryPointFile.fileExtension)) {
          try {
            final entryPoint = await _entryPointFileService.readEntryPoint(
              entity.path,
            );
            if (entryPoint.songUnitId == songUnitId) {
              return entity.path;
            }
          } catch (_) {
            continue;
          }
        }
      }
    }

    return null;
  }

  /// Get the destination path for an entry point file based on the mode
  Future<String> _getDestinationPath({
    required SongUnit songUnit,
    required ConfigurationMode mode,
    required List<LibraryLocation> libraryLocations,
  }) async {
    final filename = _entryPointFileService.generateFilename(
      songUnit.metadata.title,
    );

    if (mode == ConfigurationMode.centralized) {
      final centralizedPath = await getCentralizedConfigPath();
      await Directory(centralizedPath).create(recursive: true);
      return p.join(centralizedPath, filename);
    } else {
      // In-place mode: place alongside the first source file or in the library location
      final sourceDir = _getSourceDirectory(songUnit, libraryLocations);
      return p.join(sourceDir, filename);
    }
  }

  /// Get the directory where the entry point file should be placed in in-place mode
  String _getSourceDirectory(
    SongUnit songUnit,
    List<LibraryLocation> libraryLocations,
  ) {
    // Try to find a local source file and use its directory
    for (final source in songUnit.sources.getAllSources()) {
      final origin = source.origin;
      if (origin is LocalFileOrigin) {
        final path = origin.path;
        if (p.isAbsolute(path) && File(path).existsSync()) {
          return p.dirname(path);
        }
      }
    }

    // Fall back to the song unit's library location
    if (songUnit.libraryLocationId != null) {
      final location = libraryLocations.firstWhere(
        (loc) => loc.id == songUnit.libraryLocationId,
        orElse: () => libraryLocations.first,
      );
      return location.rootPath;
    }

    // Fall back to the default library location
    if (libraryLocations.isNotEmpty) {
      final defaultLocation = libraryLocations.firstWhere(
        (loc) => loc.isDefault,
        orElse: () => libraryLocations.first,
      );
      return defaultLocation.rootPath;
    }

    // Last resort: use the current directory
    return Directory.current.path;
  }

  /// Create a tag ID to name resolver using the tag repository.
  /// Returns null if no tag repository is available.
  /// Only resolves non-collection user tags (skips built-in, automatic, and collection tags).
  TagIdToNameResolver? _createTagIdToNameResolver() {
    final repo = _tagRepository;
    if (repo == null) return null;
    return (String tagId) async {
      final tag = await repo.getTag(tagId);
      if (tag == null) return null;
      // Skip built-in tags (always exist, never exported)
      if (tag.tagType == TagType.builtIn) return null;
      // Skip automatic tags (system-maintained)
      if (tag.tagType == TagType.automatic) return null;
      // Skip collections (playlists, queues, groups)
      if (tag.isCollection) return null;
      return tag.name;
    };
  }

  /// Create a new entry point file for a song unit
  ///
  /// This is called when a new song unit is added to the library.
  /// The entry point file is created in the appropriate location based on the mode.
  Future<void> createEntryPointFile({
    required SongUnit songUnit,
    required ConfigurationMode mode,
    required List<LibraryLocation> libraryLocations,
  }) async {
    // Ensure PathResolver has current locations for @library/ path generation
    _entryPointFileService.updateLocations(libraryLocations);

    final destPath = await _getDestinationPath(
      songUnit: songUnit,
      mode: mode,
      libraryLocations: libraryLocations,
    );

    final directory = p.dirname(destPath);
    await _entryPointFileService.writeEntryPoint(
      songUnit,
      directory,
      tagIdToNameResolver: _createTagIdToNameResolver(),
    );
  }

  /// Create an entry point file in a specific directory.
  ///
  /// Used when updating a song unit that already has an entry point file â€?  /// the new file is written back to the same directory as the old one,
  /// regardless of the current configuration mode.
  /// If [libraryLocations] is provided, updates the PathResolver for correct
  /// @library/ path generation.
  Future<void> createEntryPointFileAt({
    required SongUnit songUnit,
    required String directory,
    List<LibraryLocation>? libraryLocations,
  }) async {
    if (libraryLocations != null) {
      _entryPointFileService.updateLocations(libraryLocations);
    }
    await _entryPointFileService.writeEntryPoint(
      songUnit,
      directory,
      tagIdToNameResolver: _createTagIdToNameResolver(),
    );
  }

  /// Internal method to create entry point file (used by migration)
  Future<void> _createEntryPointFile({
    required SongUnit songUnit,
    required ConfigurationMode mode,
    required List<LibraryLocation> libraryLocations,
  }) async {
    await createEntryPointFile(
      songUnit: songUnit,
      mode: mode,
      libraryLocations: libraryLocations,
    );
  }

  /// Write an entry point file to a specific path
  Future<void> _writeEntryPointFile(
    EntryPointFile entryPoint,
    String destPath,
  ) async {
    final file = File(destPath);
    await file.parent.create(recursive: true);

    const encoder = JsonEncoder.withIndent('  ');
    final jsonString = encoder.convert(entryPoint.toJson());
    await file.writeAsString(jsonString);
  }

  /// Clean up empty directories after migration
  Future<void> _cleanupEmptyDirectories(String dirPath) async {
    var dir = Directory(dirPath);

    while (dir.existsSync()) {
      final contents = dir.listSync();
      if (contents.isEmpty) {
        await dir.delete();
        dir = dir.parent;
      } else {
        break;
      }
    }
  }

  /// Delete the entry point file for a song unit
  ///
  /// Searches for the entry point file in both centralized and in-place locations
  /// and deletes it if found. Only deletes the configuration file, not source files.
  ///
  /// Returns true if a file was found and deleted, false otherwise.
  Future<bool> deleteEntryPointFile({
    required SongUnit songUnit,
    required ConfigurationMode currentMode,
    required List<LibraryLocation> libraryLocations,
  }) async {
    try {
      // Try to find the entry point file in the current mode location
      var entryPointPath = await _findEntryPointFile(
        songUnit: songUnit,
        mode: currentMode,
        libraryLocations: libraryLocations,
      );

      // If not found in current mode, try the other mode (in case of inconsistency)
      if (entryPointPath == null) {
        final otherMode = currentMode == ConfigurationMode.centralized
            ? ConfigurationMode.inPlace
            : ConfigurationMode.centralized;
        entryPointPath = await _findEntryPointFile(
          songUnit: songUnit,
          mode: otherMode,
          libraryLocations: libraryLocations,
        );
      }

      if (entryPointPath == null) {
        // No entry point file found
        return false;
      }

      // Delete the file
      final file = File(entryPointPath);
      if (file.existsSync()) {
        await file.delete();

        // Clean up empty directories if in centralized mode
        if (currentMode == ConfigurationMode.centralized) {
          await _cleanupEmptyDirectories(p.dirname(entryPointPath));
        }

        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Find entry point file for a song unit by searching all possible locations
  ///
  /// This is a public method that can be used to check if an entry point file exists.
  Future<String?> findEntryPointFile({
    required SongUnit songUnit,
    required ConfigurationMode currentMode,
    required List<LibraryLocation> libraryLocations,
  }) async {
    // Try current mode first
    final path = await _findEntryPointFile(
      songUnit: songUnit,
      mode: currentMode,
      libraryLocations: libraryLocations,
    );

    if (path != null) return path;

    // Try other mode
    final otherMode = currentMode == ConfigurationMode.centralized
        ? ConfigurationMode.inPlace
        : ConfigurationMode.centralized;
    return _findEntryPointFile(
      songUnit: songUnit,
      mode: otherMode,
      libraryLocations: libraryLocations,
    );
  }

  /// Migrate entry point files for a specific library location between modes.
  ///
  /// When switching a location to in-place: moves JSON files from central
  /// storage into the library location (alongside audio sources).
  /// When switching to centralized: moves JSON files from the library
  /// location into central storage.
  ///
  /// Only affects song units whose audio sources are within [location].
  Future<bool> migrateLocationEntryPoints({
    required LibraryLocation location,
    required ConfigurationMode toMode,
    required List<LibraryLocation> allLocations,
    MigrationProgressCallback? onProgress,
  }) async {
    final fromMode = toMode == ConfigurationMode.inPlace
        ? ConfigurationMode.centralized
        : ConfigurationMode.inPlace;

    // Ensure PathResolver has current locations
    _entryPointFileService.updateLocations(allLocations);

    try {
      final allSongUnits = await _libraryRepository.getAllSongUnits();

      // Filter to song units associated with this location
      final songUnits = allSongUnits.where((su) {
        // Match by libraryLocationId
        if (su.libraryLocationId == location.id) return true;
        // Also match by checking if any local source is within this location
        for (final source in su.sources.getAllSources()) {
          if (source.origin is LocalFileOrigin) {
            final path = (source.origin as LocalFileOrigin).path;
            if (path.startsWith(location.rootPath)) return true;
          }
        }
        return false;
      }).toList();

      final total = songUnits.length;
      var current = 0;

      for (final songUnit in songUnits) {
        current++;
        onProgress?.call(
          current,
          total,
          'Migrating: ${songUnit.metadata.title}',
        );

        await _migrateSongUnitEntryPoint(
          songUnit: songUnit,
          fromMode: fromMode,
          toMode: toMode,
          libraryLocations: allLocations,
        );
      }

      onProgress?.call(total, total, 'Migration complete');
      return true;
    } catch (e) {
      return false;
    }
  }
}
