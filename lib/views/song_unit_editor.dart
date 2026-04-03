import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/translations.g.dart';
import '../models/source.dart';
import '../models/source_origin.dart';
import '../viewmodels/library_view_model.dart';
import '../viewmodels/settings_view_model.dart';
import '../viewmodels/song_unit_editor_view_model.dart';
import 'song_unit_editor/metadata_section.dart';
import 'song_unit_editor/source_list_section.dart';
import 'song_unit_editor/source_with_validation.dart';
import 'song_unit_editor/user_tags_section.dart';
import 'widgets/video_removal_prompt.dart';

/// Song Unit editor view.
/// All business logic lives in [SongUnitEditorViewModel].
class SongUnitEditor extends StatefulWidget {
  const SongUnitEditor({super.key, this.songUnitId});
  final String? songUnitId;

  @override
  State<SongUnitEditor> createState() => _SongUnitEditorState();
}

class _SongUnitEditorState extends State<SongUnitEditor> {
  final _formKey = GlobalKey<FormState>();

  // Text controllers live in the view because they are UI-only concerns.
  final _nameController = TextEditingController();
  final _albumController = TextEditingController();
  final _timeController = TextEditingController();

  late final SongUnitEditorViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = SongUnitEditorViewModel(
      libraryViewModel: context.read<LibraryViewModel>(),
      settingsViewModel: context.read<SettingsViewModel>(),
    );
    _vm.addListener(_onViewModelChanged);

