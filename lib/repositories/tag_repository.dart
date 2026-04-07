import 'dart:async';

import '../models/tag_extensions.dart';
import '../src/rust/api/collection_api.dart' as rust_collection;
import '../src/rust/api/tag_api.dart' as rust_tag;

/// Events emitted by the TagRepository.
/// These exist because Rust FFI is request/response — it can't push
/// notifications to Dart. The repository wraps FFI calls and emits events
/// so viewmodels can react to changes.
sealed class TagEvent {
  const TagEvent();
}

class TagCreated extends TagEvent {
  const TagCreated(this.tag);
  final Tag tag;
}

class TagUpdated extends TagEvent {
  const TagUpdated(this.tag);
  final Tag tag;
}

class TagDeleted extends TagEvent {
  const TagDeleted(this.tagId);
  final String tagId;
}

class AliasAdded extends TagEvent {
  const AliasAdded(this.aliasName, this.primaryTagId);
  final String aliasName;
  final String primaryTagId;
}

class AliasRemoved extends TagEvent {
  const AliasRemoved(this.aliasName, this.primaryTagId);
  final String aliasName;
  final String primaryTagId;
}

class BuiltInTags {
  static const String name = 'name';
  static const String artist = 'artist';
  static const String album = 'album';
  static const String time = 'time';
  static const String duration = 'duration';
  static const String user = 'user';
  static const List<String> all = [name, artist, album, time, duration, user];
}

/// Thin wrapper around Rust FFI that adds an event stream.
///
/// All validation (name rules, duplicates, built-in protection, hierarchy)
/// is handled by Rust. If Rust rejects an operation, it returns an error
/// string which callers handle. This class only:
/// - Delegates to FFI
/// - Emits events so viewmodels stay in sync
/// - Provides convenience queries (filtering, etc.)
class TagRepository {
  TagRepository();

  final StreamController<TagEvent> _eventController =
      StreamController<TagEvent>.broadcast(sync: true);

  Stream<TagEvent> get events => _eventController.stream;

  // ==========================================================================
  // Tag CRUD — all validation is in Rust
  // ==========================================================================

  Future<void> initializeBuiltInTags() async {
    for (final tagName in BuiltInTags.all) {
      final existing = await rust_tag.resolveTag(nameOrAlias: tagName);
      if (existing == null) {
        await rust_tag.createTag(key: tagName, value: tagName);
      }
    }
  }

  Future<Tag?> getTag(String id) => rust_tag.getTag(id: id);
  Future<Tag?> getTagByName(String name) => rust_tag.resolveTag(nameOrAlias: name);
  Future<Tag?> getTagByNameOrAlias(String nameOrAlias) => rust_tag.resolveTag(nameOrAlias: nameOrAlias);
  Future<Tag?> resolveAlias(String aliasName) => rust_tag.resolveTag(nameOrAlias: aliasName);

  /// Create a user tag. Rust handles name validation, duplicates, and hierarchy (a/b/c paths).
  Future<Tag> createTag(String name, {String? parentId}) async {
    final tag = await rust_tag.createTag(value: name.trim(), parentId: parentId);
    _eventController.add(TagCreated(tag));
    return tag;
  }

  /// Create an automatic tag (e.g. user:xx, playlist:xx). Returns existing if found.
  Future<Tag> createAutomaticTag(String name, {String? parentId}) async {
    final existing = await rust_tag.resolveTag(nameOrAlias: name);
    if (existing != null) return existing;
    final tag = await rust_tag.createTag(value: name, parentId: parentId);
    _eventController.add(TagCreated(tag));
    return tag;
  }

  /// Delete a tag. Rust rejects deletion of built-in tags.
  Future<void> deleteTag(String id) async {
    await rust_tag.deleteTag(id: id);
    _eventController.add(TagDeleted(id));
  }

  Future<Tag> updateTag(Tag tag) async {
    final updated = await rust_tag.updateTag(tag: tag);
    _eventController.add(TagUpdated(updated));
    return updated;
  }

  Future<void> addAlias(String primaryTagId, String aliasName) async {
    await rust_tag.addAlias(tagId: primaryTagId, alias: aliasName);
    _eventController.add(AliasAdded(aliasName, primaryTagId));
  }

