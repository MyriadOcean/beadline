import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../models/entry_point_file.dart';
import '../models/library_location.dart';
import '../models/song_unit.dart';
import '../models/source_origin.dart';
import '../repositories/library_repository.dart';
import '../repositories/tag_repository.dart';
import '../models/tag_extensions.dart';
import 'entry_point_file_service.dart';
import 'library_location_manager.dart';
import 'thumbnail_cache.dart';
import 'thumbnail_extractor.dart';

/// Result of discovering an entry point file
class DiscoveryResult {
  const DiscoveryResult({
    required this.filePath,
    this.entryPoint,
    this.error,
    this.isNew = true,
    this.needsUpdate = false,
    this.libraryLocation,
  });

  /// Path to the discovered entry point file
  final String filePath;

  /// Parsed entry point file, if successful
  final EntryPointFile? entryPoint;

  /// Error message if parsing failed
  final String? error;

  /// Whether this entry point is new (not already in library)
  final bool isNew;

  /// Whether this entry point needs to be updated (exists but modified)
  final bool needsUpdate;

  /// The library location containing this entry point
  final LibraryLocation? libraryLocation;

  /// Whether the discovery was successful
  bool get isSuccess => entryPoint != null && error == null;

  /// Whether the discovery failed
  bool get isError => error != null;
}

/// Service for discovering entry point files in library locations
class DiscoveryService {
  DiscoveryService(
    this._libraryLocationManager,
    this._entryPointFileService,
    this._libraryRepository, {
    TagRepository? tagRepository,
    ThumbnailExtractor? thumbnailExtractor,
  }) : _tagRepository = tagRepository,
       _thumbnailExtractor = thumbnailExtractor ?? ThumbnailExtractor();

  final LibraryLocationManager _libraryLocationManager;
  final EntryPointFileService _entryPointFileService;
  final LibraryRepository _libraryRepository;
  final TagRepository? _tagRepository;
  final ThumbnailExtractor _thumbnailExtractor;

  /// Create a tag name resolver that looks up or creates user tags.
  /// Only resolves non-collection, non-built-in tags.
  TagNameToIdResolver? _createTagNameResolver() {
    final repo = _tagRepository;
    if (repo == null) return null;
    return (String tagName) async {
      // Skip built-in tag names
      if (BuiltInTags.all.contains(tagName)) return null;
      // Try to find existing tag by name
      final existing = await repo.getTagByName(tagName);
      if (existing != null) {
        // Skip collections — we don't import playlist/queue/group membership
        if (existing.isCollection) return null;
        return existing.id;
      }
      // Create a new user tag
      try {
        final created = await repo.createTag(tagName);
        return created.id;
      } catch (_) {
        return null;
      }
    };
  }

  /// Scan all library locations for entry point files
  ///
  /// Returns a stream of DiscoveryResult for each found entry point file.
  /// Invalid files produce results with error messages.
  Stream<DiscoveryResult> scanAllLocations() async* {
    final locations = await _libraryLocationManager.getLocations();

    debugPrint(
      'DiscoveryService.scanAllLocations: ${locations.length} locations',
    );

    // Update PathResolver with current locations so relative paths
    // (@library/ prefixes) can be resolved during entry point parsing
    _entryPointFileService.updateLocations(locations);

    for (final location in locations) {
      debugPrint(
        'DiscoveryService.scanAllLocations: Scanning ${location.name} (${location.rootPath}) accessible=${location.isAccessible}',
      );
      if (!location.isAccessible) {
        debugPrint(
          'DiscoveryService.scanAllLocations: Skipping inaccessible location: ${location.name}',
        );
        continue;
      }

      yield* scanLocation(location);
    }
  }

  /// Scan a specific library location for entry point files
  ///
  /// Recursively finds all `beadline-*.json` files in the location.
  /// Returns a stream of DiscoveryResult for each found file.
  Stream<DiscoveryResult> scanLocation(LibraryLocation location) async* {
    final directory = Directory(location.rootPath);

    if (!directory.existsSync()) {
      return;
    }

    yield* _scanDirectory(directory, location);
  }

