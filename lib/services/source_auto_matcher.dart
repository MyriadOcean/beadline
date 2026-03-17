import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models/source.dart';
import '../models/source_origin.dart';

/// Service for automatically discovering and matching related source files
///
/// When adding a source (e.g., audio file), this service searches for related files
/// with the same base name but different extensions in the same directory.
///
/// Examples:
/// - abc.mp3 → finds abc.lrc (lyrics), abc.mp4 (video), abc.jpg (thumbnail)
/// - song.flac → finds song.lrc, song.mkv, song.png
class SourceAutoMatcher {
  /// Audio file extensions
  static const audioExtensions = [
    '.mp3',
    '.flac',
    '.wav',
    '.aac',
    '.ogg',
    '.m4a',
    '.opus',
    '.wma',
  ];

  /// Video file extensions
  static const videoExtensions = [
    '.mp4',
    '.mkv',
    '.avi',
    '.mov',
    '.wmv',
    '.flv',
    '.webm',
    '.m4v',
  ];

  /// Image file extensions (for thumbnails/display)
  static const imageExtensions = [
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.bmp',
    '.webp',
  ];

  /// Lyrics file extensions
  static const lyricsExtensions = [
    '.lrc',
    '.txt', // Some lyrics files use .txt
  ];

  /// Accompaniment file naming patterns
  /// These are common suffixes used for accompaniment/karaoke versions
  static const accompanimentSuffixes = [
    // English patterns
    '_inst',
    '_instrumental',
    '_karaoke',
    '_accomp',
    '_backing',
    '-inst',
    '-instrumental',
    '-karaoke',
    '-accomp',
    '-backing',
    ' (instrumental)',
    ' (karaoke)',
    // Chinese patterns
    '_伴奏',
    '-伴奏',
    ' 伴奏',
    '(伴奏)',
    '（伴奏）',
    '_纯音乐',
    '-纯音乐',
    ' 纯音乐',
    '_无人声',
    '-无人声',
    ' 无人声',
  ];

  /// Auto-discover and match related sources for a given file path
  ///
  /// Returns a map of source types to lists of matched file paths:
  /// - 'audio': Additional audio sources
  /// - 'video': Video sources
  /// - 'image': Image sources (for display)
  /// - 'lyrics': Lyrics sources
  /// - 'accompaniment': Accompaniment/instrumental sources
  Future<Map<String, List<String>>> discoverRelatedSources(
    String filePath,
  ) async {
    final result = <String, List<String>>{
      'audio': [],
      'video': [],
      'image': [],
      'lyrics': [],
      'accompaniment': [],
    };

    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        debugPrint('SourceAutoMatcher: File does not exist: $filePath');
        return result;
      }

      final directory = file.parent;
      final baseName = p.basenameWithoutExtension(filePath);
      final extension = p.extension(filePath).toLowerCase();

      debugPrint(
        'SourceAutoMatcher: Discovering sources for: $baseName$extension',
      );

      // List all files in the same directory
      final files = directory.listSync();

      for (final entity in files) {
        if (entity is! File) continue;

        final entityPath = entity.path;
        final entityBaseName = p.basenameWithoutExtension(entityPath);
        final entityExtension = p.extension(entityPath).toLowerCase();

        // Skip the original file
        if (entityPath == filePath) continue;

        // Check if base names match (case-insensitive)
        final baseNamesMatch =
            entityBaseName.toLowerCase() == baseName.toLowerCase();

        if (baseNamesMatch) {
          // Exact base name match - categorize by extension
          _categorizeMatchedFile(entityPath, entityExtension, result);
        } else {
          // Check for accompaniment patterns
          final isAccompaniment = _isAccompanimentFile(
            entityBaseName,
            baseName,
          );
          if (isAccompaniment && audioExtensions.contains(entityExtension)) {
            result['accompaniment']!.add(entityPath);
            debugPrint(
              'SourceAutoMatcher: Found accompaniment: ${p.basename(entityPath)}',
            );
          }
        }
      }

