import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../i18n/translations.g.dart';

import '../models/tag_extensions.dart';
import '../viewmodels/library_view_model.dart';
import '../viewmodels/tag_view_model.dart';
import 'song_picker_dialog.dart';
import 'widgets/bulk_action_toolbar.dart';
import 'widgets/cached_thumbnail.dart';
import 'widgets/collection/collection_list_view.dart';
import 'widgets/group_picker_dialog.dart';

/// Playlists management page with unified tag-based collection system.
/// Uses TagViewModel for all operations (no PlaylistViewModel dependency).
/// Supports nested groups, references, lock/unlock, and expand/collapse.
class PlaylistsManagementPage extends StatefulWidget {
  const PlaylistsManagementPage({super.key});

  @override
  State<PlaylistsManagementPage> createState() =>
      PlaylistsManagementPageState();
}

class PlaylistsManagementPageState extends State<PlaylistsManagementPage> {
  String? _selectedPlaylistId;
  bool _menuOpen = false;

  // Long-press detection for left panel
  Timer? _longPressTimer;
  Offset? _longPressPos;

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final showBackButton = isMobile && _selectedPlaylistId != null;

    return Scaffold(
      appBar: AppBar(
        leading: showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _selectedPlaylistId = null),
              )
            : null,
        title: Text(context.t.playlists.title),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Consumer<TagViewModel>(
      builder: (context, tagViewModel, child) {
        if (tagViewModel.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        // Filter: show only collections that are NOT groups
        // Groups are only visible within their parent collection
        final playlistTags = tagViewModel.allTags
            .where((t) => t.isCollection && !t.isGroup && !t.isQueueCollection)
            .toList();

        if (playlistTags.isEmpty && _selectedPlaylistId == null) {
          return _buildEmptyState(context);
        }

        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 600;

        if (isMobile) {
          return _selectedPlaylistId != null
              ? _buildPlaylistContent(context, _selectedPlaylistId!)
              : _buildPlaylistList(context, playlistTags);
        }

        return Row(
          children: [
            SizedBox(
              width: 280,
              child: _buildPlaylistList(context, playlistTags),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: _selectedPlaylistId != null
                  ? _buildPlaylistContent(context, _selectedPlaylistId!)
                  : _buildSelectPlaylistPrompt(context),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPlaylistList(BuildContext context, List<Tag> playlistTags) {
    final theme = Theme.of(context);

    // Sort playlists by displayOrder
    final sorted = List<Tag>.from(playlistTags)
      ..sort(
        (a, b) => (a.metadata?.displayOrder ?? 0).compareTo(
          b.metadata?.displayOrder ?? 0,
        ),
      );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '${sorted.length} ${context.t.common.songs}',
            style: theme.textTheme.titleSmall,
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (e) {
              if (e.buttons == kSecondaryMouseButton && !_menuOpen) {
                _menuOpen = true;
                _showPlaylistListContextMenu(context, e.position).whenComplete(() {
                  _menuOpen = false;
                });
              } else if (e.buttons == kPrimaryMouseButton || e.buttons == 0) {
                _longPressPos = e.position;
                _longPressTimer?.cancel();
                _longPressTimer = Timer(const Duration(milliseconds: 500), () {
                  if (!_menuOpen && _longPressPos != null) {
                    _menuOpen = true;
                    _showPlaylistListContextMenu(context, _longPressPos!).whenComplete(() {
                      _menuOpen = false;
                    });
                  }
                });
              }
            },
            onPointerUp: (_) {
              _longPressTimer?.cancel();
              _longPressTimer = null;
              _longPressPos = null;
            },
            onPointerCancel: (_) {
              _longPressTimer?.cancel();
              _longPressTimer = null;
              _longPressPos = null;
            },
            onPointerMove: (e) {
              if (_longPressPos != null &&
                  (e.position - _longPressPos!).distance > 10) {
                _longPressTimer?.cancel();
                _longPressTimer = null;
                _longPressPos = null;
              }
            },
            child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            itemCount: sorted.length,
            onReorder: (oldIndex, newIndex) async {
              if (newIndex > oldIndex) newIndex--;
              if (oldIndex == newIndex) return;
              final reordered = List<Tag>.from(sorted);
              final moved = reordered.removeAt(oldIndex);
              reordered.insert(newIndex, moved);
              final tagVM = context.read<TagViewModel>();
              await tagVM.reorderPlaylists(reordered.map((t) => t.id).toList());
            },
            itemBuilder: (context, index) {
              final tag = sorted[index];
              final isSelected = tag.id == _selectedPlaylistId;
              final metadata = tag.metadata;
              final isLocked = metadata?.isLocked ?? false;
              final capturedTag = tag;

              return Listener(
                key: ValueKey('playlist_${tag.id}'),
                behavior: HitTestBehavior.translucent,
                onPointerDown: (e) {
                  if (e.buttons == kSecondaryMouseButton && !_menuOpen) {
                    _menuOpen = true;
                    _showPlaylistItemContextMenu(context, e.position, capturedTag).whenComplete(() {
                      _menuOpen = false;
                    });
                  } else if (e.buttons == kPrimaryMouseButton || e.buttons == 0) {
                    _longPressPos = e.position;
                    _longPressTimer?.cancel();
                    _longPressTimer = Timer(const Duration(milliseconds: 500), () {
                      if (!_menuOpen && _longPressPos != null) {
                        _menuOpen = true;
                        _showPlaylistItemContextMenu(context, _longPressPos!, capturedTag).whenComplete(() {
                          _menuOpen = false;
                        });
                      }
                    });
                  }
                },
                onPointerUp: (_) {
                  _longPressTimer?.cancel();
                  _longPressTimer = null;
                  _longPressPos = null;
                },
                onPointerCancel: (_) {
                  _longPressTimer?.cancel();
                  _longPressTimer = null;
                  _longPressPos = null;
                },
                onPointerMove: (e) {
                  if (_longPressPos != null &&
                      (e.position - _longPressPos!).distance > 10) {
                    _longPressTimer?.cancel();
                    _longPressTimer = null;
                    _longPressPos = null;
                  }
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _selectedPlaylistId = tag.id),
                  child: ReorderableDragStartListener(
                    index: index,
                    child: ListTile(
                      leading: Icon(
                        isLocked ? Icons.lock : Icons.playlist_play,
                        color: isLocked ? theme.colorScheme.secondary : null,
                      ),
                      title: Text(tag.name),
                      subtitle: Text('${_countSongUnits(metadata)} ${context.t.common.songs}'),
                      selected: isSelected,
                      selectedTileColor: theme.colorScheme.primaryContainer
                          .withValues(alpha: 0.3),
                      trailing: PopupMenuButton<String>(
                        onSelected: (action) =>
                            _handlePlaylistAction(context, tag, action),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'lock',
                            child: ListTile(
                              leading: Icon(
                                isLocked ? Icons.lock_open : Icons.lock,
                              ),
                              title: Text(isLocked ? context.t.playlists.unlock : context.t.playlists.lock),
                              dense: true,
                            ),
                          ),
                          PopupMenuItem(
                            value: 'rename',
                            child: ListTile(
                              leading: const Icon(Icons.edit),
                              title: Text(context.t.common.rename),
                              dense: true,
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: ListTile(
                              leading: const Icon(Icons.delete, color: Colors.red),
                              title: Text(
                                context.t.common.delete,
                                style: const TextStyle(color: Colors.red),
                              ),
                              dense: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),        // closes ReorderableListView.builder
        ),          // closes Listener (outer)
        ),          // closes Expanded
      ],
    );
  }

  Widget _buildPlaylistContent(BuildContext context, String playlistTagId) {
    return Consumer<TagViewModel>(
      builder: (context, tagViewModel, child) {
        final tag = tagViewModel.getTagById(playlistTagId);
        if (tag == null || !tag.isCollection) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(context.t.common.error),
                const SizedBox(height: 8),
                Text('id: $playlistTagId'),
              ],
            ),
          );
        }

        final metadata = tag.metadata;
        final items = metadata?.items ?? [];
        final hasSelection = tagViewModel.hasSelection;

        return Column(
          children: [
            if (hasSelection)
              BulkActionToolbar(
                selectionCount: tagViewModel.selectionCount,
                onMoveToGroup: () => _showBulkMoveGroupPicker(
                  context,
                  playlistTagId,
                  tagViewModel,
                ),
                onRemoveFromGroup: () =>
                    _bulkRemoveFromGroup(context, playlistTagId, tagViewModel),
                onClearSelection: () => tagViewModel.clearSelection(),
              )
            else
              _buildPlaylistHeader(context, tag, items),
            const Divider(height: 1),
            Expanded(
              child: items.isEmpty
                  ? _buildEmptyPlaylistContent(context)
                  : FutureBuilder<List<QueueDisplayItem>>(
                      future: tagViewModel.buildDisplayItemsForCollection(playlistTagId),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final displayItems = snapshot.data!;
                        if (displayItems.isEmpty) {
                          return _buildEmptyPlaylistContent(context);
                        }
                        final libraryVM = context.read<LibraryViewModel>();
                        return CollectionListView(
                          collectionId: playlistTagId,
                          displayItems: displayItems,
                          tagViewModel: tagViewModel,
                          resolveSongUnit: (id) => libraryVM.songUnits
                              .where((s) => s.id == id)
                              .firstOrNull,
                          config: CollectionListConfig(
                            showIndex: true,
                            showCheckbox: hasSelection,
                            showRemoveButton: !hasSelection,
                            draggableSongs: !hasSelection,
                            isSelected: (itemId) => tagViewModel.isSelected(itemId),
                            onToggleSelect: (itemId) => tagViewModel.toggleSelection(itemId),
                            onSongTap: (song, _) => _playSong(context, song.id),
                            onSongRemove: (songUnitId, groupId) {
                              if (groupId != null) {
                                // Find the PlaylistItem ID within the group's metadata
                                final groupTag = tagViewModel.getTagById(groupId);
                                final groupItems = groupTag?.metadata?.items ?? [];
                                final item = groupItems
                                    .where((i) => i.itemType == TagItemType.songUnit && i.targetId == songUnitId)
                                    .firstOrNull;
                                if (item != null) {
                                  tagViewModel.removeFromCollection(groupId, item.id);
                                }
                              } else {
                                // Find the PlaylistItem ID for this song at root level
                                final item = items
                                    .where((i) => i.itemType == TagItemType.songUnit && i.targetId == songUnitId)
                                    .firstOrNull;
                                if (item != null) {
                                  _removeItem(context, playlistTagId, item.id);
                                }
                              }
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  /// Show group picker dialog for bulk move in playlist
  Future<void> _showBulkMoveGroupPicker(
    BuildContext context,
    String playlistTagId,
    TagViewModel tagViewModel,
  ) async {
    final tag = tagViewModel.getTagById(playlistTagId);
    if (tag == null) return;

    // Collect groups from the playlist's items
    final groups = <Tag>[];
    for (final item in tag.metadata?.items ?? []) {
      if (item.itemType == TagItemType.tagReference) {
        final refTag = tagViewModel.getTagById(item.targetId);
        if (refTag != null && refTag.isGroup) {
          groups.add(refTag);
        }
      }
    }

    final selectedGroupId = await showDialog<String>(
      context: context,
      builder: (_) => GroupPickerDialog(groups: groups),
    );

    if (selectedGroupId != null && context.mounted) {
      await tagViewModel.bulkMoveToGroup(playlistTagId, selectedGroupId);
      // Event system will handle UI update
    }
  }

  /// Bulk remove selected items from their groups in playlist
  Future<void> _bulkRemoveFromGroup(
    BuildContext context,
    String playlistTagId,
    TagViewModel tagViewModel,
  ) async {
    await tagViewModel.bulkRemoveFromGroup(playlistTagId);
    // Event system will handle UI update
  }

  Widget _buildPlaylistHeader(
    BuildContext context,
    Tag tag,
    List<TagItem> items,
  ) {
    final theme = Theme.of(context);
    final metadata = tag.metadata;
    final isLocked = metadata?.isLocked ?? false;
    final tagViewModel = context.read<TagViewModel>();

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isLocked ? Icons.lock : Icons.playlist_play,
                size: 48,
                color: isLocked
                    ? theme.colorScheme.secondary
                    : theme.colorScheme.primary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tag.name,
                            style: theme.textTheme.headlineSmall,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.checklist),
                          onPressed: () {
                            if (tagViewModel.hasSelection) {
                              tagViewModel.clearSelection();
                            } else {
                              // Enter selection mode (select nothing yet, but mode is active)
                              tagViewModel.enterSelectionMode();
                            }
                          },
                          tooltip: context.t.playlists.toggleSelectionMode,
                          color: tagViewModel.hasSelection
                              ? theme.colorScheme.primary
                              : null,
                        ),
                        IconButton(
                          icon: Icon(isLocked ? Icons.lock : Icons.lock_open),
                          onPressed: () => _toggleLock(context, tag.id),
                          tooltip: isLocked
                              ? context.t.playlists.unlock
                              : context.t.playlists.lock,
                          color: isLocked ? theme.colorScheme.secondary : null,
                        ),
                      ],
                    ),
                    Text(
                      '${_countSongUnitsRecursive(items, <String>{})} ${context.t.common.songs}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (isLocked)
                      Text(
                        context.t.playlists.lock,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: items.isNotEmpty
                ? () => _addPlaylistToQueue(context, tag.id)
                : null,
            icon: const Icon(Icons.queue),
            label: Text(context.t.library.actions.addToQueue),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Empty states
  // ===========================================================================

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapUp: (details) {
        _showPlaylistListContextMenu(context, details.globalPosition);
      },
      onLongPressStart: (details) {
        _showPlaylistListContextMenu(context, details.globalPosition);
      },
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.playlist_play,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              context.t.playlists.noPlaylists,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              context.t.playlists.noPlaylistsHint,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectPlaylistPrompt(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.touch_app,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            context.t.playlists.selectPlaylist,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPlaylistContent(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapUp: (details) {
        if (_selectedPlaylistId != null) {
          _showPlaylistContentContextMenu(
            context,
            details.globalPosition,
            _selectedPlaylistId!,
          );
        }
      },
      onLongPressStart: (details) {
        if (_selectedPlaylistId != null) {
          _showPlaylistContentContextMenu(
            context,
            details.globalPosition,
            _selectedPlaylistId!,
          );
        }
      },
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_off,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              context.t.playlists.noPlaylists,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              context.t.playlists.noPlaylistsHint,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  /// Context menu for the playlist list panel (create new playlist)
  Future<void> _showPlaylistListContextMenu(BuildContext context, Offset position) {
    return showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        PopupMenuItem(
          value: 'create_playlist',
          child: ListTile(
            leading: const Icon(Icons.add),
            title: Text(context.t.playlists.createPlaylist),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    ).then((value) {
      if (value == null || !context.mounted) return;
      if (value == 'create_playlist') {
        _showCreatePlaylistDialog(context);
      }
    });
  }

  /// Context menu for individual playlist items in the list
  Future<void> _showPlaylistItemContextMenu(BuildContext context, Offset position, Tag tag) {
    final metadata = tag.metadata;
    final isLocked = metadata?.isLocked ?? false;
    
    return showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        PopupMenuItem(
          value: 'lock',
          child: ListTile(
            leading: Icon(
              isLocked ? Icons.lock_open : Icons.lock,
            ),
            title: Text(isLocked ? context.t.playlists.unlock : context.t.playlists.lock),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'rename',
          child: ListTile(
            leading: const Icon(Icons.edit),
            title: Text(context.t.common.rename),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: Text(
              context.t.common.delete,
              style: const TextStyle(color: Colors.red),
            ),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    ).then((value) {
      if (value == null || !context.mounted) return;
      _handlePlaylistAction(context, tag, value);
    });
  }

  /// Context menu for playlist content area (used by empty state and content list)
  void _showPlaylistContentContextMenu(
    BuildContext context,
    Offset position,
    String playlistId,
  ) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        PopupMenuItem(
          value: 'add_songs',
          child: ListTile(
            leading: const Icon(Icons.music_note),
            title: Text(context.t.playlists.addSongs),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'create_group',
          child: ListTile(
            leading: const Icon(Icons.folder),
            title: Text(context.t.playlists.createGroup),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'add_reference',
          child: ListTile(
            leading: const Icon(Icons.link),
            title: Text(context.t.playlists.addCollectionRef),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    ).then((value) {
      if (value == null || !context.mounted) return;
      switch (value) {
        case 'add_songs':
          showAddSongsDialog(context, playlistId);
          break;
        case 'create_group':
          showCreateGroupDialog(context, playlistId);
          break;
        case 'add_reference':
          showAddCollectionReferenceDialog(context, playlistId);
          break;
      }
    });
  }

  // ===========================================================================
  // Dialogs
  // ===========================================================================

  void _showCreatePlaylistDialog(BuildContext context) {
    final nameController = TextEditingController();
    final tagViewModel = context.read<TagViewModel>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t.playlists.createPlaylist),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: context.t.playlists.title,
            hintText: context.t.playlists.createPlaylist,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.t.common.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                await tagViewModel.createCollection(name);
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              }
            },
            child: Text(context.t.common.create),
          ),
        ],
      ),
    );
  }

  void showAddSongsDialog(BuildContext context, String playlistId) async {
    final tagViewModel = context.read<TagViewModel>();

    // Get current playlist to find its items
    final currentPlaylist = tagViewModel.allTags
        .where((t) => t.id == playlistId && t.isCollection)
        .firstOrNull;

    // Get current playlist items to exclude them from selection
    final currentItems = currentPlaylist?.metadata?.items ?? [];
    final excludeSongIds = currentItems
        .where((item) => item.itemType == TagItemType.songUnit)
        .map((item) => item.targetId)
        .toList();

    final selectedSongIds = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) =>
          SongPickerDialog(excludeSongIds: excludeSongIds),
    );

    if (selectedSongIds != null &&
        selectedSongIds.isNotEmpty &&
        context.mounted) {
      for (final songId in selectedSongIds) {
        await tagViewModel.addSongUnitToCollection(playlistId, songId);
      }

      // The TagUpdated event will trigger Consumer rebuild automatically
      // No need to manually manage loading state

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${context.t.queue.songs.replaceAll('{count}', '${selectedSongIds.length}')} â†?${context.t.playlists.title}',
            ),
          ),
        );
      }
    }
  }

  void showCreateGroupDialog(BuildContext context, String playlistId) {
    final nameController = TextEditingController();
    final tagViewModel = context.read<TagViewModel>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t.playlists.createGroupTitle),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: context.t.playlists.groupName,
            hintText: context.t.playlists.enterGroupName,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.t.common.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                final group = await tagViewModel.createCollection(
                  name,
                  parentId: playlistId,
                  isGroup: true,
                );
                await tagViewModel.addCollectionReference(playlistId, group.id);
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              }
            },
            child: Text(context.t.common.create),
          ),
        ],
      ),
    );
  }

