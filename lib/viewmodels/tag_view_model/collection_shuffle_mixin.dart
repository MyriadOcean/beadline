import 'package:flutter/foundation.dart';
import '../../models/playlist_metadata.dart';
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
    if (aq?.playlistMetadata == null) return false;

    final metadata = aq!.playlistMetadata!;
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
        (i) => i.type == PlaylistItemType.songUnit && i.targetId == su.id,
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
    if (refreshedQueue?.playlistMetadata != null) {
      await updateActiveQueue(
        refreshedQueue!.playlistMetadata!.copyWith(currentIndex: newIndex),
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
    if (aq?.playlistMetadata == null) return 0;

    final metadata = aq!.playlistMetadata!;
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
        return PlaylistItem(
          id: uuid.v4(),
          type: PlaylistItemType.songUnit,
          targetId: entry.value.id,
          order: entry.key,
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

  /// Shuffle any collection (respects locked sub-collections)
  Future<void> shuffle(String collectionId) async {
    try {
      errorValue = null;
      final collection =
          await tagRepository.getCollectionTag(collectionId);
      if (collection == null || !collection.isCollection) {
        errorValue = 'Collection not found';
        notifyListeners();
        return;
      }

      final metadata = collection.playlistMetadata!;
      if (metadata.items.length <= 1) return;

      final unlockedItems = <PlaylistItem>[];
      final lockedGroups = <List<PlaylistItem>>[];

      for (final item in metadata.items) {
        if (item.type == PlaylistItemType.collectionReference) {
          final refTag =
              await tagRepository.getCollectionTag(item.targetId);
          if (refTag != null && refTag.isCollection) {
            if (refTag.isLocked) {
              lockedGroups.add([item]);
              await _shuffleGroupInternal(item.targetId, parentLocked: true);
            } else {
              await _shuffleGroupInternal(item.targetId);
              unlockedItems.add(item);
            }
            continue;
          }
        }
        unlockedItems.add(item);
      }

      unlockedItems.shuffle(random);
      lockedGroups.shuffle(random);

      final shuffledItems = <PlaylistItem>[];
      var unlockedIndex = 0;
      var lockedGroupIndex = 0;

      while (unlockedIndex < unlockedItems.length ||
          lockedGroupIndex < lockedGroups.length) {
        final unlockedBatch = random.nextInt(3) + 1;
        for (var i = 0;
            i < unlockedBatch && unlockedIndex < unlockedItems.length;
            i++) {
          shuffledItems.add(unlockedItems[unlockedIndex++]);
        }
        if (lockedGroupIndex < lockedGroups.length) {
          shuffledItems.addAll(lockedGroups[lockedGroupIndex++]);
        }
      }

      for (var i = 0; i < shuffledItems.length; i++) {
        shuffledItems[i] = shuffledItems[i].copyWith(order: i);
      }

      await tagRepository.updateCollectionMetadata(
        collectionId,
        metadata.copyWith(items: shuffledItems),
      );

      if (collectionId == activeQueueIdValue) {
        await loadCurrentQueueSongs();
        await updateCachedValues();
      }
      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint('TagViewModel: shuffle() - caught exception: $e');
      debugPrint(
          'TagViewModel: shuffle() - exception stack trace: $stackTrace');
      errorValue = e.toString();
      notifyListeners();
    }
  }

  Future<void> _shuffleGroupInternal(
    String groupId, {
    bool parentLocked = false,
  }) async {
    final groupTag = await tagRepository.getCollectionTag(groupId);
    if (groupTag == null || !groupTag.isCollection) return;
    final meta = groupTag.playlistMetadata;
    if (meta == null || meta.items.length <= 1) {
      if (meta != null) {
        for (final item in meta.items) {
          if (item.type == PlaylistItemType.collectionReference) {
            await _shuffleGroupInternal(
              item.targetId,
              parentLocked: parentLocked || groupTag.isLocked,
            );
          }
        }
      }
      return;
    }

    if (parentLocked || groupTag.isLocked) {
      for (final item in meta.items) {
        if (item.type == PlaylistItemType.collectionReference) {
          await _shuffleGroupInternal(item.targetId, parentLocked: true);
        }
      }
      return;
    }

    final unlockedItems = <PlaylistItem>[];
    final lockedGroups = <List<PlaylistItem>>[];

    for (final item in meta.items) {
      if (item.type == PlaylistItemType.collectionReference) {
        final refTag =
            await tagRepository.getCollectionTag(item.targetId);
        if (refTag != null && refTag.isCollection) {
          if (refTag.isLocked) {
            lockedGroups.add([item]);
            await _shuffleGroupInternal(item.targetId, parentLocked: true);
          } else {
            await _shuffleGroupInternal(item.targetId);
            unlockedItems.add(item);
          }
          continue;
        }
      }
      unlockedItems.add(item);
    }

    unlockedItems.shuffle(random);
    lockedGroups.shuffle(random);

    final shuffled = <PlaylistItem>[];
    var ui = 0;
    var li = 0;
    while (ui < unlockedItems.length || li < lockedGroups.length) {
      final batch = random.nextInt(3) + 1;
      for (var i = 0; i < batch && ui < unlockedItems.length; i++) {
        shuffled.add(unlockedItems[ui++]);
      }
      if (li < lockedGroups.length) {
        shuffled.addAll(lockedGroups[li++]);
      }
    }

    for (var i = 0; i < shuffled.length; i++) {
      shuffled[i] = shuffled[i].copyWith(order: i);
    }

    await tagRepository.updateCollectionMetadata(
      groupId,
      meta.copyWith(items: shuffled),
    );
  }

  // ==========================================================================
  // Deduplicate & Clear
  // ==========================================================================

  /// Deduplicate any collection
  Future<int> deduplicate(String collectionId) async {
    try {
      errorValue = null;
      final collection =
          await tagRepository.getCollectionTag(collectionId);
      if (collection == null || !collection.isCollection) {
        errorValue = 'Collection not found';
        notifyListeners();
        return 0;
      }

      final metadata = collection.playlistMetadata!;
      if (metadata.items.length <= 1) return 0;

      final originalLength = metadata.items.length;
      final seenTargetIds = <String>{};
      final deduped = <PlaylistItem>[];

      for (final item in metadata.items) {
        if (!seenTargetIds.contains(item.targetId)) {
          seenTargetIds.add(item.targetId);
          deduped.add(item);
        }
      }

      final removedCount = originalLength - deduped.length;

      if (removedCount > 0) {
        for (var i = 0; i < deduped.length; i++) {
          deduped[i] = deduped[i].copyWith(order: i);
        }
        final updatedTag = collection.copyWith(
          playlistMetadata: metadata.copyWith(items: deduped),
        );
        await tagRepository.updateTag(updatedTag);

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

      final metadata = collection.playlistMetadata!;

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
    List<PlaylistItem> items,
  ) async {
    for (final item in items) {
      if (item.type == PlaylistItemType.collectionReference) {
        final groupId = item.targetId;
        final groupTag = await tagRepository.getCollectionTag(groupId);
        if (groupTag != null && groupTag.isGroup) {
          final groupMetadata = groupTag.playlistMetadata;
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
      if (collection.playlistMetadata == null) continue;
      final hasReference = await _collectionReferencesGroup(
        collection.id,
        groupId,
        collection.playlistMetadata!.items,
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
    List<PlaylistItem> items,
  ) async {
    for (final item in items) {
      if (item.type == PlaylistItemType.collectionReference) {
        if (item.targetId == groupId) return true;
        final nestedGroup =
            await tagRepository.getCollectionTag(item.targetId);
        if (nestedGroup?.playlistMetadata != null) {
          final hasReference = await _collectionReferencesGroup(
            item.targetId,
            groupId,
            nestedGroup!.playlistMetadata!.items,
          );
          if (hasReference) return true;
        }
      }
    }
    return false;
  }
}
