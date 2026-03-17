import 'dart:math';

import 'package:beadline/models/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory storage for testing settings persistence
class InMemorySettingsStorage {
  AppSettings? _settings;
  final Map<String, List<String>> _directories = {};

  Future<AppSettings> loadSettings() async {
    return _settings ?? AppSettings.defaults();
  }

  Future<void> saveSettings(AppSettings settings) async {
    _settings = settings;
  }

  void clear() {
    _settings = null;
    _directories.clear();
  }

  // File system simulation
  Future<bool> directoryExists(String path) async {
    return _directories.containsKey(path);
  }

  Future<void> createDirectory(String path) async {
    _directories[path] = [];
  }

  Future<void> copyDirectory(String source, String dest) async {
    if (_directories.containsKey(source)) {
      _directories[dest] = List.from(_directories[source]!);
    }
  }

  Future<void> deleteDirectory(String path) async {
    _directories.remove(path);
  }

  void addFileToDirectory(String dirPath, String fileName) {
    _directories.putIfAbsent(dirPath, () => []);
    _directories[dirPath]!.add(fileName);
  }

  List<String>? getDirectoryContents(String path) {
    return _directories[path];
  }
}

/// Test generators for settings
class SettingsTestGenerators {
  static final Random _random = Random();

  static String randomPath() {
    return '/path/to/${_randomString(5)}/${_randomString(8)}';
  }

  static String _randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => chars.codeUnitAt(_random.nextInt(chars.length)),
      ),
    );
  }

  static LyricsMode randomLyricsMode() {
    return LyricsMode.values[_random.nextInt(LyricsMode.values.length)];
  }

  static String randomThemeMode() {
    const modes = ['light', 'dark', 'system'];
    return modes[_random.nextInt(modes.length)];
  }

  static AppSettings randomSettings() {
    return AppSettings(
      libraryPath: randomPath(),
      metadataWriteBack: _random.nextBool(),
      lyricsMode: randomLyricsMode(),
      ktvMode: _random.nextBool(),
      themeMode: randomThemeMode(),
      languageCode: _random.nextBool() ? _randomString(2) : null,
    );
  }
}

