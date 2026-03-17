import 'package:json_annotation/json_annotation.dart';

part 'playlist_metadata.g.dart';

/// Type of item in a playlist
enum PlaylistItemType {
  songUnit, // Direct song unit member
  collectionReference, // Reference to another collection (playlist/group)
}

/// Single item in a playlist
@JsonSerializable()
class PlaylistItem {
  const PlaylistItem({
    required this.id,
    required this.type,
    required this.targetId,
    required this.order,
    this.inheritLock = true,
  });

  factory PlaylistItem.fromJson(Map<String, dynamic> json) =>
      _$PlaylistItemFromJson(json);

  /// Unique ID for this playlist item
  final String id;

  /// Type of item (song unit or collection reference)
  final PlaylistItemType type;

  /// ID of the target (song unit ID or collection tag ID)
  final String targetId;

  /// Display order in the playlist
  final int order;

  /// Whether to inherit lock state from referenced collection
  final bool inheritLock;

  Map<String, dynamic> toJson() => _$PlaylistItemToJson(this);

  PlaylistItem copyWith({
    String? id,
    PlaylistItemType? type,
    String? targetId,
    int? order,
    bool? inheritLock,
  }) {
    return PlaylistItem(
      id: id ?? this.id,
      type: type ?? this.type,
      targetId: targetId ?? this.targetId,
      order: order ?? this.order,
      inheritLock: inheritLock ?? this.inheritLock,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaylistItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          type == other.type &&
          targetId == other.targetId &&
          order == other.order &&
          inheritLock == other.inheritLock;

  @override
  int get hashCode =>
      id.hashCode ^
      type.hashCode ^
      targetId.hashCode ^
      order.hashCode ^
      inheritLock.hashCode;
}

/// Metadata for collection tags (playlists/queues)
@JsonSerializable()
class PlaylistMetadata {
  const PlaylistMetadata({
    required this.isLocked,
    required this.displayOrder,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
    this.currentIndex = -1,
    this.playbackPositionMs = 0,
    this.wasPlaying = false,
    this.removeAfterPlay = false,
    this.temporarySongUnits,
    this.isQueue = false,
  });

  /// Create an empty collection metadata
  factory PlaylistMetadata.empty({bool isQueue = false}) {
    final now = DateTime.now();
    return PlaylistMetadata(
      isLocked: false,
      displayOrder: 0,
      items: const [],
      createdAt: now,
      updatedAt: now,
      isQueue: isQueue,
    );
  }

  factory PlaylistMetadata.fromJson(Map<String, dynamic> json) =>
      _$PlaylistMetadataFromJson(json);

  /// Whether this collection is locked (prevents randomization)
  final bool isLocked;

  /// Display order for sorting collections
  final int displayOrder;

  /// Ordered list of items in this collection
  final List<PlaylistItem> items;

  /// Playback state (only used when this collection is being played)
  /// -1 = not playing, >=0 = currently playing at this index
  final int currentIndex;

  /// Current playback position in milliseconds
  final int playbackPositionMs;

  /// Whether this collection was playing when switched away
  final bool wasPlaying;

  /// Whether to remove songs after playing
  final bool removeAfterPlay;

  /// Temporary song units (for audio entries not in library)
  /// Map of song unit ID to serialized JSON
  final Map<String, Map<String, dynamic>>? temporarySongUnits;

  /// Whether this collection is a queue (vs a playlist)
  /// Queues appear in Queue Management, playlists appear in Playlists page
  final bool isQueue;

  /// When this collection was created
  final DateTime createdAt;

  /// When this collection was last updated
  final DateTime updatedAt;

  /// Check if this collection is currently being played
  bool get isPlaying => currentIndex >= 0;

  /// Check if this collection has any playback state
  bool get hasPlaybackState =>
      currentIndex != -1 ||
      playbackPositionMs != 0 ||
      wasPlaying ||
      temporarySongUnits != null;

  Map<String, dynamic> toJson() => _$PlaylistMetadataToJson(this);

  PlaylistMetadata copyWith({
    bool? isLocked,
    int? displayOrder,
    List<PlaylistItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? currentIndex,
    int? playbackPositionMs,
    bool? wasPlaying,
    bool? removeAfterPlay,
    Map<String, Map<String, dynamic>>? temporarySongUnits,
    bool? isQueue,
  }) {
    return PlaylistMetadata(
      isLocked: isLocked ?? this.isLocked,
      displayOrder: displayOrder ?? this.displayOrder,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      currentIndex: currentIndex ?? this.currentIndex,
      playbackPositionMs: playbackPositionMs ?? this.playbackPositionMs,
      wasPlaying: wasPlaying ?? this.wasPlaying,
      removeAfterPlay: removeAfterPlay ?? this.removeAfterPlay,
      temporarySongUnits: temporarySongUnits ?? this.temporarySongUnits,
      isQueue: isQueue ?? this.isQueue,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaylistMetadata &&
          runtimeType == other.runtimeType &&
          isLocked == other.isLocked &&
          displayOrder == other.displayOrder &&
          _listEquals(items, other.items) &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      isLocked.hashCode ^
      displayOrder.hashCode ^
      items.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode;

  bool _listEquals(List<PlaylistItem> a, List<PlaylistItem> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
