import 'dart:convert';
import 'dart:io';

import 'package:beadline/models/entry_point_file.dart';
import 'package:beadline/services/entry_point_file_service.dart';
import 'package:beadline/services/path_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../models/test_generators.dart';

void main() {
  group('EntryPointFileService Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('entry_point_test_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    /// **Feature: storage-locations, Property 2: Entry Point File Serialization Round-Trip**
    /// **Validates: Requirements 5.5**
    ///
    /// For any valid SongUnit, serializing to an entry point file and then
    /// parsing that file SHALL produce a semantically equivalent SongUnit
    /// (same ID, name, sources, tags, and preferences).
    test('Property 2: Entry point serialization round-trip', () async {
      for (var i = 0; i < 100; i++) {
        // Create a storage location using the temp directory
        final location = TestGenerators.randomStorageLocation().copyWith(
          rootPath: tempDir.path,
        );
        final locations = [location];
        final resolver = PathResolver(locations);
        final service = EntryPointFileService(resolver);

        // Generate a SongUnit with local sources within the storage location
        final originalSongUnit = TestGenerators.randomSongUnitWithLocalSources(
          location,
        );

        // Create subdirectory for entry point
        final subDir = Directory(
          p.join(tempDir.path, TestGenerators.randomPathSegment()),
        );
        await subDir.create(recursive: true);

        // Write entry point file
        await service.writeEntryPoint(originalSongUnit, subDir.path);

        // Find the written file
        final files = await subDir.list().toList();
        final entryPointFile = files.whereType<File>().firstWhere(
          (f) => p.basename(f.path).startsWith('.beadline-'),
        );

        // Read and parse the entry point file
        final parsedEntryPoint = await service.readEntryPoint(
          entryPointFile.path,
        );

        // Convert back to SongUnit
        final restoredSongUnit = await service.toSongUnit(
          parsedEntryPoint,
          entryPointFile.path,
        );

        // Verify semantic equivalence
        expect(
          restoredSongUnit.id,
          equals(originalSongUnit.id),
          reason: 'Song Unit ID should be preserved',
        );
        expect(
          restoredSongUnit.metadata.title,
          equals(originalSongUnit.metadata.title),
          reason: 'Title should be preserved',
        );
        expect(
          restoredSongUnit.metadata.artists,
          equals(originalSongUnit.metadata.artists),
          reason: 'Artists should be preserved',
        );
        expect(
          restoredSongUnit.metadata.album,
          equals(originalSongUnit.metadata.album),
          reason: 'Album should be preserved',
        );
        expect(
          restoredSongUnit.tagIds,
          equals(originalSongUnit.tagIds),
          reason: 'Tag IDs should be preserved',
        );

        // Verify source counts match
        expect(
          restoredSongUnit.sources.audioSources.length,
          equals(originalSongUnit.sources.audioSources.length),
          reason: 'Audio source count should be preserved',
        );
        expect(
          restoredSongUnit.sources.displaySources.length,
          equals(originalSongUnit.sources.displaySources.length),
          reason: 'Display source count should be preserved',
        );
        expect(
          restoredSongUnit.sources.hoverSources.length,
          equals(originalSongUnit.sources.hoverSources.length),
          reason: 'Hover source count should be preserved',
        );

        // Clean up subdirectory
        await subDir.delete(recursive: true);
      }
    });

    /// **Feature: storage-locations, Property 3: Filename Generation with Sanitization**
    /// **Validates: Requirements 4.1, 4.5**
    ///
    /// For any Song Unit name (including names with invalid filename characters),
    /// the generated entry point filename SHALL be a valid filename, and the
    /// parsed entry point file SHALL preserve the original Song Unit name in metadata.
    test('Property 3: Filename generation with sanitization', () {
      final location = TestGenerators.randomStorageLocation().copyWith(
        rootPath: tempDir.path,
      );
      final resolver = PathResolver([location]);
      final service = EntryPointFileService(resolver);

      for (var i = 0; i < 100; i++) {
        // Generate a name with potentially invalid characters
        final originalName =
            TestGenerators.randomSongUnitNameWithSpecialChars();

        // Generate filename
        final filename = service.generateFilename(originalName);

        // Verify filename is valid (no invalid characters)
        const invalidChars = r'<>:"/\|?*';
        for (final char in invalidChars.split('')) {
          expect(
            filename.contains(char),
            isFalse,
            reason: 'Filename should not contain invalid character: $char',
          );
        }

        // Verify filename has correct format
        expect(
          filename.startsWith(EntryPointFile.filePrefix),
          isTrue,
          reason: 'Filename should start with ${EntryPointFile.filePrefix}',
        );
        expect(
          filename.endsWith(EntryPointFile.fileExtension),
          isTrue,
          reason: 'Filename should end with ${EntryPointFile.fileExtension}',
        );

        // Verify filename is not empty (excluding prefix and extension)
        final nameOnly = filename
            .substring(EntryPointFile.filePrefix.length)
            .replaceAll(EntryPointFile.fileExtension, '');
        expect(
          nameOnly.isNotEmpty,
          isTrue,
          reason: 'Sanitized name should not be empty',
        );
      }
    });

    /// **Feature: storage-locations, Property 4: Entry Point File Required Fields**
    /// **Validates: Requirements 5.1, 5.2, 5.3**
    ///
    /// For any entry point file created by the system, the file SHALL contain
    /// version, songUnitId, name, and sources fields. For any entry point file
    /// missing required fields, parsing SHALL produce a specific validation error.
    test(
      'Property 4: Entry point file required fields - created files have all fields',
      () async {
        for (var i = 0; i < 100; i++) {
          final location = TestGenerators.randomStorageLocation().copyWith(
            rootPath: tempDir.path,
          );
          final resolver = PathResolver([location]);
          final service = EntryPointFileService(resolver);

          final songUnit = TestGenerators.randomSongUnitWithLocalSources(
            location,
          );

          // Create subdirectory
          final subDir = Directory(
            p.join(tempDir.path, TestGenerators.randomPathSegment()),
          );
          await subDir.create(recursive: true);

          // Write entry point file
          await service.writeEntryPoint(songUnit, subDir.path);

          // Find and read the file directly as JSON
          final files = await subDir.list().toList();
          final entryPointFile = files.whereType<File>().firstWhere(
            (f) => p.basename(f.path).startsWith('.beadline-'),
          );

          final content = await entryPointFile.readAsString();
          final json = jsonDecode(content) as Map<String, dynamic>;

          // Verify all required fields are present
          expect(
            json.containsKey('version'),
            isTrue,
            reason: 'Entry point file should contain version field',
          );
          expect(
            json.containsKey('songUnitId'),
            isTrue,
            reason: 'Entry point file should contain songUnitId field',
          );
          expect(
            json.containsKey('name'),
            isTrue,
            reason: 'Entry point file should contain name field',
          );
          expect(
            json.containsKey('sources'),
            isTrue,
            reason: 'Entry point file should contain sources field',
          );

          // Verify version is valid
          expect(
            json['version'],
            isA<int>(),
            reason: 'Version should be an integer',
          );
          expect(
            json['version'],
            greaterThan(0),
            reason: 'Version should be positive',
          );

          // Clean up
          await subDir.delete(recursive: true);
        }
      },
    );

    test('Property 4: Missing required fields produce specific errors', () {
      final location = TestGenerators.randomStorageLocation().copyWith(
        rootPath: tempDir.path,
      );
      final resolver = PathResolver([location]);
      final service = EntryPointFileService(resolver);

      // Test missing version
      expect(
        () => service.parseEntryPoint(
          '{"songUnitId": "test", "name": "test", "sources": [], "createdAt": "2025-01-01T00:00:00Z", "modifiedAt": "2025-01-01T00:00:00Z"}',
          '/test/path',
        ),
        throwsA(
          isA<EntryPointValidationException>().having(
            (e) => e.field,
            'field',
            'version',
          ),
        ),
        reason: 'Missing version should throw with field=version',
      );

      // Test missing songUnitId
      expect(
        () => service.parseEntryPoint(
          '{"version": 1, "name": "test", "sources": [], "createdAt": "2025-01-01T00:00:00Z", "modifiedAt": "2025-01-01T00:00:00Z"}',
          '/test/path',
        ),
        throwsA(
          isA<EntryPointValidationException>().having(
            (e) => e.field,
            'field',
            'songUnitId',
          ),
        ),
        reason: 'Missing songUnitId should throw with field=songUnitId',
      );

      // Test missing name
      expect(
        () => service.parseEntryPoint(
          '{"version": 1, "songUnitId": "test", "sources": [], "createdAt": "2025-01-01T00:00:00Z", "modifiedAt": "2025-01-01T00:00:00Z"}',
          '/test/path',
        ),
        throwsA(
          isA<EntryPointValidationException>().having(
            (e) => e.field,
            'field',
            'name',
          ),
        ),
        reason: 'Missing name should throw with field=name',
      );

      // Test missing sources
      expect(
        () => service.parseEntryPoint(
          '{"version": 1, "songUnitId": "test", "name": "test", "createdAt": "2025-01-01T00:00:00Z", "modifiedAt": "2025-01-01T00:00:00Z"}',
          '/test/path',
        ),
        throwsA(
          isA<EntryPointValidationException>().having(
            (e) => e.field,
            'field',
            'sources',
          ),
        ),
        reason: 'Missing sources should throw with field=sources',
      );

      // Test invalid JSON
      expect(
        () => service.parseEntryPoint('not valid json', '/test/path'),
        throwsA(isA<EntryPointValidationException>()),
        reason: 'Invalid JSON should throw validation exception',
      );
    });

    /// **Feature: storage-locations, Property 13: Serialization Uses Relative Paths**
    /// **Validates: Requirements 2.5**
    ///
    /// For any Song Unit with local file sources within a storage location,
    /// the serialized JSON SHALL contain relative paths (starting with `./`
    /// or `@storage/`) rather than absolute paths.
    test('Property 13: Serialization uses relative paths', () async {
      for (var i = 0; i < 100; i++) {
        final location = TestGenerators.randomStorageLocation().copyWith(
          rootPath: tempDir.path,
        );
        final resolver = PathResolver([location]);
        final service = EntryPointFileService(resolver);

        final songUnit = TestGenerators.randomSongUnitWithLocalSources(
          location,
        );

        // Create subdirectory
        final subDir = Directory(
          p.join(tempDir.path, TestGenerators.randomPathSegment()),
        );
        await subDir.create(recursive: true);

        // Write entry point file
        await service.writeEntryPoint(songUnit, subDir.path);

        // Find and read the file
        final files = await subDir.list().toList();
        final entryPointFile = files.whereType<File>().firstWhere(
          (f) => p.basename(f.path).startsWith('.beadline-'),
        );

        final content = await entryPointFile.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        final sources = json['sources'] as List<dynamic>;

        // Verify all local file sources use relative paths
        for (final source in sources) {
          final sourceMap = source as Map<String, dynamic>;
          if (sourceMap['originType'] == 'localFile') {
            final path = sourceMap['path'] as String;

            // Path should be relative (start with ./ or @library/)
            final isRelative =
                path.startsWith('./') || path.startsWith('@library/');
            expect(
              isRelative,
              isTrue,
              reason: 'Local file path should be relative: $path',
            );

            // Path should NOT be absolute
            expect(
              p.isAbsolute(path),
              isFalse,
              reason: 'Local file path should not be absolute: $path',
            );
          }
        }

        // Clean up
        await subDir.delete(recursive: true);
      }
    });

    test('sanitizeName handles edge cases', () {
      final location = TestGenerators.randomStorageLocation();
      final resolver = PathResolver([location]);
      final service = EntryPointFileService(resolver);

      // Empty string
      expect(service.sanitizeName(''), equals('unnamed'));

      // Only invalid characters
      expect(service.sanitizeName('<>:"/\\|?*'), equals('unnamed'));

      // Leading/trailing dots
      expect(service.sanitizeName('...test...'), equals('test'));

      // Multiple underscores
      expect(service.sanitizeName('a___b'), equals('a_b'));

      // Very long name
      final longName = 'a' * 200;
      expect(service.sanitizeName(longName).length, lessThanOrEqualTo(100));

      // Normal name preserved
      expect(service.sanitizeName('My Song'), equals('My Song'));
    });

    test('JSON output is formatted with 2-space indentation', () async {
      final location = TestGenerators.randomStorageLocation().copyWith(
        rootPath: tempDir.path,
      );
      final resolver = PathResolver([location]);
      final service = EntryPointFileService(resolver);

      final songUnit = TestGenerators.randomSongUnitWithLocalSources(location);

      // Create subdirectory
      final subDir = Directory(p.join(tempDir.path, 'test_indent'));
      await subDir.create(recursive: true);

      // Write entry point file
      await service.writeEntryPoint(songUnit, subDir.path);

      // Find and read the file
      final files = await subDir.list().toList();
      final entryPointFile = files.whereType<File>().firstWhere(
        (f) => p.basename(f.path).startsWith('.beadline-'),
      );

      final content = await entryPointFile.readAsString();

      // Verify indentation (should have lines starting with 2 spaces)
      final lines = content.split('\n');
      final indentedLines = lines.where(
        (l) => l.startsWith('  ') && !l.startsWith('    '),
      );
      expect(
        indentedLines.isNotEmpty,
        isTrue,
        reason: 'JSON should have 2-space indented lines',
      );

      // Clean up
      await subDir.delete(recursive: true);
    });
  });
}
