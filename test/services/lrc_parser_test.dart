import 'package:beadline/services/lrc_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late LrcParser parser;

  setUp(() {
    parser = LrcParser();
  });

  group('LrcParser', () {
    group('parse', () {
      test('parses simple LRC content', () {
        const lrcContent = '''
[00:00.00]First line
[00:05.50]Second line
[00:10.00]Third line
''';

        final result = parser.parse(lrcContent);

        expect(result.lines.length, 3);
        expect(result.lines[0].text, 'First line');
        expect(result.lines[0].timestamp, Duration.zero);
        expect(result.lines[1].text, 'Second line');
        expect(
          result.lines[1].timestamp,
          const Duration(seconds: 5, milliseconds: 500),
        );
        expect(result.lines[2].text, 'Third line');
        expect(result.lines[2].timestamp, const Duration(seconds: 10));
      });

      test('parses metadata tags', () {
        const lrcContent = '''
[ti:Test Song]
[ar:Test Artist]
[al:Test Album]
[au:Lyrics Author]
[by:LRC Creator]
[offset:500]
[00:00.00]Lyrics line
''';

        final result = parser.parse(lrcContent);

        expect(result.metadata.title, 'Test Song');
        expect(result.metadata.artist, 'Test Artist');
        expect(result.metadata.album, 'Test Album');
        expect(result.metadata.author, 'Lyrics Author');
        expect(result.metadata.creator, 'LRC Creator');
        expect(result.metadata.offset, 500);
      });

      test('handles multiple timestamps for same line', () {
        const lrcContent = '''
[00:10.00][00:30.00]Repeated line
''';

        final result = parser.parse(lrcContent);

        expect(result.lines.length, 2);
        expect(result.lines[0].text, 'Repeated line');
        expect(result.lines[0].timestamp, const Duration(seconds: 10));
        expect(result.lines[1].text, 'Repeated line');
        expect(result.lines[1].timestamp, const Duration(seconds: 30));
      });

      test('handles colon separator in timestamp', () {
        const lrcContent = '''
[00:05:50]Line with colon separator
''';

        final result = parser.parse(lrcContent);

        expect(result.lines.length, 1);
        expect(result.lines[0].text, 'Line with colon separator');
        expect(
          result.lines[0].timestamp,
          const Duration(seconds: 5, milliseconds: 500),
        );
      });

      test('handles 3-digit milliseconds', () {
        const lrcContent = '''
[00:05.500]Line with milliseconds
''';

        final result = parser.parse(lrcContent);

        expect(result.lines.length, 1);
        expect(
          result.lines[0].timestamp,
          const Duration(seconds: 5, milliseconds: 500),
        );
      });

      test('sorts lines by timestamp', () {
        const lrcContent = '''
[00:20.00]Third
[00:05.00]First
[00:10.00]Second
''';

        final result = parser.parse(lrcContent);

        expect(result.lines[0].text, 'First');
        expect(result.lines[1].text, 'Second');
        expect(result.lines[2].text, 'Third');
      });

      test('handles empty content', () {
        final result = parser.parse('');

        expect(result.isEmpty, true);
        expect(result.lines, isEmpty);
      });

      test('handles content with only metadata', () {
        const lrcContent = '''
[ti:Song Title]
[ar:Artist Name]
''';

        final result = parser.parse(lrcContent);

        expect(result.isEmpty, true);
        expect(result.metadata.title, 'Song Title');
        expect(result.metadata.artist, 'Artist Name');
      });
    });

    group('getLineAt', () {
      test('returns correct line at position', () {
        const lrcContent = '''
[00:00.00]First
[00:10.00]Second
[00:20.00]Third
''';

        final result = parser.parse(lrcContent);

        expect(result.getLineAt(const Duration(seconds: 5))?.text, 'First');
        expect(result.getLineAt(const Duration(seconds: 15))?.text, 'Second');
        expect(result.getLineAt(const Duration(seconds: 25))?.text, 'Third');
      });

      test('returns null for empty lyrics', () {
        final result = parser.parse('');

        expect(result.getLineAt(const Duration(seconds: 5)), isNull);
      });

      test('applies offset from metadata', () {
        const lrcContent = '''
[offset:500]
[00:10.00]Line
''';

        final result = parser.parse(lrcContent);

        // With +500ms offset, the adjusted position is position + 500ms
        // So at 9.5s, adjusted position is 10s, which matches the line
        expect(
          result.getLineAt(const Duration(seconds: 9, milliseconds: 500))?.text,
          'Line',
        );
      });
    });

    group('getNextLine', () {
      test('returns next line', () {
        const lrcContent = '''
[00:00.00]First
[00:10.00]Second
[00:20.00]Third
''';

        final result = parser.parse(lrcContent);

        expect(result.getNextLine(const Duration(seconds: 5))?.text, 'Second');
        expect(result.getNextLine(const Duration(seconds: 15))?.text, 'Third');
      });

      test('returns null at end', () {
        const lrcContent = '''
[00:00.00]First
[00:10.00]Last
''';

        final result = parser.parse(lrcContent);

        expect(result.getNextLine(const Duration(seconds: 15)), isNull);
      });
    });

    group('serialize', () {
      test('serializes lyrics back to LRC format', () {
        const lrcContent = '''
[ti:Test Song]
[ar:Test Artist]
[00:00.00]First line
[00:10.00]Second line
''';

        final parsed = parser.parse(lrcContent);
        final serialized = parser.serialize(parsed);

        expect(serialized, contains('[ti:Test Song]'));
        expect(serialized, contains('[ar:Test Artist]'));
        expect(serialized, contains('[00:00.00]First line'));
        expect(serialized, contains('[00:10.00]Second line'));
      });

      test('round-trip preserves content', () {
        const lrcContent = '''
[ti:Test Song]
[ar:Test Artist]
[00:00.00]First line
[00:05.50]Second line
[00:10.00]Third line
''';

        final parsed = parser.parse(lrcContent);
        final serialized = parser.serialize(parsed);
        final reparsed = parser.parse(serialized);

        expect(reparsed.metadata.title, parsed.metadata.title);
        expect(reparsed.metadata.artist, parsed.metadata.artist);
        expect(reparsed.lines.length, parsed.lines.length);
        for (var i = 0; i < parsed.lines.length; i++) {
          expect(reparsed.lines[i].text, parsed.lines[i].text);
          expect(reparsed.lines[i].timestamp, parsed.lines[i].timestamp);
        }
      });
    });
  });
}