  void showAddCollectionReferenceDialog(
    BuildContext context,
    String playlistId,
  ) {
    final tagViewModel = context.read<TagViewModel>();

    final availableCollections = tagViewModel.allTags
        .where((t) => t.isCollection && !t.isGroup && !t.isQueueCollection && t.id != playlistId)
        .toList();

    if (availableCollections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t.playlists.noOtherCollections)),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t.playlists.addCollectionRefTitle),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableCollections.length,
            itemBuilder: (context, index) {
              final collection = availableCollections[index];
              return ListTile(
                leading: const Icon(Icons.playlist_play),
                title: Text(collection.name),
                subtitle: Text(
                  '${collection.metadata?.items.length ?? 0} ${context.t.common.items}',
                ),
                onTap: () async {
                  await tagViewModel.addCollectionReference(
                    playlistId,
                    collection.id,
                  );
                  // Event system will handle UI update
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${context.t.playlists.addReferenceTo} ${collection.name}',
                        ),
                      ),
                    );
                  }
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showRenamePlaylistDialog(BuildContext context, Tag tag) {
    final nameController = TextEditingController(text: tag.name);
    final tagViewModel = context.read<TagViewModel>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t.playlists.renamePlaylist),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(labelText: context.t.common.rename),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.t.common.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty && name != tag.name) {
                await tagViewModel.renameTag(tag.id, name);
                // Event system will handle UI update
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              }
            },
            child: Text(context.t.common.rename),
          ),
        ],
      ),
    );
  }

  void _showDeletePlaylistDialog(BuildContext context, Tag tag) {
    final tagViewModel = context.read<TagViewModel>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t.playlists.deletePlaylist),
        content: Text(
          '${context.t.playlists.deletePlaylistConfirm} "${tag.name}"?\n\n'
          '${context.t.playlists.deletePlaylistNote}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.t.common.cancel),
          ),
          TextButton(
            onPressed: () async {
              await tagViewModel.deleteTag(tag.id);
              if (_selectedPlaylistId == tag.id) {
                setState(() => _selectedPlaylistId = null);
              }
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(context.t.common.delete),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================

  /// Count total song units in a playlist metadata, including nested groups.
  int _countSongUnits(TagMetadata? metadata) {
    if (metadata == null) return 0;
    return _countSongUnitsRecursive(metadata.items, <String>{});
  }

  int _countSongUnitsRecursive(List<TagItem> items, Set<String> visited) {
    final tagVM = context.read<TagViewModel>();
    var count = 0;
    for (final item in items) {
      if (item.itemType == TagItemType.songUnit) {
        count++;
      } else if (item.itemType == TagItemType.tagReference) {
        if (visited.contains(item.targetId)) continue;
        visited.add(item.targetId);
        final refTag = tagVM.getTagById(item.targetId);
        if (refTag != null && refTag.metadata != null) {
          count += _countSongUnitsRecursive(refTag.metadata!.items, visited);
        }
      }
    }
    return count;
  }

  // ===========================================================================
  // Actions (all use TagViewModel generic collection operations)
  // ===========================================================================

  void _handlePlaylistAction(BuildContext context, Tag tag, String action) {
    switch (action) {
      case 'lock':
        _toggleLock(context, tag.id);
        break;
      case 'rename':
        _showRenamePlaylistDialog(context, tag);
        break;
      case 'delete':
        _showDeletePlaylistDialog(context, tag);
        break;
    }
  }

  void _toggleLock(BuildContext context, String collectionId) async {
    final tagViewModel = context.read<TagViewModel>();
    await tagViewModel.toggleLock(collectionId);
    // Event system will handle UI update
  }

  void _removeItem(
    BuildContext context,
    String playlistId,
    String itemId,
  ) async {
    final tagViewModel = context.read<TagViewModel>();
    await tagViewModel.removeFromCollection(playlistId, itemId);
    // Event system will handle UI update
  }

  void _playSong(BuildContext context, String songUnitId) {
    context.read<TagViewModel>().requestSong(songUnitId);
  }

  void _addPlaylistToQueue(BuildContext context, String playlistId) async {
    final tagViewModel = context.read<TagViewModel>();
    final tag = tagViewModel.getTagById(playlistId);
    final playlistName = tag?.name ?? 'Playlist';

    // Ask whether to add as a group
    final asGroup = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t.library.actions.addToQueue),
        content: Text(
          '${context.t.playlists.addReferenceTo} "$playlistName"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.t.common.no),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.t.common.yes),
          ),
        ],
      ),
    );

    if (asGroup == null || !context.mounted) return; // Dismissed

    if (asGroup) {
      final group = await tagViewModel.addCollectionToQueue(playlistId);
      if (context.mounted) {
        if (group != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${context.t.common.add} "${group.name}"',
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.t.common.error)),
          );
        }
      }
    } else {
      final count = await tagViewModel.addCollectionItemsToQueue(playlistId);
      if (context.mounted) {
        if (count > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.t.queue.songs.replaceAll('{count}', '$count'),
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.t.common.error)),
          );
        }
      }
    }
  }
}