      // Log summary
      debugPrint('SourceAutoMatcher: Discovery complete:');
      debugPrint('  Audio: ${result['audio']!.length}');
      debugPrint('  Video: ${result['video']!.length}');
      debugPrint('  Image: ${result['image']!.length}');
      debugPrint('  Lyrics: ${result['lyrics']!.length}');
      debugPrint('  Accompaniment: ${result['accompaniment']!.length}');
    } catch (e) {
      debugPrint('SourceAutoMatcher: Error discovering sources: $e');
    }

    return result;
  }

  /// Categorize a matched file by its extension
  void _categorizeMatchedFile(
    String filePath,
    String extension,
    Map<String, List<String>> result,
  ) {
    if (audioExtensions.contains(extension)) {
      result['audio']!.add(filePath);
      debugPrint('SourceAutoMatcher: Found audio: ${p.basename(filePath)}');
    } else if (videoExtensions.contains(extension)) {
      result['video']!.add(filePath);
      debugPrint('SourceAutoMatcher: Found video: ${p.basename(filePath)}');
    } else if (imageExtensions.contains(extension)) {
      result['image']!.add(filePath);
      debugPrint('SourceAutoMatcher: Found image: ${p.basename(filePath)}');
    } else if (lyricsExtensions.contains(extension)) {
      result['lyrics']!.add(filePath);
      debugPrint('SourceAutoMatcher: Found lyrics: ${p.basename(filePath)}');
    }
  }

  /// Check if a file is an accompaniment version of the base file
  bool _isAccompanimentFile(String fileName, String baseName) {
    final lowerFileName = fileName.toLowerCase();
    final lowerBaseName = baseName.toLowerCase();

    // Check if fileName starts with baseName and has an accompaniment suffix
    if (!lowerFileName.startsWith(lowerBaseName)) {
      return false;
    }

    final suffix = lowerFileName.substring(lowerBaseName.length);

    for (final pattern in accompanimentSuffixes) {
      if (suffix.startsWith(pattern.toLowerCase())) {
        return true;
      }
    }

    return false;
  }

  /// Detect audio format from file extension
  AudioFormat _detectAudioFormat(String extension) {
    switch (extension.toLowerCase()) {
      case '.mp3':
        return AudioFormat.mp3;
      case '.flac':
        return AudioFormat.flac;
      case '.wav':
        return AudioFormat.wav;
      case '.aac':
        return AudioFormat.aac;
      case '.ogg':
        return AudioFormat.ogg;
      case '.m4a':
        return AudioFormat.m4a;
      default:
        return AudioFormat.other;
    }
  }

  /// Detect lyrics format from file extension
  LyricsFormat _detectLyricsFormat(String extension) {
    // Currently only LRC is supported
    return LyricsFormat.lrc;
  }

  /// Create Source objects from discovered file paths
  ///
  /// Returns a SourceCollection with all discovered sources
  Future<DiscoveredSources> createSourcesFromPaths(
    Map<String, List<String>> paths,
  ) async {
    const uuid = Uuid();
    final audioSources = <AudioSource>[];
    final videoSources = <DisplaySource>[];
    final imageSources = <DisplaySource>[];
    final lyricsSources = <HoverSource>[];
    final accompanimentSources = <AccompanimentSource>[];

    // Create audio sources
    for (final path in paths['audio']!) {
      final extension = p.extension(path);
      audioSources.add(
        AudioSource(
          id: uuid.v4(),
          origin: LocalFileOrigin(path),
          priority: audioSources.length, // Lower priority than main source
          format: _detectAudioFormat(extension),
        ),
      );
    }

    // Create video sources
    for (final path in paths['video']!) {
      videoSources.add(
        DisplaySource(
          id: uuid.v4(),
          origin: LocalFileOrigin(path),
          displayType: DisplayType.video,
          priority: videoSources.length,
        ),
      );
    }

    // Create image sources
    for (final path in paths['image']!) {
      imageSources.add(
        DisplaySource(
          id: uuid.v4(),
          origin: LocalFileOrigin(path),
          displayType: DisplayType.image,
          priority: imageSources.length,
        ),
      );
    }

    // Create lyrics sources
    for (final path in paths['lyrics']!) {
      final extension = p.extension(path);
      lyricsSources.add(
        HoverSource(
          id: uuid.v4(),
          origin: LocalFileOrigin(path),
          priority: lyricsSources.length,
          format: _detectLyricsFormat(extension),
        ),
      );
    }

    // Create accompaniment sources
    for (final path in paths['accompaniment']!) {
      final extension = p.extension(path);
      accompanimentSources.add(
        AccompanimentSource(
          id: uuid.v4(),
          origin: LocalFileOrigin(path),
          priority: accompanimentSources.length,
          format: _detectAudioFormat(extension),
        ),
      );
    }

    return DiscoveredSources(
      audioSources: audioSources,
      videoSources: videoSources,
      imageSources: imageSources,
      lyricsSources: lyricsSources,
      accompanimentSources: accompanimentSources,
    );
  }

  /// Convenience method to discover and create sources in one call
  Future<DiscoveredSources> discoverAndCreateSources(String filePath) async {
    final paths = await discoverRelatedSources(filePath);
    return createSourcesFromPaths(paths);
  }
}

/// Container for discovered sources
class DiscoveredSources {
  const DiscoveredSources({
    required this.audioSources,
    required this.videoSources,
    required this.imageSources,
    required this.lyricsSources,
    required this.accompanimentSources,
  });

  final List<AudioSource> audioSources;
  final List<DisplaySource> videoSources;
  final List<DisplaySource> imageSources;
  final List<HoverSource> lyricsSources;
  final List<AccompanimentSource> accompanimentSources;

  /// Check if any sources were discovered
  bool get hasAnySources =>
      audioSources.isNotEmpty ||
      videoSources.isNotEmpty ||
      imageSources.isNotEmpty ||
      lyricsSources.isNotEmpty ||
      accompanimentSources.isNotEmpty;

  /// Get total count of discovered sources
  int get totalCount =>
      audioSources.length +
      videoSources.length +
      imageSources.length +
      lyricsSources.length +
      accompanimentSources.length;
}
