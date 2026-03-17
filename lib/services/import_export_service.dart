import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import '../data/file_system_service.dart';
import '../models/library_location.dart';
import '../models/song_unit.dart';
import '../models/source_collection.dart';
import '../models/source_origin.dart';
import '../repositories/library_repository.dart';
import '../services/thumbnail_cache.dart';
import 'path_resolver.dart';

/// Progress callback for import/export operations
typedef ProgressCallback =
    void Function(int current, int total, String message);

/// Result of an import operation
class ImportResult {
  const ImportResult({
    required this.imported,
    required this.skipped,
    required this.errors,
  });
  final List<SongUnit> imported;
  final List<SongUnit> skipped;
  final List<ImportError> errors;

  bool get hasErrors => errors.isNotEmpty;
  int get totalProcessed => imported.length + skipped.length + errors.length;
}

/// Error during import
class ImportError {
  const ImportError({required this.fileName, required this.message});
  final String fileName;
  final String message;

  @override
  String toString() => 'ImportError($fileName): $message';
}

/// Metadata for batch exports
class BatchExportMeta {
  const BatchExportMeta({
    required this.version,
    required this.createdAt,
    required this.count,
  });

  factory BatchExportMeta.fromJson(Map<String, dynamic> json) {
    return BatchExportMeta(
      version: json['version'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      count: json['count'] as int,
    );
  }
  final String version;
  final DateTime createdAt;
  final int count;

  Map<String, dynamic> toJson() => {
    'version': version,
    'createdAt': createdAt.toIso8601String(),
    'count': count,
  };
}

/// Data for export isolate
class _ExportData {
  _ExportData({
    required this.songUnitsJson,
    required this.sourceFiles,
    required this.outputPath,
    this.customThumbnails,
  });
  final List<Map<String, dynamic>> songUnitsJson;
  final Map<String, List<int>> sourceFiles; // path -> bytes
  final String outputPath;
  final Map<String, List<int>>? customThumbnails; // thumbnailId -> bytes
}

/// Result from export isolate
class _ExportResult {
  _ExportResult({required this.success, this.error});
  final bool success;
  final String? error;
}

/// Service for importing and exporting Song Units
class ImportExportService {
  ImportExportService(
    this._libraryRepository,
    this._fileSystem, {
    List<LibraryLocation> libraryLocations = const [],
  }) : _libraryLocations = libraryLocations;
  final LibraryRepository _libraryRepository;
  final FileSystemService _fileSystem;
  final List<LibraryLocation> _libraryLocations;
  final Uuid _uuid = const Uuid();

  /// Warnings generated during export/import operations
  /// These are logged when paths cannot be made relative
  final List<String> _warnings = [];

  static const String _exportVersion = '1.0.0';
  static const String _songUnitJsonFile = 'song-unit.json';
  static const String _metaJsonFile = 'meta.json';
  static const String _sourcesDir = 'sources';

  /// Get warnings from the last operation
  List<String> get warnings => List.unmodifiable(_warnings);

  /// Clear warnings
  void clearWarnings() => _warnings.clear();

  /// Create a PathResolver with current library locations
  PathResolver _createPathResolver() => PathResolver(_libraryLocations);

