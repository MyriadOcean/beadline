/// Unified drag data for queue items (songs and groups)
enum QueueDragType { song, group }

class QueueDragData {
  const QueueDragData.song({
    required this.flatIndex,
    this.playlistItemId,
    this.songGroupId,
  }) : type = QueueDragType.song,
       groupItemId = null,
       groupId = null;

  const QueueDragData.group({required this.groupItemId, required this.groupId})
    : type = QueueDragType.group,
      flatIndex = -1,
      playlistItemId = null,
      songGroupId = null;

  final QueueDragType type;
  final int flatIndex;
  final String? groupItemId;
  final String? groupId;

  /// For songs: the PlaylistItem ID captured at drag start (avoids stale lookups)
  final String? playlistItemId;

  /// For songs: the group ID this song belongs to (null if top-level)
  final String? songGroupId;

  bool get isSong => type == QueueDragType.song;
  bool get isGroup => type == QueueDragType.group;
}
