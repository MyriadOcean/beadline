import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/metadata.dart';
import '../models/source.dart';
import '../models/source_origin.dart';
import '../src/rust/api/media_api.dart' as rust_media;
import 'source_validator.dart';

/// Result of metadata extraction
class ExtractionResult {
  const ExtractionResult({
    required this.success,
    this.metadata,
    this.errorMessage,
    this.rawTags = const {},
  });

  factory ExtractionResult.success(
    Metadata metadata, {
    Map<String, String>? rawTags,
  }) {
    return ExtractionResult(
      success: true,
      metadata: metadata,
      rawTags: rawTags ?? {},
    );
  }

  factory ExtractionResult.failure(String message) {
    return ExtractionResult(success: false, errorMessage: message);
  }
  final bool success;
  final Metadata? metadata;
  final String? errorMessage;
  final Map<String, String> rawTags;
}

/// Service for extracting metadata from media files
class MetadataExtractor {
  final SourceValidator _validator = SourceValidator();

  /// Extract metadata from a source
  Future<ExtractionResult> extractFromSource(Source source) async {
    switch (source.origin) {
      case LocalFileOrigin(:final path):
        return extractFromFile(path);
      case UrlOrigin(:final url):
        return _extractFromUrl(url);
      case ApiOrigin(:final provider, :final resourceId):
        return _extractFromApi(provider, resourceId);
    }
  }

  /// Extract metadata from a local file
  Future<ExtractionResult> extractFromFile(String path) async {
    final file = File(path);
    if (!file.existsSync()) {
      return ExtractionResult.failure('File not found: $path');
    }

    final detection = _validator.detectSourceType(path);
    if (!detection.isValid) {
      return ExtractionResult.failure('Unsupported file type: $path');
    }

    switch (detection.detectedType) {
      case SourceType.audio:
        return _extractFromAudioFile(path);
      case SourceType.display:
        if (detection.detectedDisplayType == DisplayType.video) {
          return _extractFromVideoFile(path);
        }
        return _extractFromImageFile(path);
      case SourceType.hover:
        return _extractFromLrcFile(path);
      default:
        return ExtractionResult.failure(
          'Cannot extract metadata from this file type',
        );
    }
  }

  /// Extract metadata from an audio file (MP3, FLAC, etc.)
  /// Uses lofty via Rust FFI for tag extraction, falls back to filename parsing.
  Future<ExtractionResult> _extractFromAudioFile(String path) async {
    final filename = _getFilenameWithoutExtension(path);
    final parsedFromFilename = _parseFilename(filename);
    final rawTags = <String, String>{'filename': filename, 'path': path};

    try {
      final file = File(path);
      final stat = file.statSync();
      rawTags['size'] = stat.size.toString();
    } catch (_) {}

    // Try lofty via Rust FFI first
    try {
      final lofty = await rust_media.extractMediaMetadata(filePath: path);
      if (lofty != null) {
        final durationMs = lofty.durationMs.toInt();
        final title = lofty.title ?? parsedFromFilename['title'] ?? filename;
        final artistStr = lofty.artist ?? parsedFromFilename['artist'] ?? '';
        final album = lofty.album ?? '';

        rawTags['duration_source'] = 'lofty';
        if (lofty.title != null) rawTags['title'] = lofty.title!;
        if (lofty.artist != null) rawTags['artist'] = lofty.artist!;
        if (lofty.album != null) rawTags['album'] = lofty.album!;
        if (lofty.year != null) rawTags['year'] = lofty.year.toString();

        return ExtractionResult.success(
          Metadata(
            title: title,
            artists: _parseArtistString(artistStr),
            album: album,
            year: lofty.year,
            duration: Duration(milliseconds: durationMs),
          ),
          rawTags: rawTags,
        );
      }
    } catch (e) {
      debugPrint('MetadataExtractor: lofty extraction failed, falling back: $e');
    }

    // Fallback: filename parsing + file header duration
    final duration = await _getAudioDuration(path);
    if (duration != null) {
      rawTags['duration'] = duration.inSeconds.toString();
      rawTags['duration_source'] = 'file_header';
    }

    return ExtractionResult.success(
      Metadata(
        title: parsedFromFilename['title'] ?? filename,
        artists: _parseArtistString(parsedFromFilename['artist'] ?? ''),
        album: '',
        duration: duration ?? Duration.zero,
      ),
      rawTags: rawTags,
    );
  }