  Future<void> removeAlias(String primaryTagId, String aliasName) async {
    await rust_tag.removeAlias(alias: aliasName);
    _eventController.add(AliasRemoved(aliasName, primaryTagId));
  }

  Future<List<Tag>> getBuiltInTags() => rust_tag.getTagsByType(tagType: 'builtIn');
  Future<List<Tag>> getUserTags() => rust_tag.getTagsByType(tagType: 'user');
  Future<List<Tag>> getAutomaticTags() => rust_tag.getTagsByType(tagType: 'automatic');
  Future<List<Tag>> getAllTags() => rust_tag.getAllTags();
  Future<String> getTagPath(String tagId) => rust_tag.getTagPath(tagId: tagId);
  Future<List<Tag>> getChildTags(String parentId) => rust_tag.getChildren(parentId: parentId);
  Future<List<Tag>> getDescendants(String tagId) => rust_tag.getDescendants(tagId: tagId);

  Future<void> updateIncludeChildren(String tagId, bool includeChildren) async {
    final tag = await getTag(tagId);
    if (tag == null) return;
    final updated = await rust_tag.updateTag(tag: tag.copyWith(includeChildren: includeChildren));
    _eventController.add(TagUpdated(updated));
  }

  // ==========================================================================
  // Collection operations
  // ==========================================================================

  Future<Tag> createCollection(String name, {String? parentId, bool isGroup = false, bool isQueue = false}) async {
    final ct = isGroup ? 'group' : (isQueue ? 'queue' : 'playlist');
    final tag = await rust_collection.createCollection(name: name.trim(), parentId: parentId, collectionType: ct);
    _eventController.add(TagCreated(tag));
    return tag;
  }

  Future<void> addItemToCollection(String collectionId, TagItem item) async {
    await rust_collection.addItemToCollection(
      collectionId: collectionId, itemType: item.itemType, targetId: item.targetId, inheritLock: item.inheritLock,
    );
    await _emitCollectionUpdate(collectionId);
  }

  Future<void> removeItemFromCollection(String collectionId, String itemId) async {
    await rust_collection.removeItemFromCollection(collectionId: collectionId, itemId: itemId);
    await _emitCollectionUpdate(collectionId);
  }

  Future<void> reorderCollectionItems(String collectionId, List<String> itemIds) async {
    await rust_collection.reorderCollectionItems(collectionId: collectionId, itemIds: itemIds);
    await _emitCollectionUpdate(collectionId);
  }

  Future<void> setCollectionLock(String collectionId, bool isLocked) async {
    await rust_collection.setCollectionLock(collectionId: collectionId, isLocked: isLocked);
    await _emitCollectionUpdate(collectionId);
  }

  Future<bool> toggleLock(String collectionId) async {
    final tag = await rust_collection.getCollection(id: collectionId);
    if (tag == null) throw StateError('Tag is not a collection');
    final newState = !tag.isLocked;
    await setCollectionLock(collectionId, newState);
    return newState;
  }

  Future<void> addToCollection(String collectionId, TagItem item) => addItemToCollection(collectionId, item);
  Future<void> removeFromCollection(String collectionId, String itemId) => removeItemFromCollection(collectionId, itemId);

  Future<void> reorderCollection(String collectionId, int oldIndex, int newIndex) async {
    final items = await rust_collection.getCollectionItems(collectionId: collectionId);
    if (oldIndex < 0 || oldIndex >= items.length) throw RangeError('oldIndex out of range');
    if (newIndex < 0 || newIndex >= items.length) throw RangeError('newIndex out of range');
    final ids = items.map((i) => i.id).toList();
    final moved = ids.removeAt(oldIndex);
    ids.insert(newIndex, moved);
    await reorderCollectionItems(collectionId, ids);
  }

  Future<void> startPlaying(String collectionId, {int startIndex = 0, int playbackPositionMs = 0}) async {
    await rust_collection.startPlaying(collectionId: collectionId, startIndex: startIndex, playbackPositionMs: playbackPositionMs);
    await _emitCollectionUpdate(collectionId);
  }

  Future<void> stopPlaying(String collectionId) async {
    await rust_collection.stopPlaying(collectionId: collectionId);
    await _emitCollectionUpdate(collectionId);
  }

