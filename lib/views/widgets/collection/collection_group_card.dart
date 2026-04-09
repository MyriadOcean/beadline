import 'package:flutter/material.dart';

import '../../../i18n/translations.g.dart';
import '../../../models/tag_extensions.dart';
import 'collection_drag_data.dart';
import 'collection_drop_zone.dart';

/// Callback signatures for group card operations
typedef OnReorderInGroup = void Function(String songUnitId, int newIndex);
typedef OnMoveIntoGroup = void Function(
    CollectionDragData data, int insertIndex);

/// A card widget that displays a group (header + children).
///
/// The card is a DragTarget — dropping on the header appends at the end.
/// The card is also a Draggable so groups can be rearranged by drag-and-drop.
/// Right-clicking empty space inside the card fires [onEmptySpaceRightClick]
/// with the global position so the parent can show a context menu.
class CollectionGroupCard extends StatefulWidget {
  const CollectionGroupCard({
    required this.groupTag,
    required this.collectionId,
    required this.childCount,
    required this.childBuilder,
    required this.onReorder,
    required this.onMoveIn,
    this.isCollapsed = false,
    this.onToggleCollapse,
    this.onRename,
    this.onToggleLock,
    this.onCreateNestedGroup,
    this.onRemoveGroup,
    this.onEmptySpaceRightClick,
    this.extraMenuItems,
    super.key,
  });

  final Tag groupTag;
  final String collectionId;
  final int childCount;
  final Widget Function(BuildContext context, int index) childBuilder;
  final OnReorderInGroup onReorder;
  final OnMoveIntoGroup onMoveIn;
  final bool isCollapsed;
  final VoidCallback? onToggleCollapse;
  final VoidCallback? onRename;
  final VoidCallback? onToggleLock;
  final void Function(String parentGroupId)? onCreateNestedGroup;
  final VoidCallback? onRemoveGroup;

  /// Called when the user right-clicks empty space inside this group.
  /// Receives the global tap position and insert index so the parent can
  /// show a context menu and create the group at the right position.
  final void Function(Offset position, String groupId, int insertIndex)?
      onEmptySpaceRightClick;

  final List<PopupMenuEntry<String>>? extraMenuItems;

  @override
  State<CollectionGroupCard> createState() => _CollectionGroupCardState();
}

class _CollectionGroupCardState extends State<CollectionGroupCard> {
  int _dragOverCount = 0;
  bool get _isDragOver => _dragOverCount > 0;

  void _incDrag() {
    if (mounted) setState(() => _dragOverCount++);
  }

  void _decDrag() {
    if (mounted) {
      setState(() => _dragOverCount = (_dragOverCount - 1).clamp(0, 999));
    }
  }

  void _resetDrag() {
    if (mounted) setState(() => _dragOverCount = 0);
  }

  Tag get group => widget.groupTag;
  bool get isExpanded => !widget.isCollapsed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLocked = group.isLocked;

