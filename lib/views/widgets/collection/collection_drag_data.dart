/// Unified drag data for collection items (songs and groups).
/// Always uses song unit ID — never PlaylistItem.id or flat indices.
class CollectionDragData {
  const CollectionDragData.song({
    required this.songUnitId,
    required this.sourceCollectionId,
    this.sourceGroupId,
  }) : type = CollectionDragType.song,
       groupId = null;

  const CollectionDragData.group({
    required this.groupId,
    required this.sourceCollectionId,
  }) : type = CollectionDragType.group,
       songUnitId = null,
       sourceGroupId = null;

  final CollectionDragType type;

  /// For songs: the song unit's ID (SongUnit.id / PlaylistItem.targetId)
  final String? songUnitId;

  /// The collection (queue/playlist) this item belongs to
  final String sourceCollectionId;

  /// For songs: the group this song came from (null = root level)
  final String? sourceGroupId;

  /// For groups: the group tag ID being dragged
  final String? groupId;

  bool get isSong => type == CollectionDragType.song;
  bool get isGroup => type == CollectionDragType.group;
}

enum CollectionDragType { song, group }
