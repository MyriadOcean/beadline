import 'package:flutter/foundation.dart';
import '../../models/tag.dart';
import '../../src/rust/api/tag_api.dart' as rust_tag;
import '../../src/rust/frb_generated.dart' show RustLib;
import 'tag_view_model_base.dart';

/// Mixin handling tag CRUD operations, aliases, tag-SongUnit associations,
/// batch operations, and tag queries.
mixin TagOperationsMixin on TagViewModelBase {
  // ==========================================================================
  // Tag Loading
  // ==========================================================================

  /// Load all tags from the repository (implements base abstract method)
  Future<void> loadTagsImpl() async {
    try {
      final isInitialLoad = allTagsList.isEmpty;
      if (isInitialLoad) {
        isLoadingValue = true;
        notifyListeners();
      }
      errorValue = null;

      final pureTags = await tagRepository.getAllTags();
      final collections = await tagRepository.getCollections(
        includeGroups: true,
        includeQueues: true,
      );
      final collectionIds = {for (final c in collections) c.id};
      allTagsList = [
        ...pureTags.where((t) => !collectionIds.contains(t.id)),
        ...collections,
      ];
      recategorizeTags();

      isLoadingValue = false;
      notifyListeners();
    } catch (e) {
      errorValue = e.toString();
      isLoadingValue = false;
      notifyListeners();
    }
  }

  /// Silent version of loadTags — refreshes in-memory cache without
  /// triggering intermediate notifyListeners.
  Future<void> loadTagsSilent() async {
    final pureTags = await tagRepository.getAllTags();
    final collections = await tagRepository.getCollections(
      includeGroups: true,
      includeQueues: true,
    );
    final collectionIds = {for (final c in collections) c.id};
    allTagsList = [
      ...pureTags.where((t) => !collectionIds.contains(t.id)),
      ...collections,
    ];
    recategorizeTags();
  }

  // ==========================================================================
  // Tag CRUD
  // ==========================================================================

  /// Create a new user tag
  Future<Tag?> createTag(String name, {String? parentId}) async {
    try {
      errorValue = null;
      final tag = await tagRepository.createTag(name, parentId: parentId);
      syncCreateTagToRust(tag);
      return tag;
    } catch (e) {
      errorValue = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Rename a tag
  Future<void> renameTag(String tagId, String newName) async {
    try {
      errorValue = null;
      final tag = await tagRepository.getTag(tagId);
      if (tag == null) {
        errorValue = 'Tag not found';
        notifyListeners();
        return;
      }
      final updatedTag = tag.copyWith(name: newName);
      await tagRepository.updateTag(updatedTag);
      syncDeleteTagFromRust(tagId);
      syncCreateTagToRust(updatedTag);
    } catch (e) {
      errorValue = e.toString();
      notifyListeners();
    }
  }

  /// Delete a tag
  Future<void> deleteTag(String tagId) async {
    try {
      errorValue = null;
      await tagRepository.deleteTag(tagId);
      syncDeleteTagFromRust(tagId);
    } catch (e) {
      errorValue = e.toString();
      notifyListeners();
    }
  }

  // ==========================================================================
  // Aliases
  // ==========================================================================

  /// Add an alias for a tag
  Future<void> addAlias(String primaryTagId, String aliasName) async {
    try {
      errorValue = null;
      await tagRepository.addAlias(primaryTagId, aliasName);
      syncAddAliasToRust(primaryTagId, aliasName);
    } catch (e) {
      errorValue = e.toString();
      notifyListeners();
    }
  }

  /// Remove an alias from a tag
  Future<void> removeAlias(String primaryTagId, String aliasName) async {
    try {
      errorValue = null;
      await tagRepository.removeAlias(primaryTagId, aliasName);
      syncRemoveAliasFromRust(aliasName);
    } catch (e) {
      errorValue = e.toString();
      notifyListeners();
    }
  }

  // ==========================================================================
  // Tag-SongUnit Associations
  // ==========================================================================

  /// Add a tag to a Song Unit
  Future<void> addTagToSongUnit(String songUnitId, String tagId) async {
    try {
      errorValue = null;
      final songUnit = await libraryRepository.getSongUnit(songUnitId);
      if (songUnit == null) {
        errorValue = 'Song Unit not found';
        notifyListeners();
        return;
      }
      if (songUnit.tagIds.contains(tagId)) return;

      final updatedSongUnit = songUnit.copyWith(
        tagIds: [...songUnit.tagIds, tagId],
      );
      await libraryRepository.updateSongUnit(updatedSongUnit);
    } catch (e) {
      errorValue = e.toString();
      notifyListeners();
    }
  }

  /// Remove a tag from a Song Unit
  Future<void> removeTagFromSongUnit(String songUnitId, String tagId) async {
    try {
      errorValue = null;
      final songUnit = await libraryRepository.getSongUnit(songUnitId);
      if (songUnit == null) {
        errorValue = 'Song Unit not found';
        notifyListeners();
        return;
      }
      final updatedSongUnit = songUnit.copyWith(
        tagIds: songUnit.tagIds.where((id) => id != tagId).toList(),
      );
      await libraryRepository.updateSongUnit(updatedSongUnit);
    } catch (e) {
      errorValue = e.toString();
      notifyListeners();
    }
  }

  // ==========================================================================
  // Batch Operations
  // ==========================================================================

  /// Batch add tags to multiple Song Units (atomic operation)
  Future<void> batchAddTags(
    List<String> songUnitIds,
    List<String> tagIds,
  ) async {
    try {
      errorValue = null;
      isLoadingValue = true;
      notifyListeners();

      final updates = <Future<void>>[];
      for (final songUnitId in songUnitIds) {
        final songUnit = await libraryRepository.getSongUnit(songUnitId);
        if (songUnit == null) continue;
        final newTagIds = tagIds.where(
          (tagId) => !songUnit.tagIds.contains(tagId),
        );
        if (newTagIds.isNotEmpty) {
          final updatedSongUnit = songUnit.copyWith(
            tagIds: [...songUnit.tagIds, ...newTagIds],
          );
          updates.add(libraryRepository.updateSongUnit(updatedSongUnit));
        }
      }
      await Future.wait(updates);

      isLoadingValue = false;
      notifyListeners();
    } catch (e) {
      errorValue = e.toString();
      isLoadingValue = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Batch remove tags from multiple Song Units (atomic operation)
  Future<void> batchRemoveTags(
    List<String> songUnitIds,
    List<String> tagIds,
  ) async {
    try {
      errorValue = null;
      isLoadingValue = true;
      notifyListeners();

      final updates = <Future<void>>[];
      for (final songUnitId in songUnitIds) {
        final songUnit = await libraryRepository.getSongUnit(songUnitId);
        if (songUnit == null) continue;
        final updatedTagIds = songUnit.tagIds
            .where((tagId) => !tagIds.contains(tagId))
            .toList();
        if (updatedTagIds.length != songUnit.tagIds.length) {
          final updatedSongUnit = songUnit.copyWith(tagIds: updatedTagIds);
          updates.add(libraryRepository.updateSongUnit(updatedSongUnit));
        }
      }
      await Future.wait(updates);

      isLoadingValue = false;
      notifyListeners();
    } catch (e) {
      errorValue = e.toString();
      isLoadingValue = false;
      notifyListeners();
      rethrow;
    }
  }

  // ==========================================================================
  // Tag Queries
  // ==========================================================================

  /// Get a tag by ID (from cache)
  Tag? getTagById(String id) {
    try {
      return allTagsList.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Get a tag by ID from the repository (async, always fresh)
  Future<Tag?> getTagAsync(String id) async {
    return tagRepository.getTag(id);
  }

  /// Get a tag by name
  Tag? getTagByName(String name) {
    try {
      return allTagsList.firstWhere(
        (t) => t.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Get child tags of a parent
  List<Tag> getChildTags(String parentId) {
    return allTagsList.where((t) => t.parentId == parentId).toList();
  }

  /// Get root tags (tags without parents)
  List<Tag> getRootTags() {
    return allTagsList.where((t) => t.parentId == null).toList();
  }

  /// Get tags for the Tag Panel display (only pure user-created tags)
  List<Tag> getTagPanelTags() {
    return allTagsList
        .where(
          (tag) =>
              tag.type == TagType.user && !tag.isGroup && !tag.isCollection,
        )
        .toList();
  }

  // ==========================================================================
  // Rust FRB Sync Helpers
  // ==========================================================================

  bool get _rustAvailable {
    try {
      RustLib.instance.api;
      return true;
    } catch (_) {
      return false;
    }
  }

  @protected
  void syncCreateTagToRust(Tag tag) {
    if (tag.isCollection) return;
    if (!_rustAvailable) return;
    final String? key;
    if (tag.type == TagType.builtIn) {
      key = tag.name;
    } else {
      key = null;
    }
    rust_tag
        .createTag(key: key, value: tag.name, parentId: tag.parentId)
        .then((_) {})
        .catchError((Object e) {
      debugPrint('Rust sync: createTag failed for "${tag.name}": $e');
    });
  }

  @protected
  void syncDeleteTagFromRust(String tagId) {
    if (!_rustAvailable) return;
    rust_tag.deleteTag(id: tagId).catchError((e) {
      debugPrint('Rust sync: deleteTag failed for "$tagId": $e');
    });
  }

  @protected
  void syncAddAliasToRust(String tagId, String alias) {
    if (!_rustAvailable) return;
    rust_tag.addAlias(tagId: tagId, alias: alias).catchError((e) {
      debugPrint('Rust sync: addAlias failed for "$tagId" / "$alias": $e');
    });
  }

  @protected
  void syncRemoveAliasFromRust(String alias) {
    if (!_rustAvailable) return;
    rust_tag.removeAlias(alias: alias).catchError((e) {
      debugPrint('Rust sync: removeAlias failed for "$alias": $e');
    });
  }
}
