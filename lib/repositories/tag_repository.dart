import 'dart:async';

import '../models/playlist_metadata.dart';
import '../models/tag.dart';
import '../src/rust/api/collection_api.dart' as rust_collection;
import '../src/rust/api/tag_api.dart' as rust_tag;

/// Events emitted by the TagRepository
sealed class TagEvent {
  const TagEvent();
}

/// Event emitted when a tag is created
class TagCreated extends TagEvent {
  const TagCreated(this.tag);
  final Tag tag;
}

/// Event emitted when a tag is updated
class TagUpdated extends TagEvent {
  const TagUpdated(this.tag);
  final Tag tag;
}

/// Event emitted when a tag is deleted
class TagDeleted extends TagEvent {
  const TagDeleted(this.tagId);
  final String tagId;
}

/// Event emitted when an alias is added
class AliasAdded extends TagEvent {
  const AliasAdded(this.aliasName, this.primaryTagId);
  final String aliasName;
  final String primaryTagId;
}

/// Event emitted when an alias is removed
class AliasRemoved extends TagEvent {
  const AliasRemoved(this.aliasName, this.primaryTagId);
  final String aliasName;
  final String primaryTagId;
}

/// Built-in tag names
class BuiltInTags {
  static const String name = 'name';
  static const String artist = 'artist';
  static const String album = 'album';
  static const String time = 'time';
  static const String duration = 'duration';
  static const String user = 'user';

  static const List<String> all = [name, artist, album, time, duration, user];
}

/// Repository for managing Tags
///
/// All tag CRUD operations are delegated to Rust FFI via
/// `lib/src/rust/api/tag_api.dart`. The FRB-transparent `DartTag` struct
/// is converted to/from the Dart `Tag` model for UI consumption.
/// Collection operations are delegated via `collection_api.dart`.
class TagRepository {
  TagRepository();
  final StreamController<TagEvent> _eventController =
      StreamController<TagEvent>.broadcast(sync: true);

  /// Stream of tag events for change notifications
  Stream<TagEvent> get events => _eventController.stream;

  /// Initialize built-in tags on first run
  Future<void> initializeBuiltInTags() async {
    for (final tagName in BuiltInTags.all) {
      final existing = await getTagByName(tagName);
      if (existing == null) {
        await _createTagInternal(name: tagName, type: TagType.builtIn);
      }
    }
  }

  /// Get a tag by ID
  Future<Tag?> getTag(String id) async {
    final result = await rust_tag.getTag(id: id);
    if (result == null) return null;
    return _dartTagToTag(result);
  }

  /// Get a tag by name
  Future<Tag?> getTagByName(String name) async {
    final result = await rust_tag.resolveTag(nameOrAlias: name);
    if (result == null) return null;
    return _dartTagToTag(result);
  }

  /// Create a new user tag
  /// Tag names can contain any characters except dangerous/reserved ones
  /// Dangerous: " (quotes can break JSON/queries)
  /// Reserved: ! & (used for query logic), : (used for key:value syntax), * (wildcard)
  /// Special: / (used for hierarchy - will auto-create parent tags)
  /// Leading/trailing whitespace is automatically trimmed
  Future<Tag> createTag(String name, {String? parentId}) async {
    // Auto-trim whitespace
    final trimmedName = name.trim();

    // Check if this is a hierarchical tag (contains /)
    if (trimmedName.contains('/')) {
      return _createHierarchicalTag(trimmedName);
    }

    // Validate tag name
    if (!_isValidTagName(trimmedName)) {
      throw ArgumentError(
        'Tag name cannot contain dangerous or reserved characters: " ! & : *',
      );
    }

    // Check if tag already exists
    final existing = await getTagByName(trimmedName);
    if (existing != null) {
      throw StateError('Tag with name "$trimmedName" already exists');
    }

    return _createTagInternal(
      name: trimmedName,
      type: TagType.user,
      parentId: parentId,
    );
  }

  /// Create a hierarchical tag from a path like "parent/child/grandchild"
  /// Auto-creates parent tags if they don't exist
  Future<Tag> _createHierarchicalTag(String path) async {
    final parts = path
        .split('/')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      throw ArgumentError('Invalid hierarchical tag path');
    }

    // Validate each part
    for (final part in parts) {
      if (!_isValidTagName(part)) {
        throw ArgumentError(
          'Tag name "$part" cannot contain dangerous or reserved characters: " ! & : *',
        );
      }
    }

    Tag? currentParent;

