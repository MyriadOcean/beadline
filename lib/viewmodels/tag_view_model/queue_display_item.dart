import '../../models/song_unit.dart';

/// Represents an item in the queue display: either a song or a group header
class QueueDisplayItem {
  const QueueDisplayItem.song({
    required this.songUnit,
    required this.flatIndex,
    this.playlistItemId,
    this.groupId,
  })  : type = QueueDisplayItemType.song,
        groupName = null,
        songCount = 0,
        isLocked = false,
        groupSongs = null,
        subItems = null;

  const QueueDisplayItem.group({
    required this.groupName,
    required this.groupId,
    required this.songCount,
    required this.isLocked,
    this.groupSongs,
    this.subItems,
  })  : type = QueueDisplayItemType.group,
        songUnit = null,
        flatIndex = -1,
        playlistItemId = null;

  final QueueDisplayItemType type;
  final SongUnit? songUnit;
  final int flatIndex;
  final String? groupName;
  final String? groupId;
  final int songCount;
  final bool isLocked;

  /// The PlaylistItem ID for this song in the active queue (for drag-drop operations)
  final String? playlistItemId;

  /// For group items: the resolved songs inside this group (for card display)
  final List<SongUnit>? groupSongs;

  /// For group items: nested display items (songs and sub-groups) preserving hierarchy
  final List<QueueDisplayItem>? subItems;

  bool get isSong => type == QueueDisplayItemType.song;
  bool get isGroup => type == QueueDisplayItemType.group;
}

enum QueueDisplayItemType { song, group }