  Future<void> updatePlaybackState(String collectionId, {required int currentIndex, required int playbackPositionMs, required bool wasPlaying}) async {
    await rust_collection.updatePlaybackState(collectionId: collectionId, currentIndex: currentIndex, playbackPositionMs: playbackPositionMs, wasPlaying: wasPlaying);
    await _emitCollectionUpdate(collectionId);
  }

  Future<Tag?> getCollectionTag(String collectionId) => rust_collection.getCollection(id: collectionId);

  Future<void> updateCollectionMetadata(String collectionId, TagMetadata metadata) async {
    await rust_collection.updateCollectionMetadata(collectionId: collectionId, metadata: metadata);
    await _emitCollectionUpdate(collectionId);
  }

  Future<List<TagItem>> getCollectionItems(String collectionId) =>
      rust_collection.getCollectionItems(collectionId: collectionId);

  /// Get collections with optional filtering.
  Future<List<Tag>> getCollections({bool includeGroups = true, bool includeQueues = true}) async {
    final tags = await rust_collection.getCollections();
    return tags.where((t) {
      if (!includeGroups && t.isGroup) return false;
      if (!includeQueues && t.isActiveQueue) return false;
      return true;
    }).toList();
  }

  Future<List<Tag>> getActiveQueues() async {
    final tags = await rust_collection.getCollections(filterType: 'queue');
    return tags.where((t) => t.isActiveQueue).toList();
  }

  Future<List<Tag>> getPlaylists() => rust_collection.getCollections(filterType: 'playlist');

  Future<List<String>> resolveContent(String collectionId, {int maxDepth = 10, Set<String>? visited, dynamic libraryRepository}) =>
      rust_collection.resolveContent(collectionId: collectionId, maxDepth: BigInt.from(maxDepth));

  Future<bool> wouldCreateCircularReference(String parentId, String targetId) =>
      rust_collection.wouldCreateCircularReference(parentId: parentId, targetId: targetId);

  /// Deep-copy all items from source into target, recursively. Returns song count.
  Future<int> deepCopyCollection(String sourceId, String targetId, {int maxDepth = 10}) async {
    final count = await rust_collection.deepCopyCollection(sourceId: sourceId, targetId: targetId, maxDepth: BigInt.from(maxDepth));
    await _emitCollectionUpdate(targetId);
    return count;
  }

  /// Remove duplicate song entries, keeping first occurrence. Returns removed count.
  Future<int> deduplicateCollection(String collectionId) async {
    final count = await rust_collection.deduplicateCollection(collectionId: collectionId);
    if (count > 0) await _emitCollectionUpdate(collectionId);
    return count;
  }

  /// Shuffle items. Locked groups stay together. Current song moves to front.
  Future<void> shuffleCollection(String collectionId, {String? currentSongId}) async {
    await rust_collection.shuffleCollection(collectionId: collectionId, currentSongId: currentSongId);
    await _emitCollectionUpdate(collectionId);
  }

  // ==========================================================================
  // Deprecated aliases
  // ==========================================================================

  @Deprecated('Use createCollection') Future<Tag> createPlaylist(String name, {String? parentId}) => createCollection(name, parentId: parentId);
  @Deprecated('Use addItemToCollection') Future<void> addItemToPlaylist(String id, TagItem item) => addItemToCollection(id, item);
  @Deprecated('Use removeItemFromCollection') Future<void> removeItemFromPlaylist(String id, String itemId) => removeItemFromCollection(id, itemId);
  @Deprecated('Use reorderCollectionItems') Future<void> reorderPlaylistItems(String id, List<String> ids) => reorderCollectionItems(id, ids);
  @Deprecated('Use setCollectionLock') Future<void> setPlaylistLock(String id, bool locked) => setCollectionLock(id, locked);
  @Deprecated('Use getCollectionItems') Future<List<TagItem>> getPlaylistItems(String id) => getCollectionItems(id);
  @Deprecated('Use getCollections') Future<List<Tag>> getPlaylistTags() => getCollections();

  // ==========================================================================
  // Internal
  // ==========================================================================

  Future<void> _emitCollectionUpdate(String collectionId) async {
    final tag = await rust_collection.getCollection(id: collectionId);
    if (tag != null) _eventController.add(TagUpdated(tag));
  }

  void dispose() => _eventController.close();
}
