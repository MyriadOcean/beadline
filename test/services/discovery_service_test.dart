import 'dart:convert';
import 'dart:io';

import 'package:beadline/data/settings_storage.dart';
import 'package:beadline/models/app_settings.dart';
import 'package:beadline/models/entry_point_file.dart';
import 'package:beadline/repositories/library_repository.dart';
import 'package:beadline/services/discovery_service.dart';
import 'package:beadline/services/entry_point_file_service.dart';
import 'package:beadline/services/library_location_manager.dart';
import 'package:beadline/services/path_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../models/test_generators.dart';

/// Mock SettingsStorage for testing
class MockSettingsStorage extends SettingsStorage {
  AppSettings _settings = AppSettings.defaults();

  @override
  Future<AppSettings> loadSettings() async => _settings;

  @override
  Future<void> saveSettings(AppSettings settings) async {
    _settings = settings;
  }

  void reset() {
    _settings = AppSettings.defaults();
  }
}

void main() {
  late Directory tempDir;
  late MockSettingsStorage mockSettingsStorage;
  late LibraryLocationManager libraryLocationManager;
  late LibraryRepository libraryRepository;
  late PathResolver pathResolver;
  late EntryPointFileService entryPointFileService;
  late DiscoveryService discoveryService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('discovery_test_');
    mockSettingsStorage = MockSettingsStorage();
    libraryLocationManager = LibraryLocationManager(mockSettingsStorage);
    libraryRepository = LibraryRepository();
    pathResolver = PathResolver([]);
    entryPointFileService = EntryPointFileService(pathResolver);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
    libraryRepository.dispose();
  });

  /// Helper to create an entry point file in a directory
  Future<String> createEntryPointFile(
    String directory,
    EntryPointFile entryPoint,
  ) async {
    final filename =
        '.beadline-${entryPointFileService.sanitizeName(entryPoint.name)}.json';
    final filePath = p.join(directory, filename);

    const encoder = JsonEncoder.withIndent('  ');
    final jsonString = encoder.convert(entryPoint.toJson());

    await File(filePath).writeAsString(jsonString);
    return filePath;
  }

  /// Helper to create an invalid entry point file
  Future<String> createInvalidEntryPointFile(
    String directory,
    String name,
    String content,
  ) async {
    final filename = '.beadline-$name.json';
    final filePath = p.join(directory, filename);
    await File(filePath).writeAsString(content);
    return filePath;
  }

  group('DiscoveryService Tests', () {
    test('scanLocation finds entry point files', () async {
      // Create library location
      final location = await libraryLocationManager.addLocation(
        tempDir.path,
        name: 'Test Library',
      );

      // Update path resolver with the location
      pathResolver = PathResolver([location]);
      entryPointFileService = EntryPointFileService(pathResolver);
      discoveryService = DiscoveryService(
        libraryLocationManager,
        entryPointFileService,
        libraryRepository,
      );

      // Create entry point files
      final entryPoint1 = TestGenerators.randomEntryPointFile();
      final entryPoint2 = TestGenerators.randomEntryPointFile();

      await createEntryPointFile(tempDir.path, entryPoint1);
      await createEntryPointFile(tempDir.path, entryPoint2);

      // Scan location
      final results = await discoveryService.scanLocation(location).toList();

      expect(results.length, equals(2));
      expect(results.every((r) => r.isSuccess), isTrue);
    });

    test('scanLocation finds entry points in subdirectories', () async {
      final location = await libraryLocationManager.addLocation(
        tempDir.path,
        name: 'Test Library',
      );

      pathResolver = PathResolver([location]);
      entryPointFileService = EntryPointFileService(pathResolver);
      discoveryService = DiscoveryService(
        libraryLocationManager,
        entryPointFileService,
        libraryRepository,
      );

      // Create subdirectories with entry points
      final subDir1 = await Directory(p.join(tempDir.path, 'album1')).create();
      final subDir2 = await Directory(
        p.join(tempDir.path, 'album2', 'disc1'),
      ).create(recursive: true);

      await createEntryPointFile(
        tempDir.path,
        TestGenerators.randomEntryPointFile(),
      );
      await createEntryPointFile(
        subDir1.path,
        TestGenerators.randomEntryPointFile(),
      );
      await createEntryPointFile(
        subDir2.path,
        TestGenerators.randomEntryPointFile(),
      );

      final results = await discoveryService.scanLocation(location).toList();

      expect(results.length, equals(3));
    });

    test('scanLocation handles invalid entry point files gracefully', () async {
      final location = await libraryLocationManager.addLocation(
        tempDir.path,
        name: 'Test Library',
      );

      pathResolver = PathResolver([location]);
      entryPointFileService = EntryPointFileService(pathResolver);
      discoveryService = DiscoveryService(
        libraryLocationManager,
        entryPointFileService,
        libraryRepository,
      );

      // Create valid entry point
      await createEntryPointFile(
        tempDir.path,
        TestGenerators.randomEntryPointFile(),
      );

      // Create invalid entry point (missing required fields)
      await createInvalidEntryPointFile(
        tempDir.path,
        'invalid',
        '{"version": 1}',
      );

      // Create invalid JSON
      await createInvalidEntryPointFile(
        tempDir.path,
        'broken',
        'not valid json',
      );

      final results = await discoveryService.scanLocation(location).toList();

      expect(results.length, equals(3));

      final successful = results.where((r) => r.isSuccess).toList();
      final errors = results.where((r) => r.isError).toList();

      expect(successful.length, equals(1));
      expect(errors.length, equals(2));

      // Verify error messages are present
      for (final error in errors) {
        expect(error.error, isNotNull);
        expect(error.error, isNotEmpty);
      }
    });

    test('isAlreadyImported returns true for existing Song Units', () async {
      final location = await libraryLocationManager.addLocation(
        tempDir.path,
        name: 'Test Library',
      );

      pathResolver = PathResolver([location]);
      entryPointFileService = EntryPointFileService(pathResolver);
      discoveryService = DiscoveryService(
        libraryLocationManager,
        entryPointFileService,
        libraryRepository,
      );

      // Add a Song Unit to the library
      final songUnit = TestGenerators.randomSongUnit();
      await libraryRepository.addSongUnit(songUnit);

      // Check if it's already imported
      final isImported = await discoveryService.isAlreadyImported(songUnit.id);
      expect(isImported, isTrue);

      // Check for non-existent ID
      final isNotImported = await discoveryService.isAlreadyImported(
        'non-existent-id',
      );
      expect(isNotImported, isFalse);
    });

    test('importEntryPoint adds new Song Unit to library', () async {
      final location = await libraryLocationManager.addLocation(
        tempDir.path,
        name: 'Test Library',
      );

      pathResolver = PathResolver([location]);
      entryPointFileService = EntryPointFileService(pathResolver);
      discoveryService = DiscoveryService(
        libraryLocationManager,
        entryPointFileService,
        libraryRepository,
      );

      final entryPoint = TestGenerators.randomEntryPointFile();
      final filePath = await createEntryPointFile(tempDir.path, entryPoint);

      // Import the entry point
      final imported = await discoveryService.importEntryPoint(
        entryPoint,
        filePath,
      );

      expect(imported, isNotNull);
      expect(imported!.id, equals(entryPoint.songUnitId));

      // Verify it's in the library
      final inLibrary = await libraryRepository.getSongUnit(
        entryPoint.songUnitId,
      );
      expect(inLibrary, isNotNull);
    });

    test('importEntryPoint skips already imported Song Units', () async {
      final location = await libraryLocationManager.addLocation(
        tempDir.path,
        name: 'Test Library',
      );

      pathResolver = PathResolver([location]);
      entryPointFileService = EntryPointFileService(pathResolver);
      discoveryService = DiscoveryService(
        libraryLocationManager,
        entryPointFileService,
        libraryRepository,
      );

      final entryPoint = TestGenerators.randomEntryPointFile();
      final filePath = await createEntryPointFile(tempDir.path, entryPoint);

      // Import once
      final first = await discoveryService.importEntryPoint(
        entryPoint,
        filePath,
      );
      expect(first, isNotNull);

      // Try to import again
      final second = await discoveryService.importEntryPoint(
        entryPoint,
        filePath,
      );
      expect(second, isNull);

      // Verify only one in library
      final count = await libraryRepository.getSongUnitCount();
      expect(count, equals(1));
    });

    test('scanAllLocations scans all accessible locations', () async {
      // Create multiple library directories
      final dir1 = await Directory(p.join(tempDir.path, 'library1')).create();
      final dir2 = await Directory(p.join(tempDir.path, 'library2')).create();

      final location1 = await libraryLocationManager.addLocation(
        dir1.path,
        name: 'Library 1',
      );
      final location2 = await libraryLocationManager.addLocation(
        dir2.path,
        name: 'Library 2',
      );

      pathResolver = PathResolver([location1, location2]);
      entryPointFileService = EntryPointFileService(pathResolver);
      discoveryService = DiscoveryService(
        libraryLocationManager,
        entryPointFileService,
        libraryRepository,
      );

      // Create entry points in each location
      await createEntryPointFile(
        dir1.path,
        TestGenerators.randomEntryPointFile(),
      );
      await createEntryPointFile(
        dir1.path,
        TestGenerators.randomEntryPointFile(),
      );
      await createEntryPointFile(
        dir2.path,
        TestGenerators.randomEntryPointFile(),
      );

      final results = await discoveryService.scanAllLocations().toList();

      expect(results.length, equals(3));
      expect(results.every((r) => r.isSuccess), isTrue);
    });

    test('summarize provides correct statistics', () async {
      final location = await libraryLocationManager.addLocation(
        tempDir.path,
        name: 'Test Library',
      );

      pathResolver = PathResolver([location]);
      entryPointFileService = EntryPointFileService(pathResolver);
      discoveryService = DiscoveryService(
        libraryLocationManager,
        entryPointFileService,
        libraryRepository,
      );

      // Create some entry points
      final entryPoint1 = TestGenerators.randomEntryPointFile();
      final entryPoint2 = TestGenerators.randomEntryPointFile();

      await createEntryPointFile(tempDir.path, entryPoint1);
      await createEntryPointFile(tempDir.path, entryPoint2);
      await createInvalidEntryPointFile(tempDir.path, 'invalid', 'bad json');

      // Pre-import one entry point
      final songUnit = await entryPointFileService.toSongUnit(
        entryPoint1,
        p.join(
          tempDir.path,
          '.beadline-${entryPointFileService.sanitizeName(entryPoint1.name)}.json',
        ),
      );
      await libraryRepository.addSongUnit(songUnit);

      // Scan and summarize
      final results = await discoveryService.scanLocation(location).toList();
      final summary = discoveryService.summarize(results);

      expect(summary.total, equals(3));
      expect(summary.successful, equals(2));
      expect(summary.errors, equals(1));
      expect(summary.existing, equals(1));
      expect(summary.newCount, equals(1));
    });
  });
}
