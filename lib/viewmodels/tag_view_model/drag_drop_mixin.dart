import 'package:flutter/foundation.dart';
import '../../models/tag_extensions.dart';
import 'tag_view_model_base.dart';

/// Mixin handling drag-and-drop grouping operations: move songs to/from groups,
/// move groups, nest groups, and related helpers.
mixin DragDropMixin on TagViewModelBase {
  // Must be provided by CollectionOperationsMixin
  Future<void> loadTagsSilent();
  Future<void> recomputeDisplayOrders(String collectionId);

  // ==========================================================================
  // Helpers
  // ==========================================================================

  Future<TagItem?> _findTagItem(
    String collectionId,
    String itemId,
  ) async {
    final tag = await tagRepository.getCollectionTag(collectionId);
    if (tag == null || !tag.isCollection) return null;
    final items = tag.metadata?.items ?? [];
    try {
      return items.firstWhere((i) => i.id == itemId);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _findContainingCollection(
    String parentCollectionId,
    String itemId, {
    int depth = 0,
  }) async {
    if (depth > 10) return null;
    final parentItem =
        await _findTagItem(parentCollectionId, itemId);
    if (parentItem != null) return parentCollectionId;

    final parentTag =
        await tagRepository.getCollectionTag(parentCollectionId);
    if (parentTag == null || !parentTag.isCollection) return null;
    final items = parentTag.metadata?.items ?? [];
    for (final item in items) {
      if (item.itemType == TagItemType.tagReference) {
        final refTag =
            await tagRepository.getCollectionTag(item.targetId);
        if (refTag != null && refTag.isGroup) {
          final found = await _findContainingCollection(
            item.targetId,
            itemId,
            depth: depth + 1,
          );
          if (found != null) return found;
        }
      }
    }
    return null;
  }

  Future<(String, TagItem)?> _findTagItemByTargetId(
    String parentCollectionId,
    String itemIdOrTargetId, {
    int depth = 0,
  }) async {
    if (depth > 10) return null;
    final parentTag =
        await tagRepository.getCollectionTag(parentCollectionId);
    if (parentTag == null || !parentTag.isCollection) return null;
    final parentItems = parentTag.metadata?.items ?? [];

    for (final pi in parentItems) {
      if (pi.itemType == TagItemType.songUnit &&
          pi.targetId == itemIdOrTargetId) {
        return (parentCollectionId, pi);
      }
    }

    for (final pi in parentItems) {
      if (pi.itemType == TagItemType.tagReference) {
        final groupTag =
            await tagRepository.getCollectionTag(pi.targetId);
        if (groupTag != null && groupTag.isGroup) {
          final result = await _findTagItemByTargetId(
            pi.targetId,
            itemIdOrTargetId,
            depth: depth + 1,
          );
          if (result != null) return result;
        }
      }
    }

    return null;
  }

  // ==========================================================================
  // Move Song Unit To/From Group
  // ==========================================================================

  /// Move a song unit into a group
  Future<void> moveSongUnitToGroup(
    String collectionId,
    String songUnitItemId,
    String targetGroupId, {
    int? insertIndex,
  }) async {
    try {
      errorValue = null;
      suppressEvents = true;

      final result = await _findTagItemByTargetId(
        collectionId,
        songUnitItemId,
      );

      if (result == null) {
        debugPrint(
            'moveSongUnitToGroup: song "$songUnitItemId" not found in "$collectionId"');
        errorValue = 'Item not found in collection';
        suppressEvents = false;
        notifyListeners();
        return;
      }

      final sourceCollectionId = result.$1;
      final item = result.$2;
      final targetId = item.targetId;
      final actualItemId = item.id;

      await tagRepository.removeItemFromCollection(
        sourceCollectionId,
        actualItemId,
      );

      final groupTag =
          await tagRepository.getCollectionTag(targetGroupId);
      final groupItems = groupTag?.metadata?.items ?? [];
      int order;
      if (insertIndex != null &&
          insertIndex >= 0 &&
          insertIndex <= groupItems.length) {
        order = insertIndex;
      } else {
        order = groupItems.length;
      }

      await tagRepository.addItemToCollection(
        targetGroupId,
        TagItem(
          id: uuid.v4(),
          itemType: TagItemType.songUnit,
          targetId: targetId,
          order: 0,
          inheritLock: true,
          ),
      );

      final freshGroup =
          await tagRepository.getCollectionTag(targetGroupId);
      if (freshGroup?.metadata != null &&
          order < (freshGroup!.metadata!.items.length - 1)) {
        final freshItems = List<TagItem>.from(
            freshGroup.metadata!.items);
        if (freshItems.isNotEmpty) {
          final newItem = freshItems.removeLast();
          final clampedIdx = order.clamp(0, freshItems.length);
          freshItems.insert(clampedIdx, newItem);
          await tagRepository.reorderCollectionItems(
            targetGroupId,
            freshItems.map((i) => i.id).toList(),
          );
        }
      }

      await recomputeDisplayOrders(sourceCollectionId);
      await loadTagsSilent();

      if (collectionId == activeQueueIdValue) {
        await loadCurrentQueueSongs();
        await updateCachedValues();
      }

      await Future<void>.delayed(Duration.zero);
      suppressEvents = false;
      notifyListeners();
    } catch (e) {
      suppressEvents = false;
      errorValue = e.toString();
      notifyListeners();
    }
  }

  /// Move a song unit out of a group to the top-level collection
  Future<void> moveSongUnitOutOfGroup(
    String groupId,
    String songUnitItemId,
    String parentCollectionId, {
    required int insertIndex,
  }) async {
    try {
      errorValue = null;
      suppressEvents = true;

      final result =
          await _findTagItemByTargetId(groupId, songUnitItemId);
      final resolved = result ??
          await _findTagItemByTargetId(
              parentCollectionId, songUnitItemId);

      if (resolved == null) {
        errorValue = 'Item not found in group or not a song unit';
        suppressEvents = false;
        notifyListeners();
        return;
      }

      final actualGroupId = resolved.$1;
      final item = resolved.$2;
      final targetId = item.targetId;
      final actualItemId = item.id;

      await tagRepository.removeItemFromCollection(
        actualGroupId,
        actualItemId,
      );

      await tagRepository.addItemToCollection(
        parentCollectionId,
        TagItem(
          id: uuid.v4(),
          itemType: TagItemType.songUnit,
          targetId: targetId,
          order: 0,
          inheritLock: true,
          ),
      );

      final freshParent =
          await tagRepository.getCollectionTag(parentCollectionId);
      if (freshParent?.metadata != null) {
        final freshItems = List<TagItem>.from(
            freshParent!.metadata!.items);
        if (freshItems.isNotEmpty) {
          final newItem = freshItems.removeLast();
          final clampedIdx = insertIndex.clamp(0, freshItems.length);
          freshItems.insert(clampedIdx, newItem);
          await tagRepository.reorderCollectionItems(
            parentCollectionId,
            freshItems.map((i) => i.id).toList(),
          );
        }
      }

      await recomputeDisplayOrders(actualGroupId);
      await loadTagsSilent();

      if (parentCollectionId == activeQueueIdValue) {
        await loadCurrentQueueSongs();
        await updateCachedValues();
      }

      await Future<void>.delayed(Duration.zero);
      suppressEvents = false;
      notifyListeners();
    } catch (e) {
      suppressEvents = false;
      errorValue = e.toString();
      notifyListeners();
    }
  }

  // ==========================================================================
  // Move Group Operations
  // ==========================================================================

  /// Move an entire group to a new position within its parent collection
  Future<void> moveGroup(
    String parentCollectionId,
    String groupItemId,
    int newIndex,
  ) async {
    try {
      errorValue = null;
      suppressEvents = true;

      final actualParentId = await _findContainingCollection(
        parentCollectionId,
        groupItemId,
      );
      if (actualParentId == null) {
        errorValue = 'Group item not found in collection';
        suppressEvents = false;
        notifyListeners();
        return;
      }

      final collection =
          await tagRepository.getCollectionTag(actualParentId);
 
      if (collection == null || !collection.isCollection) {
        errorValue = 'Collection not found';
        suppressEvents = false;
        notifyListeners();
        return;
      }

      final metadata = collection.metadata!;
      final items = List<TagItem>.from(metadata.items);

      final currentIndex = items.indexWhere((i) => i.id == groupItemId);
      if (currentIndex == -1) {
        errorValue = 'Group item not found in collection';
        suppressEvents = false;
        notifyListeners();
        return;
      }

      final clampedIndex = newIndex.clamp(0, items.length - 1);
      if (currentIndex == clampedIndex) {
        suppressEvents = false;
        return;
      }

      final item = items.removeAt(currentIndex);
      items.insert(clampedIndex, item);

      final reorderedIds = items.map((i) => i.id).toList();
      await tagRepository.reorderCollectionItems(
          actualParentId, reorderedIds);

      await loadTagsSilent();

      if (parentCollectionId == activeQueueIdValue ||
          actualParentId == activeQueueIdValue) {
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

  /// Move a group into another group (nesting it)
  Future<void> moveGroupIntoGroup(
    String rootCollectionId,
    String groupItemId,
    String targetGroupId,
  ) async {
    try {
      errorValue = null;
      suppressEvents = true;

      final sourceParentId = await _findContainingCollection(
        rootCollectionId,
        groupItemId,
      );
      if (sourceParentId == null) {
        errorValue = 'Group item not found';
        suppressEvents = false;
        notifyListeners();
        return;
      }

      final item = await _findTagItem(sourceParentId, groupItemId);
      if (item == null ||
          item.itemType != TagItemType.tagReference) {
        errorValue = 'Group reference not found';
        suppressEvents = false;
        notifyListeners();
        return;
      }

      final groupId = item.targetId;
      if (groupId == targetGroupId) return;

      await tagRepository.removeItemFromCollection(
          sourceParentId, item.id);

      final targetTag =
          await tagRepository.getCollectionTag(targetGroupId);
      final targetItems = targetTag?.metadata?.items ?? [];
      await tagRepository.addItemToCollection(
        targetGroupId,
        TagItem(
          id: uuid.v4(),
          itemType: TagItemType.tagReference,
          targetId: groupId,
          order: targetItems.length,
          inheritLock: true,
          ),
      );

      await recomputeDisplayOrders(sourceParentId);
      await recomputeDisplayOrders(targetGroupId);
      await loadTagsSilent();

      if (rootCollectionId == activeQueueIdValue) {
        await loadCurrentQueueSongs();
        await updateCachedValues();
      }

      await Future<void>.delayed(Duration.zero);
      suppressEvents = false;
      notifyListeners();
    } catch (e) {
      suppressEvents = false;
      errorValue = e.toString();
      notifyListeners();
    }
  }

  /// Move a group out of its current parent to a target collection
  Future<void> moveGroupOutToCollection(
    String rootCollectionId,
    String groupItemId,
    String targetCollectionId,
    int insertIndex,
  ) async {
    try {
      errorValue = null;
      suppressEvents = true;

      final sourceParentId = await _findContainingCollection(
        rootCollectionId,
        groupItemId,
      );
      if (sourceParentId == null) {
        errorValue = 'Group item not found';
        suppressEvents = false;
        notifyListeners();
        return;
      }

      if (sourceParentId == targetCollectionId) {
        suppressEvents = false;
        await moveGroup(rootCollectionId, groupItemId, insertIndex);
        return;
      }

      final item = await _findTagItem(sourceParentId, groupItemId);
      if (item == null ||
          item.itemType != TagItemType.tagReference) {
        errorValue = 'Group reference not found';
        suppressEvents = false;
        notifyListeners();
        return;
      }

      final groupId = item.targetId;

      await tagRepository.removeItemFromCollection(
          sourceParentId, item.id);

      await tagRepository.addItemToCollection(
        targetCollectionId,
        TagItem(
          id: uuid.v4(),
          itemType: TagItemType.tagReference,
          targetId: groupId,
          order: insertIndex,
          inheritLock: true,
          ),
      );

      await recomputeDisplayOrders(sourceParentId);
      await recomputeDisplayOrders(targetCollectionId);
      await loadTagsSilent();

      if (rootCollectionId == activeQueueIdValue) {
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
}
