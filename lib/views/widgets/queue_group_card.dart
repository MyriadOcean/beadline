import 'package:flutter/material.dart';

import '../../i18n/translations.g.dart';
import '../../models/playlist_metadata.dart';
import '../../viewmodels/player_view_model.dart';
import '../../viewmodels/tag_view_model.dart';
import 'queue_drag_data.dart';
import 'queue_group_dialogs.dart';
import 'queue_group_song_item.dart';

/// Card widget for displaying a queue group with expand/collapse and drag-drop
class QueueGroupCard extends StatelessWidget {
  const QueueGroupCard({
    required this.item,
    required this.tagViewModel,
    required this.playerViewModel,
    required this.useThumbnailBackground,
    required this.isCollapsed,
    required this.onToggleCollapse,
    required this.groupInsertionGroupId,
    required this.groupInsertionIndex,
    required this.onGroupInsertionChanged,
    super.key,
  });

  final QueueDisplayItem item;
  final TagViewModel tagViewModel;
  final PlayerViewModel playerViewModel;
  final bool useThumbnailBackground;
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;
  final String? groupInsertionGroupId;
  final int? groupInsertionIndex;
  final Function(String?, int?) onGroupInsertionChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Find the group's PlaylistItem ID for drag operations
    String? groupPlaylistItemId;
    final activeQueue = tagViewModel.allTags
        .where((t) => t.id == tagViewModel.activeQueueId)
        .firstOrNull;
    if (activeQueue?.playlistMetadata != null) {
      final queueItem = activeQueue!.playlistMetadata!.items
          .where(
            (i) =>
                i.type == PlaylistItemType.collectionReference &&
                i.targetId == item.groupId,
          )
          .firstOrNull;
      groupPlaylistItemId = queueItem?.id;
    }

    final dragData = groupPlaylistItemId != null
        ? QueueDragData.group(
            groupItemId: groupPlaylistItemId,
            groupId: item.groupId!,
          )
        : QueueDragData.group(groupItemId: '', groupId: item.groupId ?? '');

    return DragTarget<QueueDragData>(
      onWillAcceptWithDetails: (details) {
        final data = details.data;
        if (data.isGroup) {
          return data.groupId != item.groupId;
        }
        return !item.isLocked;
      },
      onAcceptWithDetails: (details) async {
        final data = details.data;
        if (data.isGroup && data.groupItemId != null && item.groupId != null) {
          await tagViewModel.moveGroupIntoGroup(
            tagViewModel.activeQueueId,
            data.groupItemId!,
            item.groupId!,
          );
          return;
        }
        if (data.isSong &&
            data.playlistItemId != null &&
            item.groupId != null) {
          if (data.songGroupId != null && data.songGroupId != item.groupId) {
            await tagViewModel.moveSongUnitToGroup(
              tagViewModel.activeQueueId,
              data.playlistItemId!,
              item.groupId!,
            );
            return;
          }
          if (data.songGroupId == null) {
            await tagViewModel.moveSongUnitToGroup(
              tagViewModel.activeQueueId,
              data.playlistItemId!,
              item.groupId!,
            );
          }
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isDropTarget = candidateData.isNotEmpty;
        return _buildCardContent(
          context,
          theme,
          isDropTarget,
          dragData,
        );
      },
    );
  }

