import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../models/entry_point_file.dart';
import '../models/library_location.dart';
import 'library_location_manager.dart';

/// Event types for file system changes
enum FileChangeType { created, modified, deleted }

/// Represents a file system change event
class FileChangeEvent {
  const FileChangeEvent({
    required this.path,
    required this.type,
    this.libraryLocationId,
  });

  final String path;
  final FileChangeType type;
  final String? libraryLocationId;

  @override
  String toString() => 'FileChangeEvent($type: $path)';
}

/// Service for watching file system changes in library locations
///
/// This service monitors library locations for changes to entry point files
/// (beadline-*.json) and emits events when files are created, modified, or deleted.
class FileSystemWatcher {
  FileSystemWatcher(this._libraryLocationManager);

  final LibraryLocationManager _libraryLocationManager;

  /// Map of library location ID to directory watcher subscription
  final Map<String, StreamSubscription<FileSystemEvent>> _watchers = {};

  /// Stream controller for file change events
  final StreamController<FileChangeEvent> _eventController =
      StreamController<FileChangeEvent>.broadcast();

  /// Whether the watcher is currently active
  bool _isWatching = false;

  /// Debounce timers for file changes (to handle rapid successive events)
  final Map<String, Timer> _debounceTimers = {};

  /// Debounce duration for file changes
  static const _debounceDuration = Duration(milliseconds: 500);

  /// Stream of file change events
  Stream<FileChangeEvent> get events => _eventController.stream;

  /// Whether the watcher is currently active
  bool get isWatching => _isWatching;

  /// Start watching all library locations for changes
  Future<void> startWatching() async {
    if (_isWatching) return;

    _isWatching = true;

    try {
      final locations = await _libraryLocationManager.getLocations();

      for (final location in locations) {
        if (location.isAccessible) {
          await _watchLocation(location);
        }
      }
    } catch (e) {
      debugPrint('FileSystemWatcher: Error starting watchers: $e');
    }
  }

  /// Stop watching all library locations
  Future<void> stopWatching() async {
    _isWatching = false;

    for (final subscription in _watchers.values) {
      await subscription.cancel();
    }
    _watchers.clear();

    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
  }

  /// Add a watcher for a specific library location
  Future<void> _watchLocation(LibraryLocation location) async {
    // Cancel existing watcher if any
    await _watchers[location.id]?.cancel();

    final directory = Directory(location.rootPath);
    if (!directory.existsSync()) {
      debugPrint(
        'FileSystemWatcher: Directory does not exist: ${location.rootPath}',
      );
      return;
    }

    try {
      // Watch the directory recursively
      final watcher = directory.watch(recursive: true);

      _watchers[location.id] = watcher.listen(
        (event) => _handleFileSystemEvent(event, location),
        onError: (error) {
          debugPrint(
            'FileSystemWatcher: Error watching ${location.rootPath}: $error',
          );
        },
      );

      debugPrint('FileSystemWatcher: Started watching ${location.rootPath}');
    } catch (e) {
      debugPrint('FileSystemWatcher: Failed to watch ${location.rootPath}: $e');
    }
  }

  /// Handle a file system event
  void _handleFileSystemEvent(FileSystemEvent event, LibraryLocation location) {
    final path = event.path;
    final filename = p.basename(path);

    // Process both entry point files and audio files
    if (!_isEntryPointFile(filename) && !_isAudioFile(filename)) {
      return;
    }

    // Debounce rapid successive events for the same file
    _debounceTimers[path]?.cancel();
    _debounceTimers[path] = Timer(_debounceDuration, () {
      _debounceTimers.remove(path);
      _emitEvent(event, location);
    });
  }

  /// Check if a filename matches the entry point file pattern (current or legacy)
  bool _isEntryPointFile(String filename) {
    return (filename.startsWith(EntryPointFile.filePrefix) ||
            filename.startsWith(EntryPointFile.legacyFilePrefix)) &&
        filename.endsWith(EntryPointFile.fileExtension);
  }

  /// Check if a filename is an audio file
  bool _isAudioFile(String filename) {
    final ext = p.extension(filename).toLowerCase();
    return const [
      '.mp3',
      '.flac',
      '.wav',
      '.aac',
      '.ogg',
      '.m4a',
    ].contains(ext);
  }

  /// Emit a file change event
  void _emitEvent(FileSystemEvent event, LibraryLocation location) {
    FileChangeType type;

    if (event is FileSystemCreateEvent) {
      type = FileChangeType.created;
    } else if (event is FileSystemModifyEvent) {
      type = FileChangeType.modified;
    } else if (event is FileSystemDeleteEvent) {
      type = FileChangeType.deleted;
    } else if (event is FileSystemMoveEvent) {
      // Treat move as delete + create
      // First emit delete for the old path
      _eventController.add(
        FileChangeEvent(
          path: event.path,
          type: FileChangeType.deleted,
          libraryLocationId: location.id,
        ),
      );
      // Then emit create for the new path (if it's still an entry point file)
      if (event.destination != null &&
          _isEntryPointFile(p.basename(event.destination!))) {
        _eventController.add(
          FileChangeEvent(
            path: event.destination!,
            type: FileChangeType.created,
            libraryLocationId: location.id,
          ),
        );
      }
      return;
    } else {
      return;
    }

    _eventController.add(
      FileChangeEvent(
        path: event.path,
        type: type,
        libraryLocationId: location.id,
      ),
    );
  }

  /// Refresh watchers for all library locations
  ///
  /// Call this when library locations are added, removed, or modified.
  Future<void> refreshWatchers() async {
    if (!_isWatching) return;

    // Stop all existing watchers
    for (final subscription in _watchers.values) {
      await subscription.cancel();
    }
    _watchers.clear();

    // Start new watchers
    try {
      final locations = await _libraryLocationManager.getLocations();

      for (final location in locations) {
        if (location.isAccessible) {
          await _watchLocation(location);
        }
      }
    } catch (e) {
      debugPrint('FileSystemWatcher: Error refreshing watchers: $e');
    }
  }

  /// Add a watcher for a newly added library location
  Future<void> addLocationWatcher(LibraryLocation location) async {
    if (!_isWatching) return;

    if (location.isAccessible) {
      await _watchLocation(location);
    }
  }

  /// Remove a watcher for a removed library location
  Future<void> removeLocationWatcher(String locationId) async {
    final subscription = _watchers.remove(locationId);
    await subscription?.cancel();
  }

  /// Dispose of resources
  Future<void> dispose() async {
    await stopWatching();
    await _eventController.close();
  }
}
