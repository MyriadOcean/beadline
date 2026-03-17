import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../models/entry_point_file.dart';
import '../models/library_location.dart';
import '../models/playback_preferences.dart';
import '../models/song_unit.dart';
import '../models/source.dart';
import '../models/source_collection.dart';
import '../models/source_origin.dart';
import 'path_resolver.dart';

/// Exception thrown when entry point file validation fails
class EntryPointValidationException implements Exception {
  EntryPointValidationException(this.message, {this.field});
  final String message;
  final String? field;

  @override
  String toString() => field != null
      ? 'EntryPointValidationException: $message (field: $field)'
      : 'EntryPointValidationException: $message';
}

/// Callback to resolve tag IDs to tag names (for export)
typedef TagIdToNameResolver = Future<String?> Function(String tagId);

/// Callback to resolve tag names to tag IDs, creating if needed (for import)
typedef TagNameToIdResolver = Future<String?> Function(String tagName);

/// Service for reading, writing, and validating entry point files.
class EntryPointFileService {
  EntryPointFileService(this._pathResolver);
  final PathResolver _pathResolver;

  /// Update the library locations used for path resolution.
  void updateLocations(List<LibraryLocation> locations) {
    _pathResolver.updateLocations(locations);
  }

  /// Characters that are invalid in filenames across platforms
  static const _invalidFilenameChars = r'<>:"/\|?*';

  /// Additional characters to sanitize for safety
  static const _additionalSanitizeChars = '\x00\n\r\t';

  /// Generate a filename for an entry point file from a Song Unit name.
  ///
  /// Returns a filename in the format `beadline-[sanitized-name].json`
  String generateFilename(String songUnitName) {
    final sanitized = sanitizeName(songUnitName);
    return '${EntryPointFile.filePrefix}$sanitized${EntryPointFile.fileExtension}';
  }

  /// Sanitize a name for use in a filename.
  ///
  /// Removes or replaces invalid filename characters while preserving
  /// as much of the original name as possible.
  String sanitizeName(String name) {
    if (name.isEmpty) {
      return 'unnamed';
    }

    var sanitized = name;

    // Replace invalid characters with underscores
    for (final char in _invalidFilenameChars.split('')) {
      sanitized = sanitized.replaceAll(char, '_');
    }

    // Remove control characters
    for (final char in _additionalSanitizeChars.split('')) {
      sanitized = sanitized.replaceAll(char, '');
    }

    // Trim leading/trailing whitespace and dots (problematic on some systems)
    sanitized = sanitized.trim();
    while (sanitized.startsWith('.')) {
      sanitized = sanitized.substring(1);
    }
    while (sanitized.endsWith('.')) {
      sanitized = sanitized.substring(0, sanitized.length - 1);
    }

    // Collapse multiple underscores
    sanitized = sanitized.replaceAll(RegExp(r'_+'), '_');

    // Trim underscores from ends
    sanitized = sanitized.trim();
    while (sanitized.startsWith('_')) {
      sanitized = sanitized.substring(1);
    }
    while (sanitized.endsWith('_')) {
      sanitized = sanitized.substring(0, sanitized.length - 1);
    }

    // If nothing left, use default
    if (sanitized.isEmpty) {
      return 'unnamed';
    }

    // Limit length to avoid filesystem issues (keep reasonable length)
    if (sanitized.length > 100) {
      sanitized = sanitized.substring(0, 100);
    }

    return sanitized;
  }

  /// Write a Song Unit to an entry point file.
  ///
  /// Converts absolute paths to relative paths using PathResolver.
  /// Formats JSON with 2-space indentation for human readability.
  /// If [tagIdToNameResolver] is provided, tag names are written for portability.
  Future<void> writeEntryPoint(
    SongUnit songUnit,
    String directory, {
    TagIdToNameResolver? tagIdToNameResolver,
  }) async {
    final entryPointPath = p.join(
      directory,
      generateFilename(songUnit.metadata.title),
    );

    final entryPoint = await songUnitToEntryPoint(
      songUnit,
      entryPointPath,
      tagIdToNameResolver: tagIdToNameResolver,
    );
    final json = entryPoint.toJson();

    // Format with 2-space indentation
    const encoder = JsonEncoder.withIndent('  ');
    final jsonString = encoder.convert(json);

    final file = File(entryPointPath);
    await file.writeAsString(jsonString);
  }

  /// Read and parse an entry point file.
  ///
  /// Validates required fields and reports specific errors for missing
  /// or invalid data.
  Future<EntryPointFile> readEntryPoint(String filePath) async {
    final file = File(filePath);

    if (!file.existsSync()) {
      throw EntryPointValidationException(
        'Entry point file does not exist: $filePath',
      );
    }

    debugPrint('EntryPointFileService.readEntryPoint: Reading $filePath');
    final content = await file.readAsString();
    debugPrint(
      'EntryPointFileService.readEntryPoint: Read ${content.length} chars from $filePath',
    );
    return parseEntryPoint(content, filePath);
  }

  /// Parse entry point file content.
  ///
  /// Validates required fields and reports specific errors.
  EntryPointFile parseEntryPoint(String content, String filePath) {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      throw EntryPointValidationException('Invalid JSON syntax: $e');
    }

