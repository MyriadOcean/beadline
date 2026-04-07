/// Convenience extensions on the FRB-generated Tag, TagMetadata, and TagItem types.
/// These replace the old hand-written Dart Tag/PlaylistMetadata/PlaylistItem models.

import '../src/rust/api/tag_api.dart';

// Re-export FRB types so consumers only need one import.
export '../src/rust/api/tag_api.dart' show Tag, TagType, TagMetadata, TagItem, TagItemType;

/// Convenience getters on [Tag].
extension TagExtensions on Tag {
  /// Whether this tag has metadata (i.e. contains songs).
  bool get isCollection => metadata != null;

  /// Whether this tag is currently being played.
  bool get isActiveQueue => metadata != null && metadata!.currentIndex >= 0;

  /// Whether this is a playlist (has metadata, not a group, not a queue).
  bool get isPlaylist => metadata != null && !isGroup && !metadata!.isQueue;

  /// Whether this is a queue collection.
  bool get isQueueCollection => metadata != null && !isGroup && metadata!.isQueue;

  /// Number of items in metadata (0 if no metadata).
  int get itemCount => metadata?.items.length ?? 0;

  /// Wildcard-aware name matching.
  bool matches(String query) {
    final clean = query.replaceAll('*', '');
    if (query.startsWith('*') && query.endsWith('*')) {
      return name.toLowerCase().contains(clean.toLowerCase());
    } else if (query.startsWith('*')) {
      return name.toLowerCase().endsWith(clean.toLowerCase());
    } else if (query.endsWith('*')) {
      return name.toLowerCase().startsWith(clean.toLowerCase());
    }
    return name.toLowerCase() == clean.toLowerCase();
  }

  /// Create a copy with overridden fields.
  Tag copyWith({
    String? id,
    String? name,
    String? key,
    TagType? tagType,
    String? parentId,
    List<String>? aliasNames,
    bool? includeChildren,
    bool? isGroup,
    bool? isLocked,
    int? displayOrder,
    TagMetadata? metadata,
  }) {
    return Tag(
      id: id ?? this.id,
      name: name ?? this.name,
      key: key ?? this.key,
      tagType: tagType ?? this.tagType,
      parentId: parentId ?? this.parentId,
      aliasNames: aliasNames ?? this.aliasNames,
      includeChildren: includeChildren ?? this.includeChildren,
      isGroup: isGroup ?? this.isGroup,
      isLocked: isLocked ?? this.isLocked,
      displayOrder: displayOrder ?? this.displayOrder,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Convenience getters and copyWith on [TagMetadata].
extension TagMetadataExtensions on TagMetadata {
  /// Whether this metadata indicates active playback.
  bool get isPlaying => currentIndex >= 0;

  /// Whether any playback state exists.
  bool get hasPlaybackState =>
      currentIndex != -1 || playbackPositionMs != 0 || wasPlaying;

  /// Create a copy with overridden fields.
  TagMetadata copyWith({
    bool? isLocked,
    int? displayOrder,
    List<TagItem>? items,
    int? currentIndex,
    int? playbackPositionMs,
    bool? wasPlaying,
    bool? removeAfterPlay,
    bool? isQueue,
    String? createdAt,
    String? updatedAt,
  }) {
    return TagMetadata(
      isLocked: isLocked ?? this.isLocked,
      displayOrder: displayOrder ?? this.displayOrder,
      items: items ?? this.items,
      currentIndex: currentIndex ?? this.currentIndex,
      playbackPositionMs: playbackPositionMs ?? this.playbackPositionMs,
      wasPlaying: wasPlaying ?? this.wasPlaying,
      removeAfterPlay: removeAfterPlay ?? this.removeAfterPlay,
      isQueue: isQueue ?? this.isQueue,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Create empty metadata.
  static TagMetadata empty({bool isQueue = false}) {
    final now = DateTime.now().toIso8601String();
    return TagMetadata(
      isLocked: false,
      displayOrder: 0,
      items: const [],
      currentIndex: -1,
      playbackPositionMs: 0,
      wasPlaying: false,
      removeAfterPlay: false,
      isQueue: isQueue,
      createdAt: now,
      updatedAt: now,
    );
  }
}

/// copyWith on [TagItem].
extension TagItemExtensions on TagItem {
  TagItem copyWith({
    String? id,
    TagItemType? itemType,
    String? targetId,
    int? order,
    bool? inheritLock,
  }) {
    return TagItem(
      id: id ?? this.id,
      itemType: itemType ?? this.itemType,
      targetId: targetId ?? this.targetId,
      order: order ?? this.order,
      inheritLock: inheritLock ?? this.inheritLock,
    );
  }
}
