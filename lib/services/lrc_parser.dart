/// LRC (Lyrics) file parser
/// Parses LRC format lyrics files and extracts timestamps and text
library;

/// Represents a single line of lyrics with its timestamp
class LyricsLine {
  const LyricsLine({required this.timestamp, required this.text});

  /// Timestamp when this line should be displayed
  final Duration timestamp;

  /// The text content of this line
  final String text;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LyricsLine &&
        other.timestamp == timestamp &&
        other.text == text;
  }

  @override
  int get hashCode => timestamp.hashCode ^ text.hashCode;

  @override
  String toString() => 'LyricsLine(${_formatDuration(timestamp)}: $text)';

  static String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    final centiseconds = ((d.inMilliseconds % 1000) ~/ 10).toString().padLeft(
      2,
      '0',
    );
    return '$minutes:$seconds.$centiseconds';
  }
}

/// Metadata extracted from LRC file
class LyricsMetadata {
  const LyricsMetadata({
    this.title,
    this.artist,
    this.album,
    this.author,
    this.length,
    this.creator,
    this.offset = 0,
    this.editor,
    this.version,
  });

  /// Song title [ti:]
  final String? title;

  /// Artist name [ar:]
  final String? artist;

  /// Album name [al:]
  final String? album;

  /// Lyrics author [au:]
  final String? author;

  /// Length of the song [length:]
  final Duration? length;

  /// Creator of the LRC file [by:]
  final String? creator;

  /// Offset in milliseconds [offset:]
  final int offset;

  /// Program that created the LRC file [re:]
  final String? editor;

  /// Version of the program [ve:]
  final String? version;

  @override
  String toString() {
    return 'LyricsMetadata(title: $title, artist: $artist, album: $album)';
  }
}

/// Parsed LRC file result
class ParsedLyrics {
  const ParsedLyrics({required this.metadata, required this.lines});

  /// Metadata from the LRC file
  final LyricsMetadata metadata;

  /// List of lyrics lines sorted by timestamp
  final List<LyricsLine> lines;

  /// Check if lyrics are empty
  bool get isEmpty => lines.isEmpty;

  /// Check if lyrics are not empty
  bool get isNotEmpty => lines.isNotEmpty;

  /// Get the line that should be displayed at the given position
  LyricsLine? getLineAt(Duration position) {
    if (lines.isEmpty) return null;

    // Apply offset from metadata
    final adjustedPosition = position + Duration(milliseconds: metadata.offset);

    // Find the last line that starts before or at the current position
    LyricsLine? currentLine;
    for (final line in lines) {
      if (line.timestamp <= adjustedPosition) {
        currentLine = line;
      } else {
        break;
      }
    }
    return currentLine;
  }

  /// Get the index of the current line at the given position
  int getLineIndexAt(Duration position) {
    if (lines.isEmpty) return -1;

    final adjustedPosition = position + Duration(milliseconds: metadata.offset);

    var currentIndex = -1;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].timestamp <= adjustedPosition) {
        currentIndex = i;
      } else {
        break;
      }
    }
    return currentIndex;
  }

  /// Get the next line after the current position
  LyricsLine? getNextLine(Duration position) {
    final currentIndex = getLineIndexAt(position);
    if (currentIndex < 0 || currentIndex >= lines.length - 1) {
      return null;
    }
    return lines[currentIndex + 1];
  }
}

/// LRC format parser
/// Parses LRC (Lyrics) format files according to the standard format
class LrcParser {
  /// Regular expression for timestamp format [mm:ss.xx] or [mm:ss:xx]
  static final RegExp _timestampRegex = RegExp(
    r'\[(\d{1,2}):(\d{2})[\.:]([\d]{1,3})\]',
  );

  /// Regular expression for metadata tags
  static final RegExp _metadataRegex = RegExp(r'\[([a-zA-Z]+):([^\]]*)\]');

