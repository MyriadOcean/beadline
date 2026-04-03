import 'dart:async';

import 'package:flutter/material.dart';

import '../../../i18n/translations.g.dart';
import '../../../models/song_unit.dart';
import '../../../models/tag.dart';
import '../../../viewmodels/tag_view_model.dart';
import '../song_unit_list_tile.dart';
import 'collection_drag_data.dart';
import 'collection_group_card.dart';

/// Configuration for how a collection list view behaves.
class CollectionListConfig {
  const CollectionListConfig({
    this.showIndex = false,
    this.showThumbnailBackground = false,
    this.showRemoveButton = true,
    this.showCheckbox = false,
    this.draggableSongs = true,
    this.currentPlayingIndex = -1,
    this.onSongTap,
    this.onSongRemove,
    this.onSongContextMenu,
    this.isSelected,
    this.onToggleSelect,
    this.extraGroupMenuItems,
  });

  final bool showIndex;
  final bool showThumbnailBackground;
  final bool showRemoveButton;
  final bool showCheckbox;
  final bool draggableSongs;
  final int currentPlayingIndex;
  final void Function(SongUnit songUnit, int flatIndex)? onSongTap;
  final void Function(String songUnitId, String? groupId)? onSongRemove;

  /// Right-click context menu for a song. Receives (songUnit, position, groupId).
  final void Function(SongUnit songUnit, Offset position, String? groupId)? onSongContextMenu;

  final bool Function(String playlistItemId)? isSelected;
  final void Function(String playlistItemId)? onToggleSelect;
  final List<PopupMenuEntry<String>>? extraGroupMenuItems;
}

/// Shared collection list view used by both queue view and playlists page.
/// Each item is wrapped in a DragTarget that detects whether the cursor is
/// in the top or bottom half, showing an insertion indicator accordingly.
class CollectionListView extends StatefulWidget {
  const CollectionListView({
    required this.collectionId,
    required this.displayItems,
    required this.tagViewModel,
    required this.config,
    required this.resolveSongUnit,
    super.key,
  });

  final String collectionId;
  final List<QueueDisplayItem> displayItems;
  final TagViewModel tagViewModel;
  final CollectionListConfig config;
  final SongUnit? Function(String songUnitId) resolveSongUnit;

  @override
  State<CollectionListView> createState() => _CollectionListViewState();
}

class _CollectionListViewState extends State<CollectionListView> {
  final Set<String> _collapsedGroups = {};

  // Which item index has the insertion indicator, and whether it's above or below
  int? _hoverIndex;
  bool _hoverAbove = true;