    if (widget.songUnitId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _vm.loadSongUnit(widget.songUnitId!);
        _syncControllersFromVm();
      });
    }
  }

  @override
  void dispose() {
    _vm.removeListener(_onViewModelChanged);
    _vm.dispose();
    _nameController.dispose();
    _albumController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  /// React to ViewModel changes: show messages, pop on save, sync controllers.
  void _onViewModelChanged() {
    if (!mounted) return;

    final msg = _vm.consumeMessage();
    if (msg != null) {
      final text = _translateMessage(msg);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }

    if (_vm.consumeShouldPop()) {
      Navigator.pop(context);
      return;
    }

    // Sync text controllers when VM metadata changes (e.g. after extraction)
    _syncControllersFromVm();
    setState(() {}); // Rebuild with new VM state
  }

  String _translateMessage(EditorMessage msg) {
    final t = context.t.songEditor;
    return switch (msg) {
      CannotSaveInPlaceNoLocationsMsg() => t.cannotSaveInPlaceNoLocations,
      FailedToLoadUrlMsg() => t.failedToLoadUrl,
      NoAudioSourcesForMetadataMsg() => t.noAudioSourcesForMetadata,
      CannotExtractFromApiMsg() => t.cannotExtractFromApi,
      MetadataReloadedMsg() => t.metadataReloaded,
      AudioExtractedMsg(:final name) =>
        t.audioExtracted.replaceAll('{name}', name),
      NoAudioFoundMsg(:final name) =>
        t.noAudioFound.replaceAll('{name}', name),
      AutoDiscoveredMsg(:final types) =>
        t.autoDiscovered.replaceAll('{types}', types),
      AddedSourceMsg(:final title) =>
        t.addedSource.replaceAll('{title}', title),
      ErrorMsg(:final detail) => '${context.t.common.error}: $detail',
    };
  }

  /// Push VM metadata into text controllers (one-way: VM → controllers).
  void _syncControllersFromVm() {
    if (_nameController.text != _vm.name) _nameController.text = _vm.name;
    if (_albumController.text != _vm.album) _albumController.text = _vm.album;
    if (_timeController.text != _vm.time) _timeController.text = _vm.time;
  }

  /// Push text controller values into VM before save.
  void _syncVmFromControllers() {
    _vm.setName(_nameController.text);
    _vm.setAlbum(_albumController.text);
    _vm.setTime(_timeController.text);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _vm.isEditing
              ? context.t.songEditor.titleEdit
              : context.t.songEditor.titleNew,
        ),
        actions: [
          if (_vm.isEditing) ...[
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _vm.reloadMetadataFromSource(),
              tooltip: context.t.songEditor.reloadMetadata,
            ),
            IconButton(
              icon: const Icon(Icons.save_alt),
              onPressed: _showWriteMetadataDialog,
              tooltip: context.t.songEditor.writeMetadata,
            ),
          ],
          TextButton(
            onPressed: () {
              if (!_formKey.currentState!.validate()) return;
              _syncVmFromControllers();
              _vm.saveSongUnit();
            },
            child: Text(context.t.common.save),
          ),
        ],
      ),
      body: _vm.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SourcesSection(
                    displaySources: _vm.displaySources,
                    audioSources: _vm.audioSources,
                    accompanimentSources: _vm.accompanimentSources,
                    hoverSources: _vm.hoverSources,
                    onAdd: _showAddSourceDialog,
                    onRemove: _removeSource,
                    onReorder: _vm.reorderSources,
                    onEditName: _showEditSourceNameDialog,
                    onEditOffset: _showOffsetDialog,
                    getSourceName: SongUnitEditorViewModel.getSourceName,
                    getLinkedVideoName: _vm.getLinkedVideoName,
                  ),
                  const SizedBox(height: 24),
                  MetadataSection(
                    nameController: _nameController,
                    albumController: _albumController,
                    timeController: _timeController,
                    artistValues: _vm.artistValues,
                    thumbnailPath: _vm.thumbnailPath,
                    availableThumbnails: _vm.availableThumbnails,
                    isExtractingThumbnails: _vm.isExtractingThumbnails,
                    hasAudioSources: _vm.hasAudioSources,
                    onAddArtist: () => _showAddArtistDialog(context),
                    onRemoveArtist: (i) => _vm.removeArtist(i),
                    onPickThumbnail: _pickThumbnail,
                    onSelectThumbnail: _showThumbnailSelectionDialog,
                    onReloadThumbnails: () => _vm.reloadThumbnailsFromSources(),
                    onClearThumbnail: () => _vm.clearThumbnail(),
                  ),
                  const SizedBox(height: 24),
                  UserTagsSection(
                    selectedUserTagIds: _vm.selectedUserTagIds,
                    onToggleTag: _vm.toggleUserTag,
                  ),
                ],
              ),
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dialogs (UI-only — delegate actions to VM)
  // ---------------------------------------------------------------------------

  void _showAddSourceDialog(SourceType type) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t.songEditor.addSource),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.folder),
              title: Text(ctx.t.songEditor.localFile),
              onTap: () {
                Navigator.pop(ctx);
                _pickFile(type);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFile(SourceType type) async {
    final extensions = _vm.getFileExtensions(type);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      allowMultiple: true,
    );
    if (result != null && result.files.isNotEmpty) {
      for (final file in result.files) {
        if (file.path != null) {
          final showWarning =
              await _vm.addSource(type, LocalFileOrigin(file.path!));
          if (showWarning && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.t.songEditor.urlNotDirectMedia),
                duration: const Duration(seconds: 5),
                action: SnackBarAction(label: context.t.common.ok, onPressed: () {}),
              ),
            );
          }
        }
      }
    }
  }

  Future<void> _removeSource(
    List<SourceWithValidation> sources,
    SourceType type,
    int index,
  ) async {
    final query = _vm.prepareRemoveSource(sources, type, index);
    if (query == null) return; // Already removed

    // Need user prompt for linked video/audio
    final action = await showVideoRemovalPrompt(
      context,
      videoSource: query.videoSource,
      linkedAudio: query.linkedAudio,
    );

    if (!mounted) return;

    final choice = switch (action) {
      VideoRemovalAction.cancel => VideoRemovalChoice.cancel,
      VideoRemovalAction.removeBoth => VideoRemovalChoice.removeBoth,
      VideoRemovalAction.keepAudio => VideoRemovalChoice.keepAudio,
    };
    _vm.executeVideoRemoval(query, choice);
  }

  void _showOffsetDialog(
    List<SourceWithValidation> sources,
    SourceType type,
    int index,
  ) {
    final item = sources[index];
    Duration currentOffset;
    if (item.source is DisplaySource) {
      currentOffset = (item.source as DisplaySource).offset;
    } else if (item.source is AudioSource) {
      currentOffset = (item.source as AudioSource).offset;
    } else if (item.source is AccompanimentSource) {
      currentOffset = (item.source as AccompanimentSource).offset;
    } else if (item.source is HoverSource) {
      currentOffset = (item.source as HoverSource).offset;
    } else {
      currentOffset = Duration.zero;
    }
    final controller = TextEditingController(
      text: currentOffset.inMilliseconds.toString(),
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t.songEditor.setOffsetTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.t.songEditor.offsetHint),
            const SizedBox(height: 4),
            Text(context.t.songEditor.offsetNote),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: context.t.songEditor.offsetLabel,
                hintText: '0',
                suffixText: context.t.common.ms,
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(signed: true),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.t.common.cancel),
          ),
          FilledButton(
            onPressed: () {
              final ms = int.tryParse(controller.text) ?? 0;
              _vm.updateSourceOffset(
                sources, type, index, Duration(milliseconds: ms),
              );
              Navigator.pop(dialogContext);
            },
            child: Text(context.t.common.apply),
          ),
        ],
      ),
    );
  }

  void _showEditSourceNameDialog(
    List<SourceWithValidation> sources,
    SourceType type,
    int index,
  ) {
    final item = sources[index];
    final controller = TextEditingController(
      text: item.source.displayName ?? '',
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t.songEditor.editDisplayNameTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${context.t.songEditor.originalName}: ${SongUnitEditorViewModel.getSourceName(item.source)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: context.t.songEditor.displayNameLabel,
                hintText: context.t.songEditor.displayNameHint,
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.t.common.cancel),
          ),
          FilledButton(
            onPressed: () {
              _vm.updateSourceDisplayName(
                sources, type, index,
                controller.text.isEmpty ? null : controller.text,
              );
              Navigator.pop(dialogContext);
            },
            child: Text(context.t.common.save),
          ),
        ],
      ),
    );
  }

  void _showAddArtistDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t.songEditor.addSongs),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: ctx.t.tags.tagName,
            hintText: ctx.t.tags.tagName,
          ),
          autofocus: true,
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              _vm.addArtists(value);
              Navigator.pop(ctx);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.t.common.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _vm.addArtists(controller.text);
                Navigator.pop(ctx);
              }
            },
            child: Text(ctx.t.common.add),
          ),
        ],
      ),
    );
  }

  Future<void> _pickThumbnail() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null &&
        result.files.isNotEmpty &&
        result.files.first.path != null) {
      final filePath = result.files.first.path!;
      final fileName = filePath.split('/').last.split('\\').last;
      try {
        final bytes = await File(filePath).readAsBytes();
        await _vm.pickThumbnailFromBytes(bytes, fileName);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.t.dialogs.errorAddingCustomThumbnail
                    .replaceAll('{error}', e.toString()),
              ),
            ),
          );
        }
      }
    }
  }

  void _showThumbnailSelectionDialog() {
    final thumbnails = _vm.availableThumbnails;
    if (thumbnails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t.common.noThumbnailsAvailable)),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(ctx.t.dialogs.selectThumbnail),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _vm.availableThumbnails.entries.map((entry) {
                  final displayName = entry.key;
                  final thumbnailPath = entry.value;
                  final isSelected = _vm.thumbnailPath == thumbnailPath;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () {
                        _vm.selectThumbnail(thumbnailPath);
                        Navigator.of(dialogContext).pop();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.file(
                                File(thumbnailPath),
                                width: 60, height: 60, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 60, height: 60, color: Colors.grey,
                                  child: const Icon(Icons.error),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                displayName,
                                style: Theme.of(ctx).textTheme.bodyMedium,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isSelected)
                              Icon(Icons.check_circle,
                                  color: Theme.of(ctx).colorScheme.primary),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () {
                                _vm.removeThumbnailEntry(displayName);
                                setDialogState(() {});
                                if (_vm.availableThumbnails.isEmpty) {
                                  Navigator.of(dialogContext).pop();
                                }
                              },
                              tooltip: context.t.songEditor.removeFromCollection,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(ctx.t.common.cancel),
            ),
          ],
        ),
      ),
    );
  }

  void _showWriteMetadataDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.t.songEditor.metadataWriteNotImplemented),
      ),
    );
  }
}
