import 'package:flutter/foundation.dart';
import '../../models/playlist_metadata.dart';
import '../../models/song_unit.dart';
import 'queue_display_item.dart';
import 'tag_view_model_base.dart';

/// Mixin handling queue song loading and display item building/updating.
mixin QueueDisplayBuilderMixin on TagViewModelBase {
  // ==========================================================================
  // Queue Song Loading
  // ==========================================================================

  /// Load songs for the current active queue (implements base abstract method)
  Future<void> loadCurrentQueueSongsImpl() async {
    final aq = await getActiveQueue();
    if (aq == null || aq.playlistMetadata == null) {
      currentQueueSongsList = [];
      queueDisplayItemsList = [];
      return;
    }

    final metadata = aq.playlistMetadata!;
    final songUnits = <SongUnit>[];
    final displayItems = <QueueDisplayItem>[];

    for (final item in metadata.items) {
      if (item.type == PlaylistItemType.songUnit) {
        final songUnitId = item.targetId;
        if (songUnitId.startsWith('temp_') &&
            metadata.temporarySongUnits != null) {
          final tempData = metadata.temporarySongUnits![songUnitId];
          if (tempData != null) {
            try {
              final songUnit = SongUnit.fromJson(tempData);
              displayItems.add(QueueDisplayItem.song(
                songUnit: songUnit,
                flatIndex: songUnits.length,
                playlistItemId: item.id,
              ));
              songUnits.add(songUnit);
              continue;
            } catch (e) {
              debugPrint(
                'Failed to deserialize temporary song unit $songUnitId: $e',
              );
            }
          }
        }

        final songUnit = await libraryRepository.getSongUnit(songUnitId);
        if (songUnit != null) {
          displayItems.add(QueueDisplayItem.song(
            songUnit: songUnit,
            flatIndex: songUnits.length,
            playlistItemId: item.id,
          ));
          songUnits.add(songUnit);
        }
      } else if (item.type == PlaylistItemType.collectionReference) {
        final groupDisplayItem = await buildGroupDisplayItem(
          item.targetId,
          songUnits,
          temporarySongUnits: metadata.temporarySongUnits,
        );
        if (groupDisplayItem != null) {
          displayItems.add(groupDisplayItem);
          addFlatSongsFromGroup(groupDisplayItem, displayItems, item.targetId);
        }
      }
    }
    currentQueueSongsList = songUnits;
    queueDisplayItemsList = displayItems;
  }

  // ==========================================================================
  // Display Item Building
  // ==========================================================================

  /// Recursively build a QueueDisplayItem.group with nested subItems.
  @protected
  Future<QueueDisplayItem?> buildGroupDisplayItem(
    String groupId,
    List<SongUnit> flatSongList, {
    int depth = 0,
    Map<String, Map<String, dynamic>>? temporarySongUnits,
  }) async {
    if (depth > 10) {
      debugPrint('Max depth exceeded for group $groupId');
      return null;
    }

    final groupTag = await tagRepository.getCollectionTag(groupId);
    if (groupTag == null) return null;
    final groupMetadata = groupTag.playlistMetadata;
    if (groupMetadata == null) return null;

    final subItems = <QueueDisplayItem>[];
    final allSongs = <SongUnit>[];

    for (final item in groupMetadata.items) {
      if (item.type == PlaylistItemType.songUnit) {
        SongUnit? songUnit;
        if (item.targetId.startsWith('temp_') && temporarySongUnits != null) {
          final tempData = temporarySongUnits[item.targetId];
          if (tempData != null) {
            try {
              songUnit = SongUnit.fromJson(tempData);
            } catch (e) {
              debugPrint(
                'Failed to deserialize temporary song unit ${item.targetId}: $e',
              );
            }
          }
        }
        songUnit ??= await libraryRepository.getSongUnit(item.targetId);
        if (songUnit != null) {
          subItems.add(QueueDisplayItem.song(
            songUnit: songUnit,
            flatIndex: flatSongList.length,
            playlistItemId: item.id,
            groupId: groupId,
          ));
          flatSongList.add(songUnit);
          allSongs.add(songUnit);
        }
      } else if (item.type == PlaylistItemType.collectionReference) {
        final subGroup = await buildGroupDisplayItem(
          item.targetId,
          flatSongList,
          depth: depth + 1,
          temporarySongUnits: temporarySongUnits,
        );
        if (subGroup != null) {
          subItems.add(subGroup);
          if (subGroup.groupSongs != null) {
            allSongs.addAll(subGroup.groupSongs!);
          }
        }
      }
    }

    return QueueDisplayItem.group(
      groupName: groupTag.name,
      groupId: groupId,
      songCount: allSongs.length,
      isLocked: groupTag.isLocked,
      groupSongs: allSongs,
      subItems: subItems,
    );
  }

  /// Add flat song display items from a group's subItems into the top-level list.
  @protected
  void addFlatSongsFromGroup(
    QueueDisplayItem group,
    List<QueueDisplayItem> displayItems,
    String topGroupId,
  ) {
    final subs = group.subItems ?? [];
    for (final sub in subs) {
      if (sub.isSong) {
        displayItems.add(QueueDisplayItem.song(
          songUnit: sub.songUnit!,
          flatIndex: sub.flatIndex,
          playlistItemId: sub.playlistItemId,
          groupId: sub.groupId,
        ));
      } else if (sub.isGroup) {
        addFlatSongsFromGroup(sub, displayItems, topGroupId);
      }
    }
  }

  /// Build display items for any collection (public, for playlists page).
  Future<List<QueueDisplayItem>> buildDisplayItemsForCollection(
    String collectionId,
  ) async {
    final collection = await tagRepository.getCollectionTag(collectionId);
    if (collection == null || collection.playlistMetadata == null) return [];

    final metadata = collection.playlistMetadata!;
    final songUnits = <SongUnit>[];
    final displayItems = <QueueDisplayItem>[];

    for (final item in metadata.items) {
      if (item.type == PlaylistItemType.songUnit) {
        final songUnit = await libraryRepository.getSongUnit(item.targetId);
        if (songUnit != null) {
          displayItems.add(QueueDisplayItem.song(
            songUnit: songUnit,
            flatIndex: songUnits.length,
            playlistItemId: item.id,
          ));
          songUnits.add(songUnit);
        }
      } else if (item.type == PlaylistItemType.collectionReference) {
        final groupDisplayItem = await buildGroupDisplayItem(
          item.targetId,
          songUnits,
          temporarySongUnits: metadata.temporarySongUnits,
        );
        if (groupDisplayItem != null) {
          displayItems.add(groupDisplayItem);
        }
      }
    }
    return displayItems;
  }

  // ==========================================================================
  // Display Item Updating
  // ==========================================================================

  /// Update all display items that reference the given song unit.
  void updateDisplayItemsForSongUnit(SongUnit songUnit) {
    queueDisplayItemsList = queueDisplayItemsList.map((item) {
      if (item.isSong && item.songUnit?.id == songUnit.id) {
        return QueueDisplayItem.song(
          songUnit: songUnit,
          flatIndex: item.flatIndex,
          playlistItemId: item.playlistItemId,
          groupId: item.groupId,
        );
      }
      if (item.isGroup) {
        return _updateGroupDisplayItem(item, songUnit);
      }
      return item;
    }).toList();
  }

  QueueDisplayItem _updateGroupDisplayItem(
    QueueDisplayItem group,
    SongUnit songUnit,
  ) {
    final updatedSubItems = group.subItems?.map((sub) {
      if (sub.isSong && sub.songUnit?.id == songUnit.id) {
        return QueueDisplayItem.song(
          songUnit: songUnit,
          flatIndex: sub.flatIndex,
          playlistItemId: sub.playlistItemId,
          groupId: sub.groupId,
        );
      }
      if (sub.isGroup) return _updateGroupDisplayItem(sub, songUnit);
      return sub;
    }).toList();

    final updatedGroupSongs = group.groupSongs
        ?.map((s) => s.id == songUnit.id ? songUnit : s)
        .toList();

    return QueueDisplayItem.group(
      groupName: group.groupName,
      groupId: group.groupId,
      songCount: group.songCount,
      isLocked: group.isLocked,
      groupSongs: updatedGroupSongs,
      subItems: updatedSubItems,
    );
  }
}
