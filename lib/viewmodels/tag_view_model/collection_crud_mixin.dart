import '../../models/playlist_metadata.dart';
import '../../models/tag.dart';
import 'tag_view_model_base.dart';

/// Mixin handling collection CRUD, add/remove items, and add references.
mixin CollectionCrudMixin on TagViewModelBase {
  // Must be provided by other mixins
  Future<void> loadTagsSilent();

  // ==========================================================================
  // Collection CRUD
  // ==========================================================================

  /// Create a collection (playlist, queue, or group)
  Future<Tag> createCollection(
    String name, {
    String? parentId,
    bool isGroup = false,
    bool isQueue = false,
  }) async {
    try {
      errorValue = null;
      final tag = await tagRepository.createCollection(
        name,
        parentId: parentId,
        isGroup: isGroup,
        isQueue: isQueue,
      );
      return tag;
    } catch (e) {
      errorValue = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Create a nested group inside an existing collection and add a reference.
  Future<Tag?> createNestedGroup(String parentCollectionId, String name,
      {int? insertIndex}) async {
    try {
      errorValue = null;
      final parentTag =
          await tagRepository.getCollectionTag(parentCollectionId);
      if (parentTag == null || !parentTag.isCollection) {
        errorValue = 'Parent collection not found';
        notifyListeners();
        return null;
      }

      final group = await tagRepository.createCollection(
        name,
        parentId: parentCollectionId,
        isGroup: true,
      );

      final metadata = parentTag.playlistMetadata!;
      final nextOrder = metadata.items.isEmpty
          ? 0
          : metadata.items.map((i) => i.order).reduce((a, b) => a > b ? a : b) +
              1;

      final newItem = PlaylistItem(
        id: uuid.v4(),
        type: PlaylistItemType.collectionReference,
        targetId: group.id,
        order: nextOrder,
      );

      await tagRepository.addItemToCollection(parentCollectionId, newItem);

      if (insertIndex != null) {
        final freshParent =
            await tagRepository.getCollectionTag(parentCollectionId);
        if (freshParent?.playlistMetadata != null) {
          final items = List<PlaylistItem>.from(
              freshParent!.playlistMetadata!.items)
            ..sort((a, b) => a.order.compareTo(b.order));
          final addedIndex = items.lastIndexWhere(
            (i) =>
                i.targetId == group.id &&
                i.type == PlaylistItemType.collectionReference,
          );
          if (addedIndex >= 0) {
            final addedItem = items.removeAt(addedIndex);
            final clampedIdx = insertIndex.clamp(0, items.length);
            items.insert(clampedIdx, addedItem);
            await tagRepository.reorderCollectionItems(
              parentCollectionId,
              items.map((i) => i.id).toList(),
            );
          }
        }
      }

      await loadTags();
      await loadCurrentQueueSongs();
      await updateCachedValues();
      notifyListeners();
      return group;
    } catch (e) {
      errorValue = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Reorder playlists in the sidebar
  Future<void> reorderPlaylists(List<String> playlistIds) async {
    try {
      errorValue = null;
      for (var i = 0; i < playlistIds.length; i++) {
        final tag = await tagRepository.getCollectionTag(playlistIds[i]);
        if (tag != null && tag.isCollection) {
          final updated = tag.copyWith(
            playlistMetadata: tag.playlistMetadata?.copyWith(displayOrder: i),
          );
          await tagRepository.updateTag(updated);
        }
      }
      await loadTags();
    } catch (e) {
      errorValue = e.toString();
      notifyListeners();
    }
  }

  /// Get all collections, optionally filtered
  Future<List<Tag>> getCollections({
    bool includeGroups = true,
    bool includeQueues = true,
  }) async {
    try {
      final collections = await tagRepository.getCollections(
        includeGroups: includeGroups,
      );
      if (!includeQueues) {
        return collections.where((c) => !c.isActiveQueue).toList();
      }
      return collections;
    } catch (e) {
      errorValue = e.toString();
      notifyListeners();
      return [];
    }
  }

  /// Create a new playlist
  Future<void> createPlaylist(String name) async {
    try {
      errorValue = null;
      await tagRepository.createCollection(name);
      notifyListeners();
    } catch (e) {
      errorValue = e.toString();
      notifyListeners();
    }
  }

  /// Add a Song Unit to a playlist
  Future<void> addToPlaylist(String playlistId, String songUnitId) async {
    await addSongUnitToCollection(playlistId, songUnitId);
  }

  // ==========================================================================
  // Add / Remove Items
  // ==========================================================================

  /// Add a song unit to any collection
  Future<void> addSongUnitToCollection(
    String collectionId,
    String songUnitId,
  ) async {
    try {
      errorValue = null;
      final collectionTag =
          await tagRepository.getCollectionTag(collectionId);
      if (collectionTag == null || !collectionTag.isCollection) {
        errorValue = 'Collection not found';
        notifyListeners();
        return;
      }
      final songUnit = await libraryRepository.getSongUnit(songUnitId);
      if (songUnit == null) {
        errorValue = 'Song Unit not found';
        notifyListeners();
        return;
      }

      final metadata =
          collectionTag.playlistMetadata ?? PlaylistMetadata.empty();
      final nextOrder = metadata.items.isEmpty
          ? 0
          : metadata.items.map((i) => i.order).reduce((a, b) => a > b ? a : b) +
              1;

      final item = PlaylistItem(
        id: uuid.v4(),
        type: PlaylistItemType.songUnit,
        targetId: songUnitId,
        order: nextOrder,
      );

      await tagRepository.addItemToPlaylist(collectionId, item);

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

  /// Add a collection reference to any collection
  Future<void> addCollectionReference(String parentId, String targetId) async {
    try {
      errorValue = null;
      if (await wouldCreateCircularReference(parentId, targetId)) {
        errorValue = 'Cannot add collection: would create circular reference';
        notifyListeners();
        return;
      }

      final parentTag = await tagRepository.getCollectionTag(parentId);
      if (parentTag == null || !parentTag.isCollection) {
        errorValue = 'Parent collection not found';
        notifyListeners();
        return;
      }

      final metadata = parentTag.playlistMetadata ?? PlaylistMetadata.empty();
      final nextOrder = metadata.items.isEmpty
          ? 0
          : metadata.items.map((i) => i.order).reduce((a, b) => a > b ? a : b) +
              1;

      final item = PlaylistItem(
        id: uuid.v4(),
        type: PlaylistItemType.collectionReference,
        targetId: targetId,
        order: nextOrder,
      );

      await tagRepository.addItemToPlaylist(parentId, item);

      if (parentId == activeQueueIdValue) {
        await loadCurrentQueueSongs();
        await updateCachedValues();
      }
      notifyListeners();
    } catch (e) {
      errorValue = e.toString();
      notifyListeners();
    }
  }

  /// Remove an item from any collection
  Future<void> removeFromCollection(String collectionId, String itemId) async {
    try {
      errorValue = null;
      await tagRepository.removeItemFromPlaylist(collectionId, itemId);
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

  // ==========================================================================
  // Circular Reference Detection
  // ==========================================================================

  /// Check if adding a reference would create a circular reference
  Future<bool> wouldCreateCircularReference(
    String parentId,
    String targetId,
  ) async {
    if (parentId == targetId) return true;
    final visited = <String>{};
    return _checkCircularReference(targetId, parentId, visited);
  }

  Future<bool> _checkCircularReference(
    String currentId,
    String searchForId,
    Set<String> visited,
  ) async {
    if (visited.contains(currentId)) return false;
    visited.add(currentId);

    final tag = await tagRepository.getCollectionTag(currentId);
    if (tag == null || !tag.isCollection) return false;

    final metadata = tag.playlistMetadata;
    if (metadata == null) return false;

    for (final item in metadata.items) {
      if (item.type == PlaylistItemType.collectionReference) {
        if (item.targetId == searchForId) return true;
        if (await _checkCircularReference(
          item.targetId,
          searchForId,
          visited,
        )) {
          return true;
        }
      }
    }
    return false;
  }

  /// Toggle lock state of any collection
  Future<void> toggleLock(String collectionId) async {
    try {
      errorValue = null;
      final tag = await tagRepository.getCollectionTag(collectionId);
      if (tag == null || !tag.isCollection) {
        errorValue = 'Collection not found';
        notifyListeners();
        return;
      }
      final metadata = tag.playlistMetadata ?? PlaylistMetadata.empty();
      await tagRepository.setPlaylistLock(collectionId, !metadata.isLocked);
      await loadCurrentQueueSongs();
      notifyListeners();
    } catch (e) {
      errorValue = e.toString();
      notifyListeners();
    }
  }
}
