import 'dart:io';

import 'package:uuid/uuid.dart';

import '../data/settings_storage.dart';
import '../models/app_settings.dart';
import '../models/configuration_mode.dart';
import '../models/library_location.dart';

/// Exception thrown when a library location operation fails
class LibraryLocationException implements Exception {
  const LibraryLocationException(this.message, {this.code});
  final String message;
  final String? code;

  @override
  String toString() => 'LibraryLocationException: $message';
}

/// Manages the list of configured library locations
/// Persists locations to AppSettings via SettingsStorage
/// Discovery is automatically triggered when locations are added
class LibraryLocationManager {
  LibraryLocationManager(this._settingsStorage);
  final SettingsStorage _settingsStorage;
  static const Uuid _uuid = Uuid();

  /// Cached settings to avoid repeated disk reads
  AppSettings? _cachedSettings;

  /// Get all configured library locations
  /// Returns locations with updated accessibility status
  Future<List<LibraryLocation>> getLocations() async {
    final settings = await _loadSettings();
    return settings.libraryLocations;
  }

  /// Add a new library location
  /// Validates the path exists and is accessible before adding
  /// Returns the created LibraryLocation
  /// Note: Discovery should be triggered after calling this method
  Future<LibraryLocation> addLocation(String path, {String? name}) async {
    // Validate the path first
    final validationResult = await validateLocation(path);
    if (!validationResult.isValid) {
      throw LibraryLocationException(
        validationResult.error ?? 'Invalid path',
        code: 'INVALID_PATH',
      );
    }

    final settings = await _loadSettings();

    // Check for duplicate path
    final normalizedPath = _normalizePath(path);
    if (settings.libraryLocations.any(
      (loc) => _normalizePath(loc.rootPath) == normalizedPath,
    )) {
      throw const LibraryLocationException(
        'Library location already exists',
        code: 'DUPLICATE_PATH',
      );
    }

    // Create new library location
    final location = LibraryLocation(
      id: _uuid.v4(),
      name: name ?? _generateNameFromPath(path),
      rootPath: normalizedPath,
      isDefault: settings.libraryLocations.isEmpty, // First location is default
      addedAt: DateTime.now().toUtc(),
    );

    // Add to settings and save
    final updatedLocations = [...settings.libraryLocations, location];
    await _saveSettings(settings.copyWith(libraryLocations: updatedLocations));

    return location;
  }

  /// Remove a library location by ID
  /// Does not delete any files, only removes the reference
  Future<void> removeLocation(String id) async {
    final settings = await _loadSettings();

    final locationIndex = settings.libraryLocations.indexWhere(
      (loc) => loc.id == id,
    );

    if (locationIndex == -1) {
      throw const LibraryLocationException(
        'Library location not found',
        code: 'NOT_FOUND',
      );
    }

    final removedLocation = settings.libraryLocations[locationIndex];
    final updatedLocations = [...settings.libraryLocations]
      ..removeAt(locationIndex);

    // If we removed the default location, make the first remaining one default
    if (removedLocation.isDefault && updatedLocations.isNotEmpty) {
      updatedLocations[0] = updatedLocations[0].copyWith(isDefault: true);
    }

    await _saveSettings(settings.copyWith(libraryLocations: updatedLocations));
  }

  /// Set a library location as the default
  Future<void> setDefaultLocation(String id) async {
    final settings = await _loadSettings();

    final locationIndex = settings.libraryLocations.indexWhere(
      (loc) => loc.id == id,
    );

    if (locationIndex == -1) {
      throw const LibraryLocationException(
        'Library location not found',
        code: 'NOT_FOUND',
      );
    }

    // Update all locations: clear existing default, set new default
    final updatedLocations = settings.libraryLocations.map((loc) {
      if (loc.id == id) {
        return loc.copyWith(isDefault: true);
      } else if (loc.isDefault) {
        return loc.copyWith(isDefault: false);
      }
      return loc;
    }).toList();

    await _saveSettings(settings.copyWith(libraryLocations: updatedLocations));
  }

  /// Validate that a path exists, is a directory, and is accessible
  Future<ValidationResult> validateLocation(String path) async {
    try {
      // First check if the path exists at all using FileSystemEntity
      final entityType = FileSystemEntity.typeSync(path);

      if (entityType == FileSystemEntityType.notFound) {
        return const ValidationResult(
          isValid: false,
          error: 'Path does not exist',
          code: 'PATH_NOT_EXISTS',
        );
      }

      // Check if it's a directory (not a file)
      if (entityType != FileSystemEntityType.directory) {
        return const ValidationResult(
          isValid: false,
          error: 'Path is not a directory',
          code: 'NOT_DIRECTORY',
        );
      }

      final directory = Directory(path);

      // Check if directory is readable by listing contents
      try {
        directory.listSync();
      } catch (e) {
        return const ValidationResult(
          isValid: false,
          error: 'Directory is not accessible (permission denied)',
          code: 'PERMISSION_DENIED',
        );
      }

      return const ValidationResult(isValid: true);
    } catch (e) {
      return ValidationResult(
        isValid: false,
        error: 'Failed to validate path: $e',
        code: 'VALIDATION_ERROR',
      );
    }
  }

