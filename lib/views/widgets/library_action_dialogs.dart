import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../i18n/translations.g.dart';
import '../../models/song_unit.dart';
import '../../viewmodels/library_view_model.dart';
import '../../viewmodels/settings_view_model.dart';
import '../../viewmodels/tag_view_model.dart';
import 'error_display.dart';

/// Dialog for adding a song unit to a playlist
class AddToPlaylistDialog extends StatelessWidget {

  const AddToPlaylistDialog({
    required this.songUnit,
    this.onCreatePlaylist,
    super.key,
  });
  final SongUnit songUnit;
  final VoidCallback? onCreatePlaylist;

  @override
  Widget build(BuildContext context) {
    final tagViewModel = context.read<TagViewModel>();

    // Get all playlist tags
    final playlistTags = tagViewModel.allTags
        .where((t) => t.name.startsWith('playlist:'))
        .toList();

    return AlertDialog(
      title: Text(context.t.library.actions.addToPlaylist),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (playlistTags.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(context.t.playlists.noPlaylists),
              )
            else
              ...playlistTags.map((tag) {
                final playlistName = tag.name.replaceFirst('playlist:', '');
                final isInPlaylist = songUnit.tagIds.contains(tag.id);
                return ListTile(
                  leading: Icon(
                    isInPlaylist ? Icons.check_circle : Icons.playlist_add,
                    color: isInPlaylist ? Colors.green : null,
                  ),
                  title: Text(playlistName),
                  subtitle: isInPlaylist
                      ? Text(context.t.library.alreadyInPlaylist)
                      : null,
                  onTap: isInPlaylist
                      ? null
                      : () async {
                          await tagViewModel.addToPlaylist(
                            playlistName,
                            songUnit.id,
                          );
                          if (context.mounted) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(context.t.playlists.addedToPlaylist
                                    .replaceAll('{name}', playlistName)),
                              ),
                            );
                          }
                        },
                );
              }),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.add),
              title: Text(context.t.playlists.createPlaylist),
              onTap: () {
                Navigator.of(context).pop();
                onCreatePlaylist?.call();
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.t.common.cancel),
        ),
      ],
    );
  }
}

/// Dialog for creating a new playlist and adding a song unit to it
class CreatePlaylistDialog extends StatefulWidget {

  const CreatePlaylistDialog({
    required this.songUnit,
    super.key,
  });
  final SongUnit songUnit;

  @override
  State<CreatePlaylistDialog> createState() => _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends State<CreatePlaylistDialog> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tagViewModel = context.read<TagViewModel>();

    return AlertDialog(
      title: Text(context.t.playlists.createPlaylist),
      content: TextField(
        controller: _nameController,
        decoration: InputDecoration(
          labelText: context.t.playlists.title,
          hintText: context.t.playlists.createPlaylist,
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.t.common.cancel),
        ),
        FilledButton(
          onPressed: () async {
            final name = _nameController.text.trim();
            if (name.isNotEmpty) {
              await tagViewModel.createPlaylist(name);
              await tagViewModel.addToPlaylist(name, widget.songUnit.id);
              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.t.playlists.createdPlaylistAndAdded
                        .replaceAll('{name}', name)),
                  ),
                );
              }
            }
          },
          child: Text(context.t.library.createAndAdd),
        ),
      ],
    );
  }
}

/// Dialog for deleting a song unit with optional config file deletion
class DeleteSongUnitDialog extends StatefulWidget {

  const DeleteSongUnitDialog({
    required this.songUnit,
    super.key,
  });
  final SongUnit songUnit;

  @override
  State<DeleteSongUnitDialog> createState() => _DeleteSongUnitDialogState();
}

class _DeleteSongUnitDialogState extends State<DeleteSongUnitDialog> {
  bool _deleteConfigFile = false;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<LibraryViewModel>();

    return AlertDialog(
      title: Text(context.t.library.deleteSongUnit),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t.library.deleteItemsConfirm.replaceAll('{count}', '1'),
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            value: _deleteConfigFile,
            onChanged: (value) {
              setState(() {
                _deleteConfigFile = value ?? false;
              });
            },
            title: Text(context.t.library.alsoDeleteConfigFile),
            subtitle: Text(
              context.t.library.configFileNote,
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.t.common.cancel),
        ),
        TextButton(
          onPressed: () async {
            Navigator.of(context).pop();

            if (_deleteConfigFile) {
              // Delete with config file - no undo support for this
              final settingsViewModel = context.read<SettingsViewModel>();
              final success = await viewModel.deleteSongUnitWithConfig(
                id: widget.songUnit.id,
                deleteConfigFile: true,
                currentMode: settingsViewModel.configMode,
                libraryLocations: settingsViewModel.settings.libraryLocations,
              );

              if (context.mounted) {
                if (success) {
                  ErrorSnackBar.showSuccess(
                    context,
                    'Deleted "${widget.songUnit.metadata.title}" and its configuration file.',
                  );
                } else {
                  ErrorSnackBar.show(
                    context,
                    'Failed to delete: ${viewModel.error ?? "Unknown error"}',
                  );
                }
              }
            } else {
              // Delete without config file
              await viewModel.deleteSongUnit(widget.songUnit.id);

              if (context.mounted) {
                ErrorSnackBar.showSuccess(
                  context,
                  'Deleted "${widget.songUnit.metadata.title}".',
                );
              }
            }
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: Text(context.t.common.delete),
        ),
      ],
    );
  }
}

/// Dialog for bulk deleting selected song units
class BulkDeleteDialog extends StatelessWidget {

  const BulkDeleteDialog({
    required this.selectedItems,
    required this.onConfirm,
    super.key,
  });
  final List<SongUnit> selectedItems;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final totalCount = selectedItems.length;
    final fullCount = selectedItems.where((s) => !s.isTemporary).length;
    final tempCount = selectedItems.where((s) => s.isTemporary).length;

    return AlertDialog(
      title: Text(context.t.library.actions.deleteSelected),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.t.library.deleteItemsConfirm
              .replaceAll('{count}', totalCount.toString())),
          if (fullCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('• $fullCount ${context.t.common.songs}'),
            ),
          if (tempCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('• $tempCount ${context.t.library.audioOnly}'),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.t.common.cancel),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onConfirm();
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: Text(context.t.common.delete),
        ),
      ],
    );
  }
}

/// Dialog showing import results
class ImportResultDialog extends StatelessWidget {

  const ImportResultDialog({
    required this.importResult,
    super.key,
  });
  final dynamic importResult;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.t.library.importComplete),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.t.library.imported.replaceAll(
              '{count}', importResult.imported.length.toString())),
          Text(context.t.library.skippedDuplicates.replaceAll(
              '{count}', importResult.skipped.length.toString())),
          if (importResult.errors.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Errors: ${importResult.errors.length}',
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 4),
            ...importResult.errors.take(3).map<Widget>(
                  (e) => Text(
                    '- ${e.fileName}: ${e.message}',
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            if (importResult.errors.length > 3)
              Text(context.t.library.importMore.replaceAll(
                  '{count}', (importResult.errors.length - 3).toString())),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.t.common.ok),
        ),
      ],
    );
  }
}