  /// Recursively scan a directory for entry point files
  Stream<DiscoveryResult> _scanDirectory(
    Directory directory,
    LibraryLocation location,
  ) async* {
    final foundEntryPoints = <String>{};
    // Collect directories seen during scan for the Android fallback
    final seenDirs = <String>{directory.path};
    // Collect visible filenames per directory for the Android probe fallback
    final visibleFilesByDir = <String, List<String>>{};
    try {
      var totalFiles = 0;
      var entryPointFiles = 0;
      await for (final entity in directory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          totalFiles++;
          final filename = p.basename(entity.path);
          final dir = p.dirname(entity.path);
          seenDirs.add(dir);
          visibleFilesByDir.putIfAbsent(dir, () => []).add(filename);

          // Check if this is an entry point file
          if (_isEntryPointFile(filename)) {
            entryPointFiles++;
            foundEntryPoints.add(p.normalize(entity.path));
            debugPrint(
              'DiscoveryService: Found entry point file: ${entity.path}',
            );
            yield await _processEntryPointFile(entity.path, location);
          }
        }
      }
      debugPrint(
        'DiscoveryService: Scanned ${directory.path} - $totalFiles files, $entryPointFiles entry points',
      );
    } catch (e) {
      debugPrint(
        'DiscoveryService: Error scanning directory ${directory.path}: $e',
      );
    }

