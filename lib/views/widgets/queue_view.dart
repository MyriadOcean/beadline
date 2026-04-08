import 'dart:async';

import 'package:flutter/material.dart';

import '../../i18n/translations.g.dart';
import '../../viewmodels/player_view_model.dart';
import '../../viewmodels/settings_view_model.dart';
import '../../viewmodels/tag_view_model.dart';
import '../queue_management_dialog.dart';
import 'collection/collection_list_view.dart';

/// Queue view widget for displaying and managing the playback queue.
/// Uses the shared [CollectionListView] for rendering items with drag-drop.
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
  State<QueueView> createState() => QueueViewState();
}

class QueueViewState extends State<QueueView> {
  final ScrollController _queueScrollController = ScrollController();

  /// Scroll the queue list to make the currently playing song visible.
  void scrollToCurrentSong() {
    final currentIndex = widget.tagViewModel.currentIndex;
    if (currentIndex < 0 || !_queueScrollController.hasClients) return;

    // Estimate item height (~60px per item) and scroll to center the current item
    const estimatedItemHeight = 60.0;
    final targetOffset = currentIndex * estimatedItemHeight;
    final viewportHeight = _queueScrollController.position.viewportDimension;
    final centeredOffset = (targetOffset - viewportHeight / 2 + estimatedItemHeight / 2)
        .clamp(0.0, _queueScrollController.position.maxScrollExtent);

    _queueScrollController.animateTo(
      centeredOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _queueScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tagVM = widget.tagViewModel;
    final playerVM = widget.playerViewModel;
    final queue = tagVM.queue;
    final displayItems = tagVM.queueDisplayItems;
    final useThumbnailBg =
        widget.settingsViewModel.settings.useThumbnailBackgroundInQueue;

    return Card(
      margin: const EdgeInsets.all(8),
      child: Column(
        children: [
          _buildHeader(context, theme, queue),
          const Divider(height: 1),
          Expanded(
            child: displayItems.isEmpty
                ? _buildEmptyState(context, theme)
                : CollectionListView(
                    collectionId: tagVM.activeQueueId,
                    displayItems: displayItems,
                    tagViewModel: tagVM,
                    scrollController: _queueScrollController,
                    resolveSongUnit: (id) => tagVM.queueSongUnits
                        .where((s) => s.id == id)
                        .firstOrNull,
                    config: CollectionListConfig(
                      showIndex: true,
                      showThumbnailBackground: useThumbnailBg,
                      currentPlayingIndex: tagVM.currentIndex,
                      onSongTap: (song, flatIndex) async {
                        await tagVM.jumpTo(flatIndex);
                        await playerVM.play(song);
                      },
                      onSongRemove: (songUnitId, groupId) async {
                        // Find the flat index for this song
                        final flatIdx = displayItems
                            .where((d) => d.isSong && d.songUnit?.id == songUnitId)
                            .firstOrNull
                            ?.flatIndex ?? -1;
                        if (flatIdx < 0) return;
                        final wasPlaying = await tagVM.removeFromQueue(flatIdx);
                        if (wasPlaying) {
                          await playerVM.stop();
                          final next = tagVM.currentSongUnit;
                          if (next != null) await playerVM.play(next);
                        }
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Header
  // ===========================================================================

  Widget _buildHeader(BuildContext context, ThemeData theme, List queue) {
    final tagVM = widget.tagViewModel;
    final playerVM = widget.playerViewModel;

    return GestureDetector(
      onSecondaryTapUp: (details) {
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
                  Text(context.t.queue.title, style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    context.t.queue.songs.replaceAll('{count}', queue.length.toString()),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.library_music),
              onPressed: () => unawaited(showDialog(context: context, builder: (_) => const QueueManagementDialog())),
              tooltip: context.t.queue.manage,
            ),
            if (queue.isNotEmpty)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                tooltip: context.t.queue.actions,
                onSelected: (value) async {
                  switch (value) {
                    case 'deduplicate':
                      final removed = await tagVM.deduplicateQueue();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(removed > 0
                            ? context.t.queue.removedDuplicates.replaceAll('{count}', removed.toString())
                            : context.t.queue.noDuplicates),
                        duration: const Duration(seconds: 2),
                      ));
                    case 'shuffle':
                      unawaited(tagVM.shuffle(tagVM.activeQueueId));
                    case 'toggle_remove_after_play':
                      tagVM.setRemoveAfterPlay(!tagVM.removeAfterPlay);
                    case 'clear':
                      unawaited(playerVM.stop());
                      unawaited(tagVM.clearQueue());
                  }
                },
                itemBuilder: (context) => [
                  if (tagVM.queue.length > 1)
                    PopupMenuItem(value: 'deduplicate', child: ListTile(leading: const Icon(Icons.filter_1), title: Text(context.t.queue.removeDuplicates), dense: true, contentPadding: EdgeInsets.zero)),
                  if (tagVM.queue.length > 1)
                    PopupMenuItem(value: 'shuffle', child: ListTile(leading: const Icon(Icons.shuffle), title: Text(context.t.dialogs.home.shuffle), dense: true, contentPadding: EdgeInsets.zero)),
                  PopupMenuItem(value: 'toggle_remove_after_play', child: ListTile(leading: Icon(tagVM.removeAfterPlay ? Icons.playlist_remove : Icons.playlist_play), title: Text(tagVM.removeAfterPlay ? context.t.queue.removeAfterPlayOn : context.t.queue.removeAfterPlayOff), dense: true, contentPadding: EdgeInsets.zero)),
                  PopupMenuItem(value: 'clear', child: ListTile(leading: const Icon(Icons.clear_all), title: Text(context.t.queue.clearQueue), dense: true, contentPadding: EdgeInsets.zero)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Context menu & empty state
  // ===========================================================================

  void _showQueueContextMenu(BuildContext context, Offset position) {
    final tagVM = widget.tagViewModel;
    final playerVM = widget.playerViewModel;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: [
        if (tagVM.queue.length > 1)
          PopupMenuItem(value: 'deduplicate', child: ListTile(leading: const Icon(Icons.filter_1), title: Text(context.t.queue.removeDuplicates), dense: true, contentPadding: EdgeInsets.zero)),
        if (tagVM.queue.length > 1)
          PopupMenuItem(value: 'shuffle', child: ListTile(leading: const Icon(Icons.shuffle), title: Text(context.t.queue.shuffle), dense: true, contentPadding: EdgeInsets.zero)),
        PopupMenuItem(value: 'toggle_remove_after_play', child: ListTile(leading: Icon(tagVM.removeAfterPlay ? Icons.check_box : Icons.check_box_outline_blank), title: Text(tagVM.removeAfterPlay ? context.t.queue.removeAfterPlayOn : context.t.queue.removeAfterPlayOff), dense: true, contentPadding: EdgeInsets.zero)),
        if (tagVM.queue.isNotEmpty)
          PopupMenuItem(value: 'clear', child: ListTile(leading: const Icon(Icons.clear_all), title: Text(context.t.queue.clearQueue), dense: true, contentPadding: EdgeInsets.zero)),
        PopupMenuItem(value: 'create_group', child: ListTile(leading: const Icon(Icons.create_new_folder_outlined), title: Text(context.t.playlists.createGroup), dense: true, contentPadding: EdgeInsets.zero)),
      ],
    ).then((value) async {
      if (value == null || !context.mounted) return;
      switch (value) {
        case 'deduplicate':
          final removed = await tagVM.deduplicateQueue();
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(removed > 0
                ? context.t.queue.removedDuplicates.replaceAll('{count}', removed.toString())
                : context.t.queue.noDuplicates),
            duration: const Duration(seconds: 2),
          ));
        case 'shuffle':
          unawaited(tagVM.shuffle(tagVM.activeQueueId));
        case 'toggle_remove_after_play':
          tagVM.setRemoveAfterPlay(!tagVM.removeAfterPlay);
        case 'clear':
          unawaited(playerVM.stop());
          unawaited(tagVM.clearQueue());
        case 'create_group':
          _showCreateGroupDialog(context);
      }
    });
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return GestureDetector(
      onSecondaryTapDown: (details) => _showQueueContextMenu(context, details.globalPosition),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.queue_music, size: 64, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              Text(context.t.queue.empty, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateGroupDialog(BuildContext context) {
    final nameController = TextEditingController();
    final tagVM = widget.tagViewModel;

    showDialog(
      context: context,
      builder: (dc) => AlertDialog(
        title: Text(context.t.playlists.createGroupTitle),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(labelText: context.t.playlists.groupName, hintText: context.t.playlists.enterGroupName),
          autofocus: true,
          onSubmitted: (_) async {
            final name = nameController.text.trim();
            if (name.isNotEmpty) {
              final result = await tagVM.createNestedGroup(tagVM.activeQueueId, name);
              if (result != null && dc.mounted) {
                Navigator.of(dc).pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t.playlists.groupCreated.replaceAll('{name}', result.name))));
                }
              }
            }
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dc).pop(), child: Text(context.t.common.cancel)),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                final result = await tagVM.createNestedGroup(tagVM.activeQueueId, name);
                if (result != null && dc.mounted) {
                  Navigator.of(dc).pop();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t.playlists.groupCreated.replaceAll('{name}', result.name))));
                  }
                }
              }
            },
            child: Text(context.t.common.create),
          ),
        ],
      ),
    );
  }
}