  /// Parse LRC content string into ParsedLyrics
  ParsedLyrics parse(String content) {
    final lines = content.split('\n');
    final lyricsLines = <LyricsLine>[];
    final metadataMap = <String, String>{};

    for (final line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;

      // Try to parse as metadata first
      final metadataMatch = _metadataRegex.firstMatch(trimmedLine);
      if (metadataMatch != null && !_timestampRegex.hasMatch(trimmedLine)) {
        final key = metadataMatch.group(1)!.toLowerCase();
        final value = metadataMatch.group(2)!.trim();
        metadataMap[key] = value;
        continue;
      }

      // Parse lyrics lines with timestamps
      // A line can have multiple timestamps for the same text
      final timestamps = <Duration>[];
      var text = trimmedLine;

      // Extract all timestamps from the line
      final matches = _timestampRegex.allMatches(trimmedLine);
      for (final match in matches) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final centiseconds = _parseCentiseconds(match.group(3)!);

        final timestamp = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: centiseconds * 10,
        );
        timestamps.add(timestamp);

        // Remove the timestamp from the text
        text = text.replaceFirst(match.group(0)!, '');
      }

      // Clean up the text
      text = text.trim();

      // Create a lyrics line for each timestamp
      for (final timestamp in timestamps) {
        lyricsLines.add(LyricsLine(timestamp: timestamp, text: text));
      }
    }

    // Sort lines by timestamp
    lyricsLines.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Build metadata
    final metadata = _buildMetadata(metadataMap);

    return ParsedLyrics(metadata: metadata, lines: lyricsLines);
  }

  /// Parse centiseconds, handling both 2-digit and 3-digit formats
  int _parseCentiseconds(String value) {
    final parsed = int.parse(value);
    // If it's 3 digits, it's milliseconds, convert to centiseconds
    if (value.length == 3) {
      return parsed ~/ 10;
    }
    return parsed;
  }

  /// Build metadata from parsed map
  LyricsMetadata _buildMetadata(Map<String, String> map) {
    Duration? length;
    if (map.containsKey('length')) {
      length = _parseLength(map['length']!);
    }

    var offset = 0;
    if (map.containsKey('offset')) {
      offset = int.tryParse(map['offset']!) ?? 0;
    }

    return LyricsMetadata(
      title: map['ti'],
      artist: map['ar'],
      album: map['al'],
      author: map['au'],
      length: length,
      creator: map['by'],
      offset: offset,
      editor: map['re'],
      version: map['ve'],
    );
  }

  /// Parse length string (mm:ss format)
  Duration? _parseLength(String value) {
    final parts = value.split(':');
    if (parts.length == 2) {
      final minutes = int.tryParse(parts[0]);
      final seconds = int.tryParse(parts[1]);
      if (minutes != null && seconds != null) {
        return Duration(minutes: minutes, seconds: seconds);
      }
    }
    return null;
  }

  /// Serialize ParsedLyrics back to LRC format string
  String serialize(ParsedLyrics lyrics) {
    final buffer = StringBuffer();

    // Write metadata
    final meta = lyrics.metadata;
    if (meta.title != null) buffer.writeln('[ti:${meta.title}]');
    if (meta.artist != null) buffer.writeln('[ar:${meta.artist}]');
    if (meta.album != null) buffer.writeln('[al:${meta.album}]');
    if (meta.author != null) buffer.writeln('[au:${meta.author}]');
    if (meta.creator != null) buffer.writeln('[by:${meta.creator}]');
    if (meta.editor != null) buffer.writeln('[re:${meta.editor}]');
    if (meta.version != null) buffer.writeln('[ve:${meta.version}]');
    if (meta.offset != 0) buffer.writeln('[offset:${meta.offset}]');
    if (meta.length != null) {
      final minutes = meta.length!.inMinutes;
      final seconds = meta.length!.inSeconds % 60;
      buffer.writeln('[length:$minutes:${seconds.toString().padLeft(2, '0')}]');
    }

    // Write lyrics lines
    for (final line in lyrics.lines) {
      final timestamp = _formatTimestamp(line.timestamp);
      buffer.writeln('$timestamp${line.text}');
    }

    return buffer.toString();
  }

  /// Format duration as LRC timestamp [mm:ss.xx]
  String _formatTimestamp(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    final centiseconds = ((d.inMilliseconds % 1000) ~/ 10).toString().padLeft(
      2,
      '0',
    );
    return '[$minutes:$seconds.$centiseconds]';
  }
}
