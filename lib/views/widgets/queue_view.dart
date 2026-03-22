import 'dart:async';

import 'package:flutter/material.dart';

import '../../i18n/translations.g.dart';
import '../../viewmodels/player_view_model.dart';
import '../../viewmodels/settings_view_model.dart';
import '../../viewmodels/tag_view_model.dart';
import '../queue_management_dialog.dart';
import 'queue_drag_data.dart';
import 'queue_group_card.dart';
import 'queue_item_tile.dart';

/// Queue view widget for displaying and managing the playback queue
class QueueView extends StatefulWidget {
  const QueueView({
    required this.tagViewModel,
    required this.playerViewModel,
    required this.settingsViewModel,
    super.key,
  });

  final TagViewModel tagViewModel;
  final PlayerViewModel playerViewModel;
  final SettingsViewModel settingsViewModel;

  @override
  State<QueueView> createState() => _QueueViewState();
}

class _QueueViewState extends State<QueueView> {
  // Queue group expand/collapse state (groups expanded by default; this tracks collapsed ones)
  final Set<String> _collapsedQueueGroups = {};

  // Drag insertion indicator state for queue
  int? _queueInsertionIndex;
  // Insertion indicator for items inside a group (key: groupId, value: index)
  String? _groupInsertionGroupId;
  int? _groupInsertionIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final queue = widget.tagViewModel.queue;
    final displayItems = widget.tagViewModel.queueDisplayItems;
    final currentIndex = widget.tagViewModel.currentIndex;
    final useThumbnailBackground =
        widget.settingsViewModel.settings.useThumbnailBackgroundInQueue;