  /// Export a single Song Unit to a ZIP file
  /// Returns the path to the created ZIP file
  /// If [outputPath] is provided, exports to that path; otherwise uses default exports directory
  /// If [entryPointPath] is provided, paths are made relative to that location
  ///
  /// The ZIP contains:
  /// - song-unit.json: Song Unit data (metadata, sources, tags, preferences)
  /// - sources/: Directory containing local source files
  /// - beadline/thumbnails/: Custom thumbnails (if any)
  Future<File> exportSongUnit(
    SongUnit songUnit, {
    ProgressCallback? onProgress,
    String? outputPath,
    String? entryPointPath,
  }) async {
    _warnings.clear();
    onProgress?.call(0, 1, 'Preparing ${songUnit.metadata.title}...');

    // Convert paths to relative if entryPointPath is provided
    final songUnitForExport = entryPointPath != null
        ? _convertToRelativePaths(songUnit, entryPointPath)
        : songUnit;

    // Collect source files on main thread
    final sourceFiles = <String, List<int>>{};
    for (final source in songUnit.sources.getAllSources()) {
      if (source.origin is LocalFileOrigin) {
        final localOrigin = source.origin as LocalFileOrigin;
        final filePath = localOrigin.path;
        if (await _fileSystem.fileExists(filePath)) {
          sourceFiles[filePath] = await _fileSystem.readFileAsBytes(filePath);
        }
      }
    }

    // Collect custom thumbnail if present
    Map<String, List<int>>? customThumbnails;
    if (songUnit.metadata.thumbnailSourceId != null &&
        songUnit.metadata.thumbnailSourceId!.startsWith('custom_')) {
      final thumbnailPath = await ThumbnailCache.instance.getThumbnail(
        songUnit.metadata.thumbnailSourceId!,
      );
      if (thumbnailPath != null) {
        final thumbnailFile = File(thumbnailPath);
        if (thumbnailFile.existsSync()) {
          customThumbnails = {
            songUnit.metadata.thumbnailSourceId!: await thumbnailFile
                .readAsBytes(),
          };
        }
      }
    }

    // Determine output path
    final sanitizedTitle = _sanitizeFileName(songUnit.metadata.title);
    final fileName = '${sanitizedTitle}_${songUnit.id.substring(0, 8)}.zip';
    String filePath;
    if (outputPath != null) {
      filePath = outputPath.endsWith('.zip')
          ? outputPath
          : path.join(outputPath, fileName);
    } else {
      final exportsDir = await _fileSystem.getExportsDirectory();
      filePath = path.join(exportsDir.path, fileName);
    }

    // Run heavy ZIP encoding in isolate
    // Deep serialize to ensure all data is primitive types (no streams/objects)
    final songUnitJson =
        jsonDecode(jsonEncode(songUnitForExport.toJson()))
            as Map<String, dynamic>;

    final exportData = _ExportData(
      songUnitsJson: [songUnitJson],
      sourceFiles: sourceFiles,
      outputPath: filePath,
      customThumbnails: customThumbnails,
    );

    final result = await Isolate.run(() => _encodeAndWriteZip(exportData));

    if (!result.success) {
      throw Exception(result.error ?? 'Export failed');
    }

    onProgress?.call(1, 1, 'Exported ${songUnit.metadata.title}');
    return File(filePath);
  }

  /// Export multiple Song Units to a batch ZIP file
  /// Returns the path to the created ZIP file
  /// If [outputPath] is provided, exports to that path; otherwise uses default exports directory
  /// If [entryPointPath] is provided, paths are made relative to that location
  ///
  /// The ZIP contains:
  /// - meta.json: Batch metadata (version, createdAt, count)
  /// - Individual Song Unit ZIPs
  Future<File> exportSongUnits(
    List<SongUnit> songUnits, {
    ProgressCallback? onProgress,
    String? outputPath,
    String? entryPointPath,
  }) async {
    if (songUnits.isEmpty) {
      throw ArgumentError('Cannot export empty list of Song Units');
    }

    if (songUnits.length == 1) {
      return exportSongUnit(
        songUnits.first,
        onProgress: onProgress,
        outputPath: outputPath,
        entryPointPath: entryPointPath,
      );
    }

    _warnings.clear();
    final total = songUnits.length;

    // Convert paths to relative if entryPointPath is provided
    final songUnitsForExport = entryPointPath != null
        ? songUnits
              .map((su) => _convertToRelativePaths(su, entryPointPath))
              .toList()
        : songUnits;

    // Collect all source files on main thread
    final allSourceFiles = <String, List<int>>{};
    for (var i = 0; i < songUnits.length; i++) {
      final songUnit = songUnits[i];
      onProgress?.call(i, total, 'Reading ${songUnit.metadata.title}...');

      for (final source in songUnit.sources.getAllSources()) {
        if (source.origin is LocalFileOrigin) {
          final localOrigin = source.origin as LocalFileOrigin;
          final filePath = localOrigin.path;
          if (!allSourceFiles.containsKey(filePath) &&
              await _fileSystem.fileExists(filePath)) {
            allSourceFiles[filePath] = await _fileSystem.readFileAsBytes(
              filePath,
            );
          }
        }
      }
      // Yield to allow UI updates
      await Future.delayed(Duration.zero);
    }

    onProgress?.call(total, total, 'Creating archive...');

    // Determine output path
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'batch_export_$timestamp.zip';
    String filePath;
    if (outputPath != null) {
      filePath = outputPath.endsWith('.zip')
          ? outputPath
          : path.join(outputPath, fileName);
    } else {
      final exportsDir = await _fileSystem.getExportsDirectory();
      filePath = path.join(exportsDir.path, fileName);
    }

    // Run heavy ZIP encoding in isolate
    // Deep serialize to ensure all data is primitive types (no streams/objects)
    // We need to fully serialize everything before passing to isolate
    final songUnitsJson = <Map<String, dynamic>>[];
    for (final songUnit in songUnitsForExport) {
      // Double encode/decode to ensure complete serialization
      final jsonString = jsonEncode(songUnit.toJson());
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      songUnitsJson.add(jsonMap);
    }

    // Also ensure sourceFiles map is fully serialized (keys must be plain strings)
    final serializedSourceFiles = <String, List<int>>{};
    for (final entry in allSourceFiles.entries) {
      serializedSourceFiles[entry.key.toString()] = List<int>.from(entry.value);
    }

    final exportData = _ExportData(
      songUnitsJson: songUnitsJson,
      sourceFiles: serializedSourceFiles,
      outputPath: filePath.toString(),
    );

    final result = await Isolate.run(() => _encodeBatchZip(exportData));

    if (!result.success) {
      throw Exception(result.error ?? 'Export failed');
    }

    onProgress?.call(total, total, 'Export complete');
    return File(filePath);
  }

