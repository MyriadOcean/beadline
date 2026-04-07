import 'package:flutter/foundation.dart';
import '../../models/tag_extensions.dart';
import '../../models/song_unit.dart';
import 'tag_view_model_base.dart';

/// Mixin handling shuffle, deduplicate, clear, and remove-from-queue operations.
mixin CollectionShuffleMixin on TagViewModelBase {
  // ==========================================================================
  // Remove from Queue
  // ==========================================================================

  /// Remove a song from the active queue by index
  Future<bool> removeFromQueue(int index) async {
    if (index < 0 || index >= currentQueueSongsList.length) return false;

    final aq = await getActiveQueue();
    if (aq?.metadata == null) return false;

    final metadata = aq!.metadata!;
    final wasCurrentlyPlaying = index == metadata.currentIndex;

    final displayItem = queueDisplayItemsList
        .where((d) => d.isSong && d.flatIndex == index)
        .firstOrNull;

    if (displayItem != null && displayItem.playlistItemId != null) {
      if (displayItem.groupId != null) {
        await tagRepository.removeItemFromCollection(
          displayItem.groupId!,
          displayItem.playlistItemId!,
        );
      } else {
        await tagRepository.removeItemFromCollection(
          activeQueueIdValue,
          displayItem.playlistItemId!,
        );
      }
    } else {
      final su = currentQueueSongsList[index];
      final topLevelItem = metadata.items.firstWhere(
        (i) => i.itemType == TagItemType.songUnit && i.targetId == su.id,
        orElse: () => throw StateError('Song not found in queue metadata'),
      );
      await tagRepository.removeItemFromCollection(
        activeQueueIdValue,
        topLevelItem.id,
      );
    }

    var newIndex = metadata.currentIndex;
    if (index < newIndex) {
      newIndex--;
    } else if (index == newIndex) {
      if (newIndex >= currentQueueSongsList.length - 1) {
        newIndex = currentQueueSongsList.length - 2;
      }
    }
    if (newIndex < -1) newIndex = -1;

    final refreshedQueue = await getActiveQueue();
    if (refreshedQueue?.metadata != null) {
      await updateActiveQueue(
        refreshedQueue!.metadata!.copyWith(currentIndex: newIndex),
      );
    }

    await loadCurrentQueueSongs();
    await updateCachedValues();
    notifyListeners();
    return wasCurrentlyPlaying;
  }

  /// Clear the active queue
  Future<void> clearQueue() async {
    await clearCollection(activeQueueIdValue);
  }

  /// Deduplicate the active queue
  Future<int> deduplicateQueue() async {
    if (currentQueueSongsList.length <= 1) return 0;

    final aq = await getActiveQueue();
    if (aq?.metadata == null) return 0;

    final metadata = aq!.metadata!;
    final currentSong = currentSongUnit;
    final originalLength = currentQueueSongsList.length;

    final seenIds = <String>{};
    final deduplicated = <SongUnit>[];
    for (final song in currentQueueSongsList) {
      if (!seenIds.contains(song.id)) {
        seenIds.add(song.id);
        deduplicated.add(song);
      }
    }
    currentQueueSongsList = deduplicated;

    var newIdx = metadata.currentIndex;
    if (currentSong != null) {
      newIdx =
          currentQueueSongsList.indexWhere((s) => s.id == currentSong.id);
      if (newIdx == -1 && currentQueueSongsList.isNotEmpty) newIdx = 0;
    } else if (newIdx >= currentQueueSongsList.length) {
      newIdx = currentQueueSongsList.length - 1;
    }

    final removedCount = originalLength - currentQueueSongsList.length;

    if (removedCount > 0) {
      final newItems =
          currentQueueSongsList.asMap().entries.map((entry) {
        return TagItem(
          id: uuid.v4(),
          itemType: TagItemType.songUnit,
          targetId: entry.value.id,
          order: entry.key,
          inheritLock: true,
          );
      }).toList();

      await updateActiveQueue(
        metadata.copyWith(items: newItems, currentIndex: newIdx),
      );
      await loadCurrentQueueSongs();
      await updateCachedValues();
      notifyListeners();
    }

    return removedCount;
  }

  // ==========================================================================
  // Shuffle
  // ==========================================================================

  /// Shuffle any collection (respects locked sub-collections).
  /// Delegates to Rust which handles lock-aware shuffling in a single call.
  Future<void> shuffle(String collectionId) async {
    try {
      errorValue = null;
      final currentSong = currentSongUnit;
      await tagRepository.shuffleCollection(
        collectionId,
        currentSongId: currentSong?.id,
      );

      if (collectionId == activeQueueIdValue) {
        await loadCurrentQueueSongs();
        await updateCachedValues();
      }
      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint('TagViewModel: shuffle() - caught exception: $e');
      debugPrint('TagViewModel: shuffle() - stack trace: $stackTrace');
      errorValue = e.toString();
      notifyListeners();
    }
  }

  // ==========================================================================
  // Deduplicate & Clear
  // ==========================================================================

  /// Deduplicate any collection — delegates to Rust.
  Future<int> deduplicate(String collectionId) async {
    try {
      errorValue = null;
      final removedCount = await tagRepository.deduplicateCollection(collectionId);

      if (removedCount > 0) {
        if (collectionId == activeQueueIdValue) {
          await loadCurrentQueueSongs();
          await updateCachedValues();
        }
        notifyListeners();
      }

      return removedCount;
    } catch (e) {
      errorValue = e.toString();
      notifyListeners();
      return 0;
    }
  }

  /// Clear all items from any collection
  Future<void> clearCollection(String collectionId) async {
    try {
      errorValue = null;
      final collection =
          await tagRepository.getCollectionTag(collectionId);
      if (collection == null || !collection.isCollection) {
        errorValue = 'Collection not found';
        notifyListeners();
        return;
      }

      final metadata = collection.metadata!;

      if (metadata.isQueue) {
        await _recursivelyDeleteQueueOnlyGroups(collectionId, metadata.items);
        await loadTags();
      }

      final clearedMetadata = metadata.copyWith(items: [], currentIndex: -1);
      await tagRepository.updateCollectionMetadata(
          collectionId, clearedMetadata);

      if (collectionId == activeQueueIdValue) {
        currentQueueSongsList = [];
        queueDisplayItemsList = [];
        await updateCachedValues();
      }
      notifyListeners();
    } catch (e) {
      errorValue = e.toString();
      notifyListeners();
    }
  }

  Future<void> _recursivelyDeleteQueueOnlyGroups(
    String queueId,
    List<TagItem> items,
  ) async {
    for (final item in items) {
      if (item.itemType == TagItemType.tagReference) {
        final groupId = item.targetId;
        final groupTag = await tagRepository.getCollectionTag(groupId);
        if (groupTag != null && groupTag.isGroup) {
          final groupMetadata = groupTag.metadata;
          if (groupMetadata != null && groupMetadata.items.isNotEmpty) {
            await _recursivelyDeleteQueueOnlyGroups(
                groupId, groupMetadata.items);
          }
          final isOnlyReferencedHere =
              await _isGroupOnlyReferencedInCollection(groupId, queueId);
          if (isOnlyReferencedHere) {
            debugPrint(
                'Deleting queue-only group: ${groupTag.name} ($groupId)');
            await tagRepository.deleteTag(groupId);
          }
        }
      }
    }
  }

  Future<bool> _isGroupOnlyReferencedInCollection(
    String groupId,
    String collectionId,
  ) async {
    final allCollections =
        allTagsList.where((t) => t.isCollection).toList();
    var referenceCount = 0;
    for (final collection in allCollections) {
      if (collection.metadata == null) continue;
      final hasReference = await _collectionReferencesGroup(
        collection.id,
        groupId,
        collection.metadata!.items,
      );
      if (hasReference) {
        referenceCount++;
        if (referenceCount > 1) return false;
      }
    }
    return referenceCount == 1;
  }

  Future<bool> _collectionReferencesGroup(
    String collectionId,
    String groupId,
    List<TagItem> items,
  ) async {
    for (final item in items) {
      if (item.itemType == TagItemType.tagReference) {
        if (item.targetId == groupId) return true;
        final nestedGroup =
            await tagRepository.getCollectionTag(item.targetId);
        if (nestedGroup?.metadata != null) {
          final hasReference = await _collectionReferencesGroup(
            item.targetId,
            groupId,
            nestedGroup!.metadata!.items,
          );
          if (hasReference) return true;
        }
      }
    }
    return false;
  }
}