  /// Get audio duration using media_kit
  /// This works for all audio formats supported by the platform
  Future<Duration?> _getAudioDuration(String path) async {
    try {
      // Use media_kit to get duration
      // For now, use a simple approach with file analysis
      final extension = path.toLowerCase().split('.').last;

      debugPrint(
        'MetadataExtractor: Getting duration for $extension file: $path',
      );

      Duration? result;
      switch (extension) {
        case 'wav':
          result = await _calculateWavDuration(path).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint(
                'MetadataExtractor: WAV duration calculation timed out',
              );
              return null;
            },
          );
          debugPrint('MetadataExtractor: WAV duration calculated: $result');
          break;
        case 'm4a':
        case 'mp4':
          result = await _calculateM4aDuration(path).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint(
                'MetadataExtractor: M4A duration calculation timed out',
              );
              return null;
            },
          );
          debugPrint('MetadataExtractor: M4A duration calculated: $result');
          break;
        default:
          // For other formats, lofty handles duration via the main extraction path
          debugPrint(
            'MetadataExtractor: No custom duration calculation for $extension',
          );
          result = null;
      }

      return result;
    } catch (e) {
      debugPrint('MetadataExtractor: Error getting audio duration: $e');
      return null;
    }
  }

  /// Calculate duration of an M4A/MP4 file by reading its atoms
  Future<Duration?> _calculateM4aDuration(String path) async {
    try {
      debugPrint('MetadataExtractor: Calculating M4A duration for: $path');
      final file = File(path);
      final randomAccess = await file.open();

      try {
        // M4A files use the MP4 container format with atoms
        // We need to find the 'mvhd' atom which contains duration and timescale
        // The structure is: ftyp -> moov -> mvhd

        int? timescale;
        int? duration;

        // Read file in chunks to find mvhd atom
        var position = 0;
        final fileSize = await file.length();

        debugPrint('MetadataExtractor: M4A file size: $fileSize bytes');

        while (position < fileSize && (timescale == null || duration == null)) {
          await randomAccess.setPosition(position);
          final sizeBytes = await randomAccess.read(4);
          if (sizeBytes.length < 4) {
            debugPrint(
              'MetadataExtractor: Could not read atom size at position $position',
            );
            break;
          }

          var atomSize =
              (sizeBytes[0] << 24) |
              (sizeBytes[1] << 16) |
              (sizeBytes[2] << 8) |
              sizeBytes[3];

          final typeBytes = await randomAccess.read(4);
          if (typeBytes.length < 4) {
            debugPrint(
              'MetadataExtractor: Could not read atom type at position $position',
            );
            break;
          }

          final atomType = String.fromCharCodes(typeBytes);
          debugPrint(
            'MetadataExtractor: Found atom "$atomType" at position $position, size: $atomSize',
          );

          if (atomType == 'mvhd') {
            // Found the movie header atom
            final versionAndFlags = await randomAccess.read(4);
            if (versionAndFlags.length < 4) break;

            final version = versionAndFlags[0];
            debugPrint('MetadataExtractor: mvhd version: $version');

            if (version == 0) {
              // Version 0: 32-bit values
              await randomAccess.read(8); // Skip creation and modification time
              final timescaleBytes = await randomAccess.read(4);
              if (timescaleBytes.length < 4) break;
              timescale =
                  (timescaleBytes[0] << 24) |
                  (timescaleBytes[1] << 16) |
                  (timescaleBytes[2] << 8) |
                  timescaleBytes[3];

              final durationBytes = await randomAccess.read(4);
              if (durationBytes.length < 4) break;
              duration =
                  (durationBytes[0] << 24) |
                  (durationBytes[1] << 16) |
                  (durationBytes[2] << 8) |
                  durationBytes[3];

              debugPrint(
                'MetadataExtractor: M4A timescale: $timescale, duration: $duration',
              );
            } else {
              // Version 1: 64-bit values
              await randomAccess.read(
                16,
              ); // Skip creation and modification time (64-bit each)
              final timescaleBytes = await randomAccess.read(4);
              if (timescaleBytes.length < 4) break;
              timescale =
                  (timescaleBytes[0] << 24) |
                  (timescaleBytes[1] << 16) |
                  (timescaleBytes[2] << 8) |
                  timescaleBytes[3];

              final durationBytes = await randomAccess.read(8);
              if (durationBytes.length < 8) break;
              // Read all 64 bits properly
              var durationValue = 0;
              for (var i = 0; i < 8; i++) {
                durationValue = (durationValue << 8) | durationBytes[i];
              }
              duration = durationValue;

              debugPrint(
                'MetadataExtractor: M4A timescale: $timescale, duration: $duration (64-bit)',
              );
            }
            break;
          } else if (atomType == 'moov') {
            // Enter the moov atom to find mvhd inside it
            debugPrint('MetadataExtractor: Entering moov atom');
            position += 8; // Skip atom header, continue inside
            continue;
          }

          // Move to next atom
          if (atomSize == 0) {
            debugPrint('MetadataExtractor: Atom extends to end of file');
            break;
          }
          if (atomSize == 1) {
            // Extended size
            final extSizeBytes = await randomAccess.read(8);
            if (extSizeBytes.length < 8) break;
            atomSize = 0;
            for (var i = 0; i < 8; i++) {
              atomSize = (atomSize << 8) | extSizeBytes[i];
            }
            debugPrint('MetadataExtractor: Extended atom size: $atomSize');
          }

          if (atomSize < 8) {
            debugPrint('MetadataExtractor: Invalid atom size: $atomSize');
            break;
          }

          position += atomSize;
        }

        if (timescale != null && duration != null && timescale > 0) {
          final durationSeconds = duration / timescale;
          debugPrint(
            'MetadataExtractor: M4A calculated duration: ${durationSeconds}s',
          );
          return Duration(milliseconds: (durationSeconds * 1000).round());
        } else {
          debugPrint(
            'MetadataExtractor: Could not find timescale/duration in M4A file',
          );
        }
      } finally {
        await randomAccess.close();
      }

      return null;
    } catch (e) {
      debugPrint('MetadataExtractor: Error calculating M4A duration: $e');
      return null;
    }
  }

  /// Calculate duration of a WAV file by reading its header
  Future<Duration?> _calculateWavDuration(String path) async {
    try {
      debugPrint('MetadataExtractor: Calculating WAV duration for: $path');
      final file = File(path);

      // Read first 2KB to find fmt and data chunks (handles files with extra chunks)
      final bytes = await file.openRead(0, 2048).toList();

      if (bytes.isEmpty) {
        debugPrint('MetadataExtractor: WAV header is empty');
        return null;
      }

      // Flatten the list of lists into a single list
      final header = bytes.expand((x) => x).toList();

      if (header.length < 44) {
        debugPrint(
          'MetadataExtractor: WAV header too short: ${header.length} bytes',
        );
        return null;
      }

      // Check for RIFF header
      if (header[0] != 0x52 ||
          header[1] != 0x49 ||
          header[2] != 0x46 ||
          header[3] != 0x46) {
        debugPrint('MetadataExtractor: Not a valid RIFF header');
        return null;
      }

      // Check for WAVE format
      if (header[8] != 0x57 ||
          header[9] != 0x41 ||
          header[10] != 0x56 ||
          header[11] != 0x45) {
        debugPrint('MetadataExtractor: Not a valid WAVE format');
        return null;
      }

      // Find the fmt chunk to get byte rate
      int? byteRate;
      int? sampleRate;

      for (var i = 12; i < header.length - 8; i++) {
        if (header[i] == 0x66 &&
            header[i + 1] == 0x6D &&
            header[i + 2] == 0x74 &&
            header[i + 3] == 0x20) {
          // Found "fmt " chunk
          // Sample rate is at offset 12 from chunk start (i+12)
          if (i + 20 < header.length) {
            sampleRate =
                header[i + 12] |
                (header[i + 13] << 8) |
                (header[i + 14] << 16) |
                (header[i + 15] << 24);

            // Byte rate is at offset 16 from chunk start (i+16)
            byteRate =
                header[i + 16] |
                (header[i + 17] << 8) |
                (header[i + 18] << 16) |
                (header[i + 19] << 24);

            debugPrint('MetadataExtractor: Found fmt chunk at offset $i');
            debugPrint(
              'MetadataExtractor: WAV sample rate: $sampleRate, byte rate: $byteRate',
            );
            break;
          }
        }
      }

      if (byteRate == null || byteRate == 0) {
        debugPrint('MetadataExtractor: Invalid or missing byte rate');
        return null;
      }

      // Find the data chunk
      int? dataChunkSize;

      for (var i = 12; i < header.length - 8; i++) {
        if (header[i] == 0x64 &&
            header[i + 1] == 0x61 &&
            header[i + 2] == 0x74 &&
            header[i + 3] == 0x61) {
          // Found "data" chunk
          dataChunkSize =
              header[i + 4] |
              (header[i + 5] << 8) |
              (header[i + 6] << 16) |
              (header[i + 7] << 24);
          debugPrint(
            'MetadataExtractor: Found data chunk at offset $i, size: $dataChunkSize bytes',
          );
          break;
        }
      }

      if (dataChunkSize == null || dataChunkSize == 0) {
        // Fallback: use file size - estimate header size
        final fileSize = await file.length();
        // Estimate header size based on where we stopped reading
        dataChunkSize = fileSize - 1024; // Conservative estimate
        debugPrint(
          'MetadataExtractor: Data chunk not found in header, using file size fallback: $dataChunkSize bytes',
        );
      }

      // Calculate duration: data_size / byte_rate
      final durationSeconds = dataChunkSize / byteRate;

      debugPrint(
        'MetadataExtractor: WAV data size: $dataChunkSize, duration: ${durationSeconds}s',
      );

      return Duration(milliseconds: (durationSeconds * 1000).round());
    } catch (e) {
      debugPrint('MetadataExtractor: Error calculating WAV duration: $e');
      return null;
    }
  }

  /// Extract metadata from a video file
  Future<ExtractionResult> _extractFromVideoFile(String path) async {
    // Extract basic info from filename
    final filename = _getFilenameWithoutExtension(path);
    final parsedFromFilename = _parseFilename(filename);

    // TODO: Implement actual video metadata extraction
    // Video files may contain metadata in various container formats (MP4, MKV, etc.)

    final rawTags = <String, String>{
      'filename': filename,
      'path': path,
      'type': 'video',
    };

    return ExtractionResult.success(
      Metadata(
        title: parsedFromFilename['title'] ?? filename,
        artists: _parseArtistString(parsedFromFilename['artist'] ?? ''),
        album: '',
        duration: Duration.zero,
      ),
      rawTags: rawTags,
    );
  }

  /// Extract metadata from an image file
  Future<ExtractionResult> _extractFromImageFile(String path) async {
    // Images typically don't have music metadata, just use filename
    final filename = _getFilenameWithoutExtension(path);

    return ExtractionResult.success(
      Metadata(
        title: filename,
        artists: [],
        album: '',
        duration: Duration.zero,
      ),
      rawTags: {'filename': filename, 'path': path, 'type': 'image'},
    );
  }

  /// Extract metadata from an LRC file
  Future<ExtractionResult> _extractFromLrcFile(String path) async {
    final file = File(path);
    final content = await file.readAsString();

    return extractFromLrcContent(content, path);
  }

  /// Extract metadata from LRC content
  ExtractionResult extractFromLrcContent(String content, [String? sourcePath]) {
    final rawTags = <String, String>{};
    String? title;
    String? artist;
    String? album;
    int? year;
    Duration? duration;

    // Parse LRC metadata tags
    // Format: [tag:value]
    final metadataPattern = RegExp(r'^\[([a-zA-Z]+):(.+)\]$', multiLine: true);
    for (final match in metadataPattern.allMatches(content)) {
      final tag = match.group(1)?.toLowerCase();
      final value = match.group(2)?.trim();
      if (tag != null && value != null && value.isNotEmpty) {
        rawTags[tag] = value;
        switch (tag) {
          case 'ti':
          case 'title':
            title = value;
            break;
          case 'ar':
          case 'artist':
            artist = value;
            break;
          case 'al':
          case 'album':
            album = value;
            break;
          case 'by':
            // LRC author, not song artist
            rawTags['lrc_author'] = value;
            break;
          case 'length':
            duration = _parseDuration(value);
            break;
        }
      }
    }

    // Try to extract year from various tags
    if (rawTags.containsKey('year')) {
      year = int.tryParse(rawTags['year']!);
    }

    // Fallback to filename if no title found
    if (title == null && sourcePath != null) {
      final filename = _getFilenameWithoutExtension(sourcePath);
      final parsed = _parseFilename(filename);
      title = parsed['title'] ?? filename;
      artist ??= parsed['artist'];
    }

    return ExtractionResult.success(
      Metadata(
        title: title ?? 'Unknown',
        artists: _parseArtistString(artist ?? ''),
        album: album ?? '',
        year: year,
        duration: duration ?? Duration.zero,
      ),
      rawTags: rawTags,
    );
  }

  /// Extract metadata from a URL (limited without downloading)
  Future<ExtractionResult> _extractFromUrl(String url) async {
    // For URLs, we can only extract info from the URL path itself
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return ExtractionResult.failure('Invalid URL: $url');
    }

    final pathSegments = uri.pathSegments;
    if (pathSegments.isEmpty) {
      return ExtractionResult.success(
        Metadata(
          title: uri.host,
          artists: [],
          album: '',
          duration: Duration.zero,
        ),
        rawTags: {'url': url, 'host': uri.host},
      );
    }

    final lastSegment = pathSegments.last;
    final filename = _getFilenameWithoutExtension(lastSegment);
    final parsed = _parseFilename(filename);

    return ExtractionResult.success(
      Metadata(
        title: parsed['title'] ?? filename,
        artists: _parseArtistString(parsed['artist'] ?? ''),
        album: '',
        duration: Duration.zero,
      ),
      rawTags: {'url': url, 'host': uri.host, 'filename': filename},
    );
  }

  /// Extract metadata from an API source
  Future<ExtractionResult> _extractFromApi(
    String provider,
    String resourceId,
  ) async {
    // API metadata should be fetched from the API itself
    // This is a placeholder that returns minimal info
    return ExtractionResult.success(
      Metadata(
        title: resourceId,
        artists: [],
        album: '',
        duration: Duration.zero,
      ),
      rawTags: {'provider': provider, 'resourceId': resourceId},
    );
  }

  /// Get filename without extension from a path
  String _getFilenameWithoutExtension(String path) {
    final filename = path.split('/').last.split('\\').last;
    final lastDot = filename.lastIndexOf('.');
    if (lastDot == -1) return filename;
    return filename.substring(0, lastDot);
  }

  /// Parse filename to extract artist and title
  /// Common patterns:
  /// - "Artist - Title"
  /// - "Artist-Title"
  /// - "Title"
  Map<String, String> _parseFilename(String filename) {
    // Try "Artist - Title" pattern (with spaces around dash)
    var parts = filename.split(' - ');
    if (parts.length >= 2) {
      return {
        'artist': parts[0].trim(),
        'title': parts.sublist(1).join(' - ').trim(),
      };
    }

    // Try "Artist-Title" pattern (without spaces)
    parts = filename.split('-');
    if (parts.length >= 2) {
      return {
        'artist': parts[0].trim(),
        'title': parts.sublist(1).join('-').trim(),
      };
    }

    // Just title
    return {'title': filename.trim()};
  }

  /// Parse duration string to Duration
  /// Supports formats: "mm:ss", "hh:mm:ss", "ss"
  Duration? _parseDuration(String value) {
    final parts = value.split(':');
    try {
      if (parts.length == 1) {
        // Just seconds
        return Duration(seconds: int.parse(parts[0]));
      } else if (parts.length == 2) {
        // mm:ss
        return Duration(
          minutes: int.parse(parts[0]),
          seconds: int.parse(parts[1]),
        );
      } else if (parts.length == 3) {
        // hh:mm:ss
        return Duration(
          hours: int.parse(parts[0]),
          minutes: int.parse(parts[1]),
          seconds: int.parse(parts[2]),
        );
      }
    } catch (_) {
      // Parse error
    }
    return null;
  }

  /// Parse artist string into a list of artists
  /// Supports multiple separators: comma, slash, semicolon, &, feat., ft., featuring, ×, x
  List<String> _parseArtistString(String artistString) {
    if (artistString.isEmpty) return [];
    final normalized = artistString
        .replaceAll(RegExp(r'\s*[,;/&]\s*'), '|')
        .replaceAll(RegExp(r'\s+feat\.?\s+', caseSensitive: false), '|')
        .replaceAll(RegExp(r'\s+ft\.?\s+', caseSensitive: false), '|')
        .replaceAll(RegExp(r'\s+featuring\s+', caseSensitive: false), '|')
        .replaceAll(RegExp(r'\s+×\s+'), '|')
        .replaceAll(RegExp(r'\s+x\s+', caseSensitive: false), '|');
    return normalized
        .split('|')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Map extracted metadata to built-in tag values
  /// Returns a map of tag name to value for built-in tags
  Map<String, String> mapToBuiltInTags(Metadata metadata) {
    final tags = <String, String>{};

    if (metadata.title.isNotEmpty) {
      tags['name'] = metadata.title;
    }
    if (metadata.artists.isNotEmpty) {
      tags['artist'] = metadata.artistDisplay;
    }
    if (metadata.album.isNotEmpty) {
      tags['album'] = metadata.album;
    }
    if (metadata.year != null) {
      tags['time'] = metadata.year.toString();
    }
    if (metadata.duration != Duration.zero) {
      tags['duration'] = metadata.duration.inSeconds.toString();
    }

    return tags;
  }
}
