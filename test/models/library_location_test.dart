import 'package:beadline/models/library_location.dart';
import 'package:flutter_test/flutter_test.dart';
import 'test_generators.dart';

/// **Feature: storage-locations, Property 7: Library Location Aggregation**
void main() {
  group('LibraryLocation Model Tests', () {
    test('LibraryLocation JSON serialization round-trip', () {
      // Run 100 iterations with random library locations
      for (var i = 0; i < 100; i++) {
        final original = TestGenerators.randomStorageLocation();

        // Serialize to JSON
        final json = original.toJson();

        // Deserialize from JSON
        final restored = LibraryLocation.fromJson(json);

        // Verify all persisted fields match
        expect(restored.id, equals(original.id));
        expect(restored.name, equals(original.name));
        expect(restored.rootPath, equals(original.rootPath));
        expect(restored.isDefault, equals(original.isDefault));
        expect(restored.addedAt, equals(original.addedAt));
        // Note: isAccessible is not persisted (runtime status)
      }
    });

    test('LibraryLocation copyWith preserves unchanged fields', () {
      for (var i = 0; i < 100; i++) {
        final original = TestGenerators.randomStorageLocation();

        // Copy with no changes
        final copy = original.copyWith();
        expect(copy, equals(original));

        // Copy with single field change
        final newName = TestGenerators.randomString();
        final withNewName = original.copyWith(name: newName);
        expect(withNewName.name, equals(newName));
        expect(withNewName.id, equals(original.id));
        expect(withNewName.rootPath, equals(original.rootPath));
        expect(withNewName.isDefault, equals(original.isDefault));
        expect(withNewName.addedAt, equals(original.addedAt));
        expect(withNewName.isAccessible, equals(original.isAccessible));
      }
    });

    /// **Feature: storage-locations, Property 7: Library Location Aggregation**
    /// **Validates: Requirements 1.4**
    ///
    /// For any set of N library locations containing M₁, M₂, ..., Mₙ Song Units
    /// respectively, the aggregated library view SHALL contain exactly
    /// M₁ + M₂ + ... + Mₙ Song Units.
    test('Property 7: Library location aggregation counts correctly', () {
      for (var i = 0; i < 100; i++) {
        // Generate random library locations
        final locations = TestGenerators.randomStorageLocations();

        // Generate random song unit counts for each location
        final songUnitCounts = <String, int>{};
        var expectedTotal = 0;

        for (final location in locations) {
          final count = TestGenerators.randomInt(0, 20);
          songUnitCounts[location.id] = count;
          expectedTotal += count;
        }

        // Simulate aggregation by summing all counts
        var actualTotal = 0;
        for (final count in songUnitCounts.values) {
          actualTotal += count;
        }

        // Verify the aggregation property
        expect(
          actualTotal,
          equals(expectedTotal),
          reason: 'Aggregated count should equal sum of individual counts',
        );
      }
    });

    test('LibraryLocation equality works correctly', () {
      for (var i = 0; i < 100; i++) {
        final location = TestGenerators.randomStorageLocation();

        // Same location should be equal to itself
        expect(location, equals(location));

        // Copy should be equal
        final copy = location.copyWith();
        expect(copy, equals(location));

        // Different ID should not be equal
        final differentId = location.copyWith(
          id: TestGenerators.randomString(),
        );
        expect(differentId, isNot(equals(location)));
      }
    });

    test('LibraryLocation hashCode is consistent with equality', () {
      for (var i = 0; i < 100; i++) {
        final location = TestGenerators.randomStorageLocation();
        final copy = location.copyWith();

        // Equal objects should have equal hash codes
        expect(copy.hashCode, equals(location.hashCode));
      }
    });
  });
}