// =============================================================================
// Reference Song List - shows songs from a referenced collection (read-only)
// =============================================================================

class ReferenceSongList extends StatelessWidget {
  const ReferenceSongList({
    required this.refTag,
    required this.refItems,
    required this.onPlaySong,
    super.key,
  });

  final Tag refTag;
  final List<TagItem> refItems;
  final ValueChanged<String> onPlaySong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final libraryVM = context.read<LibraryViewModel>();

    final songItems = refItems
        .where((i) => i.itemType == TagItemType.songUnit)
        .toList();

    if (songItems.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Referenced collection is empty',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: songItems.map((refItem) {
        final song = libraryVM.songUnits
            .where((s) => s.id == refItem.targetId)
            .firstOrNull;
        return ListTile(
          dense: true,
          leading: song != null && song.metadata.thumbnailSourceId != null
              ? CachedThumbnail(
                  metadata: song.metadata,
                  width: 28,
                  height: 28,
                  borderRadius: BorderRadius.circular(4),
                  placeholderColor: theme.colorScheme.tertiary,
                  placeholderBackgroundColor:
                      theme.colorScheme.tertiaryContainer.withValues(
                        alpha: 0.5,
                      ),
                )
              : CircleAvatar(
                  radius: 14,
                  backgroundColor:
                      theme.colorScheme.tertiaryContainer.withValues(
                        alpha: 0.5,
                      ),
                  child: Icon(
                    Icons.music_note,
                    size: 14,
                    color: theme.colorScheme.tertiary,
                  ),
                ),
          title: Text(
            song?.metadata.title ?? 'Unknown',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            song?.metadata.artistDisplay ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            icon: const Icon(Icons.play_arrow, size: 18),
            onPressed: () => onPlaySong(refItem.targetId),
            tooltip: 'Play',
          ),
          onTap: () => onPlaySong(refItem.targetId),
        );
      }).toList(),
    );
  }
}
