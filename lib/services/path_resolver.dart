import 'package:path/path.dart' as p;

import '../models/library_location.dart';

/// Handles conversion between absolute and relative paths for library locations.
///
/// Relative path formats:
/// - `./` prefix: relative to entry point file location
/// - `@library/` prefix: relative to library location root
/// - Absolute paths: preserved for files outside library locations
class PathResolver {
  PathResolver(List<LibraryLocation> libraryLocations)
      : _libraryLocations = List.of(libraryLocations);
  List<LibraryLocation> _libraryLocations;

  /// Update the library locations used for path resolution.
  void updateLocations(List<LibraryLocation> locations) {
    _libraryLocations = List.of(locations);
  }

  /// Convert absolute path to relative path.
  ///
  /// Returns a path with `@library/` prefix if within a library location,
  /// or null if the path is not within any library location.
  String? toRelativePath(String absolutePath) {
    final normalizedPath = p.normalize(absolutePath);
    final location = findLibraryLocation(normalizedPath);

    if (location == null) {
      return null;
    }

    final normalizedRoot = p.normalize(location.rootPath);
    final relativePath = p.relative(normalizedPath, from: normalizedRoot);

    // Ensure the relative path doesn't escape the library root
    if (relativePath.startsWith('..')) {
      return null;
    }

    return '@library/$relativePath';
  }

  /// Convert relative path to absolute path using library location context.
  ///
  /// Handles:
  /// - `@library/` prefix: resolves against library location root
  /// - `./` prefix: should use [resolveFromEntryPoint] instead
  /// - Absolute paths: returned as-is
  String toAbsolutePath(String relativePath, String libraryLocationId) {
    // If already absolute, return as-is
    if (p.isAbsolute(relativePath)) {
      return p.normalize(relativePath);
    }

    // Handle @library/ prefix
    if (relativePath.startsWith('@library/')) {
      final location = _findLocationById(libraryLocationId);
      if (location == null) {
        throw ArgumentError('Library location not found: $libraryLocationId');
      }

      final pathWithoutPrefix = relativePath.substring('@library/'.length);
      return p.normalize(p.join(location.rootPath, pathWithoutPrefix));
    }

    // Handle @storage/ prefix for backward compatibility
    if (relativePath.startsWith('@storage/')) {
      final location = _findLocationById(libraryLocationId);
      if (location == null) {
        throw ArgumentError('Library location not found: $libraryLocationId');
      }

      final pathWithoutPrefix = relativePath.substring('@storage/'.length);
      return p.normalize(p.join(location.rootPath, pathWithoutPrefix));
    }

    // Handle ./ prefix - this should typically use resolveFromEntryPoint
    // but we handle it here for completeness
    if (relativePath.startsWith('./')) {
      final location = _findLocationById(libraryLocationId);
      if (location == null) {
        throw ArgumentError('Library location not found: $libraryLocationId');
      }

      final pathWithoutPrefix = relativePath.substring(2);
      return p.normalize(p.join(location.rootPath, pathWithoutPrefix));
    }

    // Treat as relative to library root
    final location = _findLocationById(libraryLocationId);
    if (location == null) {
      throw ArgumentError('Library location not found: $libraryLocationId');
    }

    return p.normalize(p.join(location.rootPath, relativePath));
  }

  /// Find which library location contains a path.
  ///
  /// Returns the library location that contains the given absolute path,
  /// or null if the path is not within any library location.
  LibraryLocation? findLibraryLocation(String absolutePath) {
    final normalizedPath = p.normalize(absolutePath);

    for (final location in _libraryLocations) {
      final normalizedRoot = p.normalize(location.rootPath);

      // Check if the path starts with the library root
      if (_isPathWithin(normalizedPath, normalizedRoot)) {
        return location;
      }
    }

    return null;
  }

  /// Alias for findLibraryLocation for backward compatibility
  LibraryLocation? findStorageLocation(String absolutePath) =>
      findLibraryLocation(absolutePath);