  /// Refresh accessibility status for all library locations
  /// Updates isAccessible field based on current file system state
  Future<List<LibraryLocation>> refreshAccessibility() async {
    final settings = await _loadSettings();

    final updatedLocations = <LibraryLocation>[];
    for (final location in settings.libraryLocations) {
      final validationResult = await validateLocation(location.rootPath);
      updatedLocations.add(
        location.copyWith(isAccessible: validationResult.isValid),
      );
    }

    await _saveSettings(settings.copyWith(libraryLocations: updatedLocations));
    return updatedLocations;
  }

  /// Get the default library location
  /// Returns null if no locations are configured
  Future<LibraryLocation?> getDefaultLocation() async {
    final settings = await _loadSettings();
    try {
      return settings.libraryLocations.firstWhere((loc) => loc.isDefault);
    } catch (e) {
      // No default found, return first location if available
      return settings.libraryLocations.isNotEmpty
          ? settings.libraryLocations.first
          : null;
    }
  }

  /// Get a library location by ID
  Future<LibraryLocation?> getLocationById(String id) async {
    final settings = await _loadSettings();
    try {
      return settings.libraryLocations.firstWhere((loc) => loc.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Find which library location contains a given path
  /// Returns null if the path is not within any library location
  LibraryLocation? findLocationForPath(
    String absolutePath,
    List<LibraryLocation> locations,
  ) {
    final normalizedPath = _normalizePath(absolutePath);
    for (final location in locations) {
      final normalizedRoot = _normalizePath(location.rootPath);
      if (normalizedPath.startsWith(normalizedRoot)) {
        // Ensure it's actually within the directory, not just a prefix match
        if (normalizedPath == normalizedRoot ||
            normalizedPath.startsWith('$normalizedRoot/')) {
          return location;
        }
      }
    }
    return null;
  }

  /// Update a library location's name
  Future<void> updateLocationName(String id, String newName) async {
    final settings = await _loadSettings();

    final updatedLocations = settings.libraryLocations.map((loc) {
      if (loc.id == id) {
        return loc.copyWith(name: newName);
      }
      return loc;
    }).toList();

    await _saveSettings(settings.copyWith(libraryLocations: updatedLocations));
  }

  /// Update a library location's configuration mode
  Future<void> updateLocationConfigMode(
    String id,
    ConfigurationMode? configMode,
  ) async {
    final settings = await _loadSettings();

    final updatedLocations = settings.libraryLocations.map((loc) {
      if (loc.id == id) {
        return configMode == null
            ? loc.copyWith(clearConfigMode: true)
            : loc.copyWith(configMode: configMode);
      }
      return loc;
    }).toList();

    await _saveSettings(settings.copyWith(libraryLocations: updatedLocations));
  }

  // Private helper methods

  Future<AppSettings> _loadSettings() async {
    _cachedSettings ??= await _settingsStorage.loadSettings();
    return _cachedSettings!;
  }

  Future<void> _saveSettings(AppSettings settings) async {
    _cachedSettings = settings;
    await _settingsStorage.saveSettings(settings);
  }

  /// Normalize a path for consistent comparison
  String _normalizePath(String path) {
    // Remove trailing slashes and normalize
    var normalized = path.replaceAll(RegExp(r'/+$'), '');
    // Handle Windows paths
    normalized = normalized.replaceAll('\\', '/');
    return normalized;
  }

  /// Generate a user-friendly name from a path
  String _generateNameFromPath(String path) {
    final normalized = _normalizePath(path);
    final parts = normalized.split('/');
    // Use the last non-empty part as the name
    for (var i = parts.length - 1; i >= 0; i--) {
      if (parts[i].isNotEmpty) {
        return parts[i];
      }
    }
    return 'Library';
  }

  /// Clear the cached settings (useful for testing)
  void clearCache() {
    _cachedSettings = null;
  }
}

/// Result of a library location validation
class ValidationResult {
  const ValidationResult({required this.isValid, this.error, this.code});
  final bool isValid;
  final String? error;
  final String? code;
}