  @override
  Widget build(BuildContext context) {
    final topLevel = widget.displayItems
        .where((item) => !item.isSong || item.groupId == null)
        .toList();
    final tagVM = widget.tagViewModel;
    final theme = Theme.of(context);

    // itemCount + 1 for trailing empty space that accepts right-click
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: topLevel.length + 1,
      itemBuilder: (context, index) {
        // Trailing empty space — right-click here creates a group at root
        if (index == topLevel.length) {
          return _EmptySpaceTarget(
            onContextMenu: (pos) => _showCreateGroupMenu(context, pos, widget.collectionId),
          );
        }

        final item = topLevel[index];
        final child = item.isGroup
            ? _buildGroupCard(context, item)
            : _buildSongTile(context, item);

        return _DragTargetItem(
          key: ValueKey('cl_${item.isGroup ? item.groupId : item.songUnit?.id}'),
          index: index,
          hoverIndex: _hoverIndex,
          hoverAbove: _hoverAbove,
          indicatorColor: theme.colorScheme.primary,
          onWillAccept: (data, above) {
            setState(() { _hoverIndex = index; _hoverAbove = above; });
            return true;
          },
          onLeave: () {
            if (_hoverIndex == index) setState(() => _hoverIndex = null);
          },
          onAccept: (data) {
            final insertIdx = _hoverAbove ? index : index + 1;
            setState(() => _hoverIndex = null);
            _handleDrop(data, insertIdx, topLevel, tagVM);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: child,
          ),
        );
      },
    );
  }

  void _handleDrop(CollectionDragData data, int insertIdx,
      List<QueueDisplayItem> topLevel, TagViewModel tagVM) {
    debugPrint('_handleDrop: insertIdx=$insertIdx, songId=${data.songUnitId}, groupId=${data.groupId}, sourceGroup=${data.sourceGroupId}');
    if (data.isSong && data.songUnitId != null) {
      if (data.sourceGroupId != null) {
        // Moving OUT of a group to root level
        unawaited(tagVM.moveSongUnitOutOfGroup(
          data.sourceGroupId!, data.songUnitId!, widget.collectionId,
          insertIndex: insertIdx,
        ));
      } else {
        // Reordering within root level
        unawaited(tagVM.reorderWithinCollection(
          widget.collectionId, data.songUnitId!, insertIdx,
        ));
      }
    } else if (data.isGroup && data.groupId != null) {
      final oldIdx =
          topLevel.indexWhere((e) => e.isGroup && e.groupId == data.groupId);
      if (oldIdx >= 0 && oldIdx != insertIdx) {
        unawaited(tagVM.reorderCollection(
          widget.collectionId, oldIdx, insertIdx,
        ));
      }
    }
  }

  Widget _buildSongTile(BuildContext context, QueueDisplayItem item, {String? groupId}) {
    final config = widget.config;
    final song = item.songUnit!;
    final isPlaying = item.flatIndex == config.currentPlayingIndex;
    final isSelected = config.isSelected?.call(item.playlistItemId ?? '') ?? false;

    return SongUnitListTile(
      songUnit: song,
      index: config.showIndex && item.flatIndex >= 0 ? item.flatIndex + 1 : null,
      isPlaying: isPlaying,
      isSelected: isSelected,
      showCheckbox: config.showCheckbox,
      showRemoveButton: config.showRemoveButton,
      showThumbnailBackground: config.showThumbnailBackground,
      draggable: config.draggableSongs,
      dragData: CollectionDragData.song(
        songUnitId: song.id,
        sourceCollectionId: widget.collectionId,
        sourceGroupId: groupId,
      ),
      onTap: config.onSongTap != null ? () => config.onSongTap!(song, item.flatIndex) : null,
      onRemove: config.onSongRemove != null ? () => config.onSongRemove!(song.id, groupId) : null,
      onSecondaryTap: config.onSongContextMenu != null
          ? (pos) => config.onSongContextMenu!(song, pos, groupId)
          : null,
      onToggleSelect: config.onToggleSelect != null && item.playlistItemId != null
          ? () => config.onToggleSelect!(item.playlistItemId!) : null,
    );
  }

  Widget _buildGroupCard(BuildContext context, QueueDisplayItem groupItem) {
    final tagVM = widget.tagViewModel;
    final config = widget.config;
    final groupTag = tagVM.getTagById(groupItem.groupId!);
    if (groupTag == null) return const SizedBox.shrink();
    final subItems = groupItem.subItems ?? [];

    return CollectionGroupCard(
      groupTag: groupTag,
      collectionId: widget.collectionId,
      childCount: _collapsedGroups.contains(groupItem.groupId) ? 0 : subItems.length,
      isCollapsed: _collapsedGroups.contains(groupItem.groupId),
      onToggleCollapse: () {
        setState(() {
          if (_collapsedGroups.contains(groupItem.groupId)) {
            _collapsedGroups.remove(groupItem.groupId);
          } else {
            _collapsedGroups.add(groupItem.groupId!);
          }
        });
      },
      childBuilder: (context, i) {
        final sub = subItems[i];
        if (sub.isSong) return _buildSongTile(context, sub, groupId: groupItem.groupId);
        if (sub.isGroup) return _buildGroupCard(context, sub);
        return const SizedBox.shrink();
      },
      onReorder: (songUnitId, newIndex) {
        unawaited(tagVM.reorderWithinCollection(groupItem.groupId!, songUnitId, newIndex));
      },
      onMoveIn: (data, insertIndex) {
        if (data.isSong && data.songUnitId != null) {
          unawaited(tagVM.moveSongUnitToGroup(
            widget.collectionId, data.songUnitId!, groupItem.groupId!,
            insertIndex: insertIndex,
          ));
        }
      },
      onRename: () => _showRenameDialog(context, groupTag),
      onToggleLock: () => unawaited(tagVM.toggleLock(groupTag.id)),
      onAddNestedGroup: () => _showCreateNestedGroupDialog(context, groupTag.id),
      onRemoveGroup: () => _showRemoveGroupDialog(context, groupTag, groupItem),
      extraMenuItems: config.extraGroupMenuItems,
    );
  }

  void _showCreateGroupMenu(BuildContext context, Offset position, String parentCollectionId) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
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
    ).then((value) {
      if (value == 'create_group' && context.mounted) {
        _showCreateNestedGroupDialog(context, parentCollectionId);
      }
    });
  }

  void _showRenameDialog(BuildContext context, Tag groupTag) {
    final ctrl = TextEditingController(text: groupTag.name);
    showDialog(context: context, builder: (dc) => AlertDialog(
      title: Text(context.t.common.rename),
      content: TextField(controller: ctrl, autofocus: true,
        decoration: InputDecoration(labelText: context.t.playlists.groupName),
        onSubmitted: (_) async { final n = ctrl.text.trim(); if (n.isNotEmpty) { await widget.tagViewModel.renameTag(groupTag.id, n); if (dc.mounted) Navigator.of(dc).pop(); } }),
      actions: [
        TextButton(onPressed: () => Navigator.of(dc).pop(), child: Text(context.t.common.cancel)),
        FilledButton(onPressed: () async { final n = ctrl.text.trim(); if (n.isNotEmpty) { await widget.tagViewModel.renameTag(groupTag.id, n); if (dc.mounted) Navigator.of(dc).pop(); } }, child: Text(context.t.common.rename)),
      ],
    ));
  }

  void _showCreateNestedGroupDialog(BuildContext context, String parentGroupId) {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (dc) => AlertDialog(
      title: Text(context.t.playlists.createGroupTitle),
      content: TextField(controller: ctrl, autofocus: true,
        decoration: InputDecoration(labelText: context.t.playlists.groupName, hintText: context.t.playlists.enterGroupName),
        onSubmitted: (_) async { final n = ctrl.text.trim(); if (n.isNotEmpty) { await widget.tagViewModel.createNestedGroup(parentGroupId, n); if (dc.mounted) Navigator.of(dc).pop(); } }),
      actions: [
        TextButton(onPressed: () => Navigator.of(dc).pop(), child: Text(context.t.common.cancel)),
        FilledButton(onPressed: () async { final n = ctrl.text.trim(); if (n.isNotEmpty) { await widget.tagViewModel.createNestedGroup(parentGroupId, n); if (dc.mounted) Navigator.of(dc).pop(); } }, child: Text(context.t.common.create)),
      ],
    ));
  }

  void _showRemoveGroupDialog(BuildContext context, Tag groupTag, QueueDisplayItem groupItem) {
    showDialog(context: context, builder: (dc) => AlertDialog(
      title: Text(context.t.common.remove),
      content: Text(context.t.dialogs.home.removeGroupQuestion.replaceAll('{groupName}', groupTag.name)),
      actions: [
        TextButton(onPressed: () => Navigator.of(dc).pop(), child: Text(context.t.common.cancel)),
        TextButton(
          onPressed: () async { await widget.tagViewModel.removeGroupFromQueue(widget.collectionId, groupTag.id); if (dc.mounted) Navigator.of(dc).pop(); },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: Text(context.t.common.remove),
        ),
      ],
    ));
  }
}