    // On Android, Directory.list() may not return all files reliably.
    // Fallback: derive candidate entry point filenames from visible files
    // and probe with File.existsSync().
    if (Platform.isAndroid && foundEntryPoints.isEmpty) {
      yield* _probeEntryPointsAndroid(
        seenDirs,
        visibleFilesByDir,
        location,
        foundEntryPoints,
      );
    }
  }

  /// Android fallback: probe for entry point files by constructing candidate
  /// filenames from visible files in each directory.
  Stream<DiscoveryResult> _probeEntryPointsAndroid(
    Set<String> directories,
    Map<String, List<String>> visibleFilesByDir,
    LibraryLocation location,
    Set<String> alreadyFound,
  ) async* {
    debugPrint(
      'DiscoveryService: Android probe - checking ${directories.length} directories',
    );

    for (final dir in directories) {
      final visibleFiles = visibleFilesByDir[dir] ?? [];
      final candidateNames = <String>{};

      for (final filename in visibleFiles) {
        final nameWithoutExt = p.basenameWithoutExtension(filename);
        if (nameWithoutExt.isNotEmpty) {
          candidateNames.add(_entryPointFileService.sanitizeName(nameWithoutExt));
          candidateNames.add(nameWithoutExt);
        }
      }

      for (final name in candidateNames) {
        if (name.isEmpty) continue;
        for (final prefix in [
          EntryPointFile.filePrefix,
          EntryPointFile.legacyFilePrefix,
        ]) {
          final candidatePath = p.join(
            dir,
            '$prefix$name${EntryPointFile.fileExtension}',
          );
          final normalized = p.normalize(candidatePath);
          if (alreadyFound.contains(normalized)) continue;

          if (File(normalized).existsSync()) {
            debugPrint(
              'DiscoveryService: Android probe - found entry point: $normalized',
            );
            alreadyFound.add(normalized);
            final result = await _processEntryPointFile(normalized, location);
            yield result;
          }
        }
      }
    }
  }

  /// Check if a filename matches the entry point file pattern (current or legacy)
  bool _isEntryPointFile(String filename) {
    return (filename.startsWith(EntryPointFile.filePrefix) ||
            filename.startsWith(EntryPointFile.legacyFilePrefix)) &&
        filename.endsWith(EntryPointFile.fileExtension);
  }

  /// Process a single entry point file
  Future<DiscoveryResult> _processEntryPointFile(
    String filePath,
    LibraryLocation location,
  ) async {
    try {
      debugPrint('DiscoveryService: Processing entry point: $filePath');

      // Parse the entry point file
      final entryPoint = await _entryPointFileService.readEntryPoint(filePath);
      debugPrint(
        'DiscoveryService: Parsed entry point: ${entryPoint.name} (${entryPoint.songUnitId})',
      );

      // Check if already imported
      final existing = await _libraryRepository.getSongUnit(
        entryPoint.songUnitId,
      );
      final isNew = existing == null;
      debugPrint(
        'DiscoveryService: isNew=$isNew for ${entryPoint.name}',
      );

      // Check if update is needed by comparing content
      var needsUpdate = false;
      if (existing != null) {
        // Convert entry point to song unit for comparison
        final fromFile = await _entryPointFileService.toSongUnit(
          entryPoint,
          filePath,
          tagNameResolver: _createTagNameResolver(),
        );
        final fromFileWithLocation = fromFile.copyWith(
          libraryLocationId: location.id,
        );

        // Compare relevant fields to determine if update is needed
        needsUpdate = _songUnitNeedsUpdate(existing, fromFileWithLocation);
      }

      return DiscoveryResult(
        filePath: filePath,
        entryPoint: entryPoint,
        isNew: isNew,
        needsUpdate: needsUpdate,
        libraryLocation: location,
      );
    } on EntryPointValidationException catch (e) {
      debugPrint(
        'DiscoveryService: Validation error for $filePath: ${e.message}',
      );
      return DiscoveryResult(
        filePath: filePath,
        error: e.message,
        libraryLocation: location,
      );
    } catch (e, stackTrace) {
      debugPrint(
        'DiscoveryService: Error processing $filePath: $e',
      );
      debugPrint(
        'DiscoveryService: Stack trace: $stackTrace',
      );
      return DiscoveryResult(
        filePath: filePath,
        error: 'Failed to read entry point file: $e',
        libraryLocation: location,
      );
    }
  }

  /// Check if a song unit needs to be updated based on content comparison
  bool _songUnitNeedsUpdate(SongUnit existing, SongUnit fromFile) {
    // Compare metadata
    if (existing.metadata != fromFile.metadata) {
      return true;
    }

    // Compare sources
    if (existing.sources != fromFile.sources) {
      return true;
    }

    // Compare tags
    if (!_listEquals(existing.tagIds, fromFile.tagIds)) {
      return true;
    }

    // Compare preferences
    if (existing.preferences != fromFile.preferences) {
      return true;
    }

    // Compare library location
    if (existing.libraryLocationId != fromFile.libraryLocationId) {
      return true;
    }

    return false;
  }

  /// Compare two lists for equality
  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Check if a Song Unit with the given ID already exists in the library
  Future<bool> isAlreadyImported(String songUnitId) async {
    final existing = await _libraryRepository.getSongUnit(songUnitId);
    return existing != null;
  }

  /// Import a discovered entry point into the library
  ///
  /// Returns the imported SongUnit if successful.
  /// Skips import if the Song Unit already exists in the library.
  Future<SongUnit?> importEntryPoint(
    EntryPointFile entryPoint,
    String filePath,
  ) async {
    // Check if already imported
    if (await isAlreadyImported(entryPoint.songUnitId)) {
      return null;
    }

    // Convert to SongUnit
    final songUnit = await _entryPointFileService.toSongUnit(
      entryPoint,
      filePath,
      tagNameResolver: _createTagNameResolver(),
    );

    // Add to library
    await _libraryRepository.addSongUnit(songUnit);

    return songUnit;
  }

  /// Import all new entry points from discovery results
  ///
  /// Returns a list of successfully imported SongUnits.
  Future<List<SongUnit>> importAllNew(List<DiscoveryResult> results) async {
    final imported = <SongUnit>[];

    for (final result in results) {
      if (result.isSuccess && result.isNew && result.entryPoint != null) {
        final songUnit = await importEntryPoint(
          result.entryPoint!,
          result.filePath,
        );
        if (songUnit != null) {
          imported.add(songUnit);
        }
      }
    }

    return imported;
  }

  /// Update an existing song unit from an entry point file
  ///
  /// Returns the updated SongUnit if successful.
  Future<SongUnit?> updateFromEntryPoint(
    EntryPointFile entryPoint,
    String filePath,
  ) async {
    // Get existing song unit
    final existing = await _libraryRepository.getSongUnit(
      entryPoint.songUnitId,
    );
    if (existing == null) {
      return null;
    }

    // Convert entry point to song unit
    final updated = await _entryPointFileService.toSongUnit(
      entryPoint,
      filePath,
      tagNameResolver: _createTagNameResolver(),
    );

    // Update in library
    await _libraryRepository.updateSongUnit(updated);

    return updated;
  }

  /// Sync all entry points - import new ones and update existing ones
  ///
  /// This performs a one-way sync:
  /// 1. Scans all library locations for entry point files
  /// 2. Imports new entry points that don't exist in the database
  /// 3. Updates existing song units from their entry point files
  ///
  /// Deletion of song units whose entry point files are removed is handled
  /// by the file watcher in real time, not during sync. This prevents
  /// accidental data loss when locations are temporarily inaccessible.
  ///
  /// Returns a SyncResult with counts of imported and updated song units.
  Future<SyncResult> syncAll({
    void Function(int current, int total, String message)? onProgress,
  }) async {
    // Step 1: Scan all library locations and collect results
    final results = await collectResults(scanAllLocations());

    debugPrint(
      'DiscoveryService.syncAll: Found ${results.length} entry point files',
    );

    final totalOperations = results.length;
    var current = 0;
    var imported = 0;
    var updated = 0;
    var errors = 0;

    // Step 2: Process discovered entry points (import new, update existing)
    for (final result in results) {
      current++;

      if (!result.isSuccess || result.entryPoint == null) {
        errors++;
        debugPrint(
          'DiscoveryService.syncAll: Error result for ${result.filePath}: ${result.error}',
        );
        onProgress?.call(
          current,
          totalOperations,
          'Error: ${result.error ?? "Unknown"}',
        );
        continue;
      }

      final entryPoint = result.entryPoint!;
      debugPrint(
        'DiscoveryService.syncAll: Processing ${entryPoint.name} (isNew=${result.isNew}, needsUpdate=${result.needsUpdate})',
      );
      onProgress?.call(
        current,
        totalOperations,
        'Processing: ${entryPoint.name}',
      );

      if (result.isNew) {
        // Import new entry point
        try {
          final songUnit = await _importEntryPointWithLocation(
            entryPoint,
            result.filePath,
            result.libraryLocation,
          );
          if (songUnit != null) {
            imported++;
            debugPrint(
              'DiscoveryService.syncAll: Imported ${entryPoint.name}',
            );
          } else {
            debugPrint(
              'DiscoveryService.syncAll: Import returned null for ${entryPoint.name} (already exists?)',
            );
          }
        } catch (e, stackTrace) {
          errors++;
          debugPrint(
            'DiscoveryService.syncAll: Failed to import ${entryPoint.name}: $e',
          );
          debugPrint(
            'DiscoveryService.syncAll: Import stack trace: $stackTrace',
          );
        }
      } else if (result.needsUpdate) {
        // Update existing entry point
        try {
          final songUnit = await _updateFromEntryPointWithLocation(
            entryPoint,
            result.filePath,
            result.libraryLocation,
          );
          if (songUnit != null) {
            updated++;
          }
        } catch (e, stackTrace) {
          errors++;
          debugPrint(
            'DiscoveryService.syncAll: Failed to update ${entryPoint.name}: $e',
          );
          debugPrint(
            'DiscoveryService.syncAll: Update stack trace: $stackTrace',
          );
        }
      }
    }

    onProgress?.call(totalOperations, totalOperations, 'Sync complete');

    // Build path to song unit ID mapping for deletion tracking
    final pathMapping = <String, String>{};
    for (final result in results) {
      if (result.isSuccess && result.entryPoint != null) {
        pathMapping[result.filePath] = result.entryPoint!.songUnitId;
      }
    }

    final syncResult = SyncResult(
      total: totalOperations,
      imported: imported,
      updated: updated,
      deleted: 0,
      errors: errors,
      pathToSongUnitId: pathMapping,
    );
    debugPrint('DiscoveryService.syncAll: $syncResult');

    // Re-extract thumbnails for units with missing or invalid thumbnail IDs.
    try {
      final allUnits = await _libraryRepository.getAllSongUnits();
      final referencedHashes = allUnits
          .map((u) => u.metadata.thumbnailSourceId)
          .whereType<String>()
          .where((id) => id.length == 64)
          .toSet();

      final missingHashes = await ThumbnailCache.instance.findMissingEntries(
        referencedHashes,
      );

      // Units that need re-extraction: missing cache file OR invalid (non-64-char) ID
      final needsReExtraction = allUnits.where((u) {
        final id = u.metadata.thumbnailSourceId;
        if (id == null) return true;
        if (id.length != 64) return true;
        if (missingHashes.contains(id)) return true;
        return false;
      }).toList();

      if (needsReExtraction.isNotEmpty) {
        if (needsReExtraction.length > 50) {
          debugPrint(
            'DiscoveryService.syncAll: Deferring thumbnail re-extraction for ${needsReExtraction.length} units (too many for startup)',
          );
        } else {
        debugPrint(
          'DiscoveryService.syncAll: Re-extracting thumbnails for ${needsReExtraction.length} units',
        );
        for (var i = 0; i < needsReExtraction.length; i++) {
          final unit = needsReExtraction[i];
          try {
            final updated = await _extractThumbnailForSongUnit(unit);
            if (updated.metadata.thumbnailSourceId != unit.metadata.thumbnailSourceId) {
              await _libraryRepository.updateSongUnit(updated);
            }
          } catch (e) {
            debugPrint('DiscoveryService.syncAll: thumbnail re-extraction failed for ${unit.metadata.title}: $e');
          }
          // Yield to the event loop every 5 units so the UI stays responsive
          if (i % 5 == 4) {
            await Future<void>.delayed(Duration.zero);
          }
        }
        }
      }
    } catch (e) {
      debugPrint(
        'DiscoveryService.syncAll: thumbnail re-extraction pass failed: $e',
      );
    }

    // Purge orphaned thumbnails after sync
    try {
      final allUnits = await _libraryRepository.getAllSongUnits();
      final referencedHashes = allUnits
          .map((u) => u.metadata.thumbnailSourceId)
          .whereType<String>()
          .where((id) => id.length == 64)
          .toSet();
      await ThumbnailCache.instance.purgeOrphans(referencedHashes);
    } catch (e) {
      debugPrint('DiscoveryService.syncAll: purge orphans failed: $e');
    }

    return syncResult;
  }

  /// Import an entry point with library location association
  Future<SongUnit?> _importEntryPointWithLocation(
    EntryPointFile entryPoint,
    String filePath,
    LibraryLocation? libraryLocation,
  ) async {
    debugPrint(
      'DiscoveryService._importEntryPointWithLocation: ${entryPoint.name} from $filePath',
    );

    // Check if already imported
    if (await isAlreadyImported(entryPoint.songUnitId)) {
      debugPrint(
        'DiscoveryService._importEntryPointWithLocation: Already imported ${entryPoint.songUnitId}',
      );
      return null;
    }

    // Convert to SongUnit with library location
    debugPrint(
      'DiscoveryService._importEntryPointWithLocation: Converting to SongUnit...',
    );
    var songUnit = await _entryPointFileService.toSongUnit(
      entryPoint,
      filePath,
      tagNameResolver: _createTagNameResolver(),
    );
    debugPrint(
      'DiscoveryService._importEntryPointWithLocation: Converted, ${songUnit.sources.getAllSources().length} sources',
    );
    if (libraryLocation != null) {
      songUnit = songUnit.copyWith(libraryLocationId: libraryLocation.id);
    }

    // Extract thumbnail from audio sources if not already set
    songUnit = await _extractThumbnailForSongUnit(songUnit);

    // Add to library
    debugPrint(
      'DiscoveryService._importEntryPointWithLocation: Adding to library...',
    );
    await _libraryRepository.addSongUnit(songUnit);
    debugPrint(
      'DiscoveryService._importEntryPointWithLocation: Added ${entryPoint.name} to library',
    );

    return songUnit;
  }

  /// Update an entry point with library location association
  Future<SongUnit?> _updateFromEntryPointWithLocation(
    EntryPointFile entryPoint,
    String filePath,
    LibraryLocation? libraryLocation,
  ) async {
    // Get existing song unit
    final existing = await _libraryRepository.getSongUnit(
      entryPoint.songUnitId,
    );
    if (existing == null) {
      return null;
    }

    // Convert entry point to song unit with library location
    var updated = await _entryPointFileService.toSongUnit(
      entryPoint,
      filePath,
      tagNameResolver: _createTagNameResolver(),
    );
    if (libraryLocation != null) {
      updated = updated.copyWith(libraryLocationId: libraryLocation.id);
    }

    // Extract thumbnail if not already set or if existing ID is not a valid content hash
    final existingThumbId = updated.metadata.thumbnailSourceId;
    if (existingThumbId == null || existingThumbId.length != 64) {
      updated = await _extractThumbnailForSongUnit(updated);
    }

    // Update in library
    await _libraryRepository.updateSongUnit(updated);

    return updated;
  }

  /// Extract thumbnail from a song unit's audio sources and cache it.
  /// If thumbnailSourceId is already a valid 64-char content hash and the
  /// file exists, skips extraction. Otherwise tries each audio source with
  /// a local file origin and stores the returned content hash.
  Future<SongUnit> _extractThumbnailForSongUnit(SongUnit songUnit) async {
    // If already has a valid content hash and the file exists, skip
    final existingId = songUnit.metadata.thumbnailSourceId;
    if (existingId != null && existingId.length == 64) {
      final cached = await ThumbnailCache.instance.getThumbnail(existingId);
      if (cached != null) return songUnit;
    }

    // Try to extract from audio sources (local files only)
    for (final source in songUnit.sources.audioSources) {
      if (source.origin is! LocalFileOrigin) continue;
      final filePath = (source.origin as LocalFileOrigin).path;
      if (!File(filePath).existsSync()) continue;

      try {
        final artworkBytes = await _thumbnailExtractor
            .extractThumbnailBytes(filePath)
            .timeout(const Duration(seconds: 5), onTimeout: () => null);

        if (artworkBytes != null && artworkBytes.isNotEmpty) {
          final hash = await ThumbnailCache.instance.cacheFromBytes(artworkBytes);
          debugPrint(
            'DiscoveryService: Cached thumbnail for ${songUnit.metadata.title} (hash: ${hash.substring(0, 8)}...)',
          );
          return songUnit.copyWith(
            metadata: songUnit.metadata.copyWith(thumbnailSourceId: hash),
          );
        }
      } catch (e) {
        debugPrint(
          'DiscoveryService: Failed to extract thumbnail from ${p.basename(filePath)}: $e',
        );
      }
    }

    return songUnit;
  }

  /// Collect all discovery results from a stream
  Future<List<DiscoveryResult>> collectResults(Stream<DiscoveryResult> stream) {
    return stream.toList();
  }

  /// Get summary statistics from discovery results
  DiscoverySummary summarize(List<DiscoveryResult> results) {
    final total = results.length;
    var successful = 0;
    var newCount = 0;
    var existing = 0;
    var errors = 0;

    for (final result in results) {
      if (result.isSuccess) {
        successful++;
        if (result.isNew) {
          newCount++;
        } else {
          existing++;
        }
      } else {
        errors++;
      }
    }

    return DiscoverySummary(
      total: total,
      successful: successful,
      newCount: newCount,
      existing: existing,
      errors: errors,
    );
  }
}

