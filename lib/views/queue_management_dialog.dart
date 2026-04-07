import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../i18n/translations.g.dart';
import '../models/song_unit.dart';
import '../models/tag_extensions.dart';
import '../viewmodels/library_view_model.dart';
import '../viewmodels/player_view_model.dart';
import '../viewmodels/tag_view_model.dart';
import 'widgets/bulk_action_toolbar.dart';
import 'widgets/cached_thumbnail.dart';
import 'widgets/group_picker_dialog.dart';

/// Dialog for managing multiple queues and viewing queue contents
class QueueManagementDialog extends StatefulWidget {
  const QueueManagementDialog({super.key});

  @override
  State<QueueManagementDialog> createState() => _QueueManagementDialogState();
}

class _QueueManagementDialogState extends State<QueueManagementDialog> {
  bool _showQueueContent = false;
  String? _selectedQueueId;
  List<Tag>? _queues;
  bool _isLoadingQueues = true;

  @override
  void initState() {
    super.initState();
    _loadQueues();
  }

  Future<void> _loadQueues() async {
    setState(() => _isLoadingQueues = true);
    final tagVM = context.read<TagViewModel>();
    final queues = await tagVM.allQueues;
    if (mounted) {
      setState(() {
        _queues = queues;
        _isLoadingQueues = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tagVM = context.watch<TagViewModel>();
    final playerVM = context.watch<PlayerViewModel>();
    final libraryVM = context.watch<LibraryViewModel>();
    final activeQueueId = tagVM.activeQueueId;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_showQueueContent) ...[
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        setState(() {
                          _showQueueContent = false;
                          _selectedQueueId = null;
                        });
                      },
                      tooltip: context.t.queue.backToQueues,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Icon(Icons.queue_music, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    _showQueueContent ? context.t.queue.queueContent : context.t.queue.manageQueues,
                    style: theme.textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Content
            Expanded(
              child: _showQueueContent && _selectedQueueId != null
                  ? _QueueContentView(
                      queueId: _selectedQueueId!,
                      tagVM: tagVM,
                      libraryVM: libraryVM,
                    )
                  : _buildQueueList(context, tagVM, playerVM, activeQueueId),
            ),
            if (!_showQueueContent) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _showCreateDialog(context),
                    icon: const Icon(Icons.add),
                    label: Text(context.t.queue.createQueue),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQueueList(
    BuildContext context,
    TagViewModel tagVM,
    PlayerViewModel playerVM,
    String activeQueueId,
  ) {
    final theme = Theme.of(context);

    if (_isLoadingQueues) {
      return const Center(child: CircularProgressIndicator());
    }
    final queues = _queues ?? [];

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: queues.length,
      itemBuilder: (context, index) {
        final queue = queues[index];
        final isActive = queue.id == activeQueueId;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          color: isActive ? theme.colorScheme.primaryContainer : null,
          child: ListTile(
            leading: Icon(
              isActive ? Icons.play_circle : Icons.queue_music,
              color: isActive ? theme.colorScheme.onPrimaryContainer : null,
            ),
            title: Text(
              queue.name,
              style: isActive
                  ? TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    )
                  : null,
            ),
            subtitle: Text(
              context.t.queue.songs.replaceAll('{count}', '${queue.itemCount}') +
                  (isActive ? ' · ${context.t.common.on}' : ''),
              style: isActive
                  ? TextStyle(color: theme.colorScheme.onPrimaryContainer)
                  : null,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.visibility),
                  onPressed: () {
                    setState(() {
                      _showQueueContent = true;
                      _selectedQueueId = queue.id;
                    });
                  },
                  tooltip: context.t.playlists.viewContent,
                ),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    switch (value) {
                      case 'switch':
                        await tagVM.switchQueue(queue.id, playerVM: playerVM);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                        break;
                      case 'rename':
                        _showRenameDialog(context, queue);
                        break;
                      case 'duplicate':
                        await tagVM.duplicateQueue(queue.id);
                        _loadQueues();
                        break;
                      case 'delete':
                        _showDeleteDialog(context, queue);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    if (!isActive)
                      PopupMenuItem(
                        value: 'switch',
                        child: ListTile(
                          leading: const Icon(Icons.swap_horiz),
                          title: Text(context.t.queue.switchToQueue),
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
                      value: 'duplicate',
                      child: ListTile(
                        leading: const Icon(Icons.content_copy),
                        title: Text(context.t.common.duplicate),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    if (!isActive && queues.length > 1)
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
                ),
              ],
            ),
            onTap: isActive
                ? null
                : () async {
                    await tagVM.switchQueue(queue.id, playerVM: playerVM);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
          ),
        );
      },
    );
  }

  void _showCreateDialog(BuildContext context) {
    final nameController = TextEditingController();
    final tagVM = context.read<TagViewModel>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t.queue.createQueue),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: context.t.queue.queueName,
            hintText: context.t.queue.enterQueueName,
          ),
          autofocus: true,
          onSubmitted: (value) async {
            if (value.trim().isNotEmpty) {
              await tagVM.createCollection(value.trim(), isQueue: true);
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              _loadQueues();
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
                await tagVM.createCollection(name, isQueue: true);
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                _loadQueues();
              }
            },
            child: Text(context.t.common.create),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, Tag queue) {
    final nameController = TextEditingController(text: queue.name);
    final tagVM = context.read<TagViewModel>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t.queue.renameQueue),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: context.t.queue.queueName,
            hintText: context.t.queue.enterNewName,
          ),
          autofocus: true,
          onSubmitted: (value) async {
            if (value.trim().isNotEmpty && value.trim() != queue.name) {
              await tagVM.renameTag(queue.id, value.trim());
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              _loadQueues();
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
              if (name.isNotEmpty && name != queue.name) {
                await tagVM.renameTag(queue.id, name);
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                _loadQueues();
              }
            },
            child: Text(context.t.common.rename),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, Tag queue) {
    final tagVM = context.read<TagViewModel>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t.queue.deleteQueue),
        content: Text(
          '${context.t.queue.deleteQueueConfirm} "${queue.name}"?\n\n'
          '${context.t.queue.deleteQueueWillRemove} ${queue.itemCount} ${context.t.queue.deleteQueueFromQueue}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.t.common.cancel),
          ),
          TextButton(
            onPressed: () async {
              await tagVM.deleteTag(queue.id);
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
              _loadQueues();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(context.t.common.delete),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Drag-and-drop data types
// ---------------------------------------------------------------------------

/// Data carried during a drag operation
class _DragData {
  const _DragData({
    required this.itemId,
    required this.sourceCollectionId,
    required this.type,
    this.groupTagId,
  });

  final String itemId;
  final String sourceCollectionId;
  final _DisplayItemType type;
  final String? groupTagId;
}

enum _DisplayItemType { song, group }

/// Visual item in the queue list: either a standalone song or a group
class _QueueDisplayItem {
  _QueueDisplayItem.song({
    required this.playlistItem,
    required this.songTitle,
    required this.songArtist,
    required this.flatIndex,
  }) : type = _DisplayItemType.song,
       groupTag = null,
       groupSongs = const [];

  _QueueDisplayItem.group({
    required this.playlistItem,
    required this.groupTag,
    required this.groupSongs,
  }) : type = _DisplayItemType.group,
       songTitle = '',
       songArtist = '',
       flatIndex = -1;

  final _DisplayItemType type;
  final TagItem playlistItem;
  final String songTitle;
  final String songArtist;
  final int flatIndex;
  final Tag? groupTag;
  final List<_GroupSongInfo> groupSongs;
}

class _GroupSongInfo {
  const _GroupSongInfo({
    required this.title,
    required this.artist,
    required this.songUnitId,
    required this.flatIndex,
    required this.playlistItemId,
  });
  final String title;
  final String artist;
  final String songUnitId;
  final int flatIndex;
  final String playlistItemId;
}

// ---------------------------------------------------------------------------
// Queue content view with drag-and-drop grouping
// ---------------------------------------------------------------------------

class _QueueContentView extends StatefulWidget {
  const _QueueContentView({
    required this.queueId,
    required this.tagVM,
    required this.libraryVM,
  });

  final String queueId;
  final TagViewModel tagVM;
  final LibraryViewModel libraryVM;

  @override
  State<_QueueContentView> createState() => _QueueContentViewState();
}

class _QueueContentViewState extends State<_QueueContentView> {
  final Set<String> _expandedGroups = {};
  List<_QueueDisplayItem>? _displayItems;
  bool _isLoading = true;

  // Drag visual state
  String? _hoveredGroupId;
  int? _insertionIndex;

  @override
  void initState() {
    super.initState();
    _loadDisplayItems();
  }

  @override
  void didUpdateWidget(covariant _QueueContentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.queueId != widget.queueId) {
      _loadDisplayItems();
    }
  }

  Future<void> _loadDisplayItems() async {
    setState(() => _isLoading = true);
    try {
      final tag = await widget.tagVM.activeQueue;
      if (tag == null || tag.metadata == null) {
        setState(() {
          _displayItems = [];
          _isLoading = false;
        });
        return;
      }

      final metadata = tag.metadata!;
      final items = <_QueueDisplayItem>[];
      var flatIndex = 0;

      for (final item in metadata.items) {
        if (item.itemType == TagItemType.tagReference) {
          final groupTag = await widget.tagVM.getTagAsync(item.targetId);
          if (groupTag != null && groupTag.isCollection) {
            final groupMeta = groupTag.metadata!;
            final groupSongs = <_GroupSongInfo>[];
            for (final groupItem in groupMeta.items) {
              if (groupItem.itemType == TagItemType.songUnit) {
                final su = await widget.libraryVM.getSongUnit(
                  groupItem.targetId,
                );
                groupSongs.add(
                  _GroupSongInfo(
                    title: su?.metadata.title ?? 'Unknown',
                    artist: su?.metadata.artistDisplay ?? '',
                    songUnitId: groupItem.targetId,
                    flatIndex: flatIndex,
                    playlistItemId: groupItem.id,
                  ),
                );
                flatIndex++;
              }
            }
            items.add(
              _QueueDisplayItem.group(
                playlistItem: item,
                groupTag: groupTag,
                groupSongs: groupSongs,
              ),
            );
          }
        } else {
          final queueSongs = widget.tagVM.queueSongUnits;
          var title = 'Unknown';
          var artist = '';
          if (flatIndex < queueSongs.length) {
            title = queueSongs[flatIndex].metadata.title;
            artist = queueSongs[flatIndex].metadata.artistDisplay;
          }
          items.add(
            _QueueDisplayItem.song(
              playlistItem: item,
              songTitle: title,
              songArtist: artist,
              flatIndex: flatIndex,
            ),
          );
          flatIndex++;
        }
      }

      setState(() {
        _displayItems = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _displayItems = [];
        _isLoading = false;
      });
    }
  }

  // ---------- build ----------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final items = _displayItems ?? [];
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.queue_music, size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              context.t.queue.empty,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    final currentIndex = widget.tagVM.currentIndex;
    final hasSelection = widget.tagVM.hasSelection;

    return Column(
      children: [
        if (hasSelection)
          BulkActionToolbar(
            selectionCount: widget.tagVM.selectionCount,
            onMoveToGroup: () => _showGroupPicker(context),
            onRemoveFromGroup: () => _bulkRemoveFromGroup(context),
            onClearSelection: () => widget.tagVM.clearSelection(),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _wrapWithDropTarget(
                index: index,
                theme: theme,
                child: item.type == _DisplayItemType.group
                    ? _buildGroupCard(context, item, index, currentIndex, theme)
                    : _buildSongTile(context, item, index, currentIndex, theme),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Show group picker dialog for bulk move
  Future<void> _showGroupPicker(BuildContext context) async {
    // Collect groups from the queue's display items
    final groups = <Tag>[];
    for (final item in _displayItems ?? []) {
      if (item.type == _DisplayItemType.group && item.groupTag != null) {
        groups.add(item.groupTag!);
      }
    }

    final selectedGroupId = await showDialog<String>(
      context: context,
      builder: (_) => GroupPickerDialog(groups: groups),
    );

    if (selectedGroupId != null && context.mounted) {
      await widget.tagVM.bulkMoveToGroup(widget.queueId, selectedGroupId);
      await _loadDisplayItems();
    }
  }

  /// Bulk remove selected items from their groups
  Future<void> _bulkRemoveFromGroup(BuildContext context) async {
    await widget.tagVM.bulkRemoveFromGroup(widget.queueId);
    await _loadDisplayItems();
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
    return DragTarget<_DragData>(
      onWillAcceptWithDetails: (details) {
        // Don't accept song drops on group items - the inner group DragTarget handles those
        final items = _displayItems ?? [];
        if (details.data.type != _DisplayItemType.group &&
            index < items.length &&
            items[index].type == _DisplayItemType.group) {
          return false;
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

        if (data.type == _DisplayItemType.group) {
          // Reorder a group
          await widget.tagVM.moveGroup(widget.queueId, data.itemId, index);
        } else if (data.sourceCollectionId == widget.queueId) {
          // Reorder a top-level song
          final oldIdx = _indexOfItem(data.itemId);
          if (oldIdx >= 0 && oldIdx != index) {
            await widget.tagVM.reorderCollection(widget.queueId, oldIdx, index);
          }
        } else {
          // Move song out of a group to top-level
          await widget.tagVM.moveSongUnitOutOfGroup(
            data.sourceCollectionId,
            data.itemId,
            widget.queueId,
            insertIndex: index,
          );
        }
        await _loadDisplayItems();
      },
      builder: (context, candidateData, rejectedData) {
        final showLine = _insertionIndex == index && candidateData.isNotEmpty;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showLine)
              Container(
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            child,
          ],
        );
      },
    );
  }

  int _indexOfItem(String itemId) {
    final items = _displayItems ?? [];
    for (var i = 0; i < items.length; i++) {
      if (items[i].playlistItem.id == itemId) {
        return i;
      }
    }
    return -1;
  }

  // ---------- group card (draggable + drop target) ----------

  Widget _buildGroupCard(
    BuildContext context,
    _QueueDisplayItem item,
    int index,
    int currentIndex,
    ThemeData theme,
  ) {
    final groupTag = item.groupTag!;
    final isLocked = groupTag.isLocked;
    final isExpanded = _expandedGroups.contains(groupTag.id);
    final songCount = item.groupSongs.length;
    final hasCurrentSong = item.groupSongs.any(
      (s) => s.flatIndex == currentIndex,
    );

    return LongPressDraggable<_DragData>(
      key: ValueKey('group_${groupTag.id}'),
      data: _DragData(
        itemId: item.playlistItem.id,
        sourceCollectionId: widget.queueId,
        type: _DisplayItemType.group,
        groupTagId: groupTag.id,
      ),
      feedback: Material(
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
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _groupCardBody(
          context,
          item,
          index,
          currentIndex,
          theme,
          groupTag: groupTag,
          isLocked: isLocked,
          isExpanded: false,
          songCount: songCount,
          hasCurrentSong: hasCurrentSong,
          isDropTarget: false,
        ),
      ),
      // The group header is also a DragTarget for dropping songs into it
      child: DragTarget<_DragData>(
        onWillAcceptWithDetails: (details) {
          if (details.data.type == _DisplayItemType.group) {
            return false;
          }
          if (isLocked) {
            return false;
          }
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
          await widget.tagVM.moveSongUnitToGroup(
            widget.queueId,
            details.data.itemId,
            groupTag.id,
          );
          await _loadDisplayItems();
        },
        builder: (context, candidateData, rejectedData) {
          final isTarget =
              _hoveredGroupId == groupTag.id && candidateData.isNotEmpty;
          return _groupCardBody(
            context,
            item,
            index,
            currentIndex,
            theme,
            groupTag: groupTag,
            isLocked: isLocked,
            isExpanded: isExpanded,
            songCount: songCount,
            hasCurrentSong: hasCurrentSong,
            isDropTarget: isTarget,
          );
        },
      ),
    );
  }

  Widget _groupCardBody(
    BuildContext context,
    _QueueDisplayItem item,
    int index,
    int currentIndex,
    ThemeData theme, {
    required Tag groupTag,
    required bool isLocked,
    required bool isExpanded,
    required int songCount,
    required bool hasCurrentSong,
    required bool isDropTarget,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: isDropTarget ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isDropTarget
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : hasCurrentSong
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            decoration: BoxDecoration(
              color: isDropTarget
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: isExpanded
                  ? const BorderRadius.vertical(top: Radius.circular(12))
                  : BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.drag_handle,
                    color: theme.colorScheme.onSurfaceVariant,
                    semanticLabel: 'Drag to reorder group',
                  ),
                ),
                Icon(Icons.folder, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                          context.t.queue.songs.replaceAll('{count}', '$songCount') +
                              (isDropTarget ? ' - ${context.t.common.add}' : ''),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDropTarget
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isLocked ? Icons.lock : Icons.lock_open,
                    size: 20,
                    color: isLocked
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () {
                    widget.tagVM.toggleLock(groupTag.id);
                    _loadDisplayItems();
                  },
                  tooltip: isLocked ? 'Unlock group' : 'Lock group',
                ),
                IconButton(
                  icon: Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedGroups.remove(groupTag.id);
                      } else {
                        _expandedGroups.add(groupTag.id);
                      }
                    });
                  },
                  tooltip: isExpanded ? 'Collapse' : 'Expand',
                ),
              ],
            ),
          ),
          // Expanded songs - each is draggable out of the group
          if (isExpanded)
            ...item.groupSongs.map(
              (song) => _buildGroupSongTile(
                context,
                song,
                groupTag,
                song.flatIndex == currentIndex,
                theme,
              ),
            ),
        ],
      ),
    );
  }

  // ---------- thumbnail helper ----------

  /// Look up a SongUnit by ID and return a CachedThumbnail if it has one,
  /// otherwise return the given fallback icon widget.
  Widget _buildSongThumbnailOrIcon(
    String? songUnitId,
    double radius,
    ThemeData theme, {
    bool isCurrent = false,
  }) {
    SongUnit? su;
    if (songUnitId != null) {
      su = widget.libraryVM.songUnits
          .where((s) => s.id == songUnitId)
          .firstOrNull;
    }
    if (su != null && su.metadata.thumbnailSourceId != null) {
      return ClipOval(
        child: CachedThumbnail(
          metadata: su.metadata,
          width: radius * 2,
          height: radius * 2,
          placeholderIcon: isCurrent ? Icons.play_arrow : Icons.music_note,
          placeholderColor: isCurrent
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSurfaceVariant,
          placeholderBackgroundColor: isCurrent
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
        ),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: isCurrent
          ? theme.colorScheme.primary
          : theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        isCurrent ? Icons.play_arrow : Icons.music_note,
        size: radius,
        color: isCurrent
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  // ---------- song tile inside a group (draggable) ----------

  Widget _buildGroupSongTile(
    BuildContext context,
    _GroupSongInfo song,
    Tag groupTag,
    bool isCurrent,
    ThemeData theme,
  ) {
    final hasSelection = widget.tagVM.hasSelection;
    final isSelected = widget.tagVM.isSelected(song.playlistItemId);

    return LongPressDraggable<_DragData>(
      data: _DragData(
        itemId: song.playlistItemId,
        sourceCollectionId: groupTag.id,
        type: _DisplayItemType.song,
      ),
      // Disable drag when in selection mode
      maxSimultaneousDrags: hasSelection ? 0 : 1,
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
                  song.title,
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
          leading: _buildSongThumbnailOrIcon(song.songUnitId, 14, theme),
          title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            song.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      child: ListTile(
        dense: true,
        selected: isSelected,
        selectedTileColor: theme.colorScheme.primaryContainer.withValues(
          alpha: 0.5,
        ),
        leading: hasSelection
            ? Checkbox(
                value: isSelected,
                onChanged: (_) =>
                    widget.tagVM.toggleSelection(song.playlistItemId),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.drag_handle,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                    semanticLabel: 'Drag to move song',
                  ),
                  const SizedBox(width: 4),
                  _buildSongThumbnailOrIcon(
                    song.songUnitId,
                    14,
                    theme,
                    isCurrent: isCurrent,
                  ),
                ],
              ),
        title: Text(
          song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: isCurrent
              ? TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                )
              : null,
        ),
        subtitle: Text(
          song.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: hasSelection
            ? () => widget.tagVM.toggleSelection(song.playlistItemId)
            : () async => widget.tagVM.jumpTo(song.flatIndex),
        onLongPress: hasSelection
            ? null
            : () => widget.tagVM.toggleSelection(song.playlistItemId),
      ),
    );
  }

  // ---------- top-level song tile (draggable) ----------

  Widget _buildSongTile(
    BuildContext context,
    _QueueDisplayItem item,
    int index,
    int currentIndex,
    ThemeData theme,
  ) {
    final isCurrent = item.flatIndex == currentIndex;
    final hasSelection = widget.tagVM.hasSelection;
    final isSelected = widget.tagVM.isSelected(item.playlistItem.id);

    return LongPressDraggable<_DragData>(
      key: ValueKey('song_${item.playlistItem.id}'),
      data: _DragData(
        itemId: item.playlistItem.id,
        sourceCollectionId: widget.queueId,
        type: _DisplayItemType.song,
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
                  item.songTitle,
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
          margin: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.drag_handle,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Expanded(
                child: ListTile(
                  dense: true,
                  title: Text(
                    item.songTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    item.songArtist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 2),
        color: isSelected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
            : isCurrent
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
            : null,
        child: Row(
          children: [
            if (hasSelection)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Checkbox(
                  value: isSelected,
                  onChanged: (_) =>
                      widget.tagVM.toggleSelection(item.playlistItem.id),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.drag_handle,
                  color: theme.colorScheme.onSurfaceVariant,
                  semanticLabel: 'Drag to reorder or move into group',
                ),
              ),
            Expanded(
              child: ListTile(
                dense: true,
                leading: _buildSongThumbnailOrIcon(
                  item.playlistItem.targetId,
                  16,
                  theme,
                  isCurrent: isCurrent,
                ),
                title: Text(
                  item.songTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: isCurrent
                      ? TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        )
                      : null,
                ),
                subtitle: Text(
                  item.songArtist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: hasSelection
                    ? null
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isCurrent)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                context.t.player.noSongPlaying,
                                style: TextStyle(
                                  color: theme.colorScheme.onPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () {
                              widget.tagVM.removeFromCollection(
                                widget.queueId,
                                item.playlistItem.id,
                              );
                              _loadDisplayItems();
                            },
                            tooltip: context.t.common.remove,
                          ),
                        ],
                      ),
                onTap: hasSelection
                    ? () => widget.tagVM.toggleSelection(item.playlistItem.id)
                    : () async => widget.tagVM.jumpTo(item.flatIndex),
                onLongPress: hasSelection
                    ? null
                    : () => widget.tagVM.toggleSelection(item.playlistItem.id),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