/// Wraps a list item in a [DragTarget] that covers the full tile height.
/// Detects whether the drag cursor is in the top or bottom half and shows
/// a thin insertion indicator line accordingly.
class _DragTargetItem extends StatelessWidget {
  const _DragTargetItem({
    required this.index,
    required this.child,
    required this.onWillAccept,
    required this.onLeave,
    required this.onAccept,
    required this.indicatorColor,
    this.hoverIndex,
    this.hoverAbove = true,
    super.key,
  });

  final int index;
  final Widget child;
  final bool Function(CollectionDragData data, bool above) onWillAccept;
  final VoidCallback onLeave;
  final void Function(CollectionDragData data) onAccept;
  final Color indicatorColor;
  final int? hoverIndex;
  final bool hoverAbove;

  @override
  Widget build(BuildContext context) {
    final showAbove = hoverIndex == index && hoverAbove;
    final showBelow = hoverIndex == index && !hoverAbove;

    return DragTarget<CollectionDragData>(
      onWillAcceptWithDetails: (details) => true,
      onMove: (details) {
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox == null) return;
        final localY = renderBox.globalToLocal(details.offset).dy;
        final above = localY < renderBox.size.height / 2;
        onWillAccept(details.data, above);
      },
      onLeave: (_) => onLeave(),
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidateData, rejectedData) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              height: showAbove ? 3 : 0,
              margin: showAbove
                  ? const EdgeInsets.symmetric(horizontal: 8)
                  : EdgeInsets.zero,
              decoration: showAbove
                  ? BoxDecoration(
                      color: indicatorColor,
                      borderRadius: BorderRadius.circular(2),
                    )
                  : null,
            ),
            child,
            // Bottom indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              height: showBelow ? 3 : 0,
              margin: showBelow
                  ? const EdgeInsets.symmetric(horizontal: 8)
                  : EdgeInsets.zero,
              decoration: showBelow
                  ? BoxDecoration(
                      color: indicatorColor,
                      borderRadius: BorderRadius.circular(2),
                    )
                  : null,
            ),
          ],
        );
      },
    );
  }
}

/// Trailing empty space in the list that accepts right-click / long-press
/// to show a "Create Group" context menu.
class _EmptySpaceTarget extends StatelessWidget {
  const _EmptySpaceTarget({required this.onContextMenu});

  final void Function(Offset position) onContextMenu;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapUp: (details) => onContextMenu(details.globalPosition),
      onLongPressStart: (details) => onContextMenu(details.globalPosition),
      child: const SizedBox(height: 60),
    );
  }
}
