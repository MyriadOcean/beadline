import 'package:json_annotation/json_annotation.dart';

import 'metadata.dart';
import 'playback_preferences.dart';

part 'entry_point_file.g.dart';

/// Reference to a source in an entry point file.
/// Uses relative paths for portability.
@JsonSerializable()
class SourceReference {
  const SourceReference({
    required this.id,
    required this.sourceType,
    required this.originType,
    required this.path,
    required this.priority,
    this.metadata = const {},
  });

  factory SourceReference.fromJson(Map<String, dynamic> json) =>
      _$SourceReferenceFromJson(json);

  /// Unique identifier for this source
  final String id;

  /// Type of source: 'display', 'audio', 'accompaniment', 'hover'
  final String sourceType;

  /// Type of origin: 'localFile', 'url', 'api'
  final String originType;

  /// Path or URL to the source.
  /// For local files, this is a relative path (./file.mp3 or @storage/path/file.mp3)
  final String path;

  /// Priority for source selection (lower = higher priority)
  final int priority;

  /// Type-specific metadata (format, duration, displayType, etc.)
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() => _$SourceReferenceToJson(this);

  SourceReference copyWith({
    String? id,
    String? sourceType,
    String? originType,
    String? path,
    int? priority,
    Map<String, dynamic>? metadata,
  }) {
    return SourceReference(
      id: id ?? this.id,
      sourceType: sourceType ?? this.sourceType,
      originType: originType ?? this.originType,
      path: path ?? this.path,
      priority: priority ?? this.priority,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SourceReference &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          sourceType == other.sourceType &&
          originType == other.originType &&
          path == other.path &&
          priority == other.priority &&
          _mapEquals(metadata, other.metadata);

  @override
  int get hashCode =>
      id.hashCode ^
      sourceType.hashCode ^
      originType.hashCode ^
      path.hashCode ^
      priority.hashCode ^
      metadata.hashCode;

  bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }
}

/// Entry point file model representing a discoverable Song Unit definition.
/// Stored as `beadline-[name].json` files alongside source files.
@JsonSerializable(explicitToJson: true)
class EntryPointFile {
  const EntryPointFile({
    this.version = currentVersion,
    required this.songUnitId,
    required this.name,
    required this.metadata,
    required this.sources,
    this.tagIds = const [],
    this.tagNames = const [],
    this.playbackPreferences,
    required this.createdAt,
    required this.modifiedAt,
  });

  factory EntryPointFile.fromJson(Map<String, dynamic> json) =>
      _$EntryPointFileFromJson(json);

  /// Current version of the entry point file format
  static const int currentVersion = 1;

  /// File prefix for entry point files
  static const String filePrefix = 'beadline-';

  /// Legacy file prefix (hidden files, caused permission issues on Android)
  static const String legacyFilePrefix = '.beadline-';

  /// File extension for entry point files
  static const String fileExtension = '.json';

  /// Version of the entry point file format
  @JsonKey(defaultValue: 1)
  final int version;

  /// Unique identifier for the Song Unit
  final String songUnitId;

  /// Display name of the Song Unit
  final String name;

  /// Song Unit metadata (title, artists, album, etc.)
  final Metadata metadata;

  /// List of source references with relative paths
  final List<SourceReference> sources;

  /// List of tag IDs associated with this Song Unit
  final List<String> tagIds;

  /// List of tag names for portability (resolved on import)
  @JsonKey(defaultValue: [])
  final List<String> tagNames;

  /// Playback preferences for this Song Unit
  final PlaybackPreferences? playbackPreferences;

  /// When this Song Unit was created
  final DateTime createdAt;

  /// When this Song Unit was last modified
  final DateTime modifiedAt;

  Map<String, dynamic> toJson() => _$EntryPointFileToJson(this);

  EntryPointFile copyWith({
    int? version,
    String? songUnitId,
    String? name,
    Metadata? metadata,
    List<SourceReference>? sources,
    List<String>? tagIds,
    List<String>? tagNames,
    PlaybackPreferences? playbackPreferences,
    DateTime? createdAt,
    DateTime? modifiedAt,
  }) {
    return EntryPointFile(
      version: version ?? this.version,
      songUnitId: songUnitId ?? this.songUnitId,
      name: name ?? this.name,
      metadata: metadata ?? this.metadata,
      sources: sources ?? this.sources,
      tagIds: tagIds ?? this.tagIds,
      tagNames: tagNames ?? this.tagNames,
      playbackPreferences: playbackPreferences ?? this.playbackPreferences,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EntryPointFile &&
          runtimeType == other.runtimeType &&
          version == other.version &&
          songUnitId == other.songUnitId &&
          name == other.name &&
          metadata == other.metadata &&
          _listEquals(sources, other.sources) &&
          _listEquals(tagIds, other.tagIds) &&
          _listEquals(tagNames, other.tagNames) &&
          playbackPreferences == other.playbackPreferences &&
          createdAt == other.createdAt &&
          modifiedAt == other.modifiedAt;

  @override
  int get hashCode =>
      version.hashCode ^
      songUnitId.hashCode ^
      name.hashCode ^
      metadata.hashCode ^
      sources.hashCode ^
      tagIds.hashCode ^
      tagNames.hashCode ^
      playbackPreferences.hashCode ^
      createdAt.hashCode ^
      modifiedAt.hashCode;

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
