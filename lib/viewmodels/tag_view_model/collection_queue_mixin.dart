import 'package:flutter/foundation.dart';
import '../../models/playlist_metadata.dart';
import '../../models/song_unit.dart';
import '../../models/tag.dart';
import 'tag_view_model_base.dart';

/// Mixin handling adding collections to queue, deep copy, dissolve/remove
/// group, and resolve content operations.
mixin CollectionQueueMixin on TagViewModelBase {
  // Must be provided by other mixins
  Future<void> loadTagsSilent();

  // ==========================================================================
  // Resolve Content
  // ==========================================================================

  /// Resolve collection content (expand references recursively)
  Future<List<SongUnit>> resolveContent(
    String collectionId, {
    int depth = 0,
    Map<String, Map<String, dynamic>>? temporarySongUnits,
  }) async {
    if (depth > 10) {
      debugPrint('Max collection nesting depth reached');
      return [];
    }

    final tag = await tagRepository.getCollectionTag(collectionId);
    if (tag == null || !tag.isCollection) return [];

    final metadata = tag.playlistMetadata;
    if (metadata == null) return [];

    final result = <SongUnit>[];

    for (final item in metadata.items) {
      switch (item.type) {
        case PlaylistItemType.songUnit:
          if (item.targetId.startsWith('temp_') &&
              temporarySongUnits != null) {
            final tempData = temporarySongUnits[item.targetId];
            if (tempData != null) {
              try {
                result.add(SongUnit.fromJson(tempData));
                continue;
              } catch (e) {
                debugPrint(
                  'Failed to deserialize temporary song unit ${item.targetId}: $e',
                );
              }
            }
          }
          final songUnit =
              await libraryRepository.getSongUnit(item.targetId);
          if (songUnit != null) result.add(songUnit);
          break;

        case PlaylistItemType.collectionReference:
          final nestedSongs = await resolveContent(
            item.targetId,
            depth: depth + 1,
            temporarySongUnits: temporarySongUnits,
          );
          result.addAll(nestedSongs);
          break;
      }
    }

    return result;
  }

  // ==========================================================================
  // Add Collection to Queue
  // ==========================================================================

  /// Add a collection to the active queue as a group
  Future<Tag?> addCollectionToQueue(
    String collectionId, {
    bool? overrideLock,
  }) async {
    try {
      errorValue = null;
      final sourceCollection =
          await tagRepository.getCollectionTag(collectionId);
      if (sourceCollection == null || !sourceCollection.isCollection) {
        errorValue = 'Collection not found';
        notifyListeners();
        return null;
      }

      final sourceItems =
          await tagRepository.getCollectionItems(collectionId);
      if (sourceItems.isEmpty) {
        errorValue = 'Collection is empty';
        notifyListeners();
        return null;
      }

      final lockState = overrideLock ?? sourceCollection.isLocked;

      final group = await tagRepository.createCollection(
        sourceCollection.name,
        parentId: activeQueueIdValue,
        isGroup: true,
      );

      if (lockState) {
        await tagRepository.setCollectionLock(group.id, true);
      }

      final copiedCount = await _deepCopyCollectionItems(
        sourceItems: sourceItems,
        targetCollectionId: group.id,
      );

      if (copiedCount == 0) {
        await tagRepository.deleteTag(group.id);
        errorValue = 'Collection is empty';
        notifyListeners();
        return null;
      }

      final aq = await getActiveQueue();
      if (aq?.playlistMetadata == null) return null;

      final metadata = aq!.playlistMetadata!;
      final nextOrder = metadata.items.isEmpty
          ? 0
          : metadata.items
                  .map((i) => i.order)
                  .reduce((a, b) => a > b ? a : b) +
              1;

      final groupRef = PlaylistItem(
        id: uuid.v4(),
        type: PlaylistItemType.collectionReference,
        targetId: group.id,
        order: nextOrder,
      );

      await tagRepository.addItemToCollection(activeQueueIdValue, groupRef);

      await loadCurrentQueueSongs();
      await updateCachedValues();
      notifyListeners();

      return await tagRepository.getCollectionTag(group.id);
    } catch (e) {
      errorValue = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Recursively deep-copy items from source into target collection.
  Future<int> _deepCopyCollectionItems({
    required List<PlaylistItem> sourceItems,
    required String targetCollectionId,
    int depth = 0,
  }) async {
    if (depth > 10) return 0;

    var orderCounter = 0;
    var songCount = 0;

    for (final item in sourceItems) {
      if (item.type == PlaylistItemType.songUnit) {
        final songUnit =
            await libraryRepository.getSongUnit(item.targetId);
        if (songUnit == null) continue;

        await tagRepository.addItemToCollection(
          targetCollectionId,
          PlaylistItem(
            id: uuid.v4(),
            type: PlaylistItemType.songUnit,
            targetId: item.targetId,
            order: orderCounter++,
          ),
        );
        songCount++;
      } else if (item.type == PlaylistItemType.collectionReference) {
        final refTag =
            await tagRepository.getCollectionTag(item.targetId);
        if (refTag == null) continue;

        final subGroup = await tagRepository.createCollection(
          refTag.name,
          parentId: targetCollectionId,
          isGroup: true,
        );

        if (refTag.isLocked) {
          await tagRepository.setCollectionLock(subGroup.id, true);
        }

        final refItems =
            await tagRepository.getCollectionItems(item.targetId);
        final subCopied = await _deepCopyCollectionItems(
          sourceItems: refItems,
          targetCollectionId: subGroup.id,
          depth: depth + 1,
        );

        if (subCopied == 0) {
          await tagRepository.deleteTag(subGroup.id);
          continue;
        }

        await tagRepository.addItemToCollection(
          targetCollectionId,
          PlaylistItem(
            id: uuid.v4(),
            type: PlaylistItemType.collectionReference,
            targetId: subGroup.id,
            order: orderCounter++,
          ),
        );
        songCount += subCopied;
      }
    }

    return songCount;
  }

  /// Add items from a collection directly to the queue without wrapping.
  Future<int> addCollectionItemsToQueue(String collectionId) async {
    try {
      errorValue = null;
      final sourceCollection =
          await tagRepository.getCollectionTag(collectionId);
      if (sourceCollection == null || !sourceCollection.isCollection) {
        errorValue = 'Collection not found';
        notifyListeners();
        return 0;
      }

      final sourceItems =
          await tagRepository.getCollectionItems(collectionId);
      if (sourceItems.isEmpty) {
        errorValue = 'Collection is empty';
        notifyListeners();
        return 0;
      }

      final aq = await getActiveQueue();
      if (aq?.playlistMetadata == null) return 0;

      final metadata = aq!.playlistMetadata!;
      var nextOrder = metadata.items.isEmpty
          ? 0
          : metadata.items
                  .map((i) => i.order)
                  .reduce((a, b) => a > b ? a : b) +
              1;

      var addedCount = 0;

      for (final item in sourceItems) {
        if (item.type == PlaylistItemType.songUnit) {
          final songUnit =
              await libraryRepository.getSongUnit(item.targetId);
          if (songUnit == null) continue;

          await tagRepository.addItemToCollection(
            activeQueueIdValue,
            PlaylistItem(
              id: uuid.v4(),
              type: PlaylistItemType.songUnit,
              targetId: item.targetId,
              order: nextOrder++,
            ),
          );
          addedCount++;
        } else if (item.type == PlaylistItemType.collectionReference) {
          final refTag =
              await tagRepository.getCollectionTag(item.targetId);
          if (refTag == null) continue;

          final subGroup = await tagRepository.createCollection(
            refTag.name,
            parentId: activeQueueIdValue,
            isGroup: true,
          );

          if (refTag.isLocked) {
            await tagRepository.setCollectionLock(subGroup.id, true);
          }

          final refItems =
              await tagRepository.getCollectionItems(item.targetId);
          final subCopied = await _deepCopyCollectionItems(
            sourceItems: refItems,
            targetCollectionId: subGroup.id,
          );

          if (subCopied == 0) {
            await tagRepository.deleteTag(subGroup.id);
            continue;
          }

          await tagRepository.addItemToCollection(
            activeQueueIdValue,
            PlaylistItem(
              id: uuid.v4(),
              type: PlaylistItemType.collectionReference,
              targetId: subGroup.id,
              order: nextOrder++,
            ),
          );
          addedCount += subCopied;
        }
      }

      if (addedCount > 0) {
        await loadCurrentQueueSongs();
        await updateCachedValues();
        notifyListeners();
      }

      return addedCount;
    } catch (e) {
      errorValue = e.toString();
      notifyListeners();
      return 0;
    }
  }

  // ==========================================================================
  // Dissolve / Remove Group
  // ==========================================================================

  /// Dissolve a group: move all songs to the parent collection
  Future<void> dissolveGroup(String parentCollectionId, String groupId) async {
    try {
      errorValue = null;
      suppressEvents = true;

      final actualParentId =
          await _resolveParentForGroup(parentCollectionId, groupId);
      if (actualParentId == null) {
        suppressEvents = false;
        return;
      }

      final parent =
          await tagRepository.getCollectionTag(actualParentId);
      if (parent == null || !parent.isCollection) {
        suppressEvents = false;
        return;
      }

      final parentMeta = parent.playlistMetadata!;
      final items = List<PlaylistItem>.from(parentMeta.items);

      final groupRefIndex = items.indexWhere(
        (i) =>
            i.type == PlaylistItemType.collectionReference &&
            i.targetId == groupId,
      );
      if (groupRefIndex == -1) {
        suppressEvents = false;
        return;
      }

      final groupTag = await tagRepository.getCollectionTag(groupId);
      if (groupTag == null || groupTag.playlistMetadata == null) {
        suppressEvents = false;
        return;
      }

      final groupItems = groupTag.playlistMetadata!.items;
      items.removeAt(groupRefIndex);

      for (var i = 0; i < groupItems.length; i++) {
        items.insert(
          groupRefIndex + i,
          PlaylistItem(
            id: uuid.v4(),
            type: groupItems[i].type,
            targetId: groupItems[i].targetId,
            order: groupRefIndex + i,
            inheritLock: groupItems[i].inheritLock,
          ),
        );
      }

      for (var i = 0; i < items.length; i++) {
        items[i] = items[i].copyWith(order: i);
      }

      final updatedMetadata = parentMeta.copyWith(
        items: items,
        updatedAt: DateTime.now(),
      );
      await tagRepository.updateCollectionMetadata(
          actualParentId, updatedMetadata);

      if (!await _isReferencedByOtherCollections(groupId,
          excludeCollectionId: actualParentId)) {
        await tagRepository.deleteTag(groupId);
      }

      await loadTagsSilent();
      await loadCurrentQueueSongs();
      await updateCachedValues();

      suppressEvents = false;
      notifyListeners();
    } catch (e) {
      suppressEvents = false;
      errorValue = e.toString();
      notifyListeners();
    }
  }

  /// Remove a group and all its songs from a parent collection
  Future<void> removeGroupFromQueue(
    String parentCollectionId,
    String groupId,
  ) async {
    try {
      errorValue = null;
      suppressEvents = true;

      final actualParentId =
          await _resolveParentForGroup(parentCollectionId, groupId);
      if (actualParentId == null) {
        errorValue = 'Group reference not found in any parent';
        suppressEvents = false;
        notifyListeners();
        return;
      }

      final parent =
          await tagRepository.getCollectionTag(actualParentId);
      if (parent == null || !parent.isCollection) {
        suppressEvents = false;
        return;
      }

      final parentMeta = parent.playlistMetadata!;
      final refItem = parentMeta.items.firstWhere(
        (i) =>
            i.type == PlaylistItemType.collectionReference &&
            i.targetId == groupId,
        orElse: () => throw StateError('Group reference not found'),
      );

      await tagRepository.removeItemFromCollection(
          actualParentId, refItem.id);

      if (!await _isReferencedByOtherCollections(groupId,
          excludeCollectionId: actualParentId)) {
        await tagRepository.deleteTag(groupId);
      }

      await loadTagsSilent();
      await loadCurrentQueueSongs();
      await updateCachedValues();

      suppressEvents = false;
      notifyListeners();
    } catch (e) {
      suppressEvents = false;
      errorValue = e.toString();
      notifyListeners();
    }
  }

  // ==========================================================================
  // Group Helpers
  // ==========================================================================

  Future<String?> _resolveParentForGroup(
    String parentCollectionId,
    String groupId,
  ) async {
    final parent =
        await tagRepository.getCollectionTag(parentCollectionId);
    if (parent != null && parent.playlistMetadata != null) {
      final hasRef = parent.playlistMetadata!.items.any(
        (i) =>
            i.type == PlaylistItemType.collectionReference &&
            i.targetId == groupId,
      );
      if (hasRef) return parentCollectionId;
    }

    final groupTag = await tagRepository.getCollectionTag(groupId);
    if (groupTag?.parentId != null) {
      final realParent =
          await tagRepository.getCollectionTag(groupTag!.parentId!);
      if (realParent != null && realParent.playlistMetadata != null) {
        final hasRef = realParent.playlistMetadata!.items.any(
          (i) =>
              i.type == PlaylistItemType.collectionReference &&
              i.targetId == groupId,
        );
        if (hasRef) return groupTag.parentId;
      }
    }

    return null;
  }

  Future<bool> _isReferencedByOtherCollections(
    String groupId, {
    required String excludeCollectionId,
  }) async {
    final allTags = await tagRepository.getAllTags();
    for (final tag in allTags) {
      if (tag.id == excludeCollectionId) continue;
      if (!tag.isCollection) continue;
      final items = tag.playlistMetadata?.items ?? [];
      for (final item in items) {
        if (item.type == PlaylistItemType.collectionReference &&
            item.targetId == groupId) {
          return true;
        }
      }
    }
    return false;
  }
}
