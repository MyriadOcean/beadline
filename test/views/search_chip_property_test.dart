import 'dart:math';

import 'package:beadline/views/widgets/search_chip.dart';
import 'package:flutter_test/flutter_test.dart';

/// Property tests for search chip color cycling and chip deletion logic.
///
/// Since no PBT library (e.g. glados, dart_check) is available, we simulate
/// property-based testing by systematically iterating over a wide range of
/// inputs and verifying the properties hold for all of them.

void main() {
  // ---------------------------------------------------------------------------
  // Property 21: Adjacent chips have different colors
  // **Validates: Requirements 10.2**
  //
  // For any list of chips with length ≥ 2, no two adjacent chips SHALL have
  // the same background color index from the cycling palette.
  // ---------------------------------------------------------------------------
  group('Property 21: Adjacent chips have different colors', () {
    test('chipPalette has no adjacent duplicate colors', () {
      // Precondition: the palette itself must have all distinct colors,
      // otherwise modulo cycling could produce adjacent duplicates.
      expect(chipPalette.length, greaterThanOrEqualTo(2),
          reason: 'Palette must have at least 2 colors');

      // Verify all colors in the palette are unique
      final uniqueColors = chipPalette.toSet();
      expect(uniqueColors.length, equals(chipPalette.length),
          reason: 'All palette colors must be distinct');
    });

    test('chipColorForIndex returns correct palette color for index', () {
      for (var i = 0; i < chipPalette.length * 3; i++) {
        expect(chipColorForIndex(i), equals(chipPalette[i % chipPalette.length]),
            reason: 'chipColorForIndex($i) should equal chipPalette[${i % chipPalette.length}]');
      }
    });

    test('adjacent condition indices always produce different colors '
        '(chip counts 2..100)', () {
      // Simulate the color assignment from _buildChipWidgets:
      // conditionColorIndex increments for each non-OR chip.
      // We verify that for any number of condition chips, adjacent ones
      // always get different colors.
      for (var chipCount = 2; chipCount <= 100; chipCount++) {
        for (var i = 0; i < chipCount - 1; i++) {
          final colorA = chipColorForIndex(i);
          final colorB = chipColorForIndex(i + 1);
          expect(colorA, isNot(equals(colorB)),
              reason: 'chipCount=$chipCount: color at index $i should differ '
                  'from color at index ${i + 1}');
        }
      }
    });

    test('color cycling wraps around palette without adjacent collision', () {
      // Specifically test the wrap-around point where index crosses
      // palette.length boundary.
      final paletteLen = chipPalette.length;
      for (var i = 0; i < paletteLen * 5; i++) {
        final colorA = chipColorForIndex(i);
        final colorB = chipColorForIndex(i + 1);
        expect(colorA, isNot(equals(colorB)),
            reason: 'Wrap-around: color at index $i should differ from '
                'color at index ${i + 1}');
      }
    });

    test('palette last and first colors differ (critical for wrap-around)', () {
      // When conditionColorIndex wraps from (paletteLen - 1) to 0,
      // the last palette color must differ from the first.
      expect(chipPalette.last, isNot(equals(chipPalette.first)),
          reason: 'Last palette color must differ from first for safe cycling');
    });

    test('randomized chip sequences always have distinct adjacent colors', () {
      // Simulate 200 random chip sequences with random OR insertions.
      // The color index only increments for non-OR chips.
      final rng = Random(42); // fixed seed for reproducibility
      for (var trial = 0; trial < 200; trial++) {
        final totalWidgets = rng.nextInt(19) + 2; // 2..20 widgets
        var conditionColorIndex = 0;
        final assignedColors = <int>[]; // color indices for condition chips

        for (var w = 0; w < totalWidgets; w++) {
          final isOr = rng.nextDouble() < 0.2; // ~20% chance of OR chip
          if (isOr) {
            continue; // OR chips don't get a color index
          }
          assignedColors.add(conditionColorIndex);
          conditionColorIndex++;
        }

        // Verify adjacent condition chips have different colors
        for (var i = 0; i < assignedColors.length - 1; i++) {
          final colorA = chipColorForIndex(assignedColors[i]);
          final colorB = chipColorForIndex(assignedColors[i + 1]);
          expect(colorA, isNot(equals(colorB)),
              reason: 'Trial $trial: adjacent condition colors at positions '
                  '${assignedColors[i]} and ${assignedColors[i + 1]} must differ');
        }
      }
    });
  });

  // ---------------------------------------------------------------------------
  // Property 22: Chip deletion reduces condition count
  // **Validates: Requirements 10.4**
  //
  // For any query with N ≥ 2 top-level conditions, removing one chip and
  // re-serializing SHALL produce a query with N-1 top-level conditions.
  //
  // Since the actual chip deletion depends on FRB/Rust for parsing, we test
  // the Dart-side text-manipulation logic that SearchViewModel.deleteChip uses:
  // given a query string and chip byte spans, removing a chip's span and
  // cleaning up whitespace/OR operators produces a valid shorter query.
  // ---------------------------------------------------------------------------
  group('Property 22: Chip deletion reduces condition count', () {
    /// Simulates the chip deletion logic from SearchViewModel.deleteChip.
    /// Given a query string and a chip's [start, end) byte offsets, removes
    /// the chip text and cleans up whitespace and orphaned OR operators.
    String simulateDeleteChip(String query, int start, int end) {
      var newText = query.substring(0, start) + query.substring(end);
      newText = newText.replaceAll(RegExp(r'\s+'), ' ').trim();
      newText = newText.replaceAll(RegExp(r'^\s*OR\s+'), '');
      newText = newText.replaceAll(RegExp(r'\s+OR\s*$'), '');
      newText = newText.replaceAll(RegExp(r'\s+OR\s+OR\s+'), ' OR ');
      return newText;
    }

    /// Counts top-level conditions in a simple query string.
    /// Splits by ' OR ' for OR-separated, then by whitespace for AND-separated.
    /// This is a simplified heuristic for testing purposes.
    int countTopLevelConditions(String query) {
      if (query.trim().isEmpty) return 0;
      // Split by OR first, then count space-separated terms within each OR branch
      final orParts = query.split(RegExp(r'\s+OR\s+'));
      var count = 0;
      for (final part in orParts) {
        final terms = part.trim().split(RegExp(r'\s+'));
        count += terms.where((t) => t.isNotEmpty).length;
      }
      return count;
    }

    /// Represents a chip with its text span in the query string.
    /// Mimics DartQueryChip's start/end fields.
    List<({String text, int start, int end})> parseSimpleChips(String query) {
      final chips = <({String text, int start, int end})>[];
      final terms = RegExp(r'\S+');
      for (final match in terms.allMatches(query)) {
        final text = match.group(0)!;
        if (text == 'OR') continue; // skip OR operators
        chips.add((text: text, start: match.start, end: match.end));
      }
      return chips;
    }

    // Test with AND-separated queries (space-separated conditions)
    test('deleting one chip from AND queries reduces count by 1', () {
      final andQueries = [
        'artist:luotianyi album:test',
        'hello world foo',
        'artist:a artist:b artist:c',
        'name:song tag:rock year:2020 genre:pop',
        'a b',
      ];

      for (final query in andQueries) {
        final originalCount = countTopLevelConditions(query);
        expect(originalCount, greaterThanOrEqualTo(2),
            reason: 'Query "$query" must have ≥ 2 conditions');

        final chips = parseSimpleChips(query);
        expect(chips.length, equals(originalCount),
            reason: 'Chip count should match condition count for "$query"');

        // Delete each chip one at a time and verify count decreases by 1
        for (var i = 0; i < chips.length; i++) {
          final chip = chips[i];
          final newQuery = simulateDeleteChip(query, chip.start, chip.end);
          final newCount = countTopLevelConditions(newQuery);
          expect(newCount, equals(originalCount - 1),
              reason: 'Deleting chip "${ chip.text}" from "$query" should '
                  'reduce count from $originalCount to ${originalCount - 1}, '
                  'got $newCount (result: "$newQuery")');
        }
      }
    });

    // Test with OR-separated queries
    test('deleting one chip from OR queries reduces count by 1', () {
      final orQueries = [
        'artist:luotianyi OR album:test',
        'hello OR world OR foo',
        'tag:rock OR tag:pop',
      ];

      for (final query in orQueries) {
        final originalCount = countTopLevelConditions(query);
        expect(originalCount, greaterThanOrEqualTo(2),
            reason: 'Query "$query" must have ≥ 2 conditions');

        final chips = parseSimpleChips(query);

        for (var i = 0; i < chips.length; i++) {
          final chip = chips[i];
          final newQuery = simulateDeleteChip(query, chip.start, chip.end);
          final newCount = countTopLevelConditions(newQuery);
          expect(newCount, equals(originalCount - 1),
              reason: 'Deleting chip "${chip.text}" from "$query" should '
                  'reduce count from $originalCount to ${originalCount - 1}, '
                  'got $newCount (result: "$newQuery")');
        }
      }
    });

    // Test with mixed AND/OR queries
    test('deleting one chip from mixed queries reduces count by 1', () {
      final mixedQueries = [
        'artist:luotianyi tag:rock OR album:test',
        'hello world OR foo bar',
      ];

      for (final query in mixedQueries) {
        final originalCount = countTopLevelConditions(query);
        expect(originalCount, greaterThanOrEqualTo(2));

        final chips = parseSimpleChips(query);

        for (var i = 0; i < chips.length; i++) {
          final chip = chips[i];
          final newQuery = simulateDeleteChip(query, chip.start, chip.end);
          final newCount = countTopLevelConditions(newQuery);
          expect(newCount, equals(originalCount - 1),
              reason: 'Deleting chip "${chip.text}" from "$query" → '
                  '"$newQuery": expected ${originalCount - 1}, got $newCount');
        }
      }
    });

    // Parameterized: generate many random AND queries and verify property
    test('randomized AND queries: deletion always reduces count by 1', () {
      final rng = Random(123);
      final sampleTerms = [
        'artist:luotianyi', 'album:test', 'tag:rock', 'name:hello',
        'year:2020', 'genre:pop', 'tag:v4', 'duration:300',
        'artist:yanhe', 'tag:ACE', 'foo', 'bar', 'baz',
      ];

      for (var trial = 0; trial < 100; trial++) {
        final termCount = rng.nextInt(4) + 2; // 2..5 terms
        final terms = List.generate(
            termCount, (_) => sampleTerms[rng.nextInt(sampleTerms.length)]);
        final query = terms.join(' ');

        final originalCount = countTopLevelConditions(query);
        final chips = parseSimpleChips(query);

        // Delete a random chip
        final deleteIdx = rng.nextInt(chips.length);
        final chip = chips[deleteIdx];
        final newQuery = simulateDeleteChip(query, chip.start, chip.end);
        final newCount = countTopLevelConditions(newQuery);

        expect(newCount, equals(originalCount - 1),
            reason: 'Trial $trial: deleting "${chip.text}" from "$query" → '
                '"$newQuery": expected ${originalCount - 1}, got $newCount');
      }
    });

    // Parameterized: generate many random OR queries and verify property
    test('randomized OR queries: deletion always reduces count by 1', () {
      final rng = Random(456);
      final sampleTerms = [
        'artist:luotianyi', 'album:test', 'tag:rock', 'name:hello',
        'year:2020', 'genre:pop', 'tag:v4',
      ];

      for (var trial = 0; trial < 100; trial++) {
        final termCount = rng.nextInt(3) + 2; // 2..4 terms
        final terms = List.generate(
            termCount, (_) => sampleTerms[rng.nextInt(sampleTerms.length)]);
        final query = terms.join(' OR ');

        final originalCount = countTopLevelConditions(query);
        final chips = parseSimpleChips(query);

        final deleteIdx = rng.nextInt(chips.length);
        final chip = chips[deleteIdx];
        final newQuery = simulateDeleteChip(query, chip.start, chip.end);
        final newCount = countTopLevelConditions(newQuery);

        expect(newCount, equals(originalCount - 1),
            reason: 'Trial $trial: deleting "${chip.text}" from "$query" → '
                '"$newQuery": expected ${originalCount - 1}, got $newCount');
      }
    });

    // Edge case: deleting from a 2-condition query leaves exactly 1
    test('deleting from 2-condition query leaves exactly 1 condition', () {
      final twoConditionQueries = [
        'hello world',
        'artist:a artist:b',
        'hello OR world',
        'tag:rock OR tag:pop',
      ];

      for (final query in twoConditionQueries) {
        final chips = parseSimpleChips(query);
        expect(chips.length, equals(2),
            reason: 'Query "$query" should have exactly 2 condition chips');

        for (final chip in chips) {
          final newQuery = simulateDeleteChip(query, chip.start, chip.end);
          final newCount = countTopLevelConditions(newQuery);
          expect(newCount, equals(1),
              reason: 'Deleting "${chip.text}" from "$query" should leave '
                  'exactly 1 condition, got $newCount (result: "$newQuery")');
        }
      }
    });
  });
}
