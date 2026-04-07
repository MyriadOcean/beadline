import 'package:json_annotation/json_annotation.dart';
import 'playlist_metadata.dart';

part 'tag.g.dart';

/// Tag type enumeration
enum TagType {
  builtIn, // System tags: name, artist, album, time, duration, user
  user, // User-created tags (can have playlistMetadata to become collections)
  automatic, // System-generated tags: user:xx
}

/// Tag model for organizing and searching Song Units
@JsonSerializable()
class Tag {
  const Tag({
    required this.id,
    required this.name,
    required this.type,
    this.parentId,
    this.aliasNames = const [],
    this.includeChildren = true,
    this.playlistMetadata,
    this.isGroup = false,
  });

  factory Tag.fromJson(Map<String, dynamic> json) => _$TagFromJson(json);
  final String id;
  final String name;
  final TagType type;
  final String? parentId;
  final List<String> aliasNames;
  final bool includeChildren;

  /// Collection metadata (if this tag contains songs)
  /// - If null: regular tag
  /// - If not null: collection (playlist/queue/group)
  final PlaylistMetadata? playlistMetadata;

  /// Whether this is a group (nested collection visible only through parent)
  /// Groups are collections that don't appear in Tag Panel or top-level Playlist Panel
  final bool isGroup;

  /// Whether this tag has playlist/queue metadata (i.e. contains songs).
  /// Equivalent to `playlistMetadata != null`.
  bool get isCollection => playlistMetadata != null;

  /// Check if this tag is currently being played
  bool get isActiveQueue =>
      playlistMetadata != null && playlistMetadata!.currentIndex >= 0;

  /// Check if this is a playlist (collection not being played, not a group)
  bool get isPlaylist =>
      playlistMetadata != null && !isGroup && !playlistMetadata!.isQueue;

  /// Check if this collection is a queue (not a playlist)
  bool get isQueueCollection =>
      playlistMetadata != null && !isGroup && playlistMetadata!.isQueue;

  /// Get number of items in collection
  int get itemCount => playlistMetadata?.items.length ?? 0;

  /// Check if collection is locked
  bool get isLocked => playlistMetadata?.isLocked ?? false;

  Map<String, dynamic> toJson() => _$TagToJson(this);

  /// Check if this tag matches a query string
  /// Supports exact match and wildcard matching
  bool matches(String query) {
    // Remove wildcards for comparison
    final cleanQuery = query.replaceAll('*', '');

    if (query.startsWith('*') && query.endsWith('*')) {
      // Contains match: *hello*
      return name.toLowerCase().contains(cleanQuery.toLowerCase());
    } else if (query.startsWith('*')) {
      // Ends with match: *hello
      return name.toLowerCase().endsWith(cleanQuery.toLowerCase());
    } else if (query.endsWith('*')) {
      // Starts with match: hello*
      return name.toLowerCase().startsWith(cleanQuery.toLowerCase());
    } else {
      // Exact match
      return name.toLowerCase() == query.toLowerCase();
    }
  }

  /// Get all descendant tag IDs (requires tag repository for full traversal)
  /// This is a placeholder - actual implementation needs access to all tags
  List<String> getDescendantIds(Map<String, Tag> allTags) {
    final descendants = <String>[];

    void collectDescendants(String tagId) {
      for (final tag in allTags.values) {
        if (tag.parentId == tagId) {
          descendants.add(tag.id);
          collectDescendants(tag.id);
        }
      }
    }

    collectDescendants(id);
    return descendants;
  }

  Tag copyWith({
    String? id,
    String? name,
    TagType? type,
    String? parentId,
    List<String>? aliasNames,
    bool? includeChildren,
    PlaylistMetadata? playlistMetadata,
    bool? isGroup,
  }) {
    return Tag(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      parentId: parentId ?? this.parentId,
      aliasNames: aliasNames ?? this.aliasNames,
      includeChildren: includeChildren ?? this.includeChildren,
      playlistMetadata: playlistMetadata ?? this.playlistMetadata,
      isGroup: isGroup ?? this.isGroup,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tag &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          type == other.type &&
          parentId == other.parentId &&
          _listEquals(aliasNames, other.aliasNames) &&
          includeChildren == other.includeChildren &&
          playlistMetadata == other.playlistMetadata &&
          isGroup == other.isGroup;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      type.hashCode ^
      parentId.hashCode ^
      aliasNames.hashCode ^
      includeChildren.hashCode ^
      playlistMetadata.hashCode ^
      isGroup.hashCode;

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
