import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:json_annotation/json_annotation.dart';

import 'metadata.dart';
import 'playback_preferences.dart';
import 'source_collection.dart';

part 'song_unit.g.dart';

/// Song Unit - the core playback entity
///
/// A Song Unit can be either a full (user-created/imported) entity or a
/// temporary one auto-generated from a discovered audio file. Temporary
/// Song Units have [isTemporary] set to true and carry a [discoveredAt]
/// timestamp. They can be promoted to full Song Units by the user.
@JsonSerializable(explicitToJson: true)
class SongUnit {
  const SongUnit({
    required this.id,
    required this.metadata,
    required this.sources,
    this.tagIds = const [],
    required this.preferences,
    this.libraryLocationId,
    this.isTemporary = false,
    this.discoveredAt,
    this.originalFilePath,
  });

  factory SongUnit.fromJson(Map<String, dynamic> json) =>
      _$SongUnitFromJson(json);
  final String id;
  final Metadata metadata;
  final SourceCollection sources;
  final List<String> tagIds;
  final PlaybackPreferences preferences;

  /// The ID of the library location containing this Song Unit's entry point file.
  /// Null if the Song Unit is not associated with a library location (e.g., centralized mode).
  final String? libraryLocationId;

  /// Whether this Song Unit was auto-generated from a discovered audio file.
  /// Temporary Song Units are shown differently in the UI and can be promoted
  /// to full Song Units by the user.
  final bool isTemporary;

  /// When this Song Unit was discovered (only set for temporary Song Units).
  @JsonKey(
    fromJson: _dateTimeFromMillisOrNull,
    toJson: _dateTimeToMillisOrNull,
  )
  final DateTime? discoveredAt;

  /// Original file path for temporary Song Units (the discovered audio file).
  /// Used for deduplication during discovery scans.
  final String? originalFilePath;

  static DateTime? _dateTimeFromMillisOrNull(int? millis) =>
      millis != null ? DateTime.fromMillisecondsSinceEpoch(millis) : null;

  static int? _dateTimeToMillisOrNull(DateTime? dateTime) =>
      dateTime?.millisecondsSinceEpoch;

  Map<String, dynamic> toJson() => _$SongUnitToJson(this);

  /// Calculate a hash for deduplication
  /// Hash is based on metadata and source origins (using normalized paths)
  String calculateHash() {
    final hashData = {
      'title': metadata.title,
      'artists': metadata.artists,
      'album': metadata.album,
      'year': metadata.year,
      'duration': metadata.duration.inSeconds,
      'sources': sources.getAllSources().map((s) {
        // Normalize source origin for consistent hashing
        // For local files, use only the filename (not full path)
        // This ensures exported/imported song units match originals
        final originJson = s.origin.toJson();
        if (originJson['type'] == 'localFile' && originJson['path'] != null) {
          final path = originJson['path'] as String;
          // Extract just the filename for hashing
          final fileName = path.split('/').last.split('\\').last;
          originJson['path'] = fileName;
        }
        return {'type': s.sourceType.toString(), 'origin': originJson};
      }).toList(),
    };

    final jsonString = jsonEncode(hashData);
    final bytes = utf8.encode(jsonString);
    final digest = sha256.convert(bytes);

    return digest.toString();
  }

  /// Display name — title or filename fallback for temporary Song Units
  String get displayName {
    if (metadata.title.isNotEmpty) return metadata.title;
    if (originalFilePath != null) {
      return originalFilePath!.split('/').last.split('\\').last;
    }
    return '';
  }

  SongUnit copyWith({
    String? id,
    Metadata? metadata,
    SourceCollection? sources,
    List<String>? tagIds,
    PlaybackPreferences? preferences,
    String? libraryLocationId,
    bool? isTemporary,
    DateTime? discoveredAt,
    String? originalFilePath,
  }) {
    return SongUnit(
      id: id ?? this.id,
      metadata: metadata ?? this.metadata,
      sources: sources ?? this.sources,
      tagIds: tagIds ?? this.tagIds,
      preferences: preferences ?? this.preferences,
      libraryLocationId: libraryLocationId ?? this.libraryLocationId,
      isTemporary: isTemporary ?? this.isTemporary,
      discoveredAt: discoveredAt ?? this.discoveredAt,
      originalFilePath: originalFilePath ?? this.originalFilePath,
    );
  }

  /// Promote a temporary Song Unit to a full one (clear temporary flag).
  SongUnit promote() {
    return copyWith(
      isTemporary: false,
      // Keep discoveredAt and originalFilePath for history
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SongUnit &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          metadata == other.metadata &&
          sources == other.sources &&
          _listEquals(tagIds, other.tagIds) &&
          preferences == other.preferences &&
          libraryLocationId == other.libraryLocationId &&
          isTemporary == other.isTemporary &&
          discoveredAt == other.discoveredAt &&
          originalFilePath == other.originalFilePath;

  @override
  int get hashCode =>
      id.hashCode ^
      metadata.hashCode ^
      sources.hashCode ^
      tagIds.hashCode ^
      preferences.hashCode ^
      libraryLocationId.hashCode ^
      isTemporary.hashCode ^
      discoveredAt.hashCode ^
      originalFilePath.hashCode;

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