  /// Encode single song unit ZIP in isolate
  static _ExportResult _encodeAndWriteZip(_ExportData data) {
    try {
      final archive = Archive();
      final songUnitJson = data.songUnitsJson.first;

      // Add song-unit.json
      final jsonBytes = utf8.encode(jsonEncode(songUnitJson));
      archive.addFile(
        ArchiveFile(_songUnitJsonFile, jsonBytes.length, jsonBytes),
      );

      // Add source files
      for (final entry in data.sourceFiles.entries) {
        final fileName = path.basename(entry.key);
        archive.addFile(
          ArchiveFile(
            '$_sourcesDir/$fileName',
            entry.value.length,
            entry.value,
          ),
        );
      }

      // Add custom thumbnails to beadline/thumbnails/
      if (data.customThumbnails != null) {
        for (final entry in data.customThumbnails!.entries) {
          final thumbnailId = entry.key;
          final bytes = entry.value;
          // Determine file extension (default to .jpg)
          const ext = '.jpg';
          archive.addFile(
            ArchiveFile(
              'beadline/thumbnails/$thumbnailId$ext',
              bytes.length,
              bytes,
            ),
          );
        }
      }

      // Encode
      final zipData = ZipEncoder().encode(archive);

      // Write
      File(data.outputPath).writeAsBytesSync(zipData);
      return _ExportResult(success: true);
    } catch (e) {
      return _ExportResult(success: false, error: e.toString());
    }
  }

  /// Encode batch ZIP in isolate
  static _ExportResult _encodeBatchZip(_ExportData data) {
    try {
      final archive = Archive();

      // Add meta.json
      final meta = BatchExportMeta(
        version: _exportVersion,
        createdAt: DateTime.now().toUtc(),
        count: data.songUnitsJson.length,
      );
      final metaBytes = utf8.encode(jsonEncode(meta.toJson()));
      archive.addFile(ArchiveFile(_metaJsonFile, metaBytes.length, metaBytes));

      // Add individual song unit ZIPs
      for (var i = 0; i < data.songUnitsJson.length; i++) {
        final songUnitJson = data.songUnitsJson[i];
        final innerArchive = Archive();

        // Add song-unit.json
        final jsonBytes = utf8.encode(jsonEncode(songUnitJson));
        innerArchive.addFile(
          ArchiveFile(_songUnitJsonFile, jsonBytes.length, jsonBytes),
        );

        // Add source files for this song unit
        final sources = songUnitJson['sources'] as Map<String, dynamic>?;
        if (sources != null) {
          _addSourceFilesToArchive(innerArchive, sources, data.sourceFiles);
        }

        // Encode inner archive
        final innerZipData = ZipEncoder().encode(innerArchive);

        // Add to outer archive
        final title =
            (songUnitJson['metadata'] as Map?)?['title'] ?? 'untitled';
        final id = songUnitJson['id'] as String? ?? '';
        final sanitizedTitle = _sanitizeFileNameStatic(title.toString());
        final innerFileName =
            '${i + 1}_${sanitizedTitle}_${id.length >= 8 ? id.substring(0, 8) : id}.zip';
        archive.addFile(
          ArchiveFile(innerFileName, innerZipData.length, innerZipData),
        );
      }

      // Encode batch archive
      final zipData = ZipEncoder().encode(archive);

      // Write
      File(data.outputPath).writeAsBytesSync(zipData);
      return _ExportResult(success: true);
    } catch (e) {
      return _ExportResult(success: false, error: e.toString());
    }
  }