    // The whole card is a DragTarget (dropping on header appends at end)
    Widget card = DragTarget<CollectionDragData>(
      onWillAcceptWithDetails: (details) {
        final data = details.data;
        if (data.isGroup) return data.groupId != group.id;
        return !isLocked;
      },
      onAcceptWithDetails: (details) {
        _resetDrag();
        final data = details.data;
        if (data.isSong &&
            data.songUnitId != null &&
            data.sourceGroupId == group.id) {
          widget.onReorder(data.songUnitId!, widget.childCount);
        } else {
          widget.onMoveIn(data, widget.childCount);
        }
      },
      onMove: (_) {
        if (!_isDragOver) _incDrag();
      },
      onLeave: (_) => _resetDrag(),
      builder: (context, candidateData, rejectedData) {
        final showHighlight = candidateData.isNotEmpty || _isDragOver;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          elevation: showHighlight ? 2 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: showHighlight
                  ? theme.colorScheme.primary
                  : isLocked
                      ? theme.colorScheme.secondary
                      : theme.colorScheme.outlineVariant,
              width: showHighlight ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(context, theme, showHighlight),
              if (isExpanded) _buildChildren(context, theme),
            ],
          ),
        );
      },
    );

    // Wrap in LongPressDraggable so groups can be rearranged (hold to drag)
    card = LongPressDraggable<CollectionDragData>(
      data: CollectionDragData.group(
        groupId: group.id,
        sourceCollectionId: widget.collectionId,
      ),
      feedback: _buildDragFeedback(context, theme),
      childWhenDragging: Opacity(opacity: 0.3, child: card),
      child: card,
    );

    return card;
  }

  Widget _buildDragFeedback(BuildContext context, ThemeData theme) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 220,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.folder, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                group.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme, bool highlight) {
    final isLocked = group.isLocked;
    final songCount = group.metadata?.items
            .where((i) => i.itemType == TagItemType.songUnit)
            .length ??
        0;

    return Container(
      color: highlight
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
          : isLocked
              ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.2)
              : theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          Icon(Icons.folder,
              size: 18,
              color: isLocked
                  ? theme.colorScheme.secondary
                  : theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${group.name}${highlight ? ' - ${context.t.playlists.dropHere}' : ''}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isLocked
                    ? theme.colorScheme.secondary
                    : theme.colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text('$songCount',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(width: 4),
          if (widget.onToggleCollapse != null)
            SizedBox(
              width: 28,
              height: 28,
              child: IconButton(
                icon: Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 16),
                padding: EdgeInsets.zero,
                onPressed: widget.onToggleCollapse,
                tooltip: isExpanded
                    ? context.t.queue.collapse
                    : context.t.queue.expand,
              ),
            ),
          SizedBox(
              width: 28,
              height: 28,
              child: _buildActionsMenu(context, theme)),
        ],
      ),
    );
  }

  Widget _buildChildren(BuildContext context, ThemeData theme) {
    if (widget.childCount == 0) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onSecondaryTapUp: (d) => widget.onEmptySpaceRightClick
            ?.call(d.globalPosition, group.id, 0),
        onLongPressStart: (d) => widget.onEmptySpaceRightClick
            ?.call(d.globalPosition, group.id, 0),
        child: EmptyGroupDropZone(
          emptyText: context.t.playlists.noSongsInGroup,
          dropText: context.t.playlists.dropHere,
          onDragEnter: _incDrag,
          onDragLeave: _decDrag,
          onAccept: (data) {
            _resetDrag();
            widget.onMoveIn(data, 0);
          },
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < widget.childCount; i++) ...[
          _groupDropZone(i),
          widget.childBuilder(context, i),
        ],
        _groupDropZone(widget.childCount),
      ],
    );
  }

  Widget _groupDropZone(int insertIndex) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapUp: (d) =>
          widget.onEmptySpaceRightClick?.call(d.globalPosition, group.id, insertIndex),
      onLongPressStart: (d) =>
          widget.onEmptySpaceRightClick?.call(d.globalPosition, group.id, insertIndex),
      child: CollectionDropZone(
        minHeight: 20,
        onDragEnter: _incDrag,
        onDragLeave: _decDrag,
        onAccept: (data) {
          _resetDrag();
          if (data.isSong &&
              data.songUnitId != null &&
              data.sourceGroupId == group.id) {
            widget.onReorder(data.songUnitId!, insertIndex);
          } else {
            widget.onMoveIn(data, insertIndex);
          }
        },
      ),
    );
  }

  Widget _buildActionsMenu(BuildContext context, ThemeData theme) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert,
          size: 16, color: theme.colorScheme.onSurfaceVariant),
      padding: EdgeInsets.zero,
      tooltip: context.t.queue.groupActions,
      onSelected: (value) {
        switch (value) {
          case 'rename':
            widget.onRename?.call();
          case 'toggle_lock':
            widget.onToggleLock?.call();
          case 'add_nested_group':
            widget.onCreateNestedGroup?.call(group.id);
          case 'remove':
            widget.onRemoveGroup?.call();
        }
      },
      itemBuilder: (context) => [
        if (widget.onRename != null)
          PopupMenuItem(
              value: 'rename',
              child: ListTile(
                  leading: const Icon(Icons.edit),
                  title: Text(context.t.common.rename),
                  dense: true,
                  contentPadding: EdgeInsets.zero)),
        if (widget.onToggleLock != null)
          PopupMenuItem(
              value: 'toggle_lock',
              child: ListTile(
                  leading:
                      Icon(group.isLocked ? Icons.lock_open : Icons.lock),
                  title: Text(group.isLocked
                      ? context.t.playlists.unlock
                      : context.t.playlists.lock),
                  dense: true,
                  contentPadding: EdgeInsets.zero)),
        if (widget.onCreateNestedGroup != null)
          PopupMenuItem(
              value: 'add_nested_group',
              child: ListTile(
                  leading: const Icon(Icons.create_new_folder_outlined),
                  title: Text(context.t.playlists.createGroup),
                  dense: true,
                  contentPadding: EdgeInsets.zero)),
        if (widget.onRemoveGroup != null)
          PopupMenuItem(
              value: 'remove',
              child: ListTile(
                  leading: const Icon(Icons.remove_circle_outline),
                  title: Text(context.t.common.remove),
                  dense: true,
                  contentPadding: EdgeInsets.zero)),
        ...?widget.extraMenuItems,
      ],
    );
  }
}
