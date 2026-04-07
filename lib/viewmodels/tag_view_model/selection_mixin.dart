import 'dart:math';
import '../../models/tag_extensions.dart';
import 'tag_view_model_base.dart';

/// Mixin handling selection state and bulk move operations.
mixin SelectionMixin on TagViewModelBase {
  // Must be provided by other mixins
  Future<void> loadTagsSilent();
  Future<void> recomputeDisplayOrders(String collectionId);

  // ==========================================================================
  // Selection State
  // ==========================================================================

  /// Unmodifiable view of currently selected item IDs
  Set<String> get selectedItemIds => Set.unmodifiable(selectedItemIdsSet);

  /// Whether selection mode is active
  bool get hasSelection => selectionModeActiveValue;

  /// Number of currently selected items
  int get selectionCount => selectedItemIdsSet.length;

  /// Enter selection mode without selecting anything
  void enterSelectionMode() {
    selectionModeActiveValue = true;
    notifyListeners();
  }

  /// Toggle selection state of an item
  void toggleSelection(String itemId) {
    selectionModeActiveValue = true;
    if (selectedItemIdsSet.contains(itemId)) {
      selectedItemIdsSet.remove(itemId);
    } else {
      selectedItemIdsSet.add(itemId);
    }
    notifyListeners();
  }

  /// Clear all selections and exit selection mode
  void clearSelection() {
    selectedItemIdsSet.clear();
    selectionModeActiveValue = false;
    notifyListeners();
  }

  /// Check if a specific item is selected
  bool isSelected(String itemId) => selectedItemIdsSet.contains(itemId);

  // ==========================================================================
  // Bulk Move Operations
  // ==========================================================================

  Future<List<TagItem>> _collectSelectedItemsFromGroups(
    String collectionId,
  ) async {
    final result = <TagItem>[];
    final parentTag =
        await tagRepository.getCollectionTag(collectionId);
    if (parentTag == null || !parentTag.isCollection) return result;

    final items = parentTag.metadata?.items ?? [];
    for (final item in items) {
      if (item.itemType == TagItemType.tagReference) {
        final refTag =
            await tagRepository.getCollectionTag(item.targetId);
        if (refTag != null && refTag.isGroup) {
          final groupItems =
              await tagRepository.getCollectionItems(item.targetId);
          for (final gi in groupItems) {
            if (selectedItemIdsSet.contains(gi.id)) {
              result.add(gi);
            }
          }
        }
      }
    }
    return result;
  }

  Future<void> _removeItemFromCurrentLocation(
    String collectionId,
    String itemId,
  ) async {
    final containingId =
        await _findContainingCollectionForBulk(collectionId, itemId);
    if (containingId != null) {
      await tagRepository.removeItemFromCollection(containingId, itemId);
    }
  }

  Future<String?> _findContainingCollectionForBulk(
    String parentCollectionId,
    String itemId, {
    int depth = 0,
  }) async {
    if (depth > 10) return null;
    final parentTag =
        await tagRepository.getCollectionTag(parentCollectionId);
    if (parentTag == null || !parentTag.isCollection) return null;
    final items = parentTag.metadata?.items ?? [];

    for (final item in items) {
      if (item.id == itemId) return parentCollectionId;
    }

    for (final item in items) {
      if (item.itemType == TagItemType.tagReference) {
        final refTag =
            await tagRepository.getCollectionTag(item.targetId);
        if (refTag != null && refTag.isGroup) {
          final found = await _findContainingCollectionForBulk(
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

  /// Bulk move selected song units into a target group
  Future<void> bulkMoveToGroup(
    String collectionId,
    String targetGroupId,
  ) async {
    if (selectedItemIdsSet.isEmpty) return;

    try {
      errorValue = null;

      final allItems =
          await tagRepository.getCollectionItems(collectionId);
      final selectedItems = allItems
          .where((item) => selectedItemIdsSet.contains(item.id))
          .toList();

      final groupItems =
          await _collectSelectedItemsFromGroups(collectionId);
      selectedItems.addAll(groupItems);

      if (selectedItems.isEmpty) {
        selectedItemIdsSet.clear();
        selectionModeActiveValue = false;
        notifyListeners();
        return;
      }

      selectedItems.sort((a, b) => a.order.compareTo(b.order));

      for (final item in selectedItems) {
        await _removeItemFromCurrentLocation(collectionId, item.id);
      }

      final existingGroupItems =
          await tagRepository.getCollectionItems(targetGroupId);
      var insertOrder = existingGroupItems.isEmpty
          ? 0
          : existingGroupItems.map((i) => i.order).reduce(max) + 1;

      for (final item in selectedItems) {
        await tagRepository.addItemToCollection(
          targetGroupId,
          TagItem(
            id: uuid.v4(),
            itemType: TagItemType.songUnit,
            targetId: item.targetId,
            order: insertOrder++,
            inheritLock: true,
            ),
        );
      }

      selectedItemIdsSet.clear();
      selectionModeActiveValue = false;

      await recomputeDisplayOrders(collectionId);
      await recomputeDisplayOrders(targetGroupId);

      if (collectionId == activeQueueIdValue) {
        await loadCurrentQueueSongs();
        await updateCachedValues();
      }

      notifyListeners();
    } catch (e) {
      errorValue = e.toString();
      notifyListeners();
    }
  }

  /// Bulk move selected song units out of groups to the top-level collection
  Future<void> bulkRemoveFromGroup(String collectionId) async {
    if (selectedItemIdsSet.isEmpty) return;

    try {
      errorValue = null;

      final selectedItems =
          await _collectSelectedItemsFromGroups(collectionId);
      selectedItems.sort((a, b) => a.order.compareTo(b.order));

      if (selectedItems.isEmpty) {
        selectedItemIdsSet.clear();
        selectionModeActiveValue = false;
        notifyListeners();
        return;
      }

      for (final item in selectedItems) {
        await _removeItemFromCurrentLocation(collectionId, item.id);
      }

      final topLevelItems =
          await tagRepository.getCollectionItems(collectionId);
      var insertOrder = topLevelItems.isEmpty
          ? 0
          : topLevelItems.map((i) => i.order).reduce(max) + 1;

      for (final item in selectedItems) {
        await tagRepository.addItemToCollection(
          collectionId,
          TagItem(
            id: uuid.v4(),
            itemType: TagItemType.songUnit,
            targetId: item.targetId,
            order: insertOrder++,
            inheritLock: true,
            ),
        );
      }

      selectedItemIdsSet.clear();
      selectionModeActiveValue = false;

      await recomputeDisplayOrders(collectionId);

      if (collectionId == activeQueueIdValue) {
        await loadCurrentQueueSongs();
        await updateCachedValues();
      }

      notifyListeners();
    } catch (e) {
      errorValue = e.toString();
      notifyListeners();
    }
  }
}