  /// Resolve a relative path from an entry point file location.
  ///
  /// Handles:
  /// - `./` prefix: relative to entry point file's directory
  /// - `@library/` prefix: relative to library location root
  /// - `@storage/` prefix: relative to library location root (backward compatibility)
  /// - Absolute paths: returned as-is
  String resolveFromEntryPoint(String relativePath, String entryPointPath) {
    // If already absolute, return as-is
    if (p.isAbsolute(relativePath)) {
      return p.normalize(relativePath);
    }

    // Handle @library/ prefix
    if (relativePath.startsWith('@library/')) {
      final location = findLibraryLocation(entryPointPath);
      if (location == null) {
        throw ArgumentError(
          'Entry point is not within any library location: $entryPointPath',
        );
      }

      final pathWithoutPrefix = relativePath.substring('@library/'.length);
      return p.normalize(p.join(location.rootPath, pathWithoutPrefix));
    }

    // Handle @storage/ prefix for backward compatibility
    if (relativePath.startsWith('@storage/')) {
      final location = findLibraryLocation(entryPointPath);
      if (location == null) {
        throw ArgumentError(
          'Entry point is not within any library location: $entryPointPath',
        );
      }

      final pathWithoutPrefix = relativePath.substring('@storage/'.length);
      return p.normalize(p.join(location.rootPath, pathWithoutPrefix));
    }

    // Handle ./ prefix - relative to entry point directory
    final entryPointDir = p.dirname(entryPointPath);

    if (relativePath.startsWith('./')) {
      final pathWithoutPrefix = relativePath.substring(2);
      return p.normalize(p.join(entryPointDir, pathWithoutPrefix));
    }

    // Treat bare relative paths as relative to entry point directory
    return p.normalize(p.join(entryPointDir, relativePath));
  }

  /// Convert an absolute path to a relative path for serialization in entry point files.
  ///
  /// Returns:
  /// - `./relative/path` if the file is in the same directory or subdirectory as entry point
  /// - `@library/relative/path` if the file is elsewhere in the SAME library location as the entry point
  /// - The original absolute path if outside all library locations OR in a different library location
  String toSerializablePath(String absolutePath, String entryPointPath) {
    final normalizedPath = p.normalize(absolutePath);
    final entryPointDir = p.dirname(entryPointPath);
    final normalizedEntryDir = p.normalize(entryPointDir);

    // Check if path is within entry point directory
    if (_isPathWithin(normalizedPath, normalizedEntryDir)) {
      final relativePath = p.relative(normalizedPath, from: normalizedEntryDir);
      return './$relativePath';
    }

    // Find the library location of the entry point
    final entryPointLocation = findLibraryLocation(entryPointPath);

    // Find the library location of the file
    final fileLocation = findLibraryLocation(normalizedPath);

    // Only use @library/ if the file is in the SAME library location as the entry point
    // This ensures that @library/ paths can be correctly resolved from the entry point
    if (fileLocation != null &&
        entryPointLocation != null &&
        fileLocation.id == entryPointLocation.id) {
      final normalizedRoot = p.normalize(fileLocation.rootPath);
      final relativePath = p.relative(normalizedPath, from: normalizedRoot);
      return '@library/$relativePath';
    }

    // Return absolute path for files outside library locations or in different library locations
    return normalizedPath;
  }

  LibraryLocation? _findLocationById(String id) {
    for (final location in _libraryLocations) {
      if (location.id == id) {
        return location;
      }
    }
    return null;
  }

  bool _isPathWithin(String path, String root) {
    // Ensure both paths end without trailing separator for consistent comparison
    final normalizedPath = p.normalize(path);
    final normalizedRoot = p.normalize(root);

    // Check if path equals root or starts with root + separator
    if (normalizedPath == normalizedRoot) {
      return true;
    }

    // Ensure we're checking for a proper directory boundary
    final rootWithSep = normalizedRoot.endsWith(p.separator)
        ? normalizedRoot
        : '$normalizedRoot${p.separator}';

    return normalizedPath.startsWith(rootWithSep);
  }
}
