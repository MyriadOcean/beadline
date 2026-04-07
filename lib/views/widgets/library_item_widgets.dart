import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../i18n/translations.g.dart';
import '../../models/song_unit.dart';
import '../../models/tag_extensions.dart';
import '../../viewmodels/settings_view_model.dart';
import '../../viewmodels/tag_view_model.dart';
import 'cached_thumbnail.dart';
import 'thumbnail_background_container.dart';

/// Thumbnail widget for library items
class LibraryItemThumbnail extends StatelessWidget {

  const LibraryItemThumbnail({
    required this.songUnit,
    required this.size,
    super.key,
  });
  final SongUnit songUnit;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Collect audio/accompaniment source IDs as fallback cache keys.
    // The editor caches thumbnails by source ID, so this picks them up
    // even if metadata.thumbnailSourceId is null or stale.
    final fallbackIds = <String>[
      ...songUnit.sources.audioSources.map((s) => s.id),
      ...songUnit.sources.accompanimentSources.map((s) => s.id),
    ];

    return CachedThumbnail(
      metadata: songUnit.metadata,
      fallbackSourceIds: fallbackIds,
      width: size,
      height: size,
      borderRadius: BorderRadius.circular(4),
      placeholderColor: theme.colorScheme.onPrimaryContainer,
      placeholderBackgroundColor: theme.colorScheme.primaryContainer,
    );
  }
}

/// Library location chip widget
class LibraryLocationChip extends StatelessWidget {

  const LibraryLocationChip({
    required this.locationName,
    super.key,
  });
  final String locationName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder,
            size: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            locationName,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tag chips row widget with optional max tags limit
class TagChipsRow extends StatelessWidget {

  const TagChipsRow({
    required this.tagIds,
    required this.tagViewModel,
    this.maxTags,
    super.key,
  });
  final List<String> tagIds;
  final TagViewModel tagViewModel;
  final int? maxTags;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tags = tagIds
        .map((id) {
          try {
            return tagViewModel.allTags.firstWhere((t) => t.id == id);
          } catch (e) {
            return null;
          }
        })
        .whereType<Tag>()
        .toList();

    if (tags.isEmpty) return const SizedBox.shrink();

    final displayTags = maxTags != null && tags.length > maxTags!
        ? tags.take(maxTags!).toList()
        : tags;

    final remainingCount = maxTags != null && tags.length > maxTags!
        ? tags.length - maxTags!
        : 0;

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        ...displayTags.map(
          (tag) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _getTagColor(tag, theme),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _getTagDisplayName(tag, tagViewModel),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontSize: 10,
              ),
            ),
          ),
        ),
        if (remainingCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '+$remainingCount',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          ),
      ],
    );
  }

  Color _getTagColor(Tag tag, ThemeData theme) {
    switch (tag.tagType) {
      case TagType.builtIn:
        return theme.colorScheme.primaryContainer;
      case TagType.user:
        return theme.colorScheme.secondaryContainer;
      case TagType.automatic:
        return theme.colorScheme.tertiaryContainer;
    }
  }

  String _getTagDisplayName(Tag tag, TagViewModel tagViewModel) {
    if (tag.parentId == null) {
      return tag.name;
    }

    // Build full path for child tags
    final pathParts = <String>[tag.name];
    Tag? current = tag;

    while (current?.parentId != null) {
      try {
        current = tagViewModel.allTags.firstWhere(
          (t) => t.id == current!.parentId,
        );
        pathParts.insert(0, current.name);
      } catch (e) {
        break;
      }
    }

    return pathParts.join('/');
  }
}

/// Compact tag chips widget for list view (shows all tags)
class CompactTagChips extends StatelessWidget {

  const CompactTagChips({
    required this.tagIds,
    required this.tagViewModel,
    super.key,
  });
  final List<String> tagIds;
  final TagViewModel tagViewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tags = tagIds
        .map((id) {
          try {
            return tagViewModel.allTags.firstWhere((t) => t.id == id);
          } catch (e) {
            return null;
          }
        })
        .whereType<Tag>()
        .toList();

