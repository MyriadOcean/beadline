import 'package:flutter/foundation.dart';
import '../../models/song_unit.dart';
import '../../models/tag_extensions.dart';
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
  }) async {
    if (depth > 10) {
      debugPrint('Max collection nesting depth reached');
      return [];
    }

    final tag = await tagRepository.getCollectionTag(collectionId);
    if (tag == null || !tag.isCollection) return [];

    final metadata = tag.metadata;
    if (metadata == null) return [];

    final result = <SongUnit>[];

    for (final item in metadata.items) {
      switch (item.itemType) {
        case TagItemType.songUnit:
          final songUnit =
              await libraryRepository.getSongUnit(item.targetId);
          if (songUnit != null) result.add(songUnit);
          break;

        case TagItemType.tagReference:
          final nestedSongs = await resolveContent(
            item.targetId,
            depth: depth + 1,
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

      final copiedCount = await tagRepository.deepCopyCollection(
        collectionId, group.id,
      );

      if (copiedCount == 0) {
        await tagRepository.deleteTag(group.id);
        errorValue = 'Collection is empty';
        notifyListeners();
        return null;
      }

      final aq = await getActiveQueue();
      if (aq?.metadata == null) return null;

      final metadata = aq!.metadata!;
      final nextOrder = metadata.items.isEmpty
          ? 0
          : metadata.items
                  .map((i) => i.order)
                  .reduce((a, b) => a > b ? a : b) +
              1;

      final groupRef = TagItem(
        id: uuid.v4(),
        itemType: TagItemType.tagReference,
        targetId: group.id,
        order: nextOrder,
        inheritLock: true,
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

  /// Add items from a collection directly to the queue without wrapping.
  Future<int> addCollectionItemsToQueue(String collectionId) async {
    try {
      errorValue = null;
      final addedCount = await tagRepository.deepCopyCollection(
        collectionId, activeQueueIdValue,
      );

      if (addedCount == 0) {
        errorValue = 'Collection is empty';
        notifyListeners();
        return 0;
      }

      await loadCurrentQueueSongs();
      await updateCachedValues();
      notifyListeners();
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

      final parentMeta = parent.metadata!;
      final items = List<TagItem>.from(parentMeta.items);

      final groupRefIndex = items.indexWhere(
        (i) =>
            i.itemType == TagItemType.tagReference &&
            i.targetId == groupId,
      );
      if (groupRefIndex == -1) {
        suppressEvents = false;
        return;
      }

      final groupTag = await tagRepository.getCollectionTag(groupId);
      if (groupTag == null || groupTag.metadata == null) {
        suppressEvents = false;
        return;
      }

      final groupItems = groupTag.metadata!.items;
      items.removeAt(groupRefIndex);

      for (var i = 0; i < groupItems.length; i++) {
        items.insert(
          groupRefIndex + i,
          TagItem(
            id: uuid.v4(),
            itemType: groupItems[i].itemType,
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
        updatedAt: DateTime.now().toIso8601String(),
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

      final parentMeta = parent.metadata!;
      final refItem = parentMeta.items.firstWhere(
        (i) =>
            i.itemType == TagItemType.tagReference &&
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
    if (parent != null && parent.metadata != null) {
      final hasRef = parent.metadata!.items.any(
        (i) =>
            i.itemType == TagItemType.tagReference &&
            i.targetId == groupId,
      );
      if (hasRef) return parentCollectionId;
    }

    final groupTag = await tagRepository.getCollectionTag(groupId);
    if (groupTag?.parentId != null) {
      final realParent =
          await tagRepository.getCollectionTag(groupTag!.parentId!);
      if (realParent != null && realParent.metadata != null) {
        final hasRef = realParent.metadata!.items.any(
          (i) =>
              i.itemType == TagItemType.tagReference &&
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
      final items = tag.metadata?.items ?? [];
      for (final item in items) {
        if (item.itemType == TagItemType.tagReference &&
            item.targetId == groupId) {
          return true;
        }
      }
    }
    return false;
  }
}
