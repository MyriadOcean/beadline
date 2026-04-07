import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../core/di/service_locator.dart';
import '../models/configuration_mode.dart';
import '../models/library_item.dart';
import '../models/library_location.dart';
import '../models/song_unit.dart';
import '../models/source_collection.dart';
import '../models/source_origin.dart';
import '../repositories/library_repository.dart';
import '../repositories/tag_repository.dart';
import '../models/tag_extensions.dart';
import '../services/audio_discovery_service.dart';
import '../services/configuration_migration_service.dart';
import '../services/discovery_service.dart';
import '../services/entry_point_file_service.dart';
import '../services/file_system_watcher.dart';
import '../services/import_export_service.dart';
import '../services/library_location_manager.dart';
import '../services/source_auto_matcher.dart';
import '../src/rust/api/evaluator_api.dart' as rust_evaluator;

/// Progress state for import/export operations
class OperationProgress {
  const OperationProgress({
    required this.current,
    required this.total,
    required this.message,
  });
  final int current;
  final int total;
  final String message;

  double get progress => total > 0 ? current / total : 0;
}

/// Result of promoting a temporary Song Unit
class PromoteResult {
  const PromoteResult({
    required this.promoted,
    required this.success,
    this.discovered,
  });
  final SongUnit promoted;
  final bool success;
  final DiscoveredSources? discovered;
}

/// ViewModel for library management
/// Handles Song Unit CRUD operations and import/export
class LibraryViewModel extends ChangeNotifier {
  LibraryViewModel({
    required LibraryRepository libraryRepository,
    ImportExportService? importExportService,
    ConfigurationMigrationService? migrationService,
    DiscoveryService? discoveryService,
    FileSystemWatcher? fileSystemWatcher,
    EntryPointFileService? entryPointFileService,
    TagRepository? tagRepository,
  }) : _libraryRepository = libraryRepository,
       _importExportService = importExportService,
       _migrationService = migrationService,
       _discoveryService = discoveryService,
       _fileSystemWatcher = fileSystemWatcher,
       _entryPointFileService = entryPointFileService,
       _tagRepository = tagRepository {
    _setupListeners();
  }
  final LibraryRepository _libraryRepository;
  final ImportExportService? _importExportService;
  final ConfigurationMigrationService? _migrationService;
  final DiscoveryService? _discoveryService;
  final FileSystemWatcher? _fileSystemWatcher;
  final EntryPointFileService? _entryPointFileService;
  final TagRepository? _tagRepository;

  List<SongUnit> _songUnits = [];
  List<LibraryItem> _libraryItems = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription<LibraryEvent>? _eventSubscription;
  StreamSubscription<FileChangeEvent>? _fileWatcherSubscription;

  // Progress tracking for import/export
  OperationProgress? _operationProgress;
  bool _isOperationInProgress = false;

  // Track if initial sync has been done
  bool _hasInitialSync = false;

  // Map of entry point file paths to song unit IDs for deletion tracking
  final Map<String, String> _pathToSongUnitId = {};

  /// All Song Units in the library
  List<SongUnit> get songUnits => List.unmodifiable(_songUnits);

  /// All library items (wrapping Song Units)
  List<LibraryItem> get libraryItems => List.unmodifiable(_libraryItems);

  /// Whether the library is loading
  bool get isLoading => _isLoading;

  /// Error message if any
  String? get error => _error;

  /// Number of Song Units in the library
  int get count => _songUnits.length;

  /// Current operation progress (for import/export)
  OperationProgress? get operationProgress => _operationProgress;

  /// Whether an import/export operation is in progress
  bool get isOperationInProgress => _isOperationInProgress;

  void _setupListeners() {
    _eventSubscription = _libraryRepository.events.listen(
      _onLibraryEvent,
      onError: _onLibraryError,
    );

    // Set up file system watcher if available
    if (_fileSystemWatcher != null) {
      _fileWatcherSubscription = _fileSystemWatcher.events.listen(
        _onFileChange,
        onError: (error) => debugPrint('File watcher error: $error'),
      );
    }
  }

  /// Handle file system change events
  Future<void> _onFileChange(FileChangeEvent event) async {
    debugPrint('LibraryViewModel.FileChange: ${event.type} - ${event.path}');

    // Only process entry point files (beadline-*.json or legacy .beadline-*.json)
    final extension = p.extension(event.path).toLowerCase();
    final fileName = p.basename(event.path);
    final isEntryPointFile =
        extension == '.json' &&
        (fileName.startsWith('beadline-') ||
            fileName.startsWith('.beadline-'));

    if (!isEntryPointFile) {
      // Not an entry point file - ignore it
      // Audio files are handled by the file watcher in main.dart
      return;
    }

    try {
      switch (event.type) {
        case FileChangeType.created:
        case FileChangeType.modified:
          await _handleFileCreatedOrModified(event);
        case FileChangeType.deleted:
          await _handleFileDeleted(event);
      }
    } catch (e) {
      debugPrint('Error handling file change: $e');
    }
  }