    // Validate required fields
    _validateRequiredField(json, 'version', filePath);
    _validateRequiredField(json, 'songUnitId', filePath);
    _validateRequiredField(json, 'name', filePath);
    _validateRequiredField(json, 'sources', filePath);

    // Validate version
    final version = json['version'];
    if (version is! int || version < 1) {
      throw EntryPointValidationException(
        'Invalid version: expected positive integer',
        field: 'version',
      );
    }

    // Validate songUnitId
    final songUnitId = json['songUnitId'];
    if (songUnitId is! String || songUnitId.isEmpty) {
      throw EntryPointValidationException(
        'Invalid songUnitId: expected non-empty string',
        field: 'songUnitId',
      );
    }

    // Validate name
    final name = json['name'];
    if (name is! String || name.isEmpty) {
      throw EntryPointValidationException(
        'Invalid name: expected non-empty string',
        field: 'name',
      );
    }

    // Validate sources is a list
    final sources = json['sources'];
    if (sources is! List) {
      throw EntryPointValidationException(
        'Invalid sources: expected array',
        field: 'sources',
      );
    }

    return EntryPointFile.fromJson(json);
  }

  void _validateRequiredField(
    Map<String, dynamic> json,
    String field,
    String filePath,
  ) {
    if (!json.containsKey(field)) {
      throw EntryPointValidationException(
        'Missing required field: $field',
        field: field,
      );
    }
  }

  /// Convert an EntryPointFile to a SongUnit.
  ///
  /// Resolves relative paths to absolute using the entry point file location.
  /// If [tagNameResolver] is provided, resolves tagNames from the JSON to
  /// tag IDs (looking up existing tags or creating new ones).
  /// Tags from tagNames are merged with any existing tagIds (deduped).
  Future<SongUnit> toSongUnit(
    EntryPointFile entryPoint,
    String entryPointPath, {
    TagNameToIdResolver? tagNameResolver,
  }) async {
    final sources = _convertSourcesToAbsolute(
      entryPoint.sources,
      entryPointPath,
    );

    // Start with existing tagIds
    final resolvedTagIds = <String>{...entryPoint.tagIds};

    // Resolve tagNames to IDs if resolver is provided
    if (tagNameResolver != null) {
      for (final name in entryPoint.tagNames) {
        final id = await tagNameResolver(name);
        if (id != null) {
          resolvedTagIds.add(id);
        }
      }
    }

    return SongUnit(
      id: entryPoint.songUnitId,
      metadata: entryPoint.metadata,
      sources: sources,
      tagIds: resolvedTagIds.toList(),
      preferences:
          entryPoint.playbackPreferences ?? PlaybackPreferences.defaults(),
    );
  }

  /// Convert a SongUnit to an EntryPointFile.
  ///
  /// Converts absolute paths to relative paths for portability.
  /// If [tagIdToNameResolver] is provided, populates tagNames for portability.
  /// Only non-collection user tags are exported as names.
  Future<EntryPointFile> songUnitToEntryPoint(
    SongUnit songUnit,
    String entryPointPath, {
    TagIdToNameResolver? tagIdToNameResolver,
  }) async {
    final sources = _convertSourcesToRelative(songUnit.sources, entryPointPath);
    final now = DateTime.now().toUtc();

    // Resolve tag IDs to names for portability
    final tagNames = <String>[];
    if (tagIdToNameResolver != null) {
      for (final tagId in songUnit.tagIds) {
        final name = await tagIdToNameResolver(tagId);
        if (name != null) {
          tagNames.add(name);
        }
      }
    }

    return EntryPointFile(
      songUnitId: songUnit.id,
      name: songUnit.metadata.title,
      metadata: songUnit.metadata,
      sources: sources,
      tagIds: songUnit.tagIds,
      tagNames: tagNames,
      playbackPreferences: songUnit.preferences,
      createdAt: now,
      modifiedAt: now,
    );
  }

  /// Convert sources to relative paths for serialization.
  List<SourceReference> _convertSourcesToRelative(
    SourceCollection sources,
    String entryPointPath,
  ) {
    final result = <SourceReference>[];

    for (final source in sources.getAllSources()) {
      result.add(_sourceToReference(source, entryPointPath));
    }

    return result;
  }

  /// Convert a single source to a SourceReference with relative path.
  SourceReference _sourceToReference(Source source, String entryPointPath) {
    String path;
    String originType;
    final metadata = <String, dynamic>{};

    switch (source.origin) {
      case LocalFileOrigin(path: final absolutePath):
        originType = 'localFile';
        path = _pathResolver.toSerializablePath(absolutePath, entryPointPath);
      case UrlOrigin(url: final url):
        originType = 'url';
        path = url;
      case ApiOrigin(provider: final provider, resourceId: final resourceId):
        originType = 'api';
        path = '$provider:$resourceId';
        metadata['provider'] = provider;
        metadata['resourceId'] = resourceId;
    }

    // Add type-specific metadata
    if (source is DisplaySource) {
      metadata['displayType'] = source.displayType.name;
      if (source.duration != null) {
        metadata['duration'] = source.duration!.inMicroseconds;
      }
      if (source.offset != Duration.zero) {
        metadata['offset'] = source.offset.inMicroseconds;
      }
    } else if (source is AudioSource) {
      metadata['format'] = source.format.name;
      if (source.duration != null) {
        metadata['duration'] = source.duration!.inMicroseconds;
      }
      if (source.offset != Duration.zero) {
        metadata['offset'] = source.offset.inMicroseconds;
      }
      if (source.linkedVideoSourceId != null) {
        metadata['linkedVideoSourceId'] = source.linkedVideoSourceId;
      }
    } else if (source is AccompanimentSource) {
      metadata['format'] = source.format.name;
      if (source.duration != null) {
        metadata['duration'] = source.duration!.inMicroseconds;
      }
      if (source.offset != Duration.zero) {
        metadata['offset'] = source.offset.inMicroseconds;
      }
    } else if (source is HoverSource) {
      metadata['format'] = source.format.name;
      if (source.offset != Duration.zero) {
        metadata['offset'] = source.offset.inMicroseconds;
      }
    }

    return SourceReference(
      id: source.id,
      sourceType: source.sourceType.name,
      originType: originType,
      path: path,
      priority: source.priority,
      metadata: metadata,
    );
  }

  /// Convert source references back to a SourceCollection with absolute paths.
  SourceCollection _convertSourcesToAbsolute(
    List<SourceReference> references,
    String entryPointPath,
  ) {
    final displaySources = <DisplaySource>[];
    final audioSources = <AudioSource>[];
    final accompanimentSources = <AccompanimentSource>[];
    final hoverSources = <HoverSource>[];

    for (final ref in references) {
      final origin = _referenceToOrigin(ref, entryPointPath);
      final offset = _parseDuration(ref.metadata['offset']) ?? Duration.zero;

      switch (ref.sourceType) {
        case 'display':
          displaySources.add(
            DisplaySource(
              id: ref.id,
              origin: origin,
              priority: ref.priority,
              displayType: _parseDisplayType(ref.metadata['displayType']),
              duration: _parseDuration(ref.metadata['duration']),
              offset: offset,
            ),
          );
        case 'audio':
          audioSources.add(
            AudioSource(
              id: ref.id,
              origin: origin,
              priority: ref.priority,
              format: _parseAudioFormat(ref.metadata['format']),
              duration: _parseDuration(ref.metadata['duration']),
              offset: offset,
              linkedVideoSourceId: ref.metadata['linkedVideoSourceId'] as String?,
            ),
          );
        case 'accompaniment':
          accompanimentSources.add(
            AccompanimentSource(
              id: ref.id,
              origin: origin,
              priority: ref.priority,
              format: _parseAudioFormat(ref.metadata['format']),
              duration: _parseDuration(ref.metadata['duration']),
              offset: offset,
            ),
          );
        case 'hover':
          hoverSources.add(
            HoverSource(
              id: ref.id,
              origin: origin,
              priority: ref.priority,
              format: _parseLyricsFormat(ref.metadata['format']),
              offset: offset,
            ),
          );
      }
    }

    return SourceCollection(
      displaySources: displaySources,
      audioSources: audioSources,
      accompanimentSources: accompanimentSources,
      hoverSources: hoverSources,
    );
  }

  /// Convert a SourceReference back to a SourceOrigin with absolute path.
  SourceOrigin _referenceToOrigin(SourceReference ref, String entryPointPath) {
    switch (ref.originType) {
      case 'localFile':
        final absolutePath = _pathResolver.resolveFromEntryPoint(
          ref.path,
          entryPointPath,
        );
        return LocalFileOrigin(absolutePath);
      case 'url':
        return UrlOrigin(ref.path);
      case 'api':
        final provider = ref.metadata['provider'] as String? ?? '';
        final resourceId = ref.metadata['resourceId'] as String? ?? '';
        return ApiOrigin(provider, resourceId);
      default:
        throw EntryPointValidationException(
          'Unknown origin type: ${ref.originType}',
          field: 'originType',
        );
    }
  }

  DisplayType _parseDisplayType(dynamic value) {
    if (value == null) return DisplayType.video;
    final name = value.toString();
    return DisplayType.values.firstWhere(
      (e) => e.name == name,
      orElse: () => DisplayType.video,
    );
  }

  AudioFormat _parseAudioFormat(dynamic value) {
    if (value == null) return AudioFormat.mp3;
    final name = value.toString();
    return AudioFormat.values.firstWhere(
      (e) => e.name == name,
      orElse: () => AudioFormat.mp3,
    );
  }

  LyricsFormat _parseLyricsFormat(dynamic value) {
    if (value == null) return LyricsFormat.lrc;
    final name = value.toString();
    return LyricsFormat.values.firstWhere(
      (e) => e.name == name,
      orElse: () => LyricsFormat.lrc,
    );
  }

  Duration? _parseDuration(dynamic value) {
    if (value == null) return null;
    if (value is int) return Duration(microseconds: value);
    if (value is num) return Duration(microseconds: value.toInt());
    return null;
  }
}