  static void _addSourceFilesToArchive(
    Archive archive,
    Map<String, dynamic> sources,
    Map<String, List<int>> sourceFiles,
  ) {
    void addFromList(List? sourceList) {
      if (sourceList == null) return;
      for (final source in sourceList) {
        final origin = source['origin'] as Map<String, dynamic>?;
        if (origin?['type'] == 'localFile') {
          final filePath = origin?['path'] as String?;
          if (filePath != null && sourceFiles.containsKey(filePath)) {
            final fileName = path.basename(filePath);
            final bytes = sourceFiles[filePath]!;
            archive.addFile(
              ArchiveFile('$_sourcesDir/$fileName', bytes.length, bytes),
            );
          }
        }
      }
    }

    addFromList(sources['displaySources'] as List?);
    addFromList(sources['audioSources'] as List?);
    addFromList(sources['accompanimentSources'] as List?);
    addFromList(sources['hoverSources'] as List?);
  }

  static String _sanitizeFileNameStatic(String name) {
    if (name.isEmpty) return 'untitled';
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
  }

  /// Import Song Units from a ZIP file
  /// Automatically detects single vs batch format
  /// Uses hash-based deduplication to skip existing Song Units
  /// If [entryPointPath] is provided, relative paths are resolved against that location
  Future<ImportResult> importFromZip(
    File zipFile, {
    ProgressCallback? onProgress,
    String? entryPointPath,
  }) async {
    _warnings.clear();
    onProgress?.call(0, 1, 'Reading archive...');

    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // Detect format: batch if meta.json exists, single otherwise
    final isBatch = archive.files.any((f) => f.name == _metaJsonFile);

    if (isBatch) {
      return _importBatch(
        archive,
        onProgress: onProgress,
        entryPointPath: entryPointPath,
      );
    } else {
      return _importSingle(
        archive,
        onProgress: onProgress,
        entryPointPath: entryPointPath,
      );
    }
  }

  /// Import a single Song Unit from an archive
  Future<ImportResult> _importSingle(
    Archive archive, {
    ProgressCallback? onProgress,
    String? entryPointPath,
  }) async {
    final imported = <SongUnit>[];
    final skipped = <SongUnit>[];
    final errors = <ImportError>[];

    try {
      onProgress?.call(0, 1, 'Importing song unit...');

      final songUnit = await _extractSongUnit(
        archive,
        '',
        entryPointPath: entryPointPath,
      );
      if (songUnit != null) {
        // Check for duplicates using hash
        final hash = songUnit.calculateHash();
        final exists = await _libraryRepository.existsByHash(hash);

        if (exists) {
          skipped.add(songUnit);
        } else {
          // Generate new ID for imported Song Unit
          final newSongUnit = songUnit.copyWith(id: _uuid.v4());
          await _libraryRepository.addSongUnit(newSongUnit);
          imported.add(newSongUnit);
        }
      }
      onProgress?.call(1, 1, 'Import complete');
    } catch (e) {
      errors.add(ImportError(fileName: 'archive', message: e.toString()));
    }

    return ImportResult(imported: imported, skipped: skipped, errors: errors);
  }

  /// Import multiple Song Units from a batch archive
  Future<ImportResult> _importBatch(
    Archive archive, {
    ProgressCallback? onProgress,
    String? entryPointPath,
  }) async {
    final imported = <SongUnit>[];
    final skipped = <SongUnit>[];
    final errors = <ImportError>[];

    // Find all inner ZIP files (exclude meta.json)
    final innerZips = archive.files
        .where((f) => f.name.endsWith('.zip') && f.isFile)
        .toList();

    final total = innerZips.length;

    for (var i = 0; i < innerZips.length; i++) {
      final innerZipFile = innerZips[i];
      onProgress?.call(i, total, 'Importing ${innerZipFile.name}...');

      try {
        final innerArchive = ZipDecoder().decodeBytes(innerZipFile.content);
        final songUnit = await _extractSongUnit(
          innerArchive,
          innerZipFile.name,
          entryPointPath: entryPointPath,
        );

        if (songUnit != null) {
          // Check for duplicates using hash
          final hash = songUnit.calculateHash();
          final exists = await _libraryRepository.existsByHash(hash);

          if (exists) {
            skipped.add(songUnit);
          } else {
            // Generate new ID for imported Song Unit
            final newSongUnit = songUnit.copyWith(id: _uuid.v4());
            await _libraryRepository.addSongUnit(newSongUnit);
            imported.add(newSongUnit);
          }
        }
      } catch (e) {
        errors.add(
          ImportError(fileName: innerZipFile.name, message: e.toString()),
        );
      }
    }

    onProgress?.call(total, total, 'Import complete');

    return ImportResult(imported: imported, skipped: skipped, errors: errors);
  }

