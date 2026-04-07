import 'package:flutter/foundation.dart';
import '../../models/tag_extensions.dart';
import '../../models/song_unit.dart';
import 'queue_display_item.dart';
import 'tag_view_model_base.dart';

/// Mixin handling all reorder operations for collections, groups, and queues.
mixin CollectionReorderMixin on TagViewModelBase {
  // Must be provided by other mixins
  Future<void> loadTagsSilent();

  // ==========================================================================
  // Collection Reorder
  // ==========================================================================

  /// Reorder items in any collection
  Future<void> reorderCollection(
    String collectionId,
    int oldIndex,
    int newIndex,
  ) async {
    if (oldIndex == newIndex) return;
    try {
      errorValue = null;
      suppressEvents = true;

      final collection =
          await tagRepository.getCollectionTag(collectionId);
      if (collection == null || !collection.isCollection) {
        errorValue = 'Collection not found';
        suppressEvents = false;
        notifyListeners();
        return;
      }

      final metadata = collection.metadata!;
      final items = List<TagItem>.from(metadata.items);
      final item = items.removeAt(oldIndex);
      items.insert(newIndex, item);
      for (var i = 0; i < items.length; i++) {
        items[i] = items[i].copyWith(order: i);
      }

      final updatedTag = collection.copyWith(
        metadata: metadata.copyWith(items: items),
      );
      await tagRepository.updateTag(updatedTag);
      await loadTagsSilent();

      if (collectionId == activeQueueIdValue) {
        await loadCurrentQueueSongs();
        await updateCachedValues();
      }

      notifyListeners();
      await Future<void>.delayed(Duration.zero);
      suppressEvents = false;
    } catch (e) {
      suppressEvents = false;
      errorValue = e.toString();
      notifyListeners();
    }
  }

  /// Reorder an item within a collection by song unit ID.
  Future<void> reorderWithinCollection(
    String collectionId,
    String songUnitId,
    int newIndex,
  ) async {
    try {
      errorValue = null;
      suppressEvents = true;

      final collection =
          await tagRepository.getCollectionTag(collectionId);
      if (collection == null || !collection.isCollection) {
        errorValue = 'Collection not found';
        suppressEvents = false;
        notifyListeners();
        return;
      }

      final metadata = collection.metadata!;
      final items = List<TagItem>.from(metadata.items);

      final oldIndex = items.indexWhere(
        (item) =>
            item.itemType == TagItemType.songUnit &&
            item.targetId == songUnitId,
      );
      if (oldIndex < 0) {
        debugPrint(
            'reorderWithinCollection: song "$songUnitId" not found in "$collectionId"');
        suppressEvents = false;
        return;
      }
      debugPrint(
          'reorderWithinCollection: oldIndex=$oldIndex, newIndex=$newIndex, itemCount=${items.length}');
      if (oldIndex == newIndex) {
        debugPrint('reorderWithinCollection: same index, skipping');
        suppressEvents = false;
        return;
      }

      final item = items.removeAt(oldIndex);
      final adjustedIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
      items.insert(adjustedIndex.clamp(0, items.length), item);

      final orderedIds = items.map((i) => i.id).toList();
      await tagRepository.reorderCollectionItems(collectionId, orderedIds);
      await loadTagsSilent();

      if (collectionId == activeQueueIdValue) {
        await loadCurrentQueueSongs();
        await updateCachedValues();
        debugPrint(
            'reorderWithinCollection: queue reloaded, ${queueDisplayItemsList.length} display items');
      }

      debugPrint('reorderWithinCollection: done, calling notifyListeners');
      notifyListeners();
      await Future<void>.delayed(Duration.zero);
      suppressEvents = false;
    } catch (e) {
      suppressEvents = false;
      errorValue = e.toString();
      notifyListeners();
    }
  }

  /// Reorder items by providing the new ordered list of item IDs.
  Future<void> reorderCollectionByIds(
    String collectionId,
    List<String> orderedItemIds,
  ) async {
    try {
      errorValue = null;
      suppressEvents = true;
      await tagRepository.reorderCollectionItems(collectionId, orderedItemIds);
      final freshTag = await tagRepository.getCollectionTag(collectionId);
      if (freshTag != null) {
        final idx = allTagsList.indexWhere((t) => t.id == collectionId);
        if (idx != -1) {
          allTagsList = [
            ...allTagsList.sublist(0, idx),
            freshTag,
            ...allTagsList.sublist(idx + 1),
          ];
          recategorizeTags();
        }
      }
      if (collectionId == activeQueueIdValue) {
        await loadCurrentQueueSongs();
        await updateCachedValues();
      }
      suppressEvents = false;
      notifyListeners();
    } catch (e) {
      suppressEvents = false;
      errorValue = e.toString();
      notifyListeners();
    }
  }

  /// Reorder items within a group
  Future<void> reorderGroupItems(
    String groupId,
    List<String> orderedItemIds,
  ) async {
    try {
      errorValue = null;
      suppressEvents = true;
      await tagRepository.reorderCollectionItems(groupId, orderedItemIds);
      final freshTag = await tagRepository.getCollectionTag(groupId);
      if (freshTag != null) {
        final idx = allTagsList.indexWhere((t) => t.id == groupId);
        if (idx != -1) {
          allTagsList = [
            ...allTagsList.sublist(0, idx),
            freshTag,
            ...allTagsList.sublist(idx + 1),
          ];
          recategorizeTags();
        }
      }
      suppressEvents = false;
      notifyListeners();
    } catch (e) {
      suppressEvents = false;
      errorValue = e.toString();
      notifyListeners();
    }
  }

  // ==========================================================================
  // Queue Reorder
  // ==========================================================================

  /// Reorder a song in the active queue
  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= currentQueueSongsList.length) return;
    if (newIndex < 0 || newIndex >= currentQueueSongsList.length) return;
    if (oldIndex == newIndex) return;

    suppressEvents = true;

    final aq = await getActiveQueue();
    if (aq?.metadata == null) {
      suppressEvents = false;
      return;
    }

    final metadata = aq!.metadata!;

    final topLevelSongItems = <TagItem>[];
    for (final item in metadata.items) {
      if (item.itemType == TagItemType.songUnit) {
        topLevelSongItems.add(item);
      }
    }

    if (oldIndex >= topLevelSongItems.length ||
        newIndex >= topLevelSongItems.length) {
      await loadCurrentQueueSongs();
      await updateCachedValues();
      suppressEvents = false;
      notifyListeners();
      return;
    }

    final movedItem = topLevelSongItems[oldIndex];
    final allItems = List<TagItem>.from(metadata.items)..remove(movedItem);

    final remainingSongItems = allItems
        .where((i) => i.itemType == TagItemType.songUnit)
        .toList();

    int insertPos;
    if (newIndex >= remainingSongItems.length) {
      insertPos = allItems.length;
    } else {
      final adjustedIndex = oldIndex < newIndex ? newIndex - 1 : newIndex;
      final targetItem = remainingSongItems[adjustedIndex];
      insertPos = allItems.indexOf(targetItem);
      if (oldIndex < newIndex) {
        insertPos++;
      }
    }

    allItems.insert(insertPos, movedItem);

    for (var i = 0; i < allItems.length; i++) {
      allItems[i] = allItems[i].copyWith(order: i);
    }

    final newQueue = List<SongUnit>.from(currentQueueSongsList);
    final songUnit = newQueue.removeAt(oldIndex);
    newQueue.insert(newIndex, songUnit);
    currentQueueSongsList = newQueue;

    var newCurrentIndex = metadata.currentIndex;
    if (newCurrentIndex == oldIndex) {
      newCurrentIndex = newIndex;
    } else if (oldIndex < newCurrentIndex && newIndex >= newCurrentIndex) {
      newCurrentIndex--;
    } else if (oldIndex > newCurrentIndex && newIndex <= newCurrentIndex) {
      newCurrentIndex++;
    }

    await updateActiveQueue(
      metadata.copyWith(items: allItems, currentIndex: newCurrentIndex),
    );

    // Reorder display items in-memory
    final topLevelDisplaySongs = queueDisplayItemsList
        .where((e) => e.isSong && e.groupId == null)
        .toList();
    if (oldIndex < topLevelDisplaySongs.length &&
        newIndex < topLevelDisplaySongs.length) {
      final movedDisplay = topLevelDisplaySongs.removeAt(oldIndex);
      topLevelDisplaySongs.insert(newIndex, movedDisplay);

      final rebuilt = <QueueDisplayItem>[];
      int songCursor = 0;
      int flatIdx = 0;
      for (final item in queueDisplayItemsList) {
        if (item.isSong && item.groupId == null) {
          rebuilt.add(QueueDisplayItem.song(
            songUnit: topLevelDisplaySongs[songCursor].songUnit!,
            flatIndex: flatIdx,
            playlistItemId: topLevelDisplaySongs[songCursor].playlistItemId,
            groupId: null,
          ));
          songCursor++;
          flatIdx++;
        } else if (item.isSong) {
          rebuilt.add(QueueDisplayItem.song(
            songUnit: item.songUnit!,
            flatIndex: flatIdx,
            playlistItemId: item.playlistItemId,
            groupId: item.groupId,
          ));
          flatIdx++;
        } else {
          rebuilt.add(item);
        }
      }
      queueDisplayItemsList = rebuilt;
    }

    cachedCurrentIndex = newCurrentIndex;
    notifyListeners();
    await Future<void>.delayed(Duration.zero);
    suppressEvents = false;
  }

  /// Recompute display orders for all items in a collection
  @protected
  Future<void> recomputeDisplayOrders(String collectionId) async {
    final tag = await tagRepository.getCollectionTag(collectionId);
    if (tag == null || !tag.isCollection) return;
    final metadata = tag.metadata;
    if (metadata == null || metadata.items.isEmpty) return;

    final sortedItems = List<TagItem>.from(metadata.items)
      ..sort((a, b) => a.order.compareTo(b.order));

    final reorderedIds = sortedItems.map((i) => i.id).toList();
    await tagRepository.reorderCollectionItems(collectionId, reorderedIds);
  }
}
