import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models/metadata.dart';
import '../models/playback_preferences.dart';
import '../models/song_unit.dart';
import '../models/source.dart';
import '../models/source_collection.dart';
import '../models/source_origin.dart';
import '../repositories/library_repository.dart';
import 'metadata_extractor.dart';
import 'thumbnail_cache.dart';
import 'thumbnail_extractor.dart';

/// Service for discovering audio files in library locations
/// and adding them as temporary Song Units.
class AudioDiscoveryService {
  AudioDiscoveryService({
    required LibraryRepository libraryRepository,
    MetadataExtractor? metadataExtractor,
    ThumbnailExtractor? thumbnailExtractor,
  }) : _libraryRepository = libraryRepository,
       _metadataExtractor = metadataExtractor ?? MetadataExtractor(),
       _thumbnailExtractor = thumbnailExtractor ?? ThumbnailExtractor();

  final LibraryRepository _libraryRepository;
  final MetadataExtractor _metadataExtractor;
  final ThumbnailExtractor _thumbnailExtractor;
  final _uuid = const Uuid();

  /// Supported audio file extensions
  static const _audioExtensions = [
    '.mp3', '.flac', '.wav', '.aac', '.ogg', '.m4a',
  ];

  /// Discover audio files in all library locations
  Future<DiscoveryResult> discoverAudioFiles(
    List<dynamic> locations, {
    void Function(int current, int total, String message)? onProgress,
  }) async {
    var discovered = 0;
    var skipped = 0;
    var errors = 0;

    for (final location in locations) {
      try {
        final result = await _discoverInLocation(
          location,
          onProgress: onProgress,
        );
        discovered += result.discovered;
        skipped += result.skipped;
        errors += result.errors;
      } catch (e) {
        debugPrint('Error discovering audio in ${location.rootPath}: $e');
        errors++;
      }
    }

    return DiscoveryResult(
      discovered: discovered,
      skipped: skipped,
      errors: errors,
    );
  }

  Future<DiscoveryResult> _discoverInLocation(
    dynamic location, {
    void Function(int current, int total, String message)? onProgress,
  }) async {
    final directory = Directory(location.rootPath as String);
    if (!directory.existsSync()) {
      return const DiscoveryResult(discovered: 0, skipped: 0, errors: 1);
    }

    var discovered = 0;
    var skipped = 0;
    var errors = 0;

    final audioFiles = <FileSystemEntity>[];
    await for (final entity in directory.list(recursive: true)) {
      if (entity is File && _isAudioFile(entity.path)) {
        audioFiles.add(entity);
      }
    }

    final total = audioFiles.length;
    var current = 0;

    for (final entity in audioFiles) {
      current++;
      final file = entity as File;
      final filePath = file.path;

      onProgress?.call(current, total, 'Scanning: ${p.basename(filePath)}');

      try {
        // Check if already exists as temporary song unit
        if (await _libraryRepository.hasTemporarySongUnitForPath(filePath)) {
          skipped++;
          continue;
        }

        // Check if referenced by any full song unit
        if (await _isFileReferencedBySongUnit(filePath)) {
          skipped++;
          continue;
        }

        // Extract metadata
        final extractionResult = await _metadataExtractor.extractFromFile(filePath);
        final metadata = extractionResult.metadata ?? Metadata.empty();

        // Extract thumbnail
        String? thumbnailSourceId;
        final audioSourceId = _uuid.v4();
        try {
          final artworkBytes = await _thumbnailExtractor
              .extractThumbnailBytes(filePath)
              .timeout(const Duration(seconds: 5), onTimeout: () => null);

          if (artworkBytes != null && artworkBytes.isNotEmpty) {
            try {
              thumbnailSourceId = await ThumbnailCache.instance.cacheFromBytes(artworkBytes);
            } catch (_) {
              thumbnailSourceId = null;
            }
          }
        } catch (_) {}

        // Create temporary Song Unit
        final songUnit = _createTemporarySongUnit(
          filePath: filePath,
          metadata: metadata,
          thumbnailSourceId: thumbnailSourceId,
          libraryLocationId: location.id as String,
          audioSourceId: audioSourceId,
        );

        await _libraryRepository.addSongUnit(songUnit);
        discovered++;
      } catch (e) {
        debugPrint('Error processing $filePath: $e');
        errors++;
      }
    }

    return DiscoveryResult(
      discovered: discovered,
      skipped: skipped,
      errors: errors,
    );
  }

  bool _isAudioFile(String path) {
    final ext = p.extension(path).toLowerCase();
    return _audioExtensions.contains(ext);
  }

  Future<bool> _isFileReferencedBySongUnit(String filePath) async {
    final songUnits = await _libraryRepository.getAllSongUnits();
    final absoluteFilePath = p.normalize(p.absolute(filePath));
    final fileName = p.basename(filePath);
    final fileDir = p.dirname(absoluteFilePath);

    for (final unit in songUnits) {
      if (unit.isTemporary) continue; // Skip other temporary ones
      for (final source in unit.sources.getAllSources()) {
        if (source.origin is LocalFileOrigin) {
          final origin = source.origin as LocalFileOrigin;
          final sourcePath = origin.path;

          // Strategy 1: Direct string match
          if (sourcePath == filePath) return true;

          // Strategy 2: Normalized absolute path match
          final absoluteSourcePath = p.isAbsolute(sourcePath)
              ? sourcePath
              : p.join(fileDir, sourcePath);
          final normalizedSourcePath = p.normalize(absoluteSourcePath);
          if (normalizedSourcePath == absoluteFilePath) return true;

          // Strategy 3: Basename match in same directory
          if (p.basename(sourcePath) == fileName &&
              p.dirname(normalizedSourcePath) == fileDir) {
            return true;
          }

          // Strategy 4: Basename-only match (handles path normalization
          // differences across platforms, e.g. Android symlinks)
          if (p.basename(sourcePath) == fileName) {
            // Compare directory paths with trailing separator stripped
            final sourceDir = p.normalize(p.dirname(absoluteSourcePath));
            final targetDir = p.normalize(fileDir);
            if (sourceDir == targetDir) return true;
          }
        }
      }
    }
    return false;
  }