  /// Create a tag name resolver for importing tags from entry point files.
  TagNameToIdResolver? _createTagNameResolver() {
    final repo = _tagRepository;
    if (repo == null) return null;
    return (String tagName) async {
      if (BuiltInTags.all.contains(tagName)) return null;
      final existing = await repo.getTagByName(tagName);
      if (existing != null) {
        if (existing.isCollection) return null;
        return existing.id;
      }
      try {
        final created = await repo.createTag(tagName);
        return created.id;
      } catch (_) {
        return null;
      }
    };
  }

  /// Handle file created or modified events
  Future<void> _handleFileCreatedOrModified(FileChangeEvent event) async {
    if (_entryPointFileService == null || _discoveryService == null) return;

    try {
      // Ensure PathResolver has current library locations so @library/ paths resolve
      try {
        final locationManager = getIt<LibraryLocationManager>();
        final locations = await locationManager.getLocations();
        _entryPointFileService.updateLocations(locations);
      } catch (e) {
        debugPrint('LibraryViewModel: Failed to update PathResolver locations: $e');
      }

      // Read the entry point file
      final entryPoint = await _entryPointFileService.readEntryPoint(
        event.path,
      );

      // Check if this song unit already exists
      final existing = await _libraryRepository.getSongUnit(
        entryPoint.songUnitId,
      );

      // Track the path to song unit ID mapping for deletion handling
      _pathToSongUnitId[event.path] = entryPoint.songUnitId;

      final tagResolver = _createTagNameResolver();

      if (existing == null) {
        // New song unit - import it
        var songUnit = await _entryPointFileService.toSongUnit(
          entryPoint,
          event.path,
          tagNameResolver: tagResolver,
        );
        if (event.libraryLocationId != null) {
          songUnit = songUnit.copyWith(
            libraryLocationId: event.libraryLocationId,
          );
        }
        await _libraryRepository.addSongUnit(songUnit);
        debugPrint('Imported new song unit: ${songUnit.metadata.title}');
      } else {
        // Existing song unit - check if it needs update
        var updated = await _entryPointFileService.toSongUnit(
          entryPoint,
          event.path,
          tagNameResolver: tagResolver,
        );
        if (event.libraryLocationId != null) {
          updated = updated.copyWith(
            libraryLocationId: event.libraryLocationId,
          );
        }

        // Only update if content actually changed
        if (_songUnitContentChanged(existing, updated)) {
          await _libraryRepository.updateSongUnit(updated);
          debugPrint('Updated song unit: ${updated.metadata.title}');
        }
      }
    } catch (e) {
      debugPrint('Error processing entry point file ${event.path}: $e');
    }
  }

  /// Handle file deleted events
  Future<void> _handleFileDeleted(FileChangeEvent event) async {
    debugPrint('Entry point file deleted: ${event.path}');

    // Look up the song unit ID from our path mapping
    final songUnitId = _pathToSongUnitId.remove(event.path);

    if (songUnitId != null) {
      // Delete the song unit from the repository
      try {
        await _libraryRepository.deleteSongUnit(songUnitId);
        debugPrint('Deleted song unit: $songUnitId');
      } catch (e) {
        debugPrint('Error deleting song unit $songUnitId: $e');
      }
    } else {
      debugPrint('No song unit ID found for deleted file: ${event.path}');
    }
  }

  /// Check if song unit content has changed (excluding timestamps)
  bool _songUnitContentChanged(SongUnit existing, SongUnit updated) {
    return existing.metadata != updated.metadata ||
        existing.sources != updated.sources ||
        existing.preferences != updated.preferences ||
        !_listEquals(existing.tagIds, updated.tagIds);
  }

  /// Compare two lists for equality
  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _onLibraryEvent(LibraryEvent event) {
    switch (event) {
      case SongUnitAdded(songUnit: final songUnit):
        _songUnits = [..._songUnits, songUnit];
        _updateLibraryItems(); // Update combined library items
        notifyListeners();
      case SongUnitUpdated(songUnit: final songUnit):
        final index = _songUnits.indexWhere((s) => s.id == songUnit.id);
        if (index != -1) {
          _songUnits = [
            ..._songUnits.sublist(0, index),
            songUnit,
            ..._songUnits.sublist(index + 1),
          ];
          _updateLibraryItems(); // Update combined library items
          notifyListeners();
        }
      case SongUnitDeleted(songUnitId: final id):
        _songUnits = _songUnits.where((s) => s.id != id).toList();
        _updateLibraryItems(); // Update combined library items
        notifyListeners();
      case SongUnitMoved(songUnit: final songUnit):
        final index = _songUnits.indexWhere((s) => s.id == songUnit.id);
        if (index != -1) {
          _songUnits = [
            ..._songUnits.sublist(0, index),
            songUnit,
            ..._songUnits.sublist(index + 1),
          ];
          _updateLibraryItems(); // Update combined library items
          notifyListeners();
        }
    }
  }

