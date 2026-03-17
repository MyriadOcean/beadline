import 'dart:io';

import 'package:beadline/data/settings_storage.dart';
import 'package:beadline/models/app_settings.dart';
import 'package:beadline/models/library_location.dart';
import 'package:beadline/services/library_location_manager.dart';
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
  late MockSettingsStorage mockStorage;
  late LibraryLocationManager manager;
  late Directory tempDir;

  setUp(() async {
    mockStorage = MockSettingsStorage();
    manager = LibraryLocationManager(mockStorage);

    // Create a temporary directory for testing
    tempDir = await Directory.systemTemp.createTemp('library_location_test_');
  });

  tearDown(() async {
    // Clean up temporary directory
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('LibraryLocationManager Tests', () {
    test('addLocation creates a new library location', () async {
      final location = await manager.addLocation(
        tempDir.path,
        name: 'Test Library',
      );

      expect(location.name, equals('Test Library'));
      // rootPath is normalized (backslashes converted to forward slashes)
      expect(location.rootPath, equals(tempDir.path.replaceAll('\\', '/')));
      expect(location.isDefault, isTrue); // First location is default
      expect(location.isAccessible, isTrue);

      final locations = await manager.getLocations();
      expect(locations.length, equals(1));
      expect(locations.first.id, equals(location.id));
    });

    test('addLocation throws for non-existent path', () async {
      final nonExistentPath = p.join(tempDir.path, 'non_existent_dir');

      expect(
        () => manager.addLocation(nonExistentPath),
        throwsA(isA<LibraryLocationException>()),
      );
    });

    test('addLocation throws for duplicate path', () async {
      await manager.addLocation(tempDir.path, name: 'First');

      expect(
        () => manager.addLocation(tempDir.path, name: 'Duplicate'),
        throwsA(isA<LibraryLocationException>()),
      );
    });

    test('removeLocation removes the library location', () async {
      final location = await manager.addLocation(tempDir.path);

      await manager.removeLocation(location.id);

      final locations = await manager.getLocations();
      expect(locations, isEmpty);
    });

    test('removeLocation throws for non-existent ID', () async {
      expect(
        () => manager.removeLocation('non-existent-id'),
        throwsA(isA<LibraryLocationException>()),
      );
    });

    test(
      'removeLocation reassigns default when removing default location',
      () async {
        // Create two directories
        final dir1 = await Directory(p.join(tempDir.path, 'dir1')).create();
        final dir2 = await Directory(p.join(tempDir.path, 'dir2')).create();

        final location1 = await manager.addLocation(dir1.path, name: 'First');
        await manager.addLocation(dir2.path, name: 'Second');

        // First location should be default
        expect(location1.isDefault, isTrue);

        // Remove the default location
        await manager.removeLocation(location1.id);

        // Second location should now be default
        final locations = await manager.getLocations();
        expect(locations.length, equals(1));
        expect(locations.first.isDefault, isTrue);
      },
    );

    test('setDefaultLocation changes the default location', () async {
      final dir1 = await Directory(p.join(tempDir.path, 'dir1')).create();
      final dir2 = await Directory(p.join(tempDir.path, 'dir2')).create();

      final location1 = await manager.addLocation(dir1.path, name: 'First');
      final location2 = await manager.addLocation(dir2.path, name: 'Second');

      // First should be default initially
      expect(location1.isDefault, isTrue);
      expect(location2.isDefault, isFalse);

      // Set second as default
      await manager.setDefaultLocation(location2.id);

      final locations = await manager.getLocations();
      final updatedLoc1 = locations.firstWhere((l) => l.id == location1.id);
      final updatedLoc2 = locations.firstWhere((l) => l.id == location2.id);

      expect(updatedLoc1.isDefault, isFalse);
      expect(updatedLoc2.isDefault, isTrue);
    });

    test('setDefaultLocation throws for non-existent ID', () async {
      expect(
        () => manager.setDefaultLocation('non-existent-id'),
        throwsA(isA<LibraryLocationException>()),
      );
    });

    test('validateLocation returns valid for existing directory', () async {
      final result = await manager.validateLocation(tempDir.path);

      expect(result.isValid, isTrue);
      expect(result.error, isNull);
    });

    test('validateLocation returns invalid for non-existent path', () async {
      final result = await manager.validateLocation('/non/existent/path');

      expect(result.isValid, isFalse);
      expect(result.code, equals('PATH_NOT_EXISTS'));
    });

    test('validateLocation returns invalid for file path', () async {
      final file = File(p.join(tempDir.path, 'test_file.txt'));
      await file.writeAsString('test');

      final result = await manager.validateLocation(file.path);

      expect(result.isValid, isFalse);
      expect(result.code, equals('NOT_DIRECTORY'));
    });

    test('refreshAccessibility updates isAccessible status', () async {
      // Add a location
      final location = await manager.addLocation(tempDir.path);
      expect(location.isAccessible, isTrue);

      // Get locations - should still be accessible
      final locations = await manager.refreshAccessibility();
      expect(locations.first.isAccessible, isTrue);

      // Note: We can't easily test inaccessible directories in unit tests
      // without mocking the file system, but we verify the method works
      // for accessible directories
    });

    test('getDefaultLocation returns the default location', () async {
      final dir1 = await Directory(p.join(tempDir.path, 'dir1')).create();
      final dir2 = await Directory(p.join(tempDir.path, 'dir2')).create();

      final location1 = await manager.addLocation(dir1.path);
      await manager.addLocation(dir2.path);

      final defaultLoc = await manager.getDefaultLocation();
      expect(defaultLoc, isNotNull);
      expect(defaultLoc!.id, equals(location1.id));
    });

    test('getDefaultLocation returns null when no locations exist', () async {
      final defaultLoc = await manager.getDefaultLocation();
      expect(defaultLoc, isNull);
    });

    test('getLocationById returns correct location', () async {
      final location = await manager.addLocation(tempDir.path);

      final found = await manager.getLocationById(location.id);
      expect(found, isNotNull);
      expect(found!.id, equals(location.id));
    });

    test('getLocationById returns null for non-existent ID', () async {
      final found = await manager.getLocationById('non-existent-id');
      expect(found, isNull);
    });

    test('findLocationForPath finds correct location', () async {
      final dir1 = await Directory(p.join(tempDir.path, 'library1')).create();
      final dir2 = await Directory(p.join(tempDir.path, 'library2')).create();

      final location1 = await manager.addLocation(dir1.path);
      final location2 = await manager.addLocation(dir2.path);

      final locations = await manager.getLocations();

      // Path in library1
      final path1 = p.join(dir1.path, 'subdir', 'file.mp3');
      final found1 = manager.findLocationForPath(path1, locations);
      expect(found1, isNotNull);
      expect(found1!.id, equals(location1.id));

      // Path in library2
      final path2 = p.join(dir2.path, 'file.mp3');
      final found2 = manager.findLocationForPath(path2, locations);
      expect(found2, isNotNull);
      expect(found2!.id, equals(location2.id));

      // Path outside both
      const outsidePath = '/some/other/path/file.mp3';
      final foundOutside = manager.findLocationForPath(outsidePath, locations);
      expect(foundOutside, isNull);
    });

    test('updateLocationName updates the name', () async {
      final location = await manager.addLocation(
        tempDir.path,
        name: 'Original',
      );

      await manager.updateLocationName(location.id, 'Updated Name');

      final locations = await manager.getLocations();
      expect(locations.first.name, equals('Updated Name'));
    });

    /// **Feature: library-locations, Property 8: Accessibility Status Propagation**
    /// **Validates: Requirements 1.5**
    ///
    /// For any library location that becomes inaccessible, all Song Units
    /// associated with that location SHALL be marked as unavailable.
    ///
    /// This test verifies that refreshAccessibility correctly updates the
    /// isAccessible status based on the actual file system state.
    test('Property 8: Accessibility status propagation', () async {
      // Create multiple test directories
      final testDirs = <Directory>[];
      for (var i = 0; i < 5; i++) {
        final dir = await Directory(
          p.join(tempDir.path, 'library_$i'),
        ).create();
        testDirs.add(dir);
      }

      // Add all directories as library locations
      final addedLocations = <LibraryLocation>[];
      for (final dir in testDirs) {
        final location = await manager.addLocation(dir.path);
        addedLocations.add(location);
      }

      // Verify all locations are initially accessible
      var locations = await manager.refreshAccessibility();
      for (final location in locations) {
        expect(
          location.isAccessible,
          isTrue,
          reason: 'All locations should be accessible initially',
        );
      }

      // Delete some directories to simulate inaccessibility
      final indicesToDelete = [1, 3]; // Delete 2nd and 4th directories
      for (final index in indicesToDelete) {
        await testDirs[index].delete(recursive: true);
      }

      // Refresh accessibility
      locations = await manager.refreshAccessibility();

      // Verify accessibility status matches actual file system state
      for (var i = 0; i < locations.length; i++) {
        final location = locations[i];
        final shouldBeAccessible = !indicesToDelete.contains(i);

        expect(
          location.isAccessible,
          equals(shouldBeAccessible),
          reason:
              'Location ${location.name} accessibility should match '
              'file system state (expected: $shouldBeAccessible)',
        );
      }
    });

    /// Property test: Accessibility status is consistent with validation
    test(
      'Property 8 (extended): Accessibility matches validation result',
      () async {
        for (var i = 0; i < 20; i++) {
          // Reset manager state
          mockStorage.reset();
          manager.clearCache();

          // Create a random number of directories
          final numDirs = TestGenerators.randomInt(1, 5);
          final testDirs = <Directory>[];

          for (var j = 0; j < numDirs; j++) {
            final dir = await Directory(
              p.join(tempDir.path, 'iter_${i}_library_$j'),
            ).create();
            testDirs.add(dir);
            await manager.addLocation(dir.path);
          }

          // Randomly delete some directories
          final deletedIndices = <int>{};
          for (var j = 0; j < testDirs.length; j++) {
            if (TestGenerators.randomInt(0, 2) == 0) {
              await testDirs[j].delete(recursive: true);
              deletedIndices.add(j);
            }
          }

          // Refresh accessibility
          final locations = await manager.refreshAccessibility();

          // Verify each location's accessibility matches validation
          for (var j = 0; j < locations.length; j++) {
            final location = locations[j];
            final validationResult = await manager.validateLocation(
              location.rootPath,
            );

            expect(
              location.isAccessible,
              equals(validationResult.isValid),
              reason:
                  'isAccessible should match validation result for ${location.name}',
            );
          }

          // Clean up remaining directories
          for (final dir in testDirs) {
            if (dir.existsSync()) {
              await dir.delete(recursive: true);
            }
          }
        }
      },
    );
  });
}
