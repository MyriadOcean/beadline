import 'package:flutter/material.dart';
import '../../i18n/translations.g.dart';

/// A toolbar shown when items are selected in a collection view.
/// Displays selection count and bulk action buttons:
/// - "Move to Group" (with group picker dialog)
/// - "Remove from Group"
/// - "Clear Selection" (X icon)
class BulkActionToolbar extends StatelessWidget {
  const BulkActionToolbar({
    super.key,
    required this.selectionCount,
    required this.onMoveToGroup,
    required this.onRemoveFromGroup,
    required this.onClearSelection,
  });

  final int selectionCount;
  final VoidCallback onMoveToGroup;
  final VoidCallback onRemoveFromGroup;
  final VoidCallback onClearSelection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onClearSelection,
            tooltip: context.t.playlists.clearSelection,
          ),
          const SizedBox(width: 4),
          Text(
            '$selectionCount ${context.t.playlists.selected}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: onMoveToGroup,
            icon: const Icon(Icons.drive_file_move_outline, size: 18),
            label: Text(context.t.playlists.moveToGroup),
          ),
          const SizedBox(width: 4),
          TextButton.icon(
            onPressed: onRemoveFromGroup,
            icon: const Icon(Icons.move_up, size: 18),
            label: Text(context.t.playlists.removeFromGroup),
          ),
        ],
      ),
    );
  }
}