  void _onLibraryError(Object error) {
    _error = error.toString();
    notifyListeners();
  }

  /// Load all Song Units from the library
  Future<void> loadLibrary() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _songUnits = await _libraryRepository.getAllSongUnits();

      // Combine into library items
      _updateLibraryItems();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update the combined library items list from song units
  void _updateLibraryItems() {
    final items =
        <LibraryItem>[
            ..._songUnits.map(LibraryItem.new),
          ]
          // Sort by date (newest first)
          ..sort((a, b) => b.sortDate.compareTo(a.sortDate));

    _libraryItems = items;
  }

  /// Add a new Song Unit to the library
  ///
  /// Note: This only adds to the database. Use [addSongUnitWithConfig] to also
  /// create the entry point configuration file.
  Future<void> addSongUnit(SongUnit songUnit) async {
    try {
      _error = null;
      await _libraryRepository.addSongUnit(songUnit);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Add a new Song Unit to the library and create its configuration file
  ///
  /// Parameters:
  /// - [songUnit]: The song unit to add
  /// - [configMode]: The current configuration mode
  /// - [libraryLocations]: The list of library locations
  ///
  /// Returns true if the song unit was added successfully
  Future<bool> addSongUnitWithConfig({
    required SongUnit songUnit,
    required ConfigurationMode configMode,
    required List<LibraryLocation> libraryLocations,
  }) async {
    try {
      _error = null;

      // Add to database
      await _libraryRepository.addSongUnit(songUnit);

      // Remove temporary song units for files now used as sources
      await _cleanupTemporaryEntriesForSongUnit(songUnit);

      // Create entry point configuration file
      // In in-place mode, always try to create the file even without library locations
      // The service will place it alongside the first local source file
      if (_migrationService != null) {
        await _migrationService.createEntryPointFile(
          songUnit: songUnit,
          mode: configMode,
          libraryLocations: libraryLocations,
        );
      }

      // Refresh to reflect removed temporary entries
      await refreshAudioEntries();

      // Notify listeners so UI refreshes immediately
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Update an existing Song Unit
  ///
  /// Note: This only updates the database. Use [updateSongUnitWithConfig] to also
  /// update the entry point configuration file.
  Future<void> updateSongUnit(SongUnit songUnit) async {
    try {
      _error = null;
      await _libraryRepository.updateSongUnit(songUnit);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Update an existing Song Unit and its configuration file
  ///
  /// Parameters:
  /// - [songUnit]: The song unit to update
  /// - [configMode]: The current configuration mode
  /// - [libraryLocations]: The list of library locations
  ///
  /// Returns true if the song unit was updated successfully
  Future<bool> updateSongUnitWithConfig({
    required SongUnit songUnit,
    required ConfigurationMode configMode,
    required List<LibraryLocation> libraryLocations,
  }) async {
    try {
      _error = null;

      // Get the old song unit to compare sources
      final oldSongUnit = await _libraryRepository.getSongUnit(songUnit.id);

      // Update in database
      await _libraryRepository.updateSongUnit(songUnit);

      // Check if any files were removed from the song unit
      if (oldSongUnit != null) {
        await _handleRemovedSources(oldSongUnit, songUnit);
      }

      // Remove temporary song units for files now used as sources
      await _cleanupTemporaryEntriesForSongUnit(songUnit);

      // Refresh the library view to show any new audio entries
      await refreshAudioEntries();

      // Note: We no longer delete audio entries when they're added to song units.
      // Instead, they're filtered out in _updateLibraryItems() so they don't appear
      // in the library view, but they remain in the database. This allows them to
      // reappear if auto-discovery is toggled or if the song unit is deleted.

      // Update entry point configuration file
      // If an entry point file already exists (e.g. in a library location),
      // write back to the same location regardless of config mode.
      // Only use mode-based destination for brand new files.
      if (_migrationService != null) {
        // Find existing entry point file location first
        final existingPath = await _migrationService.findEntryPointFile(
          songUnit: songUnit,
          currentMode: configMode,
          libraryLocations: libraryLocations,
        );

        if (existingPath != null) {
          // Remember the directory before deleting
          final existingDir = p.dirname(existingPath);
          // Delete old file (in case name changed)
          await _migrationService.deleteEntryPointFile(
            songUnit: songUnit,
            currentMode: configMode,
            libraryLocations: libraryLocations,
          );
          // Write back to the same directory where the old file was
          await _migrationService.createEntryPointFileAt(
            songUnit: songUnit,
            directory: existingDir,
            libraryLocations: libraryLocations,
          );
        } else {
          // No existing file — create in mode-based location
          await _migrationService.createEntryPointFile(
            songUnit: songUnit,
            mode: configMode,
            libraryLocations: libraryLocations,
          );
        }
      }

      // Ensure UI updates immediately
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Remove temporary song units whose originalFilePath matches any local
  /// file source in the given song unit. Called after add/update so that
  /// discovered audio entries disappear once the file is part of a real
  /// song unit.
  Future<void> _cleanupTemporaryEntriesForSongUnit(SongUnit songUnit) async {
    for (final source in songUnit.sources.getAllSources()) {
      if (source.origin is LocalFileOrigin) {
        final path = (source.origin as LocalFileOrigin).path;
        try {
          await _libraryRepository.deleteTemporarySongUnitByPath(path);
        } catch (e) {
          debugPrint(
            'LibraryViewModel: Failed to remove temp entry for $path: $e',
          );
        }
      }
    }
  }

  /// After a sync operation, remove temporary song units whose
  /// originalFilePath is now referenced by a non-temporary song unit.
  Future<void> _cleanupTemporaryEntriesAfterSync() async {
    await cleanupTemporaryEntries();
  }

  /// Remove temporary song units whose originalFilePath is referenced
  /// by a non-temporary song unit. Can be called after audio discovery
  /// to clean up entries that should have been skipped.
  Future<void> cleanupTemporaryEntries() async {
    try {
      final tempUnits = await _libraryRepository.getTemporarySongUnits();
      if (tempUnits.isEmpty) return;

      // Reload song units to ensure we have the latest data
      _songUnits = await _libraryRepository.getAllSongUnits();

      // Build a set of all local file paths used by non-temporary song units
      // Use both normalized absolute paths and basenames+dirs for matching
      final referencedPaths = <String>{};
      final referencedBasenameDir = <String>{};
      for (final unit in _songUnits) {
        if (unit.isTemporary) continue;
        for (final source in unit.sources.getAllSources()) {
          if (source.origin is LocalFileOrigin) {
            final sourcePath = (source.origin as LocalFileOrigin).path;
            referencedPaths.add(
              p.normalize(p.absolute(sourcePath)),
            );
            // Also track basename+directory for fuzzy matching
            final absPath = p.absolute(sourcePath);
            final key = '${p.normalize(p.dirname(absPath))}/${p.basename(sourcePath)}';
            referencedBasenameDir.add(key);
          }
        }
      }

      var removed = 0;
      for (final temp in tempUnits) {
        final filePath = temp.originalFilePath;
        if (filePath == null) continue;
        final normalized = p.normalize(p.absolute(filePath));

        // Strategy 1: Exact normalized path match
        if (referencedPaths.contains(normalized)) {
          await _libraryRepository.deleteTemporarySongUnitByPath(filePath);
          removed++;
          continue;
        }

        // Strategy 2: Basename + directory match (handles path normalization differences)
        final key = '${p.normalize(p.dirname(p.absolute(filePath)))}/${p.basename(filePath)}';
        if (referencedBasenameDir.contains(key)) {
          await _libraryRepository.deleteTemporarySongUnitByPath(filePath);
          removed++;
          continue;
        }
      }

      if (removed > 0) {
        debugPrint(
          'LibraryViewModel: Removed $removed temporary entries after sync',
        );
        // Reload to reflect deletions
        _songUnits = await _libraryRepository.getAllSongUnits();
        _updateLibraryItems();
      }
    } catch (e) {
      debugPrint('LibraryViewModel: Error cleaning up after sync: $e');
    }
  }

  /// Handle sources that were removed from a song unit
  /// If a file is no longer used in any song unit, create a temporary song unit for it
  Future<void> _handleRemovedSources(
    SongUnit oldSongUnit,
    SongUnit newSongUnit,
  ) async {
    // Get all file paths from old song unit
    final oldPaths = <String>{};
    for (final source in oldSongUnit.sources.getAllSources()) {
      if (source.origin is LocalFileOrigin) {
        oldPaths.add((source.origin as LocalFileOrigin).path);
      }
    }

    // Get all file paths from new song unit
    final newPaths = <String>{};
    for (final source in newSongUnit.sources.getAllSources()) {
      if (source.origin is LocalFileOrigin) {
        newPaths.add((source.origin as LocalFileOrigin).path);
      }
    }

    // Find paths that were removed
    final removedPaths = oldPaths.difference(newPaths);

    if (removedPaths.isEmpty) return;

    debugPrint(
      'LibraryViewModel: ${removedPaths.length} sources removed from song unit',
    );

    // For each removed path, check if it's still used in other song units
    for (final path in removedPaths) {
      final isStillUsed = await _isPathUsedInOtherSongUnits(
        path,
        newSongUnit.id,
      );

      if (!isStillUsed) {
        // File is not used in any song unit, try to re-discover it
        debugPrint(
          'LibraryViewModel: File $path no longer used, attempting to re-discover',
        );
        await _rediscoverFile(path, oldSongUnit.libraryLocationId);
      }
    }
  }

  /// Check if a file path is used in any song unit except the specified one
  Future<bool> _isPathUsedInOtherSongUnits(
    String filePath,
    String excludeSongUnitId,
  ) async {
    final allSongUnits = await _libraryRepository.getAllSongUnits();

    // Normalize the file path for comparison
    final absoluteFilePath = p.absolute(filePath);
    final normalizedFilePath = p.normalize(absoluteFilePath);
    final fileName = p.basename(filePath);
    final fileDir = p.dirname(absoluteFilePath);

    for (final unit in allSongUnits) {
      if (unit.id == excludeSongUnitId) continue;

      for (final source in unit.sources.getAllSources()) {
        if (source.origin is LocalFileOrigin) {
          final sourcePath = (source.origin as LocalFileOrigin).path;

          // Strategy 1: Direct match
          if (sourcePath == filePath) {
            debugPrint(
              'LibraryViewModel: File $fileName still used in song unit: ${unit.metadata.title} (direct match)',
            );
            return true;
          }

          // Strategy 2: Absolute path match
          final absoluteSourcePath = p.isAbsolute(sourcePath)
              ? sourcePath
              : p.join(fileDir, sourcePath);
          final normalizedSourcePath = p.normalize(absoluteSourcePath);

          if (normalizedSourcePath == normalizedFilePath) {
            debugPrint(
              'LibraryViewModel: File $fileName still used in song unit: ${unit.metadata.title} (absolute match)',
            );
            return true;
          }

          // Strategy 3: Filename match (same directory)
          if (p.basename(sourcePath) == fileName &&
              p.dirname(normalizedSourcePath) == fileDir) {
            debugPrint(
              'LibraryViewModel: File $fileName still used in song unit: ${unit.metadata.title} (filename+dir match)',
            );
            return true;
          }
        }
      }
    }

    return false;
  }

  /// Re-discover a file as a temporary Song Unit after it was removed from a song unit
  Future<void> _rediscoverFile(
    String filePath,
    String? libraryLocationId,
  ) async {
    try {
      // Check if file exists
      final file = File(filePath);
      if (!file.existsSync()) {
        debugPrint('LibraryViewModel: File does not exist: $filePath');
        return;
      }

      // Check if already tracked as temporary song unit
      if (await _libraryRepository.hasTemporarySongUnitForPath(filePath)) {
        debugPrint(
          'LibraryViewModel: Temporary song unit already exists for: $filePath',
        );
        return;
      }

      // Need a library location ID
      if (libraryLocationId == null) {
        debugPrint('LibraryViewModel: No library location ID for: $filePath');
        return;
      }

      // Use discovery service to process the file
      try {
        final audioDiscoveryService = getIt<AudioDiscoveryService>();
        final success = await audioDiscoveryService.processAudioFile(
          filePath,
          libraryLocationId,
        );

        if (success) {
          debugPrint(
            'LibraryViewModel: Successfully re-discovered file: $filePath',
          );
        } else {
          debugPrint(
            'LibraryViewModel: Failed to re-discover file: $filePath',
          );
        }
      } catch (e) {
        debugPrint(
          'LibraryViewModel: Error calling audio discovery service: $e',
        );
      }
    } catch (e) {
      debugPrint(
        'LibraryViewModel: Error re-discovering file $filePath: $e',
      );
    }
  }

  /// Remove all song units and temporary entries associated with a library location.
  /// Called when a library location is removed from settings.
  Future<void> removeLocationEntries(String libraryLocationId) async {
    try {
      _error = null;

      // Get all song units for this location (includes both temporary and non-temporary)
      final locationUnits = await _libraryRepository.getByLibraryLocation(
        libraryLocationId,
      );

      debugPrint(
        'LibraryViewModel.removeLocationEntries: Found ${locationUnits.length} entries for location $libraryLocationId',
      );

      var deleted = 0;
      var errors = 0;
      for (final unit in locationUnits) {
        try {
          debugPrint(
            'LibraryViewModel.removeLocationEntries: Deleting ${unit.metadata.title} (${unit.id}) isTemporary=${unit.isTemporary}',
          );
          await _libraryRepository.deleteSongUnit(unit.id);
          deleted++;
        } catch (e) {
          debugPrint(
            'LibraryViewModel.removeLocationEntries: Failed to delete ${unit.id}: $e',
          );
          errors++;
        }
      }

      // Also remove any path-to-songUnitId mappings for this location
      _pathToSongUnitId.removeWhere(
        (_, songUnitId) => locationUnits.any((u) => u.id == songUnitId),
      );

      // Reload library to reflect changes
      _songUnits = await _libraryRepository.getAllSongUnits();
      _updateLibraryItems();
      notifyListeners();

      debugPrint(
        'LibraryViewModel.removeLocationEntries: Deleted $deleted, errors $errors, ${_songUnits.length} entries remaining',
      );
    } catch (e, stackTrace) {
      debugPrint('LibraryViewModel.removeLocationEntries error: $e');
      debugPrint('LibraryViewModel.removeLocationEntries stack: $stackTrace');
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Delete a Song Unit from the library
  Future<void> deleteSongUnit(String id) async {
    try {
      _error = null;
      await _libraryRepository.deleteSongUnit(id);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Delete a Song Unit from the library with option to delete configuration file
  ///
  /// Parameters:
  /// - [id]: The ID of the song unit to delete
  /// - [deleteConfigFile]: If true, also deletes the entry point configuration file
  /// - [currentMode]: The current configuration mode (required if deleteConfigFile is true)
  /// - [libraryLocations]: The list of library locations (required if deleteConfigFile is true)
  ///
  /// Returns true if deletion was successful
  Future<bool> deleteSongUnitWithConfig({
    required String id,
    required bool deleteConfigFile,
    ConfigurationMode? currentMode,
    List<LibraryLocation>? libraryLocations,
  }) async {
    try {
      _error = null;

      // Get the song unit before deleting (needed for config file deletion)
      SongUnit? songUnit;
      if (deleteConfigFile && _migrationService != null) {
        songUnit = await _libraryRepository.getSongUnit(id);
      }

      // Delete from database
      await _libraryRepository.deleteSongUnit(id);

      // Delete configuration file if requested
      if (deleteConfigFile &&
          songUnit != null &&
          _migrationService != null &&
          currentMode != null &&
          libraryLocations != null) {
        await _migrationService.deleteEntryPointFile(
          songUnit: songUnit,
          currentMode: currentMode,
          libraryLocations: libraryLocations,
        );
      }

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Get a Song Unit by ID
  Future<SongUnit?> getSongUnit(String id) async {
    try {
      _error = null;
      return await _libraryRepository.getSongUnit(id);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Import Song Units from a ZIP file
  Future<ImportResult?> importFromZip(File zipFile) async {
    if (_importExportService == null) {
      _error = 'Import/Export service not available';
      notifyListeners();
      return null;
    }

    try {
      _isOperationInProgress = true;
      _error = null;
      notifyListeners();

      final result = await _importExportService.importFromZip(
        zipFile,
        onProgress: _updateProgress,
      );

      _isOperationInProgress = false;
      _operationProgress = null;
      notifyListeners();

      return result;
    } catch (e) {
      _error = e.toString();
      _isOperationInProgress = false;
      _operationProgress = null;
      notifyListeners();
      return null;
    }
  }

  /// Export a single Song Unit to a ZIP file
  /// If [outputPath] is provided, exports to that location
  Future<File?> exportSongUnit(String songUnitId, {String? outputPath}) async {
    if (_importExportService == null) {
      _error = 'Import/Export service not available';
      notifyListeners();
      return null;
    }

    try {
      _isOperationInProgress = true;
      _error = null;
      notifyListeners();

      final songUnit = await _libraryRepository.getSongUnit(songUnitId);
      if (songUnit == null) {
        _error = 'Song Unit not found';
        _isOperationInProgress = false;
        notifyListeners();
        return null;
      }

      final file = await _importExportService.exportSongUnit(
        songUnit,
        onProgress: _updateProgress,
        outputPath: outputPath,
      );

      _isOperationInProgress = false;
      _operationProgress = null;
      notifyListeners();

      return file;
    } catch (e) {
      _error = e.toString();
      _isOperationInProgress = false;
      _operationProgress = null;
      notifyListeners();
      return null;
    }
  }

  /// Export multiple Song Units to a batch ZIP file
  /// If [outputPath] is provided, exports to that location
  Future<File?> exportSongUnits(
    List<String> songUnitIds, {
    String? outputPath,
  }) async {
    if (_importExportService == null) {
      _error = 'Import/Export service not available';
      notifyListeners();
      return null;
    }

    try {
      _isOperationInProgress = true;
      _error = null;
      notifyListeners();

      final songUnits = <SongUnit>[];
      for (final id in songUnitIds) {
        final songUnit = await _libraryRepository.getSongUnit(id);
        if (songUnit != null) {
          songUnits.add(songUnit);
        }
      }

      if (songUnits.isEmpty) {
        _error = 'No Song Units found to export';
        _isOperationInProgress = false;
        notifyListeners();
        return null;
      }

      final file = await _importExportService.exportSongUnits(
        songUnits,
        onProgress: _updateProgress,
        outputPath: outputPath,
      );

      _isOperationInProgress = false;
      _operationProgress = null;
      notifyListeners();

      return file;
    } catch (e) {
      _error = e.toString();
      _isOperationInProgress = false;
      _operationProgress = null;
      notifyListeners();
      return null;
    }
  }

  void _updateProgress(int current, int total, String message) {
    _operationProgress = OperationProgress(
      current: current,
      total: total,
      message: message,
    );
    notifyListeners();
  }

  /// Clear any error state
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Refresh the library from the database
  Future<void> refresh() async {
    await loadLibrary();
  }

  /// Sync library with entry point files from all library locations
  ///
  /// This will:
  /// - Discover all entry point files in library locations
  /// - Import new song units that don't exist in the database
  /// - Update existing song units if the entry point file has changed
  ///
  /// Returns a SyncResult with counts of imported and updated song units.
  Future<SyncResult?> syncFromLibraryLocations() async {
    if (_discoveryService == null) {
      _error = 'Discovery service not available';
      notifyListeners();
      return null;
    }

    try {
      _isOperationInProgress = true;
      _error = null;
      notifyListeners();

      final result = await _discoveryService.syncAll(
        onProgress: _updateProgress,
      );

      // Reload the library to reflect changes
      _songUnits = await _libraryRepository.getAllSongUnits();

      _isOperationInProgress = false;
      _operationProgress = null;
      notifyListeners();

      return result;
    } catch (e) {
      _error = e.toString();
      _isOperationInProgress = false;
      _operationProgress = null;
      notifyListeners();
      return null;
    }
  }

  /// Manually trigger a library sync
  ///
  /// This is a public method that can be called from the UI to manually
  /// sync the library with entry point files from library locations.
  ///
  /// Unlike loadAndSync(), this always performs a full sync regardless
  /// of whether an initial sync has been done.
  Future<SyncResult?> syncLibrary() async {
    if (_discoveryService == null) {
      _error = 'Discovery service not available';
      notifyListeners();
      return null;
    }

    try {
      _isOperationInProgress = true;
      _error = null;
      notifyListeners();

      debugPrint('LibraryViewModel.syncLibrary: Starting full sync...');

      final syncResult = await _discoveryService.syncAll(
        onProgress: _updateProgress,
      );

      debugPrint('LibraryViewModel.syncLibrary: $syncResult');

      // Populate path to song unit ID mapping for deletion tracking
      _pathToSongUnitId.addAll(syncResult.pathToSongUnitId);

      // Reload the library to reflect changes
      _songUnits = await _libraryRepository.getAllSongUnits();

      // After sync, clean up temporary song units whose files are now
      // referenced by imported (non-temporary) song units.
      await _cleanupTemporaryEntriesAfterSync();

      _isOperationInProgress = false;
      _operationProgress = null;
      notifyListeners();

      return syncResult;
    } catch (e, stackTrace) {
      debugPrint('LibraryViewModel.syncLibrary error: $e');
      debugPrint('LibraryViewModel.syncLibrary stack: $stackTrace');
      _error = e.toString();
      _isOperationInProgress = false;
      _operationProgress = null;
      notifyListeners();
      return null;
    }
  }

  /// Load library and sync from library locations
  ///
  /// This is the main method to call on app startup or when navigating to library.
  /// It loads existing song units from the database and then
  /// syncs with entry point files from library locations (only on first call).
  ///
  /// Subsequent calls will only load from database (fast) since the file
  /// system watcher handles incremental updates.
  ///
  /// Note: Sync errors are non-fatal - the library will still be loaded
  /// from the database even if sync fails.
  Future<void> loadAndSync() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Always load from database (fast operation)
      _songUnits = await _libraryRepository.getAllSongUnits();

      // Combine into library items
      _updateLibraryItems();

      _isLoading = false;
      notifyListeners();

      // Only do full sync on first call, then rely on file watcher
      if (!_hasInitialSync && _discoveryService != null) {
        _hasInitialSync = true;
        await _syncFromLocations();

        // Note: File system watcher is started by main.dart, not here
        // This ensures the audio file listener in main.dart is set up first
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      _isOperationInProgress = false;
      _operationProgress = null;
      notifyListeners();
    }
  }

  /// Refresh library items (lightweight, no sync)
  /// Used after re-scanning to update the library view
  Future<void> refreshAudioEntries() async {
    try {
      // Reload song units to ensure we have latest data
      _songUnits = await _libraryRepository.getAllSongUnits();

      // Combine into library items
      _updateLibraryItems();

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Internal method to sync from library locations
  /// Errors here are non-fatal and won't prevent the library from loading
  Future<void> _syncFromLocations() async {
    try {
      _isOperationInProgress = true;
      notifyListeners();

      debugPrint('LibraryViewModel._syncFromLocations: Starting sync...');

      final syncResult = await _discoveryService!.syncAll(
        onProgress: _updateProgress,
      );

      debugPrint('LibraryViewModel._syncFromLocations: $syncResult');

      // Populate path to song unit ID mapping for deletion tracking
      _pathToSongUnitId.addAll(syncResult.pathToSongUnitId);

      // Reload to get any new/updated song units
      _songUnits = await _libraryRepository.getAllSongUnits();

      // Build path to song unit ID mapping for deletion tracking
      // by scanning the results from the discovery service
      // We do this by scanning all song units that have entry point files
      for (final songUnit in _songUnits) {
        if (!songUnit.isTemporary && songUnit.libraryLocationId != null) {
          // The path mapping will be built incrementally by file watcher events
        }
      }

      // Clean up temporary entries whose files are now in imported song units
      await _cleanupTemporaryEntriesAfterSync();
    } catch (e, stackTrace) {
      // Sync errors are non-fatal - just log and continue
      // The library is already loaded from the database
      // We don't set _error here to avoid showing error state
      // when the library is actually loaded successfully
      debugPrint('LibraryViewModel._syncFromLocations error: $e');
      debugPrint('LibraryViewModel._syncFromLocations stack: $stackTrace');
    } finally {
      _isOperationInProgress = false;
      _operationProgress = null;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Promote temporary Song Unit
  // ---------------------------------------------------------------------------

  /// Promote a temporary Song Unit to a full one with auto-discovery.
  /// Returns a [PromoteResult] with the promoted song unit and discovery info.
  Future<PromoteResult> promoteSongUnit(
    SongUnit tempSongUnit, {
    required ConfigurationMode configMode,
    required List<LibraryLocation> libraryLocations,
  }) async {
    final filePath = tempSongUnit.originalFilePath;

    DiscoveredSources? discovered;
    if (filePath != null) {
      final autoMatcher = SourceAutoMatcher();
      discovered = await autoMatcher.discoverAndCreateSources(filePath);
    }

    final promoted = tempSongUnit.copyWith(
      isTemporary: false,
      sources: discovered != null && discovered.hasAnySources
          ? SourceCollection(
              displaySources: [
                ...tempSongUnit.sources.displaySources,
                ...discovered.videoSources,
                ...discovered.imageSources,
              ],
              audioSources: [
                ...tempSongUnit.sources.audioSources,
                ...discovered.audioSources,
              ],
              accompanimentSources: [
                ...tempSongUnit.sources.accompanimentSources,
                ...discovered.accompanimentSources,
              ],
              hoverSources: [
                ...tempSongUnit.sources.hoverSources,
                ...discovered.lyricsSources,
              ],
            )
          : null,
    );

    final success = await updateSongUnitWithConfig(
      songUnit: promoted,
      configMode: configMode,
      libraryLocations: libraryLocations,
    );

    return PromoteResult(
      promoted: promoted,
      success: success,
      discovered: discovered,
    );
  }

  // ---------------------------------------------------------------------------
  // Search (Rust FFI)
  // ---------------------------------------------------------------------------

  /// Search song units using the Rust query evaluator.
  /// Returns a set of matching song unit IDs, or null if parsing fails
  /// (caller should fall back to simple text search).
  Future<Set<String>?> searchSongUnits(String queryText) async {
    try {
      final matchingIds = await rust_evaluator.searchSongUnits(
        queryText: queryText,
        nameAutoSearch: true,
      );
      return matchingIds.toSet();
    } catch (_) {
      return null; // Parsing failed → caller uses fallback
    }
  }

  // ---------------------------------------------------------------------------
  // Library locations
  // ---------------------------------------------------------------------------

  /// Load library locations from the location manager.
  Future<Map<String, LibraryLocation>> loadLibraryLocations() async {
    try {
      final manager = getIt<LibraryLocationManager>();
      final locations = await manager.getLocations();
      return {for (final loc in locations) loc.id: loc};
    } catch (e) {
      return {};
    }
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _fileWatcherSubscription?.cancel();
    _fileSystemWatcher?.stopWatching();
    super.dispose();
  }
}
