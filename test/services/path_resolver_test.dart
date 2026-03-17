import 'package:beadline/services/path_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../models/test_generators.dart';

void main() {
  group('PathResolver Tests', () {
    /// **Feature: storage-locations, Property 1: Path Conversion Round-Trip**
    /// **Validates: Requirements 2.1, 2.2**
    ///
    /// For any absolute path within a storage location, converting to a
    /// relative path and then back to an absolute path SHALL produce the
    /// original absolute path.
    test('Property 1: Path conversion round-trip', () {
      for (var i = 0; i < 100; i++) {
        // Generate random storage locations
        final locations = TestGenerators.randomStorageLocations(maxCount: 3);
        final resolver = PathResolver(locations);

        // Pick a random location and generate a path within it
        final location =
            locations[TestGenerators.randomInt(0, locations.length - 1)];
        final originalPath = TestGenerators.randomAbsolutePathInStorage(
          location,
        );

        // Convert to relative path
        final relativePath = resolver.toRelativePath(originalPath);

        // Should successfully convert to relative path
        expect(
          relativePath,
          isNotNull,
          reason: 'Path within storage should convert to relative',
        );
        expect(
          relativePath!.startsWith('@library/'),
          isTrue,
          reason: 'Relative path should have @library/ prefix',
        );

        // Convert back to absolute path
        final restoredPath = resolver.toAbsolutePath(relativePath, location.id);

        // Normalize both paths for comparison
        final normalizedOriginal = p.normalize(originalPath);
        final normalizedRestored = p.normalize(restoredPath);

        expect(
          normalizedRestored,
          equals(normalizedOriginal),
          reason: 'Round-trip should preserve the original path',
        );
      }
    });

    test('toRelativePath returns null for paths outside storage locations', () {
      for (var i = 0; i < 100; i++) {
        final locations = TestGenerators.randomStorageLocations(maxCount: 3);
        final resolver = PathResolver(locations);

        final outsidePath = TestGenerators.randomAbsolutePathOutsideStorage(
          locations,
        );
        final relativePath = resolver.toRelativePath(outsidePath);

        expect(
          relativePath,
          isNull,
          reason: 'Path outside storage should return null',
        );
      }
    });

    test('findStorageLocation returns correct location', () {
      for (var i = 0; i < 100; i++) {
        final locations = TestGenerators.randomStorageLocations(minCount: 2);
        final resolver = PathResolver(locations);

        // Pick a random location and generate a path within it
        final expectedLocation =
            locations[TestGenerators.randomInt(0, locations.length - 1)];
        final testPath = TestGenerators.randomAbsolutePathInStorage(
          expectedLocation,
        );

        final foundLocation = resolver.findStorageLocation(testPath);

        expect(
          foundLocation,
          isNotNull,
          reason: 'Should find storage location for path within it',
        );
        expect(
          foundLocation!.id,
          equals(expectedLocation.id),
          reason: 'Should find the correct storage location',
        );
      }
    });

    test(
      'findStorageLocation returns null for paths outside all locations',
      () {
        for (var i = 0; i < 100; i++) {
          final locations = TestGenerators.randomStorageLocations(maxCount: 3);
          final resolver = PathResolver(locations);

          final outsidePath = TestGenerators.randomAbsolutePathOutsideStorage(
            locations,
          );
          final foundLocation = resolver.findStorageLocation(outsidePath);

          expect(
            foundLocation,
            isNull,
            reason: 'Should return null for path outside all locations',
          );
        }
      },
    );

    test('toAbsolutePath handles @storage/ prefix correctly', () {
      for (var i = 0; i < 100; i++) {
        final locations = TestGenerators.randomStorageLocations(maxCount: 3);
        final resolver = PathResolver(locations);

        final location =
            locations[TestGenerators.randomInt(0, locations.length - 1)];
        final subPath =
            '${TestGenerators.randomPathSegment()}/${TestGenerators.randomPathSegment()}.${TestGenerators.randomFileExtension()}';
        final relativePath = '@storage/$subPath';

        final absolutePath = resolver.toAbsolutePath(relativePath, location.id);
        final expectedPath = p.normalize(p.join(location.rootPath, subPath));

        expect(
          absolutePath,
          equals(expectedPath),
          reason: '@storage/ prefix should resolve against storage root',
        );
      }
    });

    test('toAbsolutePath preserves absolute paths', () {
      for (var i = 0; i < 100; i++) {
        final locations = TestGenerators.randomStorageLocations(maxCount: 3);
        final resolver = PathResolver(locations);

        final location = locations[0];
        const absolutePath = '/some/absolute/path/file.mp3';

        final result = resolver.toAbsolutePath(absolutePath, location.id);

        expect(
          result,
          equals(p.normalize(absolutePath)),
          reason: 'Absolute paths should be preserved',
        );
      }
    });

    test('toAbsolutePath throws for unknown storage location ID', () {
      final locations = TestGenerators.randomStorageLocations(maxCount: 3);
      final resolver = PathResolver(locations);

      expect(
        () => resolver.toAbsolutePath('@storage/some/path.mp3', 'unknown-id'),
        throwsArgumentError,
        reason: 'Should throw for unknown storage location ID',
      );
    });

    test('toSerializablePath uses ./ for paths in entry point directory', () {
      for (var i = 0; i < 100; i++) {
        final locations = TestGenerators.randomStorageLocations(maxCount: 3);
        final resolver = PathResolver(locations);

        final location =
            locations[TestGenerators.randomInt(0, locations.length - 1)];
        final entryPointPath = TestGenerators.randomEntryPointPath(location);
        final entryPointDir = p.dirname(entryPointPath);

        // Create a path in the same directory as entry point
        final filename = '${TestGenerators.randomPathSegment()}.mp3';
        final absolutePath = p.join(entryPointDir, filename);

        final serializedPath = resolver.toSerializablePath(
          absolutePath,
          entryPointPath,
        );

        expect(
          serializedPath.startsWith('./'),
          isTrue,
          reason: 'Paths in entry point directory should use ./ prefix',
        );
        expect(
          serializedPath,
          equals('./$filename'),
          reason: 'Should be relative to entry point directory',
        );
      }
    });

    test(
      'toSerializablePath uses @library/ for paths elsewhere in storage',
      () {
        for (var i = 0; i < 100; i++) {
          final locations = TestGenerators.randomStorageLocations(maxCount: 3);
          final resolver = PathResolver(locations);

          final location =
              locations[TestGenerators.randomInt(0, locations.length - 1)];

          // Create entry point in a subdirectory
          final entryPointPath =
              '${location.rootPath}/subdir/.beadline-test.json';

          // Create a path in a different subdirectory of the same storage
          final absolutePath = '${location.rootPath}/other/file.mp3';

          final serializedPath = resolver.toSerializablePath(
            absolutePath,
            entryPointPath,
          );

          expect(
            serializedPath.startsWith('@library/'),
            isTrue,
            reason: 'Paths elsewhere in storage should use @library/ prefix',
          );
        }
      },
    );

    test('toSerializablePath preserves absolute paths outside storage', () {
      for (var i = 0; i < 100; i++) {
        final locations = TestGenerators.randomStorageLocations(maxCount: 3);
        final resolver = PathResolver(locations);

        final location = locations[0];
        final entryPointPath = TestGenerators.randomEntryPointPath(location);
        final outsidePath = TestGenerators.randomAbsolutePathOutsideStorage(
          locations,
        );

        final serializedPath = resolver.toSerializablePath(
          outsidePath,
          entryPointPath,
        );

        expect(
          serializedPath,
          equals(p.normalize(outsidePath)),
          reason: 'Paths outside storage should be preserved as absolute',
        );
      }
    });

    /// **Feature: storage-locations, Property 9: Path Resolution from Entry Point**
    /// **Validates: Requirements 4.4**
    ///
    /// For any relative path in an entry point file starting with `./`,
    /// resolving against the entry point file's directory SHALL produce a path
    /// in the same directory or a subdirectory of the entry point file.
    test('Property 9: Path resolution from entry point stays within bounds', () {
      for (var i = 0; i < 100; i++) {
        final locations = TestGenerators.randomStorageLocations(maxCount: 3);
        final resolver = PathResolver(locations);

        final location =
            locations[TestGenerators.randomInt(0, locations.length - 1)];
        final entryPointPath = TestGenerators.randomEntryPointPath(location);
        final entryPointDir = p.dirname(entryPointPath);

        // Generate a relative path with ./ prefix
        final subPath = TestGenerators.randomInt(0, 1) == 0
            ? '${TestGenerators.randomPathSegment()}.mp3'
            : '${TestGenerators.randomPathSegment()}/${TestGenerators.randomPathSegment()}.mp3';
        final relativePath = './$subPath';

        // Resolve the path
        final resolvedPath = resolver.resolveFromEntryPoint(
          relativePath,
          entryPointPath,
        );

        // Verify the resolved path is within or equal to entry point directory
        final normalizedResolved = p.normalize(resolvedPath);
        final normalizedEntryDir = p.normalize(entryPointDir);

        expect(
          normalizedResolved.startsWith(normalizedEntryDir),
          isTrue,
          reason:
              'Resolved path should be within entry point directory. '
              'Entry dir: $normalizedEntryDir, Resolved: $normalizedResolved',
        );
      }
    });

    test('resolveFromEntryPoint handles ./ prefix correctly', () {
      for (var i = 0; i < 100; i++) {
        final locations = TestGenerators.randomStorageLocations(maxCount: 3);
        final resolver = PathResolver(locations);

        final location =
            locations[TestGenerators.randomInt(0, locations.length - 1)];
        final entryPointPath = TestGenerators.randomEntryPointPath(location);
        final entryPointDir = p.dirname(entryPointPath);

        final filename = '${TestGenerators.randomPathSegment()}.mp3';
        final relativePath = './$filename';

        final resolvedPath = resolver.resolveFromEntryPoint(
          relativePath,
          entryPointPath,
        );
        final expectedPath = p.normalize(p.join(entryPointDir, filename));

        expect(
          resolvedPath,
          equals(expectedPath),
          reason: './ prefix should resolve relative to entry point directory',
        );
      }
    });

    test('resolveFromEntryPoint handles @storage/ prefix correctly', () {
      for (var i = 0; i < 100; i++) {
        final locations = TestGenerators.randomStorageLocations(maxCount: 3);
        final resolver = PathResolver(locations);

        final location =
            locations[TestGenerators.randomInt(0, locations.length - 1)];
        final entryPointPath = TestGenerators.randomEntryPointPath(location);

        final subPath =
            '${TestGenerators.randomPathSegment()}/${TestGenerators.randomPathSegment()}.mp3';
        final relativePath = '@storage/$subPath';

        final resolvedPath = resolver.resolveFromEntryPoint(
          relativePath,
          entryPointPath,
        );
        final expectedPath = p.normalize(p.join(location.rootPath, subPath));

        expect(
          resolvedPath,
          equals(expectedPath),
          reason: '@storage/ prefix should resolve relative to storage root',
        );
      }
    });

    test('resolveFromEntryPoint preserves absolute paths', () {
      for (var i = 0; i < 100; i++) {
        final locations = TestGenerators.randomStorageLocations(maxCount: 3);
        final resolver = PathResolver(locations);

        final location = locations[0];
        final entryPointPath = TestGenerators.randomEntryPointPath(location);
        const absolutePath = '/some/absolute/path/file.mp3';

        final resolvedPath = resolver.resolveFromEntryPoint(
          absolutePath,
          entryPointPath,
        );

        expect(
          resolvedPath,
          equals(p.normalize(absolutePath)),
          reason: 'Absolute paths should be preserved',
        );
      }
    });

    test('resolveFromEntryPoint round-trip with toSerializablePath', () {
      for (var i = 0; i < 100; i++) {
        final locations = TestGenerators.randomStorageLocations(maxCount: 3);
        final resolver = PathResolver(locations);

        final location =
            locations[TestGenerators.randomInt(0, locations.length - 1)];
        final entryPointPath = TestGenerators.randomEntryPointPath(location);
        final entryPointDir = p.dirname(entryPointPath);

        // Create an absolute path in the entry point directory
        final filename = '${TestGenerators.randomPathSegment()}.mp3';
        final originalPath = p.join(entryPointDir, filename);

        // Convert to serializable path
        final serializedPath = resolver.toSerializablePath(
          originalPath,
          entryPointPath,
        );

        // Resolve back
        final resolvedPath = resolver.resolveFromEntryPoint(
          serializedPath,
          entryPointPath,
        );

        expect(
          p.normalize(resolvedPath),
          equals(p.normalize(originalPath)),
          reason: 'Round-trip should preserve the original path',
        );
      }
    });
  });
}