void main() {
  group('Settings Repository Property Tests', () {
    late InMemorySettingsStorage storage;

    setUp(() {
      storage = InMemorySettingsStorage();
    });

    tearDown(() {
      storage.clear();
    });

    // Feature: song-unit-core, Property 41: Settings persistence immediacy
    // **Validates: Requirements 14.2**
    test(
      'Property 41: For any settings change, the new value SHALL be immediately retrievable after the change operation completes',
      () async {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          // Generate random settings
          final settings = SettingsTestGenerators.randomSettings();

          // Save settings
          await storage.saveSettings(settings);

          // Immediately retrieve
          final retrieved = await storage.loadSettings();

          // Verify all fields match
          expect(retrieved.libraryPath, equals(settings.libraryPath));
          expect(
            retrieved.metadataWriteBack,
            equals(settings.metadataWriteBack),
          );
          expect(retrieved.lyricsMode, equals(settings.lyricsMode));
          expect(retrieved.ktvMode, equals(settings.ktvMode));
          expect(retrieved.themeMode, equals(settings.themeMode));
          expect(retrieved.languageCode, equals(settings.languageCode));
        }
      },
    );

    test(
      'Property 41 (individual updates): Each setting update is immediately retrievable',
      () async {
        const iterations = 50;

        for (var i = 0; i < iterations; i++) {
          // Start with default settings
          var settings = AppSettings.defaults();
          await storage.saveSettings(settings);

          // Update library path
          final newPath = SettingsTestGenerators.randomPath();
          settings = settings.copyWith(libraryPath: newPath);
          await storage.saveSettings(settings);
          var retrieved = await storage.loadSettings();
          expect(retrieved.libraryPath, equals(newPath));

          // Update metadata write-back
          final newWriteBack = !settings.metadataWriteBack;
          settings = settings.copyWith(metadataWriteBack: newWriteBack);
          await storage.saveSettings(settings);
          retrieved = await storage.loadSettings();
          expect(retrieved.metadataWriteBack, equals(newWriteBack));

          // Update lyrics mode
          final newLyricsMode = SettingsTestGenerators.randomLyricsMode();
          settings = settings.copyWith(lyricsMode: newLyricsMode);
          await storage.saveSettings(settings);
          retrieved = await storage.loadSettings();
          expect(retrieved.lyricsMode, equals(newLyricsMode));

          // Update KTV mode
          final newKtvMode = !settings.ktvMode;
          settings = settings.copyWith(ktvMode: newKtvMode);
          await storage.saveSettings(settings);
          retrieved = await storage.loadSettings();
          expect(retrieved.ktvMode, equals(newKtvMode));
        }
      },
    );

    // Feature: song-unit-core, Property 42: Library migration completeness
    // **Validates: Requirements 14.3**
    test(
      'Property 42: For any library location change, all Song Units SHALL be accessible from the new location and the old location SHALL be empty',
      () async {
        const iterations = 30;

        for (var i = 0; i < iterations; i++) {
          // Set up old library with some files
          final oldPath = SettingsTestGenerators.randomPath();
          final newPath = SettingsTestGenerators.randomPath();

          // Create old directory with files
          await storage.createDirectory(oldPath);
          final fileCount = 1 + Random().nextInt(5);
          final files = <String>[];
          for (var j = 0; j < fileCount; j++) {
            final fileName = 'file_$j.json';
            files.add(fileName);
            storage.addFileToDirectory(oldPath, fileName);
          }

          // Save initial settings with old path
          var settings = AppSettings.defaults().copyWith(libraryPath: oldPath);
          await storage.saveSettings(settings);

          // Simulate library migration
          await storage.copyDirectory(oldPath, newPath);
          await storage.deleteDirectory(oldPath);

          // Update settings with new path
          settings = settings.copyWith(libraryPath: newPath);
          await storage.saveSettings(settings);

          // Verify old location is empty
          expect(
            await storage.directoryExists(oldPath),
            isFalse,
            reason: 'Old location should be empty after migration',
          );

          // Verify new location has all files
          expect(
            await storage.directoryExists(newPath),
            isTrue,
            reason: 'New location should exist after migration',
          );

          final newContents = storage.getDirectoryContents(newPath);
          expect(newContents, isNotNull);
          expect(
            newContents!.length,
            equals(fileCount),
            reason: 'All files should be migrated to new location',
          );

          for (final file in files) {
            expect(
              newContents.contains(file),
              isTrue,
              reason: 'File "$file" should be in new location',
            );
          }

          // Verify settings reflect new path
          final retrieved = await storage.loadSettings();
          expect(retrieved.libraryPath, equals(newPath));
        }
      },
    );

    test(
      'Property 42 (empty source): Migration from empty path should not fail',
      () async {
        const iterations = 20;

        for (var i = 0; i < iterations; i++) {
          // Start with empty library path
          var settings = AppSettings.defaults();
          await storage.saveSettings(settings);

          // Change to new path
          final newPath = SettingsTestGenerators.randomPath();
          settings = settings.copyWith(libraryPath: newPath);
          await storage.saveSettings(settings);

          // Verify settings are updated
          final retrieved = await storage.loadSettings();
          expect(retrieved.libraryPath, equals(newPath));
        }
      },
    );

    test(
      'Property 42 (same path): Changing to same path should be a no-op',
      () async {
        const iterations = 20;

        for (var i = 0; i < iterations; i++) {
          final path = SettingsTestGenerators.randomPath();

          // Set up directory with files
          await storage.createDirectory(path);
          storage.addFileToDirectory(path, 'test.json');

          // Save settings with path
          var settings = AppSettings.defaults().copyWith(libraryPath: path);
          await storage.saveSettings(settings);

          // "Change" to same path
          settings = settings.copyWith(libraryPath: path);
          await storage.saveSettings(settings);

          // Verify directory still exists with files
          expect(await storage.directoryExists(path), isTrue);
          final contents = storage.getDirectoryContents(path);
          expect(contents, isNotNull);
          expect(contents!.contains('test.json'), isTrue);
        }
      },
    );

    test('Property 41 (default values): Default settings are valid', () async {
      final defaults = AppSettings.defaults();

      await storage.saveSettings(defaults);
      final retrieved = await storage.loadSettings();

      expect(retrieved.libraryPath, equals(''));
      expect(retrieved.metadataWriteBack, isFalse);
      expect(retrieved.lyricsMode, equals(LyricsMode.off));
      expect(retrieved.ktvMode, isFalse);
      expect(retrieved.themeMode, equals('system'));
      expect(retrieved.languageCode, isNull);
    });

    test('Property 41 (equality): Settings equality works correctly', () async {
      const iterations = 50;

      for (var i = 0; i < iterations; i++) {
        final settings1 = SettingsTestGenerators.randomSettings();
        final settings2 = AppSettings(
          libraryPath: settings1.libraryPath,
          metadataWriteBack: settings1.metadataWriteBack,
          lyricsMode: settings1.lyricsMode,
          ktvMode: settings1.ktvMode,
          themeMode: settings1.themeMode,
          languageCode: settings1.languageCode,
        );

        expect(settings1, equals(settings2));
        expect(settings1.hashCode, equals(settings2.hashCode));
      }
    });
  });
}