  Widget _buildCardContent(
    BuildContext context,
    ThemeData theme,
    bool isDropTarget,
    QueueDragData dragData,
  ) {
    final isExpanded = !isCollapsed;
    final isLocked = item.isLocked;

    final dragFeedback = Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              '${item.groupName} (${item.songCount})',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );

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
          LongPressDraggable<QueueDragData>(
            data: dragData,
            feedback: dragFeedback,
            childWhenDragging: Opacity(
              opacity: 0.3,
              child: _buildHeaderRow(context, theme, isExpanded, isLocked, isDropTarget),
            ),
            child: _buildHeaderRow(context, theme, isExpanded, isLocked, isDropTarget),
          ),
          if (isExpanded) _buildSongList(context, theme),
        ],
      ),
    );
  }

  Widget _buildHeaderRow(
    BuildContext context,
    ThemeData theme,
    bool isExpanded,
    bool isLocked,
    bool isDropTarget,
  ) {
    return GestureDetector(
      onSecondaryTapUp: (details) {
        _showGroupContextMenu(context, details.globalPosition);
      },
      onLongPressStart: (details) {
        _showGroupContextMenu(context, details.globalPosition);
      },
      child: Container(
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
                      '${item.groupName ?? ''}${isDropTarget ? ' - ${context.t.playlists.dropHere}' : ''}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${item.songCount} ${item.songCount == 1 ? context.t.playlists.song : context.t.playlists.songs}'
                      '${isLocked ? ' - ${context.t.playlists.locked}' : ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isLocked
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
                onPressed: onToggleCollapse,
                tooltip: isExpanded ? context.t.queue.collapse : context.t.queue.expand,
              ),
            ),
            SizedBox(
              width: 32,
              height: 32,
              child: _buildActionsMenu(context, theme),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  void _showGroupContextMenu(BuildContext context, Offset position) {
    final tagVM = tagViewModel;
    final playerVM = playerViewModel;
    
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
            leading: Icon(
              item.isLocked ? Icons.lock_open : Icons.lock,
            ),
            title: Text(
              item.isLocked ? context.t.playlists.unlock : context.t.playlists.lock,
            ),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'add_nested_group',
          child: ListTile(
            leading: const Icon(Icons.create_new_folder_outlined),
            title: Text(context.t.dialogs.home.addNestedGroup),
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
        if (tagVM.queue.length > 1)
          PopupMenuItem(
            value: 'deduplicate',
            child: ListTile(
              leading: const Icon(Icons.filter_1),
              title: Text(context.t.queue.removeDuplicates),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (tagVM.queue.length > 1)
          PopupMenuItem(
            value: 'shuffle',
            child: ListTile(
              leading: const Icon(Icons.shuffle),
              title: Text(context.t.queue.shuffle),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        PopupMenuItem(
          value: 'toggle_remove_after_play',
          child: ListTile(
            leading: Icon(
              tagVM.removeAfterPlay ? Icons.check_box : Icons.check_box_outline_blank,
            ),
            title: Text(
              tagVM.removeAfterPlay
                  ? context.t.queue.removeAfterPlayOn
                  : context.t.queue.removeAfterPlayOff,
            ),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        if (tagVM.queue.isNotEmpty)
          PopupMenuItem(
            value: 'clear',
            child: ListTile(
              leading: const Icon(Icons.clear_all),
              title: Text(context.t.queue.clearQueue),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
      ],
    ).then((value) async {
      if (value == null || !context.mounted) return;
      switch (value) {
        case 'rename':
          if (item.groupId != null) {
            showRenameGroupDialog(context, tagViewModel, item);
          }
          break;
        case 'toggle_lock':
          if (item.groupId != null) {
            tagViewModel.toggleLock(item.groupId!);
          }
          break;
        case 'add_nested_group':
          if (item.groupId != null) {
            showCreateNestedGroupDialog(context, tagViewModel, item.groupId!);
          }
          break;
        case 'remove':
          if (item.groupId != null) {
            showRemoveGroupDialog(context, tagViewModel, item);
          }
          break;
        case 'deduplicate':
          final removedCount = await tagVM.deduplicateQueue();
          if (!context.mounted) return;
          if (removedCount > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.t.queue.removedDuplicates.replaceAll('{count}', removedCount.toString())),
                duration: const Duration(seconds: 2),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.t.queue.noDuplicates),
                duration: const Duration(seconds: 2),
              ),
            );
          }
          break;
        case 'shuffle':
          await tagVM.shuffle(tagVM.activeQueueId);
          break;
        case 'toggle_remove_after_play':
          tagVM.setRemoveAfterPlay(!tagVM.removeAfterPlay);
          break;
        case 'clear':
          await playerVM.stop();
          await tagVM.clearQueue();
          break;
      }
    });
  }

  Widget _buildActionsMenu(BuildContext context, ThemeData theme) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        size: 18,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      padding: EdgeInsets.zero,
      tooltip: context.t.queue.groupActions,
      onSelected: (value) {
        switch (value) {
          case 'rename':
            if (item.groupId != null) {
              showRenameGroupDialog(context, tagViewModel, item);
            }
            break;
          case 'toggle_lock':
            if (item.groupId != null) {
              tagViewModel.toggleLock(item.groupId!);
            }
            break;
          case 'add_nested_group':
            if (item.groupId != null) {
              showCreateNestedGroupDialog(context, tagViewModel, item.groupId!);
            }
            break;
          case 'remove':
            if (item.groupId != null) {
              showRemoveGroupDialog(context, tagViewModel, item);
            }
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'rename',
          child: ListTile(
            leading: const Icon(Icons.edit),
            title: Text(context.t.dialogs.home.rename),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'toggle_lock',
          child: ListTile(
            leading: Icon(
              item.isLocked ? Icons.lock_open : Icons.lock,
            ),
            title: Text(
              item.isLocked
                  ? context.t.playlists.unlock
                  : context.t.playlists.lock,
            ),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'add_nested_group',
          child: ListTile(
            leading: const Icon(Icons.create_new_folder_outlined),
            title: Text(context.t.dialogs.home.addNestedGroup),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'remove',
          child: ListTile(
            leading: const Icon(Icons.remove_circle_outline),
            title: Text(context.t.dialogs.home.remove),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Widget _buildSongList(BuildContext context, ThemeData theme) {
    final subItems = item.subItems ?? [];
    if (subItems.isEmpty) {
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

    final currentIndex = tagViewModel.currentIndex;
    final groupId = item.groupId!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < subItems.length; i++) ...[
          _buildGroupInsertionDropZone(i, groupId, theme),
          if (subItems[i].isGroup)
            // Nested sub-group (recursive)
            QueueGroupCard(
              item: subItems[i],
              tagViewModel: tagViewModel,
              playerViewModel: playerViewModel,
              useThumbnailBackground: useThumbnailBackground,
              isCollapsed: false, // Nested groups start expanded
              onToggleCollapse: () {}, // Nested groups don't collapse for simplicity
              groupInsertionGroupId: groupInsertionGroupId,
              groupInsertionIndex: groupInsertionIndex,
              onGroupInsertionChanged: onGroupInsertionChanged,
            )
          else
            QueueGroupSongItem(
              item: subItems[i],
              parentGroupId: groupId,
              isPlaying: subItems[i].flatIndex == currentIndex,
              tagViewModel: tagViewModel,
              playerViewModel: playerViewModel,
              useThumbnailBackground: useThumbnailBackground,
            ),
        ],
      ],
    );
  }

  Widget _buildGroupInsertionDropZone(int index, String groupId, ThemeData theme) {
    return DragTarget<QueueDragData>(
      onWillAcceptWithDetails: (details) {
        onGroupInsertionChanged(groupId, index);
        return true;
      },
      onLeave: (_) {
        if (groupInsertionGroupId == groupId && groupInsertionIndex == index) {
          onGroupInsertionChanged(null, null);
        }
      },
      onAcceptWithDetails: (details) async {
        final data = details.data;
        onGroupInsertionChanged(null, null);

        if (data.isGroup && data.groupItemId != null) {
          await tagViewModel.moveGroupOutToCollection(
            tagViewModel.activeQueueId,
            data.groupItemId!,
            groupId,
            index,
          );
        } else if (data.isSong && data.playlistItemId != null) {
          if (data.songGroupId == groupId) {
            await tagViewModel.reorderCollection(groupId, data.flatIndex, index);
          } else {
            await tagViewModel.moveSongUnitToGroup(
              tagViewModel.activeQueueId,
              data.playlistItemId!,
              groupId,
            );
          }
        }
      },
      builder: (context, candidateData, rejectedData) {
        final showLine =
            groupInsertionGroupId == groupId &&
            groupInsertionIndex == index &&
            candidateData.isNotEmpty;
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
}
