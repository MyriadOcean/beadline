import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../i18n/translations.g.dart';

import '../models/playlist_metadata.dart';
import '../models/tag.dart';
import '../viewmodels/library_view_model.dart';
import '../viewmodels/tag_view_model.dart';
import 'song_picker_dialog.dart';
import 'widgets/bulk_action_toolbar.dart';
import 'widgets/cached_thumbnail.dart';
import 'widgets/group_picker_dialog.dart';

/// Playlists management page with unified tag-based collection system.
/// Uses TagViewModel for all operations (no PlaylistViewModel dependency).
/// Supports nested groups, references, lock/unlock, and expand/collapse.
class PlaylistsManagementPage extends StatefulWidget {
  const PlaylistsManagementPage({super.key});

  @override
  State<PlaylistsManagementPage> createState() =>
      _PlaylistsManagementPageState();
}

class _PlaylistsManagementPageState extends State<PlaylistsManagementPage> {
  String? _selectedPlaylistId;

  /// Track collapsed groups/references within the playlist content view
  final Set<String> _collapsedItems = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TagViewModel>().loadTags();
    });
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

        if (playlistTags.isEmpty) {
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
        (a, b) => (a.playlistMetadata?.displayOrder ?? 0).compareTo(
          b.playlistMetadata?.displayOrder ?? 0,
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
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onSecondaryTapUp: (details) {
              _showPlaylistListContextMenu(context, details.globalPosition);
            },
            onLongPressStart: (details) {
              _showPlaylistListContextMenu(context, details.globalPosition);
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
              final metadata = tag.playlistMetadata;
              final isLocked = metadata?.isLocked ?? false;

              return GestureDetector(
                key: ValueKey('playlist_${tag.id}'),
                behavior: HitTestBehavior.opaque,
                onSecondaryTapUp: (details) {
                  _showPlaylistItemContextMenu(context, details.globalPosition, tag);
                },
                onLongPressStart: (details) {
                  _showPlaylistItemContextMenu(context, details.globalPosition, tag);
                },
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
                    onTap: () => setState(() => _selectedPlaylistId = tag.id),
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
              );
            },
          ),        // closes ReorderableListView.builder
        ),          // closes GestureDetector
        ),          // closes Expanded
      ],
    );
  }

  Widget _buildPlaylistContent(BuildContext context, String playlistTagId) {
    return Consumer<TagViewModel>(
      builder: (context, tagViewModel, child) {
        final tag = tagViewModel.getTagById(playlistTagId);
        if (tag == null || !tag.isCollection) {
          return Center(child: Text(context.t.common.error));
        }

        final metadata = tag.playlistMetadata;
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
                  : _PlaylistContentList(
                      playlistTagId: playlistTagId,
                      items: items,
                      tagViewModel: tagViewModel,
                      collapsedItems: _collapsedItems,
                      onToggleExpand: (id) {
                        setState(() {
                          if (_collapsedItems.contains(id)) {
                            _collapsedItems.remove(id);
                          } else {
                            _collapsedItems.add(id);
                          }
                        });
                      },
                      onRemoveItem: (itemId) =>
                          _removeItem(context, playlistTagId, itemId),
                      onPlaySong: (songUnitId) =>
                          _playSong(context, songUnitId),
                      onNavigateToCollection: (collectionId) {
                        setState(() => _selectedPlaylistId = collectionId);
                      },
                      onToggleLock: (collectionId) =>
                          _toggleLock(context, collectionId),
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
    for (final item in tag.playlistMetadata?.items ?? []) {
      if (item.type == PlaylistItemType.collectionReference) {
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
    List<PlaylistItem> items,
  ) {
    final theme = Theme.of(context);
    final metadata = tag.playlistMetadata;
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
                      '${_countSongUnitsFromItems(items)} ${context.t.common.songs}',
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
  void _showPlaylistListContextMenu(BuildContext context, Offset position) {
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
  void _showPlaylistItemContextMenu(BuildContext context, Offset position, Tag tag) {
    final metadata = tag.playlistMetadata;
    final isLocked = metadata?.isLocked ?? false;
    
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
          _showAddSongsDialog(context, playlistId);
          break;
        case 'create_group':
          _showCreateGroupDialog(context, playlistId);
          break;
        case 'add_reference':
          _showAddCollectionReferenceDialog(context, playlistId);
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

  void _showAddSongsDialog(BuildContext context, String playlistId) async {
    final tagViewModel = context.read<TagViewModel>();

    // Get current playlist to find its items
    final currentPlaylist = tagViewModel.allTags
        .where((t) => t.id == playlistId && t.isCollection)
        .firstOrNull;

    // Get current playlist items to exclude them from selection
    final currentItems = currentPlaylist?.playlistMetadata?.items ?? [];
    final excludeSongIds = currentItems
        .where((item) => item.type == PlaylistItemType.songUnit)
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
              '${context.t.queue.songs.replaceAll('{count}', '${selectedSongIds.length}')} → ${context.t.playlists.title}',
            ),
          ),
        );
      }
    }
  }

  void _showCreateGroupDialog(BuildContext context, String playlistId) {
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

  void _showAddCollectionReferenceDialog(
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
                  '${collection.playlistMetadata?.items.length ?? 0} ${context.t.common.items}',
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

  /// Count total song units in a playlist metadata, including songs inside nested groups
  int _countSongUnits(PlaylistMetadata? metadata) {
    if (metadata == null) return 0;
    return _countSongUnitsFromItems(metadata.items);
  }

  /// Count total song units from a list of items, recursively including nested groups
  int _countSongUnitsFromItems(List<PlaylistItem> items) {
    final tagVM = context.read<TagViewModel>();
    var count = 0;
    for (final item in items) {
      if (item.type == PlaylistItemType.songUnit) {
        count++;
      } else if (item.type == PlaylistItemType.collectionReference) {
        final refTag = tagVM.getTagById(item.targetId);
        if (refTag != null && refTag.playlistMetadata != null) {
          count += _countSongUnitsFromItems(refTag.playlistMetadata!.items);
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
// Playlist Content List - displays items with group cards and references
// =============================================================================

// ---------------------------------------------------------------------------
// Drag-and-drop data types for playlist panel
// ---------------------------------------------------------------------------

enum _PlaylistDragItemType { song, group }

/// Data carried during a drag operation within a playlist
class _PlaylistDragData {
  const _PlaylistDragData({
    required this.itemId,
    required this.sourceCollectionId,
    required this.type,
    this.groupTagId,
  });

  final String itemId;
  final String sourceCollectionId;
  final _PlaylistDragItemType type;
  final String? groupTagId;
}

/// Displays playlist items with drag-and-drop support for:
/// - Song units as draggable list tiles with drag handles
/// - Groups (isGroup=true collections) as draggable/droppable cards
/// - Collection references as expandable items with distinct styling
class _PlaylistContentList extends StatefulWidget {
  const _PlaylistContentList({
    required this.playlistTagId,
    required this.items,
    required this.tagViewModel,
    required this.collapsedItems,
    required this.onToggleExpand,
    required this.onRemoveItem,
    required this.onPlaySong,
    required this.onNavigateToCollection,
    required this.onToggleLock,
  });

  final String playlistTagId;
  final List<PlaylistItem> items;
  final TagViewModel tagViewModel;
  final Set<String> collapsedItems;
  final ValueChanged<String> onToggleExpand;
  final ValueChanged<String> onRemoveItem;
  final ValueChanged<String> onPlaySong;
  final ValueChanged<String> onNavigateToCollection;
  final ValueChanged<String> onToggleLock;

  @override
  State<_PlaylistContentList> createState() => _PlaylistContentListState();
}

class _PlaylistContentListState extends State<_PlaylistContentList> {
  // Drag visual state
  String? _hoveredGroupId;
  int? _insertionIndex;

  /// Recursively count song units inside a group tag, including nested sub-groups
  int _countGroupSongsRecursive(Tag groupTag) {
    final items = groupTag.playlistMetadata?.items ?? [];
    var count = 0;
    for (final item in items) {
      if (item.type == PlaylistItemType.songUnit) {
        count++;
      } else if (item.type == PlaylistItemType.collectionReference) {
        final subTag = widget.tagViewModel.getTagById(item.targetId);
        if (subTag != null && subTag.isGroup) {
          count += _countGroupSongsRecursive(subTag);
        }
      }
    }
    return count;
  }

  /// Compute the cumulative song count before each item index.
  /// Songs count as 1, groups count as the number of songs inside them.
  /// Returns a list where element [i] = number of songs before item i.
  List<int> _computeSongCountsBefore() {
    final counts = <int>[];
    var cumulative = 0;
    for (final item in widget.items) {
      counts.add(cumulative);
      if (item.type == PlaylistItemType.songUnit) {
        cumulative += 1;
      } else if (item.type == PlaylistItemType.collectionReference) {
        final refTag = widget.tagViewModel.getTagById(item.targetId);
        if (refTag != null && refTag.isGroup) {
          cumulative += _countGroupSongsRecursive(refTag);
        }
        // Non-group references don't contribute to the continuing counter
      }
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final songCountsBefore = _computeSongCountsBefore();
    return DragTarget<_PlaylistDragData>(
      onWillAcceptWithDetails: (details) {
        return details.data.type == _PlaylistDragItemType.song &&
            details.data.sourceCollectionId != widget.playlistTagId;
      },
      onAcceptWithDetails: (details) async {
        final data = details.data;
        await widget.tagViewModel.moveSongUnitOutOfGroup(
          data.sourceCollectionId,
          data.itemId,
          widget.playlistTagId,
          insertIndex: widget.items.length,
        );
      },
      builder: (context, candidateData, rejectedData) {
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: widget.items.length + 1,
          itemBuilder: (context, index) {
            // Trailing empty space: accepts drops (move to end) and right-click context menu
            if (index == widget.items.length) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Insertion bar at the very end
                  _buildInsertionDropZone(widget.items.length, theme),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onSecondaryTapUp: (details) {
                      _showPlaylistContextMenu(context, details.globalPosition);
                    },
                    onLongPressStart: (details) {
                      _showPlaylistContextMenu(context, details.globalPosition);
                    },
                    child: DragTarget<_PlaylistDragData>(
                      onWillAcceptWithDetails: (_) => true,
                      onAcceptWithDetails: (details) async {
                        final data = details.data;
                        if (data.type == _PlaylistDragItemType.group) {
                          await widget.tagViewModel.moveGroupOutToCollection(
                            widget.playlistTagId,
                            data.itemId,
                            widget.playlistTagId,
                            widget.items.length,
                          );
                        } else if (data.sourceCollectionId ==
                            widget.playlistTagId) {
                          final oldIdx = _indexOfItem(data.itemId);
                          if (oldIdx >= 0 && oldIdx < widget.items.length - 1) {
                            await widget.tagViewModel.reorderCollection(
                              widget.playlistTagId,
                              oldIdx,
                              widget.items.length - 1,
                            );
                          }
                        } else {
                          await widget.tagViewModel.moveSongUnitOutOfGroup(
                            data.sourceCollectionId,
                            data.itemId,
                            widget.playlistTagId,
                            insertIndex: widget.items.length,
                          );
                        }
                      },
                      builder: (context, candidateData, rejectedData) {
                        return Container(
                          height: 200,
                          color: candidateData.isNotEmpty
                              ? theme.colorScheme.primaryContainer.withValues(
                                  alpha: 0.3,
                                )
                              : null,
                        );
                      },
                    ),
                  ),
                ],
              );
            }
            final item = widget.items[index];
            final songsBefore = songCountsBefore[index];

            if (item.type == PlaylistItemType.collectionReference) {
              return _wrapWithDropTarget(
                index: index,
                theme: theme,
                child: _buildCollectionItem(context, item, index, songsBefore),
              );
            }

            return _wrapWithDropTarget(
              index: index,
              theme: theme,
              child: _buildSongItem(context, item, index, songsBefore),
            );
          },
        );
      },
    );
  }

  void _showPlaylistContextMenu(BuildContext context, Offset position) {
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
      // Delegate to parent page's dialog methods via a callback approach
      // We access the parent state through the context
      final parentState = context
          .findAncestorStateOfType<_PlaylistsManagementPageState>();
      if (parentState == null) return;
      switch (value) {
        case 'add_songs':
          parentState._showAddSongsDialog(context, widget.playlistTagId);
          break;
        case 'create_group':
          parentState._showCreateGroupDialog(context, widget.playlistTagId);
          break;
        case 'add_reference':
          parentState._showAddCollectionReferenceDialog(
            context,
            widget.playlistTagId,
          );
          break;
      }
    });
  }

  // ---------- insertion-line drop target wrapper ----------

  /// Each top-level item is wrapped in a DragTarget so that dragging a song
  /// or group between items shows an insertion line and triggers reorder /
  /// move-out-of-group on drop.
  Widget _wrapWithDropTarget({
    required int index,
    required ThemeData theme,
    required Widget child,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Insertion bar ABOVE this item - accepts drops to insert at this index
        _buildInsertionDropZone(index, theme),
        child,
      ],
    );
  }

  /// A thin DragTarget zone that shows an insertion indicator bar when hovered.
  /// Accepts both songs and groups for reordering / moving between positions.
  Widget _buildInsertionDropZone(int index, ThemeData theme) {
    return DragTarget<_PlaylistDragData>(
      onWillAcceptWithDetails: (details) {
        final data = details.data;
        // Don't allow dropping on self position (no-op)
        if (data.type == _PlaylistDragItemType.song &&
            data.sourceCollectionId == widget.playlistTagId) {
          final oldIdx = _indexOfItem(data.itemId);
          if (oldIdx == index || oldIdx == index - 1) return false;
        }
        setState(() => _insertionIndex = index);
        return true;
      },
      onLeave: (_) {
        if (mounted && _insertionIndex == index) {
          setState(() => _insertionIndex = null);
        }
      },
      onAcceptWithDetails: (details) async {
        final data = details.data;
        setState(() => _insertionIndex = null);

        if (data.type == _PlaylistDragItemType.group) {
          // Move group to this position in the top-level playlist
          await widget.tagViewModel.moveGroupOutToCollection(
            widget.playlistTagId,
            data.itemId,
            widget.playlistTagId,
            index,
          );
        } else if (data.sourceCollectionId == widget.playlistTagId) {
          // Reorder a top-level song within the playlist
          final oldIdx = _indexOfItem(data.itemId);
          if (oldIdx >= 0 && oldIdx != index) {
            await widget.tagViewModel.reorderCollection(
              widget.playlistTagId,
              oldIdx,
              index,
            );
          }
        } else {
          // Move song out of a group to top-level playlist
          await widget.tagViewModel.moveSongUnitOutOfGroup(
            data.sourceCollectionId,
            data.itemId,
            widget.playlistTagId,
            insertIndex: index,
          );
        }
      },
      builder: (context, candidateData, rejectedData) {
        final showLine = _insertionIndex == index && candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: showLine ? 4 : 0,
          margin: showLine
              ? const EdgeInsets.symmetric(horizontal: 8)
              : EdgeInsets.zero,
          decoration: showLine
              ? BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                )
              : null,
        );
      },
    );
  }

  int _indexOfItem(String itemId) {
    for (var i = 0; i < widget.items.length; i++) {
      if (widget.items[i].id == itemId) return i;
    }
    return -1;
  }

  /// Build a draggable song unit item tile - long-press to drag, no drag handle
  Widget _buildSongItem(
    BuildContext context,
    PlaylistItem item,
    int index,
    int songsBefore,
  ) {
    final isSelected = widget.tagViewModel.isSelected(item.id);
    final hasSelection = widget.tagViewModel.hasSelection;
    final libraryViewModel = context.read<LibraryViewModel>();
    final song = libraryViewModel.songUnits
        .where((s) => s.id == item.targetId)
        .firstOrNull;
    final title = song?.metadata.title ?? 'Unknown Song';
    final artist = song?.metadata.artistDisplay ?? '';
    final theme = Theme.of(context);

    return LongPressDraggable<_PlaylistDragData>(
      key: ValueKey('song_${item.id}'),
      data: _PlaylistDragData(
        itemId: item.id,
        sourceCollectionId: widget.playlistTagId,
        type: _PlaylistDragItemType.song,
      ),
      // Disable drag when in selection mode
      maxSimultaneousDrags: hasSelection ? 0 : 1,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 280,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.music_note,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: ListTile(
            dense: true,
            title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
      child: GestureDetector(
        onSecondaryTapUp: (details) {
          _showPlaylistContextMenu(context, details.globalPosition);
        },
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          color: isSelected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
              : null,
          child: Row(
            children: [
              if (hasSelection)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (_) =>
                        widget.tagViewModel.toggleSelection(item.id),
                  ),
                ),
              Expanded(
                child: ListTile(
                  dense: true,
                  leading: _buildSongLeading(song, songsBefore, theme),
                  title: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: artist.isNotEmpty
                      ? Text(
                          artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                  trailing: hasSelection
                      ? null
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.play_arrow),
                              onPressed: () => widget.onPlaySong(item.targetId),
                              tooltip: context.t.search.play,
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () => widget.onRemoveItem(item.id),
                              tooltip: context.t.common.remove,
                            ),
                          ],
                        ),
                  selected: isSelected,
                  onTap: hasSelection
                      ? () => widget.tagViewModel.toggleSelection(item.id)
                      : () => widget.onPlaySong(item.targetId),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build the leading widget for a song item - thumbnail if available, else index number
  Widget _buildSongLeading(dynamic song, int songsBefore, ThemeData theme) {
    if (song != null && song.metadata.thumbnailSourceId != null) {
      return CachedThumbnail(
        metadata: song.metadata,
        width: 32,
        height: 32,
        borderRadius: BorderRadius.circular(4),
        placeholderColor: theme.colorScheme.onSurfaceVariant,
        placeholderBackgroundColor: theme.colorScheme.surfaceContainerHighest,
      );
    }
    return SizedBox(
      width: 28,
      child: Text(
        '${songsBefore + 1}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Build a collection reference item (group or external reference)
  Widget _buildCollectionItem(
    BuildContext context,
    PlaylistItem item,
    int index,
    int songsBefore,
  ) {
    final theme = Theme.of(context);
    final refTag = widget.tagViewModel.getTagById(item.targetId);

    if (refTag == null) {
      return ListTile(
        key: ValueKey(item.id),
        leading: Icon(Icons.link_off, color: theme.colorScheme.error),
        title: Text(context.t.common.error),
        trailing: IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: () => widget.onRemoveItem(item.id),
          tooltip: context.t.common.remove,
        ),
      );
    }

    if (refTag.isGroup) {
      return _buildGroupCard(context, item, refTag, songsBefore);
    }

    return _buildReferenceCard(context, item, refTag);
  }

  /// Build a group card that is both draggable (to reorder) and a drop target
  /// (to accept songs dragged into it). Mirrors queue view group card pattern.
  Widget _buildGroupCard(
    BuildContext context,
    PlaylistItem item,
    Tag groupTag,
    int songsBefore,
  ) {
    final theme = Theme.of(context);
    final isLocked = groupTag.isLocked;
    final isExpanded = !widget.collapsedItems.contains(groupTag.id);
    final songCount = _countGroupSongsRecursive(groupTag);

    final dragData = _PlaylistDragData(
      itemId: item.id,
      sourceCollectionId: widget.playlistTagId,
      type: _PlaylistDragItemType.group,
      groupTagId: groupTag.id,
    );

    final dragFeedback = Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.folder, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${groupTag.name} ($songCount)',
                style: theme.textTheme.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );

    // DragTarget wraps the whole card (for receiving drops).
    // LongPressDraggable only wraps the header inside _groupCardBody.
    return DragTarget<_PlaylistDragData>(
      key: ValueKey('group_${groupTag.id}'),
      onWillAcceptWithDetails: (details) {
        final data = details.data;
        if (data.type == _PlaylistDragItemType.group) {
          // Accept group drops to nest inside - but not self
          if (data.groupTagId == groupTag.id) return false;
          if (isLocked) return false;
          setState(() => _hoveredGroupId = groupTag.id);
          return true;
        }
        if (isLocked) return false;
        setState(() => _hoveredGroupId = groupTag.id);
        return true;
      },
      onLeave: (_) {
        if (mounted && _hoveredGroupId == groupTag.id) {
          setState(() => _hoveredGroupId = null);
        }
      },
      onAcceptWithDetails: (details) async {
        setState(() => _hoveredGroupId = null);
        final data = details.data;
        if (data.type == _PlaylistDragItemType.group) {
          // Move dragged group into this group
          await widget.tagViewModel.moveGroupIntoGroup(
            widget.playlistTagId,
            data.itemId,
            groupTag.id,
          );
        } else {
          // Move song into this group
          await widget.tagViewModel.moveSongUnitToGroup(
            widget.playlistTagId,
            data.itemId,
            groupTag.id,
          );
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isTarget =
            _hoveredGroupId == groupTag.id && candidateData.isNotEmpty;
        return _groupCardBody(
          context,
          item,
          groupTag,
          theme,
          isLocked: isLocked,
          isExpanded: isExpanded,
          songCount: songCount,
          isDropTarget: isTarget,
          songsBefore: songsBefore,
          dragData: dragData,
          dragFeedback: dragFeedback,
        );
      },
    );
  }

  Widget _groupCardBody(
    BuildContext context,
    PlaylistItem item,
    Tag groupTag,
    ThemeData theme, {
    required bool isLocked,
    required bool isExpanded,
    required int songCount,
    required bool isDropTarget,
    required int songsBefore,
    required _PlaylistDragData dragData,
    required Widget dragFeedback,
  }) {
    final groupItems = groupTag.playlistMetadata?.items ?? [];

    // The header row content
    Widget buildHeaderRow() {
      return Container(
        decoration: BoxDecoration(
          color: isDropTarget
              ? theme.colorScheme.primaryContainer
              : isLocked
              ? theme.colorScheme.secondaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: isExpanded
              ? const BorderRadius.vertical(top: Radius.circular(12))
              : BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Icon(
              Icons.folder,
              size: 20,
              color: isLocked
                  ? theme.colorScheme.secondary
                  : theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      groupTag.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$songCount song${songCount == 1 ? '' : 's'}'
                      '${isLocked ? ' - Locked' : ''}'
                      '${isDropTarget ? ' - drop here' : ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDropTarget
                            ? theme.colorScheme.primary
                            : isLocked
                            ? theme.colorScheme.secondary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 32,
              height: 32,
              child: IconButton(
                icon: Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                ),
                padding: EdgeInsets.zero,
                onPressed: () => widget.onToggleExpand(groupTag.id),
                tooltip: isExpanded ? 'Collapse' : 'Expand',
              ),
            ),
            SizedBox(
              width: 32,
              height: 32,
              child: PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                padding: EdgeInsets.zero,
                tooltip: 'Group actions',
                onSelected: (value) {
                  switch (value) {
                    case 'rename':
                      _showRenameGroupDialog(context, groupTag);
                      break;
                    case 'toggle_lock':
                      widget.onToggleLock(groupTag.id);
                      break;
                    case 'add_nested_group':
                      _showCreateNestedGroupDialog(context, groupTag.id);
                      break;
                    case 'remove':
                      widget.onRemoveItem(item.id);
                      break;
                  }
                },
                itemBuilder: (context) => [
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
                    value: 'toggle_lock',
                    child: ListTile(
                      leading: Icon(isLocked ? Icons.lock_open : Icons.lock),
                      title: Text(isLocked ? context.t.playlists.unlock : context.t.playlists.lock),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'add_nested_group',
                    child: ListTile(
                      leading: const Icon(Icons.create_new_folder_outlined),
                      title: Text(context.t.playlists.createGroup),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'remove',
                    child: ListTile(
                      leading: const Icon(Icons.remove_circle_outline),
                      title: Text(context.t.common.remove),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      elevation: isDropTarget ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDropTarget
              ? theme.colorScheme.primary
              : isLocked
              ? theme.colorScheme.secondary
              : theme.colorScheme.outlineVariant,
          width: isDropTarget ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Only the header is draggable
          LongPressDraggable<_PlaylistDragData>(
            data: dragData,
            feedback: dragFeedback,
            childWhenDragging: Opacity(opacity: 0.3, child: buildHeaderRow()),
            child: buildHeaderRow(),
          ),
          // Expanded content - NOT wrapped in the draggable
          if (isExpanded)
            _GroupSongList(
              groupTag: groupTag,
              groupItems: groupItems,
              playlistTagId: widget.playlistTagId,
              tagViewModel: widget.tagViewModel,
              onPlaySong: widget.onPlaySong,
              collapsedItems: widget.collapsedItems,
              onToggleExpand: widget.onToggleExpand,
              onToggleLock: widget.onToggleLock,
              startIndex: songsBefore,
            ),
        ],
      ),
    );
  }

  void _showRenameGroupDialog(BuildContext context, Tag groupTag) {
    final nameController = TextEditingController(text: groupTag.name);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t.common.rename),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: context.t.playlists.groupName,
            hintText: context.t.playlists.enterGroupName,
          ),
          autofocus: true,
          onSubmitted: (_) async {
            final name = nameController.text.trim();
            if (name.isNotEmpty) {
              await widget.tagViewModel.renameTag(groupTag.id, name);
              // Event system will handle UI update
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            }
          },
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
                await widget.tagViewModel.renameTag(groupTag.id, name);
                // Event system will handle UI update
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              }
            },
            child: Text(context.t.common.rename),
          ),
        ],
      ),
    );
  }

  void _showCreateNestedGroupDialog(
    BuildContext context,
    String parentGroupId,
  ) {
    final nameController = TextEditingController();
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
          onSubmitted: (_) async {
            final name = nameController.text.trim();
            if (name.isNotEmpty) {
              await widget.tagViewModel.createNestedGroup(parentGroupId, name);
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            }
          },
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
                await widget.tagViewModel.createNestedGroup(
                  parentGroupId,
                  name,
                );
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              }
            },
            child: Text(context.t.common.create),
          ),
        ],
      ),
    );
  }

  /// Build a reference card (non-group collection reference)
  Widget _buildReferenceCard(
    BuildContext context,
    PlaylistItem item,
    Tag refTag,
  ) {
    final theme = Theme.of(context);
    final isExpanded = !widget.collapsedItems.contains(refTag.id);
    final refItems = refTag.playlistMetadata?.items ?? [];
    final itemCount = refItems.length;

    return Card(
      key: ValueKey('ref_${item.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.tertiary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.3),
              borderRadius: isExpanded
                  ? const BorderRadius.vertical(top: Radius.circular(12))
                  : BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Icon(Icons.link, size: 20, color: theme.colorScheme.tertiary),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '- ${refTag.name}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.tertiary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Reference - $itemCount item${itemCount == 1 ? '' : 's'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                  ),
                  onPressed: () => widget.onToggleExpand(refTag.id),
                  tooltip: isExpanded ? 'Collapse' : 'Expand',
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_new, size: 20),
                  onPressed: () => widget.onNavigateToCollection(refTag.id),
                  tooltip: 'Open collection',
                ),
                IconButton(
                  icon: Icon(
                    Icons.remove_circle_outline,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () => widget.onRemoveItem(item.id),
                  tooltip: 'Remove reference',
                ),
              ],
            ),
          ),
          if (isExpanded)
            _ReferenceSongList(
              refTag: refTag,
              refItems: refItems,
              onPlaySong: widget.onPlaySong,
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// Group Song List - shows draggable songs within a group card
// =============================================================================

class _GroupSongList extends StatelessWidget {
  const _GroupSongList({
    required this.groupTag,
    required this.groupItems,
    required this.playlistTagId,
    required this.tagViewModel,
    required this.onPlaySong,
    required this.collapsedItems,
    required this.onToggleExpand,
    required this.onToggleLock,
    this.startIndex = 0,
  });

  final Tag groupTag;
  final List<PlaylistItem> groupItems;
  final String playlistTagId;
  final TagViewModel tagViewModel;
  final ValueChanged<String> onPlaySong;
  final Set<String> collapsedItems;
  final ValueChanged<String> onToggleExpand;
  final ValueChanged<String> onToggleLock;

  /// The 0-based index offset so that numbering continues from the playlist
  final int startIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final libraryVM = context.read<LibraryViewModel>();

    if (groupItems.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          context.t.playlists.noSongsInGroup,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    var songIndex = 0;
    final items = groupItems.map((groupItem) {
      if (groupItem.type == PlaylistItemType.collectionReference) {
        // Render nested sub-group
        final subGroupTag = tagViewModel.getTagById(groupItem.targetId);
        if (subGroupTag == null) return const SizedBox.shrink();
        return _NestedSubGroupCard(
          subGroupTag: subGroupTag,
          parentGroupId: groupTag.id,
          playlistItemId: groupItem.id,
          playlistTagId: playlistTagId,
          tagViewModel: tagViewModel,
          onPlaySong: onPlaySong,
          collapsedItems: collapsedItems,
          onToggleExpand: onToggleExpand,
          onToggleLock: onToggleLock,
        );
      }

      // Render song item
      final currentSongIndex = songIndex++;
      final song = libraryVM.songUnits
          .where((s) => s.id == groupItem.targetId)
          .firstOrNull;
      final title = song?.metadata.title ?? 'Unknown';
      final artist = song?.metadata.artistDisplay ?? '';

      return LongPressDraggable<_PlaylistDragData>(
          data: _PlaylistDragData(
            itemId: groupItem.id,
            sourceCollectionId: groupTag.id,
            type: _PlaylistDragItemType.song,
          ),
          feedback: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 260,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.music_note,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.3,
            child: ListTile(
              dense: true,
              leading: song != null && song.metadata.thumbnailSourceId != null
                  ? CachedThumbnail(
                      metadata: song.metadata,
                      width: 32,
                      height: 32,
                      borderRadius: BorderRadius.circular(4),
                      placeholderColor: theme.colorScheme.onSurfaceVariant,
                      placeholderBackgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                    )
                  : SizedBox(
                      width: 28,
                      child: Text(
                        '${startIndex + currentSongIndex + 1}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
              title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          child: ListTile(
            dense: true,
            leading: song != null && song.metadata.thumbnailSourceId != null
                ? CachedThumbnail(
                    metadata: song.metadata,
                    width: 32,
                    height: 32,
                    borderRadius: BorderRadius.circular(4),
                    placeholderColor: theme.colorScheme.onSurfaceVariant,
                    placeholderBackgroundColor:
                        theme.colorScheme.surfaceContainerHighest,
                  )
                : SizedBox(
                    width: 28,
                    child: Text(
                      '${startIndex + currentSongIndex + 1}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
            title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.play_arrow, size: 18),
                  onPressed: () => onPlaySong(groupItem.targetId),
                  tooltip: 'Play',
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                  onPressed: () async {
                    await tagViewModel.removeFromCollection(
                      groupTag.id,
                      groupItem.id,
                    );
                    // Event system will handle UI update
                  },
                  tooltip: 'Remove from group',
                ),
              ],
            ),
            onTap: () => onPlaySong(groupItem.targetId),
          ),
        );
      }).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...items,
        // Trailing empty space for context menu to create nested groups
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onSecondaryTapUp: (details) {
            _showGroupContextMenu(context, details.globalPosition, groupTag);
          },
          onLongPressStart: (details) {
            _showGroupContextMenu(context, details.globalPosition, groupTag);
          },
          child: Container(
            height: 60,
            color: Colors.transparent,
          ),
        ),
      ],
    );
  }

  void _showGroupContextMenu(BuildContext context, Offset position, Tag groupTag) {
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
          value: 'add_nested_group',
          child: ListTile(
            leading: const Icon(Icons.create_new_folder_outlined),
            title: Text(context.t.playlists.createGroup),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'add_songs',
          child: ListTile(
            leading: const Icon(Icons.music_note),
            title: Text(context.t.playlists.addSongs),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    ).then((value) async {
      if (value == null || !context.mounted) return;
      final parentState = context.findAncestorStateOfType<_PlaylistContentListState>();
      if (parentState == null) return;
      
      switch (value) {
        case 'add_nested_group':
          parentState._showCreateNestedGroupDialog(context, groupTag.id);
          break;
        case 'add_songs':
          // Show dialog to add songs to this group
          final currentItems = groupTag.playlistMetadata?.items ?? [];
          final excludeSongIds = currentItems
              .where((item) => item.type == PlaylistItemType.songUnit)
              .map((item) => item.targetId)
              .toList();
          
          final selectedSongIds = await showDialog<List<String>>(
            context: context,
            builder: (dialogContext) => SongPickerDialog(excludeSongIds: excludeSongIds),
          );
          
          if (selectedSongIds != null && selectedSongIds.isNotEmpty && context.mounted) {
            for (final songId in selectedSongIds) {
              await tagViewModel.addSongUnitToCollection(groupTag.id, songId);
            }
          }
          break;
      }
    });
  }
}