  /// Extract a Song Unit from an archive
  /// If [entryPointPath] is provided, relative paths are resolved against that location
  Future<SongUnit?> _extractSongUnit(
    Archive archive,
    String context, {
    String? entryPointPath,
  }) async {
    // Find song-unit.json
    final jsonFile = archive.files.firstWhere(
      (f) =>
          f.name == _songUnitJsonFile || f.name.endsWith('/$_songUnitJsonFile'),
      orElse: () => throw Exception('song-unit.json not found in $context'),
    );

    final jsonString = utf8.decode(jsonFile.content);
    final json = jsonDecode(jsonString) as Map<String, dynamic>;

    // Parse the Song Unit
    var songUnit = SongUnit.fromJson(json);

    // Resolve relative paths if entryPointPath is provided
    if (entryPointPath != null) {
      songUnit = _resolveRelativePaths(songUnit, entryPointPath);
    }

    // Extract and save local source files
    await _extractSourceFiles(archive, songUnit);

    return songUnit;
  }

  /// Extract source files from archive and save to library
  /// Also extracts custom thumbnails from beadline/thumbnails/
  Future<void> _extractSourceFiles(Archive archive, SongUnit songUnit) async {
    final sourcesDir = await _fileSystem.getSongUnitSourcesDirectory(
      songUnit.id,
    );

    for (final source in songUnit.sources.getAllSources()) {
      if (source.origin is LocalFileOrigin) {
        final localOrigin = source.origin as LocalFileOrigin;
        final fileName = path.basename(localOrigin.path);

        // Look for the file in the archive
        final sourceFile = archive.files.firstWhere(
          (f) => f.name.endsWith(fileName) && f.isFile,
          orElse: () => ArchiveFile('', 0, []),
        );

        if (sourceFile.size > 0) {
          final destPath = path.join(sourcesDir.path, fileName);
          await _fileSystem.writeFileAsBytes(destPath, sourceFile.content);
        }
      }
    }

    // Extract custom thumbnails from .beadline/thumbnails/
    if (songUnit.metadata.thumbnailSourceId != null &&
        songUnit.metadata.thumbnailSourceId!.startsWith('custom_')) {
      final thumbnailId = songUnit.metadata.thumbnailSourceId!;

      // Look for the thumbnail in beadline/thumbnails/
      final thumbnailFile = archive.files.firstWhere(
        (f) =>
            f.name.startsWith('beadline/thumbnails/$thumbnailId') && f.isFile,
        orElse: () => ArchiveFile('', 0, []),
      );

      if (thumbnailFile.size > 0) {
        // Cache the custom thumbnail
        await ThumbnailCache.instance.cacheFromBytes(
          thumbnailFile.content as List<int>,
        );
      }
    }
  }

  /// Sanitize a file name by removing invalid characters
  String _sanitizeFileName(String name) {
    if (name.isEmpty) return 'untitled';

    // Replace invalid characters with underscores
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
  }