/// Summary statistics from a discovery scan
class DiscoverySummary {
  const DiscoverySummary({
    required this.total,
    required this.successful,
    required this.newCount,
    required this.existing,
    required this.errors,
  });

  /// Total number of entry point files found
  final int total;

  /// Number of successfully parsed entry points
  final int successful;

  /// Number of new entry points (not in library)
  final int newCount;

  /// Number of existing entry points (already in library)
  final int existing;

  /// Number of files that failed to parse
  final int errors;

  @override
  String toString() {
    return 'DiscoverySummary(total: $total, successful: $successful, '
        'new: $newCount, existing: $existing, errors: $errors)';
  }
}

/// Result of a sync operation
class SyncResult {
  const SyncResult({
    required this.total,
    required this.imported,
    required this.updated,
    required this.deleted,
    required this.errors,
    this.pathToSongUnitId = const {},
  });

  /// Total number of operations performed
  final int total;

  /// Number of new song units imported
  final int imported;

  /// Number of existing song units updated
  final int updated;

  /// Number of song units deleted (entry point file no longer exists)
  final int deleted;

  /// Number of operations that failed
  final int errors;

  /// Mapping of entry point file paths to song unit IDs (for deletion tracking)
  final Map<String, String> pathToSongUnitId;

  /// Whether any changes were made
  bool get hasChanges => imported > 0 || updated > 0 || deleted > 0;

  @override
  String toString() {
    return 'SyncResult(total: $total, imported: $imported, '
        'updated: $updated, deleted: $deleted, errors: $errors)';
  }
}
