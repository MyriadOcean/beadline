import 'package:flutter/material.dart';

import '../../models/song_unit.dart';
import 'cached_thumbnail.dart';
import 'collection/collection_drag_data.dart';
import 'thumbnail_background_container.dart';

/// Universal song unit tile used across the entire app.
/// Configurable for queue view, playlists page, library, song picker, etc.
class SongUnitListTile extends StatelessWidget {
  const SongUnitListTile({
    required this.songUnit,
    this.index,
    this.isPlaying = false,
    this.isSelected = false,
    this.showCheckbox = false,
    this.showRemoveButton = true,
    this.showThumbnailBackground = false,
    this.onTap,
    this.onRemove,
    this.onToggleSelect,
    this.onSecondaryTap,
    this.trailing,
    this.draggable = false,
    this.dragData,
    super.key,
  });

  final SongUnit songUnit;
  final int? index;
  final bool isPlaying;
  final bool isSelected;
  final bool showCheckbox;
  final bool showRemoveButton;
  final bool showThumbnailBackground;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final VoidCallback? onToggleSelect;

  /// Right-click / secondary tap handler (for context menus)
  final void Function(Offset position)? onSecondaryTap;

  /// Custom trailing widget (overrides remove button)
  final Widget? trailing;
  final bool draggable;
  final CollectionDragData? dragData;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var tile = _buildTile(context, theme);

    if (showThumbnailBackground) {
      tile = ThumbnailBackgroundContainer(
        key: ValueKey('thumb_bg_${songUnit.id}'),
        metadata: songUnit.metadata,
        useThumbnailBackground: true,
        fallbackSourceIds: _fallbackSourceIds,
        child: tile,
      );
    }

    if (draggable && dragData != null) {
      tile = Draggable<CollectionDragData>(
        data: dragData,
        feedback: _buildDragFeedback(context, theme),
        childWhenDragging: Opacity(opacity: 0.3, child: tile),
        child: tile,
      );
    }

    // Wrap in Listener to catch right-click before Draggable consumes it
    if (onSecondaryTap != null) {
      tile = Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) {
          if (event.buttons == 2) { // secondary button (right-click)
            onSecondaryTap!(event.position);
          }
        },
        child: tile,
      );
    }

    return tile;
  }

  List<String> get _fallbackSourceIds => [
    ...songUnit.sources.audioSources.map((s) => s.id),
    ...songUnit.sources.accompanimentSources.map((s) => s.id),
  ];

  Widget _buildTile(BuildContext context, ThemeData theme) {
    final effectiveTrailing = trailing ??
        (showRemoveButton && onRemove != null
            ? IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 18),
                onPressed: onRemove,
                tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
              )
            : null);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: isSelected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
          : Colors.transparent,
      child: Row(
        children: [
          if (showCheckbox)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Checkbox(
                value: isSelected,
                onChanged: (_) => onToggleSelect?.call(),
              ),
            ),
          Expanded(
            child: ListTile(
              dense: true,
              leading: _buildLeading(theme),
              onTap: showCheckbox ? onToggleSelect : onTap,
              title: Text(
                songUnit.metadata.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: isPlaying
                    ? TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      )
                    : null,
              ),
              subtitle: Text(
                songUnit.metadata.artistDisplay,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: showCheckbox ? null : effectiveTrailing,
              selected: isPlaying,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeading(ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (index != null)
          Container(
            width: 28,
            alignment: Alignment.center,
            child: Text(
              '$index',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        if (index != null) const SizedBox(width: 4),
        _buildThumbnail(theme),
      ],
    );
  }

  Widget _buildThumbnail(ThemeData theme) {
    if (songUnit.metadata.thumbnailSourceId != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: CachedThumbnail(
          metadata: songUnit.metadata,
          fallbackSourceIds: _fallbackSourceIds,
          width: 40,
          height: 40,
        ),
      );
    }
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        Icons.music_note,
        color: theme.colorScheme.onSurfaceVariant,
        size: 20,
      ),
    );
  }

  Widget _buildDragFeedback(BuildContext context, ThemeData theme) {
    return Material(
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
            _buildThumbnail(theme),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                songUnit.metadata.title,
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
}