    // Create or find each level of the hierarchy
    for (var i = 0; i < parts.length; i++) {
      final tagName = parts[i];
      final parentId = currentParent?.id;

      // Try to find existing tag with this name and parent
      Tag? existing;
      final allTags = await getAllTags();
      for (final tag in allTags) {
        if (tag.name == tagName && tag.parentId == parentId) {
          existing = tag;
          break;
        }
      }

      if (existing != null) {
        currentParent = existing;
      } else {
        // Create new tag
        currentParent = await _createTagInternal(
          name: tagName,
          type: TagType.user,
          parentId: parentId,
        );
      }
    }

    return currentParent!;
  }

  /// Create an automatic tag (e.g., user:xx, playlist:xx)
  Future<Tag> createAutomaticTag(String name, {String? parentId}) async {
    final existing = await getTagByName(name);
    if (existing != null) {
      return existing;
    }

    return _createTagInternal(
      name: name,
      type: TagType.automatic,
      parentId: parentId,
    );
  }

  /// Internal method to create a tag
  Future<Tag> _createTagInternal({
    required String name,
    required TagType type,
    String? parentId,
  }) async {
    final result = await rust_tag.createTag(
      key: type == TagType.builtIn ? name : null,
      value: name,
      parentId: parentId,
    );

    final tag = _dartTagToTag(result);
    _eventController.add(TagCreated(tag));
    return tag;
  }

  /// Delete a tag
  /// Built-in tags cannot be deleted
  /// Uses Rust FFI for the actual deletion (handles alias cascade internally).
  Future<void> deleteTag(String id) async {
    final tag = await getTag(id);
    if (tag == null) return;

    if (tag.type == TagType.builtIn) {
      throw StateError('Cannot delete built-in tag "${tag.name}"');
    }

    // Rust FFI delete_tag handles alias cascade internally
    await rust_tag.deleteTag(id: id);

    _eventController.add(TagDeleted(id));
  }

  /// Update an existing tag
  /// Returns the updated tag
  Future<Tag> updateTag(Tag tag) async {
    if (tag.type == TagType.builtIn) {
      throw StateError('Cannot update built-in tag "${tag.name}"');
    }

    final dartTag = _tagToDartTag(tag);
    await rust_tag.updateTag(tag: dartTag);

    _eventController.add(TagUpdated(tag));
    return tag;
  }

  /// Add an alias for a tag
  /// Alias must be unique across all tags and aliases
  Future<void> addAlias(String primaryTagId, String aliasName) async {
    // Check if alias already exists
    final existingAlias = await resolveAlias(aliasName);
    if (existingAlias != null) {
      throw StateError('Alias "$aliasName" already exists');
    }

    // Check if a tag with this name exists
    final existingTag = await getTagByName(aliasName);
    if (existingTag != null) {
      throw StateError('A tag with name "$aliasName" already exists');
    }

    await rust_tag.addAlias(tagId: primaryTagId, alias: aliasName);

    _eventController.add(AliasAdded(aliasName, primaryTagId));
  }

  /// Remove an alias from a tag
  Future<void> removeAlias(String primaryTagId, String aliasName) async {
    await rust_tag.removeAlias(alias: aliasName);

    _eventController.add(AliasRemoved(aliasName, primaryTagId));
  }

  /// Resolve an alias to its primary tag
  Future<Tag?> resolveAlias(String aliasName) async {
    final result = await rust_tag.resolveTag(nameOrAlias: aliasName);
    if (result == null) return null;
    return _dartTagToTag(result);
  }

  /// Get a tag by name or alias
  /// Uses Rust resolveTag which handles both name and alias lookup
  Future<Tag?> getTagByNameOrAlias(String nameOrAlias) async {
    final result = await rust_tag.resolveTag(nameOrAlias: nameOrAlias);
    if (result == null) return null;
    return _dartTagToTag(result);
  }

  /// Get all built-in tags
  Future<List<Tag>> getBuiltInTags() async {
    final results = await rust_tag.getTagsByType(tagType: 'builtIn');
    return results.map(_dartTagToTag).toList();
  }

  /// Get all user tags
  Future<List<Tag>> getUserTags() async {
    final results = await rust_tag.getTagsByType(tagType: 'user');
    return results.map(_dartTagToTag).toList();
  }

  /// Get all automatic tags
  Future<List<Tag>> getAutomaticTags() async {
    final results = await rust_tag.getTagsByType(tagType: 'automatic');
    return results.map(_dartTagToTag).toList();
  }

  /// Get all tags
  Future<List<Tag>> getAllTags() async {
    final results = await rust_tag.getAllTags();
    return results.map(_dartTagToTag).toList();
  }

  /// Get the full hierarchical path of a tag (e.g., "parent/child/grandchild")
  /// Returns just the tag name if it has no parent.
  /// Uses Rust FFI for path computation.
  Future<String> getTagPath(String tagId) async {
    return rust_tag.getTagPath(tagId: tagId);
  }

  /// Get child tags of a parent
  Future<List<Tag>> getChildTags(String parentId) async {
    final results = await rust_tag.getChildren(parentId: parentId);
    return results.map(_dartTagToTag).toList();
  }

  /// Get all descendants of a tag (recursive)
  Future<List<Tag>> getDescendants(String tagId) async {
    final results = await rust_tag.getDescendants(tagId: tagId);
    return results.map(_dartTagToTag).toList();
  }

  /// Update a tag's includeChildren setting
  Future<void> updateIncludeChildren(String tagId, bool includeChildren) async {
    final tag = await getTag(tagId);
    if (tag == null) return;

    final updatedTag = tag.copyWith(includeChildren: includeChildren);
    final dartTag = _tagToDartTag(updatedTag);
    await rust_tag.updateTag(tag: dartTag);

    _eventController.add(TagUpdated(updatedTag));
  }

  /// Validate tag name - allow any characters except dangerous/reserved ones
  /// Dangerous: " (quotes can break JSON/queries)
  /// Reserved: ! & (used for query logic), : (used for key:value syntax), * (wildcard)
  /// Note: / is allowed here as it's handled separately for hierarchy
  /// Name should already be trimmed before calling this
  bool _isValidTagName(String name) {
    if (name.isEmpty) return false;

    // Check for dangerous/reserved characters (excluding / which is handled separately)
    final dangerousChars = ['"', '!', '&', ':', '*'];
    for (final char in dangerousChars) {
      if (name.contains(char)) return false;
    }

    return true;
  }

  // ============================================================================
  // FFI Conversion Helpers — DartTag ↔ Dart Tag
  // ============================================================================

  /// Convert a Rust DartTag (FFI struct) to a Dart Tag (UI model)
  Tag _dartTagToTag(rust_tag.DartTag dt) {
    return Tag(
      id: dt.id,
      name: dt.name,
      type: TagType.values.firstWhere(
        (t) => t.name == dt.tagType,
        orElse: () => TagType.user,
      ),
      parentId: dt.parentId,
      aliasNames: dt.aliasNames,
      includeChildren: dt.includeChildren,
      isGroup: dt.isGroup,
    );
  }

  /// Convert a Dart Tag (UI model) to a Rust DartTag (FFI struct) for updates
  rust_tag.DartTag _tagToDartTag(Tag tag) {
    return rust_tag.DartTag(
      id: tag.id,
      name: tag.name,
      tagType: tag.type.name,
      parentId: tag.parentId,
      aliasNames: tag.aliasNames,
      includeChildren: tag.includeChildren,
      isGroup: tag.isGroup,
      isLocked: tag.playlistMetadata?.isLocked ?? false,
      displayOrder: tag.playlistMetadata?.displayOrder ?? 0,
      hasCollectionMetadata: tag.playlistMetadata != null,
    );
  }

  // ============================================================================
  // Collection Methods (Unified Playlists/Queues) — delegated to Rust FFI
  // ============================================================================

  /// Create a new collection (tag with songs) via Rust FFI
  ///
  /// [name] - The name of the collection
  /// [parentId] - Optional parent collection ID (for nested collections)
  /// [isGroup] - If true, this collection is only visible through its parent
  /// [isQueue] - If true, this collection appears in Queue Management (not Playlists)
  Future<Tag> createCollection(
    String name, {
    String? parentId,
    bool isGroup = false,
    bool isQueue = false,
  }) async {
    final collectionType = isGroup
        ? 'group'
        : (isQueue ? 'queue' : 'playlist');

    final result = await rust_collection.createCollection(
      name: name.trim(),
      parentId: parentId,
      collectionType: collectionType,
    );

    final tag = _collectionToTag(result);
    _eventController.add(TagCreated(tag));
    return tag;
  }

  /// Legacy method - use createCollection instead
  @Deprecated('Use createCollection instead')
  Future<Tag> createPlaylist(String name, {String? parentId}) async {
    return createCollection(name, parentId: parentId);
  }

  /// Add an item to a collection via Rust FFI
  Future<void> addItemToCollection(
    String collectionId,
    PlaylistItem item,
  ) async {
    final rustItemType = item.type == PlaylistItemType.songUnit
        ? 'songUnit'
        : 'collectionReference';

    await rust_collection.addItemToCollection(
      collectionId: collectionId,
      itemType: rustItemType,
      targetId: item.targetId,
      inheritLock: item.inheritLock,
    );

    // Re-fetch the collection to emit an updated event with current state
    final result = await rust_collection.getCollection(id: collectionId);
    if (result != null) {
      final tag = _collectionToTag(result);
      _eventController.add(TagUpdated(tag));
    }
  }

  /// Legacy method - use addItemToCollection instead
  @Deprecated('Use addItemToCollection instead')
  Future<void> addItemToPlaylist(String playlistId, PlaylistItem item) async {
    return addItemToCollection(playlistId, item);
  }

  /// Remove an item from a collection via Rust FFI
  Future<void> removeItemFromCollection(
    String collectionId,
    String itemId,
  ) async {
    await rust_collection.removeItemFromCollection(
      collectionId: collectionId,
      itemId: itemId,
    );

    // Re-fetch the collection to emit an updated event with current state
    final result = await rust_collection.getCollection(id: collectionId);
    if (result != null) {
      final tag = _collectionToTag(result);
      _eventController.add(TagUpdated(tag));
    }
  }

  /// Legacy method - use removeItemFromCollection instead
  @Deprecated('Use removeItemFromCollection instead')
  Future<void> removeItemFromPlaylist(String playlistId, String itemId) async {
    return removeItemFromCollection(playlistId, itemId);
  }

  /// Reorder collection items via Rust FFI
  Future<void> reorderCollectionItems(
    String collectionId,
    List<String> itemIds,
  ) async {
    await rust_collection.reorderCollectionItems(
      collectionId: collectionId,
      itemIds: itemIds,
    );

    // Re-fetch the collection to emit an updated event with current state
    final result = await rust_collection.getCollection(id: collectionId);
    if (result != null) {
      final tag = _collectionToTag(result);
      _eventController.add(TagUpdated(tag));
    }
  }

  /// Legacy method - use reorderCollectionItems instead
  @Deprecated('Use reorderCollectionItems instead')
  Future<void> reorderPlaylistItems(
    String playlistId,
    List<String> itemIds,
  ) async {
    return reorderCollectionItems(playlistId, itemIds);
  }

  /// Set collection lock state via Rust FFI
  Future<void> setCollectionLock(String collectionId, bool isLocked) async {
    await rust_collection.setCollectionLock(
      collectionId: collectionId,
      isLocked: isLocked,
    );

    // Re-fetch the collection to emit an updated event with current state
    final result = await rust_collection.getCollection(id: collectionId);
    if (result != null) {
      final tag = _collectionToTag(result);
      _eventController.add(TagUpdated(tag));
    }
  }

  /// Toggle collection lock state via Rust FFI
  /// Returns the new lock state
  Future<bool> toggleLock(String collectionId) async {
    // Fetch current state to determine the toggle
    final result = await rust_collection.getCollection(id: collectionId);
    if (result == null) {
      throw StateError('Tag is not a collection');
    }

    final newLockState = !result.isLocked;
    await setCollectionLock(collectionId, newLockState);
    return newLockState;
  }

  /// Legacy method - use setCollectionLock instead
  @Deprecated('Use setCollectionLock instead')
  Future<void> setPlaylistLock(String playlistId, bool isLocked) async {
    return setCollectionLock(playlistId, isLocked);
  }

  // ============================================================================
  // Convenience wrapper methods matching task specification
  // ============================================================================

  /// Add an item to a collection (wrapper for addItemToCollection)
  Future<void> addToCollection(String collectionId, PlaylistItem item) async {
    return addItemToCollection(collectionId, item);
  }

  /// Remove an item from a collection (wrapper for removeItemFromCollection)
  Future<void> removeFromCollection(String collectionId, String itemId) async {
    return removeItemFromCollection(collectionId, itemId);
  }

  /// Reorder collection items (wrapper using index-based reorder)
  Future<void> reorderCollection(
    String collectionId,
    int oldIndex,
    int newIndex,
  ) async {
    // Fetch current items from Rust to perform the index-based reorder
    final items = await rust_collection.getCollectionItems(
      collectionId: collectionId,
    );

    if (oldIndex < 0 || oldIndex >= items.length) {
      throw RangeError('oldIndex out of range');
    }
    if (newIndex < 0 || newIndex >= items.length) {
      throw RangeError('newIndex out of range');
    }

    // Build the reordered ID list
    final itemIds = items.map((item) => item.id).toList();
    final movedId = itemIds.removeAt(oldIndex);
    itemIds.insert(newIndex, movedId);

    await reorderCollectionItems(collectionId, itemIds);
  }

  // ============================================================================
  // End of convenience wrapper methods
  // ============================================================================

  /// Start playing a collection via Rust FFI
  Future<void> startPlaying(
    String collectionId, {
    int startIndex = 0,
    int playbackPositionMs = 0,
  }) async {
    await rust_collection.startPlaying(
      collectionId: collectionId,
      startIndex: startIndex,
      playbackPositionMs: playbackPositionMs,
    );

    final result = await rust_collection.getCollection(id: collectionId);
    if (result != null) {
      final tag = _collectionToTag(result);
      _eventController.add(TagUpdated(tag));
    }
  }

  /// Stop playing a collection via Rust FFI
  Future<void> stopPlaying(String collectionId) async {
    await rust_collection.stopPlaying(collectionId: collectionId);

    final result = await rust_collection.getCollection(id: collectionId);
    if (result != null) {
      final tag = _collectionToTag(result);
      _eventController.add(TagUpdated(tag));
    }
  }

  /// Update playback state via Rust FFI (called frequently during playback)
  Future<void> updatePlaybackState(
    String collectionId, {
    required int currentIndex,
    required int playbackPositionMs,
    required bool wasPlaying,
  }) async {
    await rust_collection.updatePlaybackState(
      collectionId: collectionId,
      currentIndex: currentIndex,
      playbackPositionMs: playbackPositionMs,
      wasPlaying: wasPlaying,
    );

    final result = await rust_collection.getCollection(id: collectionId);
    if (result != null) {
      final tag = _collectionToTag(result);
      _eventController.add(TagUpdated(tag));
    }
  }

  /// Get a single collection as a Tag with full PlaylistMetadata (including items).
  /// Returns null if the collection does not exist.
  Future<Tag?> getCollectionTag(String collectionId) async {
    final result = await rust_collection.getCollection(id: collectionId);
    if (result == null) return null;
    return _collectionToTag(result);
  }

  /// Persist full collection metadata (items, playback state, flags) in a single write.
  /// This is the correct way to update queue/playlist metadata — unlike updateTag(),
  /// this actually persists items, currentIndex, playbackPositionMs, etc.
  Future<void> updateCollectionMetadata(
    String collectionId,
    PlaylistMetadata metadata,
  ) async {
    final rustItems = metadata.items
        .map((item) => rust_collection.DartCollectionItem(
              id: item.id,
              itemType: item.type == PlaylistItemType.songUnit
                  ? 'songUnit'
                  : 'collectionReference',
              targetId: item.targetId,
              order: item.order,
              inheritLock: item.inheritLock,
            ))
        .toList();

    await rust_collection.updateCollectionMetadata(
      collectionId: collectionId,
      items: rustItems,
      currentIndex: metadata.currentIndex,
      playbackPositionMs: metadata.playbackPositionMs,
      wasPlaying: metadata.wasPlaying,
      removeAfterPlay: metadata.removeAfterPlay,
      isLocked: metadata.isLocked,
      displayOrder: metadata.displayOrder,
      isQueue: metadata.isQueue,
    );

    // Re-fetch and emit event so listeners stay in sync
    final result = await rust_collection.getCollection(id: collectionId);
    if (result != null) {
      final tag = _collectionToTag(result);
      _eventController.add(TagUpdated(tag));
    }
  }

  /// Get collection items via Rust FFI
  Future<List<PlaylistItem>> getCollectionItems(String collectionId) async {
    final rustItems = await rust_collection.getCollectionItems(
      collectionId: collectionId,
    );

    return rustItems.map(_collectionItemToPlaylistItem).toList();
  }

  /// Legacy method - use getCollectionItems instead
  @Deprecated('Use getCollectionItems instead')
  Future<List<PlaylistItem>> getPlaylistItems(String playlistId) async {
    return getCollectionItems(playlistId);
  }

  /// Get all collections via Rust FFI
  ///
  /// [includeGroups] - If false, filters out groups (collections with isGroup = true)
  /// [includeQueues] - If false, filters out active queues (collections with currentIndex >= 0)
  Future<List<Tag>> getCollections({
    bool includeGroups = true,
    bool includeQueues = true,
  }) async {
    final rustCollections = await rust_collection.getCollections(
      
    );

    return rustCollections
        .map(_collectionToTag)
        .where((t) {
          if (!includeGroups && t.isGroup) return false;
          if (!includeQueues && t.isActiveQueue) return false;
          return true;
        })
        .toList();
  }

  /// Get all active queues (collections being played)
  Future<List<Tag>> getActiveQueues() async {
    final rustCollections = await rust_collection.getCollections(
      filterType: 'queue',
    );

    return rustCollections
        .map(_collectionToTag)
        .where((t) => t.isActiveQueue)
        .toList();
  }

  /// Get all playlists (collections not being played)
  Future<List<Tag>> getPlaylists() async {
    final rustCollections = await rust_collection.getCollections(
      filterType: 'playlist',
    );

    return rustCollections.map(_collectionToTag).toList();
  }

  /// Legacy method - use getCollections instead
  @Deprecated('Use getCollections instead')
  Future<List<Tag>> getPlaylistTags() async {
    return getCollections();
  }

  // ============================================================================
  // Collection Content Resolution — delegated to Rust FFI
  // ============================================================================

  /// Resolve collection content recursively via Rust FFI
  ///
  /// Returns a flat list of Song Unit target IDs in order.
  /// Circular references are skipped, depth is limited.
  ///
  /// [collectionId] - The collection to resolve
  /// [maxDepth] - Maximum nesting depth (default 10)
  /// [libraryRepository] - Unused (kept for API compatibility); Rust handles resolution
  Future<List<String>> resolveContent(
    String collectionId, {
    int maxDepth = 10,
    Set<String>? visited,
    dynamic libraryRepository,
  }) async {
    return rust_collection.resolveContent(
      collectionId: collectionId,
      maxDepth: BigInt.from(maxDepth),
    );
  }

  /// Check if adding a reference would create a circular reference via Rust FFI
  ///
  /// [parentId] - The collection that would contain the reference
  /// [targetId] - The collection being referenced
  ///
  /// Returns true if adding the reference would create a circular reference
  Future<bool> wouldCreateCircularReference(
    String parentId,
    String targetId,
  ) async {
    return rust_collection.wouldCreateCircularReference(
      parentId: parentId,
      targetId: targetId,
    );
  }

  // ============================================================================
  // FFI Conversion Helpers
  // ============================================================================

  /// Convert a Rust `DartCollection` to a Dart `Tag` with `PlaylistMetadata`.
  ///
  /// This bridges the Rust domain model back to the existing Dart model
  /// so that the UI layer continues to work without changes.
  Tag _collectionToTag(rust_collection.DartCollection collection) {
    // Convert DartCollectionItems to Dart PlaylistItems, sorted by order field
    final dartItems = collection.items
        .map(_collectionItemToPlaylistItem)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    // Parse timestamps — Rust stores ISO 8601 strings
    final createdAt = DateTime.tryParse(collection.createdAt) ?? DateTime.now();
    final updatedAt = DateTime.tryParse(collection.updatedAt) ?? DateTime.now();

    final playlistMetadata = PlaylistMetadata(
      isLocked: collection.isLocked,
      displayOrder: collection.displayOrder,
      items: dartItems,
      createdAt: createdAt,
      updatedAt: updatedAt,
      currentIndex: collection.currentIndex,
      playbackPositionMs: collection.playbackPositionMs,
      wasPlaying: collection.wasPlaying,
      removeAfterPlay: collection.removeAfterPlay,
      isQueue: collection.isQueue,
    );

    return Tag(
      id: collection.id,
      name: collection.name,
      type: TagType.user, // Collections are always user tags
      parentId: collection.parentId,
      aliasNames: collection.aliasNames,
      includeChildren: collection.includeChildren,
      playlistMetadata: playlistMetadata,
      isGroup: collection.isGroup,
    );
  }

  /// Convert a Rust `DartCollectionItem` to a Dart `PlaylistItem`.
  PlaylistItem _collectionItemToPlaylistItem(
    rust_collection.DartCollectionItem item,
  ) {
    final dartType = item.itemType == 'songUnit'
        ? PlaylistItemType.songUnit
        : PlaylistItemType.collectionReference;

    return PlaylistItem(
      id: item.id,
      type: dartType,
      targetId: item.targetId,
      order: item.order,
      inheritLock: item.inheritLock,
    );
  }

  /// Dispose of resources
  void dispose() {
    _eventController.close();
  }
}
