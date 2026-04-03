import 'package:flutter/material.dart';

import 'collection_drag_data.dart';

/// A drop zone between collection items.
/// Always has a minimum height so it's hittable even when not visually active.
class CollectionDropZone extends StatelessWidget {
  const CollectionDropZone({
    required this.onAccept,
    this.onWillAccept,
    this.onDragEnter,
    this.onDragLeave,
    this.minHeight = 12,
    this.activeHeight = 4,
    super.key,
  });

  /// Called when an item is dropped on this zone
  final void Function(CollectionDragData data) onAccept;

  /// Optional: return false to reject the drop
  final bool Function(CollectionDragData data)? onWillAccept;

  /// Called when a drag enters this zone (for parent highlight)
  final VoidCallback? onDragEnter;

  /// Called when a drag leaves this zone
  final VoidCallback? onDragLeave;

  /// Height when no drag is hovering (invisible but hittable)
  final double minHeight;

  /// Height of the colored indicator line when active
  final double activeHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DragTarget<CollectionDragData>(
      onWillAcceptWithDetails: (details) {
        onDragEnter?.call();
        return onWillAccept?.call(details.data) ?? true;
      },
      onLeave: (_) => onDragLeave?.call(),
      onAcceptWithDetails: (details) {
        onDragLeave?.call();
        onAccept(details.data);
      },
      builder: (context, candidateData, rejectedData) {
        final active = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          height: active ? activeHeight : minHeight,
          margin: active
              ? const EdgeInsets.symmetric(horizontal: 8)
              : EdgeInsets.zero,
          decoration: active
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

/// A large drop zone for empty groups.
/// Shows "Drop here" text when a drag hovers over it.
class EmptyGroupDropZone extends StatelessWidget {
  const EmptyGroupDropZone({
    required this.onAccept,
    this.emptyText = 'No items',
    this.dropText = 'Drop here',
    this.onDragEnter,
    this.onDragLeave,
    super.key,
  });

  final void Function(CollectionDragData data) onAccept;
  final String emptyText;
  final String dropText;
  final VoidCallback? onDragEnter;
  final VoidCallback? onDragLeave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DragTarget<CollectionDragData>(
      onWillAcceptWithDetails: (_) {
        onDragEnter?.call();
        return true;
      },
      onLeave: (_) => onDragLeave?.call(),
      onAcceptWithDetails: (details) {
        onDragLeave?.call();
        onAccept(details.data);
      },
      builder: (context, candidateData, rejectedData) {
        final active = candidateData.isNotEmpty;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: active
              ? BoxDecoration(
                  color: theme.colorScheme.primaryContainer
                      .withValues(alpha: 0.3),
                )
              : null,
          child: Center(
            child: Text(
              active ? dropText : emptyText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: active
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      },
    );
  }
}