  /// Convert absolute paths in a Song Unit to relative paths for export
  /// Uses PathResolver to convert paths relative to the entry point location
  /// Paths outside storage locations are preserved as absolute with a warning
  SongUnit _convertToRelativePaths(SongUnit songUnit, String entryPointPath) {
    final pathResolver = _createPathResolver();

    // Convert display sources
    final displaySources = songUnit.sources.displaySources.map((source) {
      if (source.origin is LocalFileOrigin) {
        final localOrigin = source.origin as LocalFileOrigin;
        final relativePath = pathResolver.toSerializablePath(
          localOrigin.path,
          entryPointPath,
        );

        // Log warning if path couldn't be made relative
        if (path.isAbsolute(relativePath) && _libraryLocations.isNotEmpty) {
          _warnings.add(
            'Path outside library locations preserved as absolute: ${localOrigin.path}',
          );
        }

        return source.copyWith(origin: LocalFileOrigin(relativePath));
      }
      return source;
    }).toList();

    // Convert audio sources
    final audioSources = songUnit.sources.audioSources.map((source) {
      if (source.origin is LocalFileOrigin) {
        final localOrigin = source.origin as LocalFileOrigin;
        final relativePath = pathResolver.toSerializablePath(
          localOrigin.path,
          entryPointPath,
        );

        if (path.isAbsolute(relativePath) && _libraryLocations.isNotEmpty) {
          _warnings.add(
            'Path outside library locations preserved as absolute: ${localOrigin.path}',
          );
        }

        return source.copyWith(origin: LocalFileOrigin(relativePath));
      }
      return source;
    }).toList();

    // Convert accompaniment sources
    final accompanimentSources = songUnit.sources.accompanimentSources.map((
      source,
    ) {
      if (source.origin is LocalFileOrigin) {
        final localOrigin = source.origin as LocalFileOrigin;
        final relativePath = pathResolver.toSerializablePath(
          localOrigin.path,
          entryPointPath,
        );

        if (path.isAbsolute(relativePath) && _libraryLocations.isNotEmpty) {
          _warnings.add(
            'Path outside library locations preserved as absolute: ${localOrigin.path}',
          );
        }

        return source.copyWith(origin: LocalFileOrigin(relativePath));
      }
      return source;
    }).toList();

    // Convert hover sources
    final hoverSources = songUnit.sources.hoverSources.map((source) {
      if (source.origin is LocalFileOrigin) {
        final localOrigin = source.origin as LocalFileOrigin;
        final relativePath = pathResolver.toSerializablePath(
          localOrigin.path,
          entryPointPath,
        );

        if (path.isAbsolute(relativePath) && _libraryLocations.isNotEmpty) {
          _warnings.add(
            'Path outside library locations preserved as absolute: ${localOrigin.path}',
          );
        }

        return source.copyWith(origin: LocalFileOrigin(relativePath));
      }
      return source;
    }).toList();

    return songUnit.copyWith(
      sources: SourceCollection(
        displaySources: displaySources,
        audioSources: audioSources,
        accompanimentSources: accompanimentSources,
        hoverSources: hoverSources,
      ),
    );
  }

  /// Resolve relative paths in a Song Unit to absolute paths for import
  /// Uses PathResolver to resolve paths relative to the entry point location
  SongUnit _resolveRelativePaths(SongUnit songUnit, String entryPointPath) {
    final pathResolver = _createPathResolver();

    // Resolve display sources
    final displaySources = songUnit.sources.displaySources.map((source) {
      if (source.origin is LocalFileOrigin) {
        final localOrigin = source.origin as LocalFileOrigin;
        // Only resolve if it's a relative path
        if (!path.isAbsolute(localOrigin.path)) {
          final absolutePath = pathResolver.resolveFromEntryPoint(
            localOrigin.path,
            entryPointPath,
          );
          return source.copyWith(origin: LocalFileOrigin(absolutePath));
        }
      }
      return source;
    }).toList();

    // Resolve audio sources
    final audioSources = songUnit.sources.audioSources.map((source) {
      if (source.origin is LocalFileOrigin) {
        final localOrigin = source.origin as LocalFileOrigin;
        if (!path.isAbsolute(localOrigin.path)) {
          final absolutePath = pathResolver.resolveFromEntryPoint(
            localOrigin.path,
            entryPointPath,
          );
          return source.copyWith(origin: LocalFileOrigin(absolutePath));
        }
      }
      return source;
    }).toList();

    // Resolve accompaniment sources
    final accompanimentSources = songUnit.sources.accompanimentSources.map((
      source,
    ) {
      if (source.origin is LocalFileOrigin) {
        final localOrigin = source.origin as LocalFileOrigin;
        if (!path.isAbsolute(localOrigin.path)) {
          final absolutePath = pathResolver.resolveFromEntryPoint(
            localOrigin.path,
            entryPointPath,
          );
          return source.copyWith(origin: LocalFileOrigin(absolutePath));
        }
      }
      return source;
    }).toList();

    // Resolve hover sources
    final hoverSources = songUnit.sources.hoverSources.map((source) {
      if (source.origin is LocalFileOrigin) {
        final localOrigin = source.origin as LocalFileOrigin;
        if (!path.isAbsolute(localOrigin.path)) {
          final absolutePath = pathResolver.resolveFromEntryPoint(
            localOrigin.path,
            entryPointPath,
          );
          return source.copyWith(origin: LocalFileOrigin(absolutePath));
        }
      }
      return source;
    }).toList();

    return songUnit.copyWith(
      sources: SourceCollection(
        displaySources: displaySources,
        audioSources: audioSources,
        accompanimentSources: accompanimentSources,
        hoverSources: hoverSources,
      ),
    );
  }
}
