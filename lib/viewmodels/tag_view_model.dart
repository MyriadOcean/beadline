/// Barrel file for TagViewModel.
///
/// Re-exports all public types so existing `import 'tag_view_model.dart'`
/// statements continue to work without changes.
library;

import 'package:flutter/foundation.dart';
import '../data/playback_state_storage.dart';
import '../repositories/library_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/tag_repository.dart'
    show
        TagRepository,
        TagEvent,
        TagCreated,
        TagUpdated,
        TagDeleted,
        AliasAdded,
        AliasRemoved;

import 'tag_view_model/collection_crud_mixin.dart';
import 'tag_view_model/collection_queue_mixin.dart';
import 'tag_view_model/collection_reorder_mixin.dart';
import 'tag_view_model/collection_shuffle_mixin.dart';
import 'tag_view_model/drag_drop_mixin.dart';
import 'tag_view_model/queue_display_builder_mixin.dart';
import 'tag_view_model/queue_playback_mixin.dart';
import 'tag_view_model/queue_request_mixin.dart';
import 'tag_view_model/selection_mixin.dart';
import 'tag_view_model/tag_operations_mixin.dart';
import 'tag_view_model/tag_view_model_base.dart';

// Re-export the QueueDisplayItem model so consumers don't need a new import.
export 'tag_view_model/queue_display_item.dart';

/// Unified ViewModel for tag and collection management.
///
/// The implementation is split across mixins for maintainability:
/// - [TagOperationsMixin] — tag CRUD, aliases, batch ops, Rust sync
/// - [QueueDisplayBuilderMixin] — queue song loading, display item building
/// - [CollectionCrudMixin] — collection CRUD, add/remove items
/// - [CollectionReorderMixin] — all reorder operations
/// - [CollectionShuffleMixin] — shuffle, deduplicate, clear
/// - [CollectionQueueMixin] — add-to-queue, deep copy, dissolve/remove group
/// - [QueuePlaybackMixin] — playback mode, navigation
/// - [QueueRequestMixin] — song requests, queue switch, duplicate
/// - [DragDropMixin] — drag-drop grouping operations
/// - [SelectionMixin] — selection state and bulk moves
class TagViewModel extends TagViewModelBase
    with
        TagOperationsMixin,
        QueueDisplayBuilderMixin,
        CollectionCrudMixin,
        CollectionReorderMixin,
        CollectionShuffleMixin,
        CollectionQueueMixin,
        QueueRequestMixin,
        QueuePlaybackMixin,
        DragDropMixin,
        SelectionMixin {
  TagViewModel({
    required TagRepository tagRepository,
    required LibraryRepository libraryRepository,
    required SettingsRepository settingsRepository,
    required PlaybackStateStorage playbackStateStorage,
  }) : super(
          tagRepository: tagRepository,
          libraryRepository: libraryRepository,
          settingsRepository: settingsRepository,
          playbackStateStorage: playbackStateStorage,
        ) {
    _setupListeners();
    _loadActiveQueue();
  }

  void _setupListeners() {
    eventSubscription = tagRepository.events.listen(
      _onTagEvent,
      onError: _onTagError,
    );
    librarySubscription = libraryRepository.events.listen(
      _onLibraryEvent,
      onError: _onLibraryError,
    );
  }

  Future<void> _loadActiveQueue() async {
    await reloadActiveQueue();
  }

  // ==========================================================================
  // Implement abstract methods from base
  // ==========================================================================

  @override
  Future<void> loadTags() => loadTagsImpl();

  @override
  Future<void> loadCurrentQueueSongs() => loadCurrentQueueSongsImpl();

  // ==========================================================================
  // Event Handlers
  // ==========================================================================

  void _onTagEvent(TagEvent event) {
    if (suppressEvents) return;
    debugPrint('TagViewModel._onTagEvent: $event');
    switch (event) {
      case TagCreated(tag: final tag):
        debugPrint('Tag created: ${tag.id} ${tag.name}');
        allTagsList = [...allTagsList, tag];
        categorizeTag(tag);
        notifyListeners();
      case TagUpdated(tag: final tag):
        debugPrint('Tag updated: ${tag.id} ${tag.name}');
        final index = allTagsList.indexWhere((t) => t.id == tag.id);
        if (index != -1) {
          allTagsList = [
            ...allTagsList.sublist(0, index),
            tag,
            ...allTagsList.sublist(index + 1),
          ];
          recategorizeTags();
          notifyListeners();
        }
      case TagDeleted(tagId: final id):
        debugPrint('Tag deleted: $id');
        allTagsList = allTagsList.where((t) => t.id != id).toList();
        recategorizeTags();
        notifyListeners();
      case AliasAdded():
        debugPrint('AliasAdded event');
        loadTags();
      case AliasRemoved():
        debugPrint('AliasRemoved event');
        loadTags();
    }
  }

  void _onLibraryError(Object error) {
    errorValue = error.toString();
    notifyListeners();
  }

  void _onTagError(Object error) {
    errorValue = error.toString();
    notifyListeners();
  }

  void _onLibraryEvent(LibraryEvent event) async {
    switch (event) {
      case SongUnitUpdated(songUnit: final songUnit):
        final index =
            currentQueueSongsList.indexWhere((s) => s.id == songUnit.id);
        if (index != -1) {
          currentQueueSongsList = [
            ...currentQueueSongsList.sublist(0, index),
            songUnit,
            ...currentQueueSongsList.sublist(index + 1),
          ];
          updateDisplayItemsForSongUnit(songUnit);
          notifyListeners();
        }
      case SongUnitDeleted(songUnitId: final id):
        final index = currentQueueSongsList.indexWhere((s) => s.id == id);
        if (index != -1) {
          currentQueueSongsList =
              currentQueueSongsList.where((s) => s.id != id).toList();

          final aq = await getActiveQueue();
          if (aq?.playlistMetadata != null) {
            final metadata = aq!.playlistMetadata!;
            var newIndex = metadata.currentIndex;
            if (index < newIndex) {
              newIndex--;
            } else if (index == newIndex) {
              if (newIndex >= currentQueueSongsList.length) {
                newIndex = currentQueueSongsList.length - 1;
              }
            }

            final updatedItems = metadata.items
                .where((item) => item.targetId != id)
                .toList();

            await updateActiveQueue(
              metadata.copyWith(items: updatedItems, currentIndex: newIndex),
            );
          }
          notifyListeners();
        }
      case SongUnitAdded():
        break;
      case SongUnitMoved(songUnit: final songUnit):
        final index =
            currentQueueSongsList.indexWhere((s) => s.id == songUnit.id);
        if (index != -1) {
          currentQueueSongsList = [
            ...currentQueueSongsList.sublist(0, index),
            songUnit,
            ...currentQueueSongsList.sublist(index + 1),
          ];
          updateDisplayItemsForSongUnit(songUnit);
          notifyListeners();
        }
    }
  }
}