  /// Create a temporary Song Unit from a discovered audio file
  SongUnit _createTemporarySongUnit({
    required String filePath,
    required Metadata metadata,
    String? thumbnailSourceId,
    required String libraryLocationId,
    String? audioSourceId,
  }) {
    final ext = p.extension(filePath).toLowerCase().replaceFirst('.', '');
    final format = _getAudioFormat(ext);
    final sourceId = audioSourceId ?? _uuid.v4();

    return SongUnit(
      id: _uuid.v4(),
      metadata: Metadata(
        title: metadata.title.isNotEmpty ? metadata.title : p.basename(filePath),
        artists: metadata.artists,
        album: metadata.album,
        duration: metadata.duration,
        thumbnailSourceId: thumbnailSourceId,
      ),
      sources: SourceCollection(
        audioSources: [
          AudioSource(
            id: sourceId,
            origin: LocalFileOrigin(filePath),
            priority: 0,
            format: format,
            duration: metadata.duration,
          ),
        ],
      ),
      preferences: const PlaybackPreferences(),
      tagIds: [],
      libraryLocationId: libraryLocationId,
      isTemporary: true,
      discoveredAt: DateTime.now(),
      originalFilePath: filePath,
    );
  }

  static AudioFormat _getAudioFormat(String ext) {
    switch (ext) {
      case 'mp3': return AudioFormat.mp3;
      case 'flac': return AudioFormat.flac;
      case 'wav': return AudioFormat.wav;
      case 'aac': return AudioFormat.aac;
      case 'ogg': return AudioFormat.ogg;
      case 'm4a': return AudioFormat.m4a;
      default: return AudioFormat.other;
    }
  }

  /// Process a single audio file (for file watcher integration)
  Future<bool> processAudioFile(
    String filePath,
    String libraryLocationId, {
    bool extractThumbnail = true,
  }) async {
    try {
      if (!_isAudioFile(filePath)) return false;
      if (await _libraryRepository.hasTemporarySongUnitForPath(filePath)) {
        return false;
      }
      if (await _isFileReferencedBySongUnit(filePath)) return false;

      final extractionResult = await _metadataExtractor.extractFromFile(filePath);
      final metadata = extractionResult.metadata ?? Metadata.empty();

      final audioSourceId = _uuid.v4();
      String? thumbnailSourceId;
      if (extractThumbnail) {
        try {
          final artworkBytes = await _thumbnailExtractor
              .extractThumbnailBytes(filePath)
              .timeout(const Duration(seconds: 5), onTimeout: () => null);
          if (artworkBytes != null && artworkBytes.isNotEmpty) {
            try {
              thumbnailSourceId = await ThumbnailCache.instance.cacheFromBytes(artworkBytes);
            } catch (_) {
              thumbnailSourceId = null;
            }
          }
        } catch (_) {}
      }

      final songUnit = _createTemporarySongUnit(
        filePath: filePath,
        metadata: metadata,
        thumbnailSourceId: thumbnailSourceId,
        libraryLocationId: libraryLocationId,
        audioSourceId: audioSourceId,
      );

      await _libraryRepository.addSongUnit(songUnit);
      return true;
    } catch (e) {
      debugPrint('Error processing audio file $filePath: $e');
      return false;
    }
  }

  /// Remove temporary song unit when file is deleted
  Future<void> removeAudioFile(String filePath) async {
    try {
      await _libraryRepository.deleteTemporarySongUnitByPath(filePath);
    } catch (e) {
      debugPrint('Error removing temporary song unit for $filePath: $e');
    }
  }

  /// Extract thumbnails for temporary Song Units that don't have them yet
  Future<int> extractMissingThumbnails({
    void Function(int current, int total, String message)? onProgress,
  }) async {
    try {
      final tempUnits = await _libraryRepository.getTemporarySongUnits();
      final needsThumbnail = tempUnits
          .where((u) => u.metadata.thumbnailSourceId == null)
          .toList();

      if (needsThumbnail.isEmpty) return 0;

      var extracted = 0;
      final total = needsThumbnail.length;

      for (var i = 0; i < needsThumbnail.length; i++) {
        final unit = needsThumbnail[i];
        final filePath = unit.originalFilePath;
        if (filePath == null) continue;

        onProgress?.call(i + 1, total, 'Extracting: ${p.basename(filePath)}');

        try {
          final artworkBytes = await _thumbnailExtractor
              .extractThumbnailBytes(filePath);
          if (artworkBytes != null && artworkBytes.isNotEmpty) {
            final hash = await ThumbnailCache.instance.cacheFromBytes(artworkBytes);
            final updated = unit.copyWith(
              metadata: unit.metadata.copyWith(
                thumbnailSourceId: hash,
              ),
            );
            await _libraryRepository.updateSongUnit(updated);
            extracted++;
          }
        } catch (_) {}
      }

      return extracted;
    } catch (e) {
      debugPrint('Error extracting missing thumbnails: $e');
      return 0;
    }
  }
}

/// Result of audio discovery operation
class DiscoveryResult {
  const DiscoveryResult({
    required this.discovered,
    required this.skipped,
    required this.errors,
  });

  final int discovered;
  final int skipped;
  final int errors;

  int get total => discovered + skipped + errors;
}
