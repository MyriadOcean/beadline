import 'package:flutter/material.dart';

import '../../viewmodels/player_view_model.dart';
import '../../viewmodels/tag_view_model.dart';
import 'cached_thumbnail.dart';
import 'queue_drag_data.dart';
import 'thumbnail_background_container.dart';

/// A single queue item tile with drag-and-drop support
class QueueItemTile extends StatelessWidget {
  const QueueItemTile({
    required this.item,
    required this.isPlaying,
    required this.tagViewModel,
    required this.playerViewModel,
    required this.useThumbnailBackground,
    super.key,
  });

  final QueueDisplayItem item;
  final bool isPlaying;
  final TagViewModel tagViewModel;
  final PlayerViewModel playerViewModel;
  final bool useThumbnailBackground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final song = item.songUnit!;

    final dragData = QueueDragData.song(
      flatIndex: item.flatIndex,
      playlistItemId: item.playlistItemId,
    );

    final dragFeedback = Material(
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
            _buildLeading(song, false, theme),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                song.metadata.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );

    return LongPressDraggable<QueueDragData>(
      data: dragData,
      feedback: dragFeedback,
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildTileContent(context, theme, song),
      ),
      child: _buildTileContent(context, theme, song),
    );
  }

  Widget _buildTileContent(BuildContext context, ThemeData theme, dynamic song) {
    return ThumbnailBackgroundContainer(
      metadata: song.metadata,
      useThumbnailBackground: useThumbnailBackground,
      fallbackSourceIds: [
        ...song.sources.audioSources.map((s) => s.id),
        ...song.sources.accompanimentSources.map((s) => s.id),
      ],
      child: ListTile(
        dense: true,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.flatIndex >= 0)
              Container(
                width: 32,
                alignment: Alignment.center,
                child: Text(
                  '${item.flatIndex + 1}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            _buildLeading(song, isPlaying, theme),
          ],
        ),
        title: Text(
          song.metadata.title,
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
          song.metadata.artistDisplay,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.remove_circle_outline, size: 18),
          onPressed: () async {
            final wasPlaying = await tagViewModel.removeFromQueue(item.flatIndex);
            if (wasPlaying) {
              await playerViewModel.stop();
              final nextSong = tagViewModel.currentSongUnit;
              if (nextSong != null) {
                await playerViewModel.play(nextSong);
              }
            }
          },
          tooltip: 'Remove from queue',
        ),
        selected: isPlaying,
        onTap: () async {
          await tagViewModel.jumpTo(item.flatIndex);
          await playerViewModel.play(song);
        },
      ),
    );
  }

  void _showQueueItemContextMenu(BuildContext context, Offset position) {
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
        if (tagVM.queue.length > 1)
          const PopupMenuItem(
            value: 'deduplicate',
            child: ListTile(
              leading: Icon(Icons.filter_1),
              title: Text('Remove Duplicates'),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (tagVM.queue.length > 1)
          const PopupMenuItem(
            value: 'shuffle',
            child: ListTile(
              leading: Icon(Icons.shuffle),
              title: Text('Shuffle'),
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
                  ? 'Remove After Play: ON'
                  : 'Remove After Play: OFF',
            ),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        if (tagVM.queue.isNotEmpty)
          const PopupMenuItem(
            value: 'clear',
            child: ListTile(
              leading: Icon(Icons.clear_all),
              title: Text('Clear Queue'),
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
                content: Text('Removed $removedCount duplicate(s)'),
                duration: const Duration(seconds: 2),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No duplicates found'),
                duration: Duration(seconds: 2),
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

  Widget _buildLeading(dynamic song, bool isPlaying, ThemeData theme) {
    if (isPlaying) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.play_arrow,
          color: theme.colorScheme.primary,
          size: 24,
        ),
      );
    }

    if (song.metadata.thumbnailSourceId != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedThumbnail(
          metadata: song.metadata,
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
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.music_note,
        color: theme.colorScheme.onSurfaceVariant,
        size: 20,
      ),
    );
  }
}