    if (tags.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: tags
          .map(
            (tag) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getTagColor(tag, theme),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _getTagDisplayName(tag, tagViewModel),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontSize: 11,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Color _getTagColor(Tag tag, ThemeData theme) {
    switch (tag.tagType) {
      case TagType.builtIn:
        return theme.colorScheme.primaryContainer;
      case TagType.user:
        return theme.colorScheme.secondaryContainer;
      case TagType.automatic:
        return theme.colorScheme.tertiaryContainer;
    }
  }

  String _getTagDisplayName(Tag tag, TagViewModel tagViewModel) {
    if (tag.parentId == null) {
      return tag.name;
    }

    // Build full path for child tags
    final pathParts = <String>[tag.name];
    Tag? current = tag;

    while (current?.parentId != null) {
      try {
        current = tagViewModel.allTags.firstWhere(
          (t) => t.id == current!.parentId,
        );
        pathParts.insert(0, current.name);
      } catch (e) {
        break;
      }
    }

    return pathParts.join('/');
  }
}

/// List item widget for displaying a Song Unit in list view
class LibraryListItem extends StatelessWidget {

  const LibraryListItem({
    required this.songUnit,
    required this.index,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.onMenuAction,
    super.key,
  });
  final SongUnit songUnit;
  final int index;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final void Function(String action) onMenuAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsVM = context.read<SettingsViewModel>();
    final useThumbnailBackground =
        settingsVM.settings.useThumbnailBackgroundInLibrary;
    final tagViewModel = context.read<TagViewModel>();

    return ThumbnailBackgroundContainer(
      metadata: songUnit.metadata,
      useThumbnailBackground: useThumbnailBackground,
      fallbackSourceIds: [
        ...songUnit.sources.audioSources.map((s) => s.id),
        ...songUnit.sources.accompanimentSources.map((s) => s.id),
      ],
      child: Row(
        children: [
          // Index number on the left
          SizedBox(
            width: 40,
            child: Text(
              '${index + 1}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              leading: isSelectionMode
                  ? Checkbox(
                      value: isSelected,
                      onChanged: (_) => onTap(),
                    )
                  : LibraryItemThumbnail(
                      songUnit: songUnit,
                      size: 40,
                    ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      songUnit.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  if (songUnit.isTemporary) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        context.t.library.audioOnly,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onTertiaryContainer,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Text(
                    _formatDuration(_getAudioDuration(songUnit)),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    songUnit.metadata.artistDisplay,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                  if (songUnit.tagIds.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    CompactTagChips(
                      tagIds: songUnit.tagIds,
                      tagViewModel: tagViewModel,
                    ),
                  ],
                ],
              ),
              trailing: isSelectionMode
                  ? null
                  : PopupMenuButton<String>(
                      onSelected: onMenuAction,
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'add_to_queue',
                          child: ListTile(
                            leading: const Icon(Icons.queue),
                            title: Text(context.t.library.actions.addToQueue),
                            dense: true,
                          ),
                        ),
                        if (!songUnit.isTemporary)
                          PopupMenuItem(
                            value: 'edit',
                            child: ListTile(
                              leading: const Icon(Icons.edit),
                              title: Text(context.t.common.edit),
                              dense: true,
                            ),
                          ),
                        if (songUnit.isTemporary)
                          PopupMenuItem(
                            value: 'promote',
                            child: ListTile(
                              leading: const Icon(Icons.upgrade),
                              title: Text(context.t.library.actions.convertToSongUnit),
                              dense: true,
                            ),
                          ),
                        if (!songUnit.isTemporary)
                          PopupMenuItem(
                            value: 'add_to_playlist',
                            child: ListTile(
                              leading: const Icon(Icons.playlist_add),
                              title: Text(context.t.library.actions.addToPlaylist),
                              dense: true,
                            ),
                          ),
                        if (!songUnit.isTemporary)
                          PopupMenuItem(
                            value: 'export',
                            child: ListTile(
                              leading: const Icon(Icons.file_download),
                              title: Text(context.t.library.actions.exportSelected),
                              dense: true,
                            ),
                          ),
                        PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            leading: const Icon(Icons.delete, color: Colors.red),
                            title: Text(
                              context.t.common.delete,
                              style: const TextStyle(color: Colors.red),
                            ),
                            dense: true,
                          ),
                        ),
                      ],
                    ),
              selected: isSelected,
              onTap: onTap,
              onLongPress: onLongPress,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Duration _getAudioDuration(SongUnit songUnit) {
    if (songUnit.sources.audioSources.isNotEmpty) {
      return songUnit.sources.audioSources.first.duration ?? Duration.zero;
    }
    if (songUnit.sources.accompanimentSources.isNotEmpty) {
      return songUnit.sources.accompanimentSources.first.duration ?? Duration.zero;
    }
    return Duration.zero;
  }
}

/// Grid item widget for displaying a Song Unit in grid view
class LibraryGridItem extends StatelessWidget {

  const LibraryGridItem({
    required this.songUnit,
    required this.isSelected,
    required this.isSelectionMode,
    this.libraryLocationName,
    required this.onTap,
    required this.onLongPress,
    super.key,
  });
  final SongUnit songUnit;
  final bool isSelected;
  final bool isSelectionMode;
  final String? libraryLocationName;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsVM = context.read<SettingsViewModel>();
    final useThumbnailBackground =
        settingsVM.settings.useThumbnailBackgroundInLibrary;
    final tagViewModel = context.read<TagViewModel>();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: useThumbnailBackground
                      ? CachedThumbnail(
                          metadata: songUnit.metadata,
                          placeholderColor:
                              theme.colorScheme.onPrimaryContainer,
                          placeholderBackgroundColor:
                              theme.colorScheme.primaryContainer,
                        )
                      : Container(
                          color: theme.colorScheme.primaryContainer,
                          child: Center(
                            child: Icon(
                              Icons.music_note,
                              size: 48,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              songUnit.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          if (songUnit.isTemporary) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.tertiaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Audio Only',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onTertiaryContainer,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        songUnit.metadata.artistDisplay,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (libraryLocationName != null) ...[
                        const SizedBox(height: 4),
                        LibraryLocationChip(locationName: libraryLocationName!),
                      ],
                      if (songUnit.tagIds.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        TagChipsRow(
                          tagIds: songUnit.tagIds,
                          tagViewModel: tagViewModel,
                          maxTags: 2,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (isSelectionMode)
              Positioned(
                top: 4,
                right: 4,
                child: Checkbox(
                  value: isSelected,
                  onChanged: (_) => onTap(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