// =============================================================================
// Nested Sub-Group Card for playlist panel
// =============================================================================

class _NestedSubGroupCard extends StatelessWidget {
  const _NestedSubGroupCard({
    required this.subGroupTag,
    required this.parentGroupId,
    required this.playlistItemId,
    required this.playlistTagId,
    required this.tagViewModel,
    required this.onPlaySong,
    required this.collapsedItems,
    required this.onToggleExpand,
    required this.onToggleLock,
  });

  final Tag subGroupTag;
  final String parentGroupId;
  final String playlistItemId;
  final String playlistTagId;
  final TagViewModel tagViewModel;
  final ValueChanged<String> onPlaySong;
  final Set<String> collapsedItems;
  final ValueChanged<String> onToggleExpand;
  final ValueChanged<String> onToggleLock;

  int _countSongsRecursive(Tag tag) {
    final items = tag.playlistMetadata?.items ?? [];
    var count = 0;
    for (final item in items) {
      if (item.type == PlaylistItemType.songUnit) {
        count++;
      } else if (item.type == PlaylistItemType.collectionReference) {
        final sub = tagViewModel.getTagById(item.targetId);
        if (sub != null && sub.isGroup) {
          count += _countSongsRecursive(sub);
        }
      }
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isExpanded = !collapsedItems.contains(subGroupTag.id);
    final isLocked = subGroupTag.isLocked;
    final subItems = subGroupTag.playlistMetadata?.items ?? [];
    final songCount = _countSongsRecursive(subGroupTag);

    final dragData = _PlaylistDragData(
      itemId: playlistItemId,
      sourceCollectionId: parentGroupId,
      type: _PlaylistDragItemType.group,
      groupTagId: subGroupTag.id,
    );

    final dragFeedback = Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_outlined,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${subGroupTag.name} ($songCount)',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );

    Widget buildHeaderRow({bool isDropTarget = false}) {
      return Container(
        decoration: BoxDecoration(
          color: isDropTarget
              ? theme.colorScheme.primaryContainer
              : isLocked
              ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.5)
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
          borderRadius: isExpanded
              ? const BorderRadius.vertical(top: Radius.circular(8))
              : BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.only(left: 10),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => onToggleExpand(subGroupTag.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        Icons.folder_outlined,
                        size: 16,
                        color: isLocked
                            ? theme.colorScheme.secondary
                            : theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${subGroupTag.name}${isDropTarget ? ' - drop here' : ''} ($songCount)',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isLocked)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(
                            Icons.lock,
                            size: 12,
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 28,
              height: 28,
              child: PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                padding: EdgeInsets.zero,
                tooltip: 'Group actions',
                onSelected: (value) async {
                  switch (value) {
                    case 'rename':
                      _showRenameDialog(context);
                      break;
                    case 'toggle_lock':
                      onToggleLock(subGroupTag.id);
                      break;
                    case 'add_nested_group':
                      _showCreateNestedGroupDialog(context);
                      break;
                    case 'remove':
                      await tagViewModel.removeFromCollection(
                        parentGroupId,
                        playlistItemId,
                      );
                      // Event system will handle UI update
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'rename',
                    child: ListTile(
                      leading: const Icon(Icons.edit, size: 18),
                      title: Text(context.t.common.rename),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'toggle_lock',
                    child: ListTile(
                      leading: Icon(
                        isLocked ? Icons.lock_open : Icons.lock,
                        size: 18,
                      ),
                      title: Text(isLocked ? context.t.playlists.unlock : context.t.playlists.lock),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'add_nested_group',
                    child: ListTile(
                      leading: const Icon(Icons.create_new_folder_outlined, size: 18),
                      title: Text(context.t.playlists.createGroup),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'remove',
                    child: ListTile(
                      leading: const Icon(Icons.remove_circle_outline, size: 18),
                      title: Text(context.t.common.remove),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 2),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: DragTarget<_PlaylistDragData>(
        onWillAcceptWithDetails: (details) {
          final data = details.data;
          if (data.type == _PlaylistDragItemType.group) {
            // Accept group drops for deeper nesting - but not self
            if (data.groupTagId == subGroupTag.id) return false;
            if (isLocked) return false;
            return true;
          }
          // Don't accept songs if locked
          if (isLocked) return false;
          return true;
        },
        onAcceptWithDetails: (details) async {
          final data = details.data;
          if (data.type == _PlaylistDragItemType.group) {
            // Move group into this nested group
            await tagViewModel.moveGroupIntoGroup(
              playlistTagId,
              data.itemId,
              subGroupTag.id,
            );
          } else {
            // Move song into this nested group
            await tagViewModel.moveSongUnitToGroup(
              playlistTagId,
              data.itemId,
              subGroupTag.id,
            );
          }
        },
        builder: (context, candidateData, rejectedData) {
          final isDropTarget = candidateData.isNotEmpty;
          return Card(
            margin: EdgeInsets.zero,
            elevation: isDropTarget ? 3 : 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: isDropTarget
                    ? theme.colorScheme.primary
                    : isLocked
                    ? theme.colorScheme.secondary.withValues(alpha: 0.5)
                    : theme.colorScheme.outlineVariant,
                width: isDropTarget ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Only the header is draggable
                LongPressDraggable<_PlaylistDragData>(
                  data: dragData,
                  feedback: dragFeedback,
                  childWhenDragging: Opacity(
                    opacity: 0.3,
                    child: buildHeaderRow(),
                  ),
                  child: buildHeaderRow(isDropTarget: isDropTarget),
                ),
                // Expanded content - NOT wrapped in the draggable
                if (isExpanded)
                  _GroupSongList(
                    groupTag: subGroupTag,
                    groupItems: subItems,
                    playlistTagId: playlistTagId,
                    tagViewModel: tagViewModel,
                    onPlaySong: onPlaySong,
                    collapsedItems: collapsedItems,
                    onToggleExpand: onToggleExpand,
                    onToggleLock: onToggleLock,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showRenameDialog(BuildContext context) {
    final nameController = TextEditingController(text: subGroupTag.name);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t.common.rename),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: context.t.playlists.groupName,
            hintText: context.t.playlists.enterGroupName,
          ),
          autofocus: true,
          onSubmitted: (_) async {
            final name = nameController.text.trim();
            if (name.isNotEmpty) {
              await tagViewModel.renameTag(subGroupTag.id, name);
              // Event system will handle UI update
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            }
          },
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
                await tagViewModel.renameTag(subGroupTag.id, name);
                // Event system will handle UI update
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              }
            },
            child: Text(context.t.common.rename),
          ),
        ],
      ),
    );
  }

  void _showCreateNestedGroupDialog(BuildContext context) {
    final nameController = TextEditingController();
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
          onSubmitted: (_) async {
            final name = nameController.text.trim();
            if (name.isNotEmpty) {
              await tagViewModel.createNestedGroup(subGroupTag.id, name);
              // Event system will handle UI update
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            }
          },
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
                await tagViewModel.createNestedGroup(subGroupTag.id, name);
                // Event system will handle UI update
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              }
            },
            child: Text(context.t.common.create),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Reference Song List - shows songs from a referenced collection (read-only)
// =============================================================================

class _ReferenceSongList extends StatelessWidget {
  const _ReferenceSongList({
    required this.refTag,
    required this.refItems,
    required this.onPlaySong,
  });

  final Tag refTag;
  final List<PlaylistItem> refItems;
  final ValueChanged<String> onPlaySong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final libraryVM = context.read<LibraryViewModel>();

    final songItems = refItems
        .where((i) => i.type == PlaylistItemType.songUnit)
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