    return Card(
      margin: const EdgeInsets.all(8),
      child: Column(
        children: [
          // Header
          _buildHeader(context, theme, queue),
          const Divider(height: 1),
          // Queue list
          Expanded(
            child: displayItems.isEmpty
                ? _buildEmptyState(context, theme)
                : _buildQueueList(
                    context,
                    theme,
                    displayItems,
                    currentIndex,
                    useThumbnailBackground,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme, List queue) {
    return GestureDetector(
      onSecondaryTapUp: (details) {
        _showQueueContextMenu(context, details.globalPosition);
      },
      onLongPressStart: (details) {
        _showQueueContextMenu(context, details.globalPosition);
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.queue_music, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.t.queue.title,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    context.t.queue.songs.replaceAll('{count}', queue.length.toString()),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // Queue management button
            IconButton(
              icon: const Icon(Icons.library_music),
              onPressed: () {
                unawaited(
                  showDialog(
                    context: context,
                    builder: (context) => const QueueManagementDialog(),
                  ),
                );
              },
              tooltip: context.t.queue.manage,
            ),
            // Queue actions menu
            if (queue.isNotEmpty) _buildActionsMenu(context),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsMenu(BuildContext context) {
    final tagVM = widget.tagViewModel;
    final playerVM = widget.playerViewModel;

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      tooltip: context.t.queue.actions,
      onSelected: (value) async {
        switch (value) {
          case 'deduplicate':
            final removedCount = await tagVM.deduplicateQueue();
            if (!context.mounted) return;
            if (removedCount > 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    context.t.queue.removedDuplicates.replaceAll('{count}', removedCount.toString()),
                  ),
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
            unawaited(tagVM.shuffle(tagVM.activeQueueId));
            break;
          case 'toggle_remove_after_play':
            tagVM.setRemoveAfterPlay(!tagVM.removeAfterPlay);
            break;
          case 'clear':
            unawaited(playerVM.stop());
            unawaited(tagVM.clearQueue());
            break;
        }
      },
      itemBuilder: (context) => [
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
              title: Text(context.t.dialogs.home.shuffle),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        PopupMenuItem(
          value: 'toggle_remove_after_play',
          child: ListTile(
            leading: Icon(
              tagVM.removeAfterPlay
                  ? Icons.playlist_remove
                  : Icons.playlist_play,
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
    );
  }

  void _showQueueContextMenu(BuildContext context, Offset position) {
    final tagVM = widget.tagViewModel;
    final playerVM = widget.playerViewModel;
    
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
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
        case 'deduplicate':
          final removedCount = await tagVM.deduplicateQueue();
          if (!context.mounted) return;
          if (removedCount > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  context.t.queue.removedDuplicates.replaceAll('{count}', removedCount.toString()),
                ),
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
          unawaited(tagVM.shuffle(tagVM.activeQueueId));
          break;
        case 'toggle_remove_after_play':
          tagVM.setRemoveAfterPlay(!tagVM.removeAfterPlay);
          break;
        case 'clear':
          unawaited(playerVM.stop());
          unawaited(tagVM.clearQueue());
          break;
      }
    });
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return GestureDetector(
      onSecondaryTapDown: (details) {
        _showQueueContextMenu(context, details.globalPosition);
      },
      onLongPressStart: (details) {
        _showQueueContextMenu(context, details.globalPosition);
      },
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            Icon(
              Icons.queue_music,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              context.t.queue.empty,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildQueueList(
    BuildContext context,
    ThemeData theme,
    List<QueueDisplayItem> displayItems,
    int currentIndex,
    bool useThumbnailBackground,
  ) {
    final topLevelItems = displayItems.where((item) => !item.isSong || item.groupId == null).toList();

    return ListView.builder(
      itemCount: topLevelItems.length + 1,
      itemBuilder: (context, index) {
        // Last item is a drop zone for appending to end
        if (index == topLevelItems.length) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInsertionDropZone(
                index,
                theme,
                topLevelItems: topLevelItems,
              ),
              _buildEndDropZone(theme, topLevelItems),
            ],
          );
        }

        final item = topLevelItems[index];
        Widget child;

        if (item.isGroup) {
          child = QueueGroupCard(
            item: item,
            tagViewModel: widget.tagViewModel,
            playerViewModel: widget.playerViewModel,
            useThumbnailBackground: useThumbnailBackground,
            isCollapsed: _collapsedQueueGroups.contains(item.groupId),
            onToggleCollapse: () {
              setState(() {
                if (_collapsedQueueGroups.contains(item.groupId)) {
                  _collapsedQueueGroups.remove(item.groupId);
                } else {
                  _collapsedQueueGroups.add(item.groupId!);
                }
              });
            },
            groupInsertionGroupId: _groupInsertionGroupId,
            groupInsertionIndex: _groupInsertionIndex,
            onGroupInsertionChanged: (groupId, insertIndex) {
              setState(() {
                _groupInsertionGroupId = groupId;
                _groupInsertionIndex = insertIndex;
              });
            },
          );
        } else {
          final isPlaying = item.flatIndex == currentIndex;
          child = QueueItemTile(
            item: item,
            isPlaying: isPlaying,
            tagViewModel: widget.tagViewModel,
            playerViewModel: widget.playerViewModel,
            useThumbnailBackground: useThumbnailBackground,
          );
        }

        // Wrap with insertion drop zone above each item
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildInsertionDropZone(
              index,
              theme,
              topLevelItems: topLevelItems,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: child,
            ),
          ],
        );
      },
    );
  }

  Widget _buildInsertionDropZone(
    int topLevelIndex,
    ThemeData theme, {
    List<QueueDisplayItem> topLevelItems = const [],
  }) {
    final tagVM = widget.tagViewModel;

    return DragTarget<QueueDragData>(
      onWillAcceptWithDetails: (details) {
        setState(() => _queueInsertionIndex = topLevelIndex);
        return true;
      },
      onLeave: (_) {
        if (mounted && _queueInsertionIndex == topLevelIndex) {
          setState(() => _queueInsertionIndex = null);
        }
      },
      onAcceptWithDetails: (details) async {
        final data = details.data;
        setState(() => _queueInsertionIndex = null);

        if (data.isGroup && data.groupItemId != null) {
          await tagVM.moveGroupOutToCollection(
            tagVM.activeQueueId,
            data.groupItemId!,
            tagVM.activeQueueId,
            topLevelIndex,
          );
        } else if (data.isSong) {
          if (data.songGroupId != null && data.playlistItemId != null) {
            await tagVM.moveSongUnitOutOfGroup(
              data.songGroupId!,
              data.playlistItemId!,
              tagVM.activeQueueId,
              insertIndex: topLevelIndex,
            );
          } else {
            final fromIndex = data.flatIndex;
            int targetFlatIndex;
            if (topLevelIndex >= topLevelItems.length) {
              targetFlatIndex = tagVM.queueLength - 1;
            } else {
              final targetItem = topLevelItems[topLevelIndex];
              if (targetItem.isSong) {
                targetFlatIndex = targetItem.flatIndex;
                // When dragging forward (fromIndex < targetFlatIndex),
                // we need to adjust because removing the item shifts indices down
                if (fromIndex < targetFlatIndex) {
                  targetFlatIndex--;
                }
              } else {
                targetFlatIndex = topLevelIndex > 0
                    ? _nextSongFlatIndex(topLevelItems, topLevelIndex)
                    : 0;
              }
            }
            if (fromIndex >= 0 && fromIndex != targetFlatIndex) {
              unawaited(tagVM.reorderQueue(fromIndex, targetFlatIndex));
            }
          }
        }
      },
      builder: (context, candidateData, rejectedData) {
        final showLine =
            _queueInsertionIndex == topLevelIndex && candidateData.isNotEmpty;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onSecondaryTapUp: (details) {
            debugPrint('=== Insertion zone right-click at index $topLevelIndex ===');
            _showQueueEmptySpaceContextMenu(context, details.globalPosition);
          },
          onLongPressStart: (details) {
            debugPrint('=== Insertion zone long-press at index $topLevelIndex ===');
            _showQueueEmptySpaceContextMenu(context, details.globalPosition);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: showLine ? 4 : 2,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: showLine
                ? BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildEndDropZone(ThemeData theme, List<QueueDisplayItem> topLevelItems) {
    final tagVM = widget.tagViewModel;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapUp: (details) {
        debugPrint('=== End zone right-click (60px container) ===');
        _showQueueEmptySpaceContextMenu(context, details.globalPosition);
      },
      onLongPressStart: (details) {
        debugPrint('=== End zone long-press (60px container) ===');
        _showQueueEmptySpaceContextMenu(context, details.globalPosition);
      },
      child: DragTarget<QueueDragData>(
        onWillAcceptWithDetails: (_) => true,
        onAcceptWithDetails: (details) async {
          final data = details.data;
          if (data.isSong) {
            if (data.songGroupId != null && data.playlistItemId != null) {
              await tagVM.moveSongUnitOutOfGroup(
                data.songGroupId!,
                data.playlistItemId!,
                tagVM.activeQueueId,
                insertIndex: 999,
              );
            } else {
              final lastIndex = tagVM.queueLength - 1;
              if (data.flatIndex < lastIndex) {
                unawaited(tagVM.reorderQueue(data.flatIndex, lastIndex));
              }
            }
          } else if (data.isGroup && data.groupItemId != null) {
            final activeQueue = tagVM.allTags
                .where((t) => t.id == tagVM.activeQueueId)
                .firstOrNull;
            final itemCount =
                activeQueue?.playlistMetadata?.items.length ?? 0;
            await tagVM.moveGroupOutToCollection(
              tagVM.activeQueueId,
              data.groupItemId!,
              tagVM.activeQueueId,
              itemCount,
            );
          }
        },
        builder: (context, candidateData, rejectedData) {
          return Container(
            height: 60,
            color: candidateData.isNotEmpty
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                : Colors.transparent,
          );
        },
      ),
    );
  }

  void _showQueueEmptySpaceContextMenu(BuildContext context, Offset position) {
    debugPrint('=== Queue empty space context menu triggered at $position ===');
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
          value: 'create_group',
          child: ListTile(
            leading: const Icon(Icons.create_new_folder_outlined),
            title: Text(context.t.playlists.createGroup),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    ).then((value) async {
      debugPrint('Menu selection: $value');
      if (value == null || !context.mounted) return;
      if (value == 'create_group') {
        debugPrint('Opening create group dialog...');
        _showCreateQueueGroupDialog(context);
      }
    });
  }

  void _showCreateQueueGroupDialog(BuildContext context) {
    debugPrint('=== _showCreateQueueGroupDialog called ===');
    debugPrint('Active queue ID: ${widget.tagViewModel.activeQueueId}');
    final nameController = TextEditingController();
    final tagVM = widget.tagViewModel;

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
              debugPrint('Creating group "$name" in queue ${tagVM.activeQueueId}');
              final result = await tagVM.createNestedGroup(tagVM.activeQueueId, name);
              debugPrint('Group creation result: ${result?.id}, name: ${result?.name}');
              debugPrint('Queue display items count: ${tagVM.queueDisplayItems.length}');
              if (result != null && dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.t.playlists.groupCreated.replaceAll('{name}', result.name))),
                  );
                }
              } else if (dialogContext.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.t.playlists.failedToCreateGroup.replaceAll('{error}', tagVM.error ?? 'Unknown error'))),
                );
              }
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
                debugPrint('Creating group "$name" in queue ${tagVM.activeQueueId}');
                final result = await tagVM.createNestedGroup(tagVM.activeQueueId, name);
                debugPrint('Group creation result: ${result?.id}, name: ${result?.name}');
                debugPrint('Queue display items count: ${tagVM.queueDisplayItems.length}');
                if (result != null && dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.t.playlists.groupCreated.replaceAll('{name}', result.name))),
                    );
                  }
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.t.playlists.failedToCreateGroup.replaceAll('{error}', tagVM.error ?? 'Unknown error'))),
                  );
                }
              }
            },
            child: Text(context.t.common.create),
          ),
        ],
      ),
    );
  }

  int _nextSongFlatIndex(List<QueueDisplayItem> items, int startIndex) {
    for (var i = startIndex; i < items.length; i++) {
      if (items[i].isSong) return items[i].flatIndex;
    }
    for (var i = startIndex - 1; i >= 0; i--) {
      if (items[i].isSong) return items[i].flatIndex + 1;
    }
    return 0;
  }
}
