import 'dart:async';

import 'package:flutter/material.dart';

import '../../viewmodels/player_view_model.dart';
import '../../viewmodels/tag_view_model.dart';
import 'queue_drag_data.dart';
import 'thumbnail_background_container.dart';

/// A song item displayed inside a queue group
class QueueGroupSongItem extends StatelessWidget {
  const QueueGroupSongItem({
    required this.item,
    required this.parentGroupId,
    required this.isPlaying,
    required this.tagViewModel,
    required this.playerViewModel,
    required this.useThumbnailBackground,
    super.key,
  });

  final QueueDisplayItem item;
  final String parentGroupId;
  final bool isPlaying;
  final TagViewModel tagViewModel;
  final PlayerViewModel playerViewModel;
  final bool useThumbnailBackground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final song = item.songUnit!;
    final flatIdx = item.flatIndex;

    final dragData = QueueDragData.song(
      flatIndex: flatIdx,
      playlistItemId: item.playlistItemId,
      songGroupId: parentGroupId,
    );

    final dragFeedback = Material(
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
        child: _buildTileContent(context, theme, song, flatIdx),
      ),
      child: _buildTileContent(context, theme, song, flatIdx),
    );
  }

  Widget _buildTileContent(
    BuildContext context,
    ThemeData theme,
    dynamic song,
    int flatIdx,
  ) {
    return ThumbnailBackgroundContainer(
      metadata: song.metadata,
      useThumbnailBackground: useThumbnailBackground,
      fallbackSourceIds: [
        ...song.sources.audioSources.map((s) => s.id),
        ...song.sources.accompanimentSources.map((s) => s.id),
      ],
      child: ListTile(
        dense: true,
        leading: _buildLeading(song, isPlaying, theme),
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
            final wasPlaying = await tagViewModel.removeFromQueue(flatIdx);
            if (wasPlaying) {
              unawaited(playerViewModel.stop());
              final nextSong = tagViewModel.currentSongUnit;
              if (nextSong != null) {
                unawaited(playerViewModel.play(nextSong));
              }
            }
          },
          tooltip: 'Remove from queue',
        ),
        selected: isPlaying,
        onTap: () async {
          await tagViewModel.jumpTo(flatIdx);
          await playerViewModel.play(song);
        },
      ),
    );
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
        child: Image.network(
          song.metadata.thumbnailSourceId!,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildDefaultIcon(theme);
          },
        ),
      );
    }

    return _buildDefaultIcon(theme);
  }

  Widget _buildDefaultIcon(ThemeData theme) {
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
