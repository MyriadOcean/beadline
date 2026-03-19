import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../i18n/translations.g.dart';
import '../models/configuration_mode.dart';
import '../models/metadata.dart';
import '../models/online_provider_config.dart';
import '../models/playback_preferences.dart';
import '../models/song_unit.dart';
import '../models/source.dart';
import '../models/source_collection.dart';
import '../models/source_origin.dart';
import '../models/tag.dart';
import '../services/metadata_extractor.dart';
import '../services/source_auto_matcher.dart';
import '../services/thumbnail_cache.dart';
import '../services/thumbnail_extractor.dart';
import '../services/video_audio_extraction_service.dart';
import '../viewmodels/library_view_model.dart';
import '../viewmodels/search_view_model.dart';
import '../viewmodels/settings_view_model.dart';
import '../viewmodels/tag_view_model.dart';
import 'app_theme.dart';
import 'widgets/video_removal_prompt.dart';

/// Helper class for source with validation status
class _SourceWithValidation {
  _SourceWithValidation(this.source, this.error);
  final Source source;
  final String? error;
}

/// Song Unit editor widget
/// Metadata is represented as built-in tags (name, artist, album, time)
class SongUnitEditor extends StatefulWidget {
  const SongUnitEditor({super.key, this.songUnitId});
  final String? songUnitId;

  @override
  State<SongUnitEditor> createState() => _SongUnitEditorState();
}

class _SongUnitEditorState extends State<SongUnitEditor> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  final _metadataExtractor = MetadataExtractor();
  final _thumbnailExtractor = ThumbnailExtractor();
  final _sourceAutoMatcher = SourceAutoMatcher();
  final _videoAudioExtractionService = VideoAudioExtractionService();

  // Controllers for built-in tag fields (to support prefill and updates)
  final _nameController = TextEditingController();
  final _albumController = TextEditingController();
  final _timeController = TextEditingController();

  // Thumbnail path
  String? _thumbnailPath;

  // All available thumbnails: extracted from audio + manually added
  // Key: display name, Value: file path
  final Map<String, String> _availableThumbnails = {};

  // Map thumbnail paths to their source IDs (for extracted thumbnails)
  final Map<String, String> _thumbnailToSourceId = {};

  bool _isExtractingThumbnails = false;

  // Built-in tag values (metadata as tags)
  List<String> _artistValues = [];

  // Sources with validation status
  List<_SourceWithValidation> _displaySources = [];
  List<_SourceWithValidation> _audioSources = [];
  List<_SourceWithValidation> _accompanimentSources = [];
  List<_SourceWithValidation> _hoverSources = [];

  // User tags (non-built-in)
  Set<String> _selectedUserTagIds = {};

  bool _isLoading = false;
  bool _isEditing = false;
  SongUnit? _originalSongUnit;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.songUnitId != null;
    if (_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadSongUnit());
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _albumController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _loadSongUnit() async {
    setState(() => _isLoading = true);
    final viewModel = context.read<LibraryViewModel>();
    final songUnit = await viewModel.getSongUnit(widget.songUnitId!);

    if (songUnit != null && mounted) {
      setState(() {
        _originalSongUnit = songUnit;
        _nameController.text = songUnit.metadata.title;
        _artistValues = List.from(songUnit.metadata.artists);
        _albumController.text = songUnit.metadata.album;
        _timeController.text = songUnit.metadata.year?.toString() ?? '';

        _displaySources = songUnit.sources.displaySources
            .map((s) => _SourceWithValidation(s, null))
            .toList();
        _audioSources = songUnit.sources.audioSources
            .map((s) => _SourceWithValidation(s, null))
            .toList();
        _accompanimentSources = songUnit.sources.accompanimentSources
            .map((s) => _SourceWithValidation(s, null))
            .toList();
        _hoverSources = songUnit.sources.hoverSources
            .map((s) => _SourceWithValidation(s, null))
            .toList();

        _selectedUserTagIds = Set.from(songUnit.tagIds);

        _isLoading = false;
      });

      // Load thumbnail from cache using thumbnailSourceId
      if (songUnit.metadata.thumbnailSourceId != null) {
        final cachedPath = await ThumbnailCache.instance.getThumbnail(
          songUnit.metadata.thumbnailSourceId!,
        );
        if (cachedPath != null && mounted) {
          setState(() {
            _thumbnailPath = cachedPath;
            _thumbnailToSourceId[cachedPath] =
                songUnit.metadata.thumbnailSourceId!;

            // Find the source that matches this thumbnail ID to get a better display name
            final isCustom = songUnit.metadata.thumbnailSourceId!.startsWith(
              'custom_',
            );
            String displayName;

            if (isCustom) {
              displayName =
                  'Custom: ${songUnit.metadata.thumbnailSourceId!.substring(7, 15)}...';
            } else {
              // Find the source with this ID
              final matchingSource =
                  [
                        ...songUnit.sources.audioSources,
                        ...songUnit.sources.accompanimentSources,
                      ]
                      .where((s) => s.id == songUnit.metadata.thumbnailSourceId)
                      .firstOrNull;

              if (matchingSource != null &&
                  matchingSource.origin is LocalFileOrigin) {
                final fileName = (matchingSource.origin as LocalFileOrigin).path
                    .split('/')
                    .last
                    .split('\\')
                    .last;
                displayName = 'From: $fileName';
              } else {
                displayName =
                    'From: ${songUnit.metadata.thumbnailSourceId!.substring(0, 8)}...';
              }
            }

            _availableThumbnails[displayName] = cachedPath;
          });
        }
      }

      // Silently extract thumbnails from audio sources in background (no notification)
      _extractThumbnailsSilently();
    } else {
      setState(() => _isLoading = false);
    }
  }

  /// Extract thumbnails silently without showing notifications
  Future<void> _extractThumbnailsSilently() async {
    final audioFilePaths = <String, String>{}; // path -> sourceId

    // Collect all local audio file paths with their source IDs
    for (final sourceWithValidation in [
      ..._audioSources,
      ..._accompanimentSources,
    ]) {
      final origin = sourceWithValidation.source.origin;
      if (origin is LocalFileOrigin) {
        audioFilePaths[origin.path] = sourceWithValidation.source.id;
      }
    }

    if (audioFilePaths.isEmpty) return;

    // Extract in background without blocking UI
    for (final entry in audioFilePaths.entries) {
      final sourcePath = entry.key;
      final sourceId = entry.value;
      final fileName = sourcePath.split('/').last.split('\\').last;
      final displayName = 'From: $fileName';

      // Skip if already extracted for this source file
      if (_availableThumbnails.containsKey(displayName)) continue;

      try {
        final artworkBytes = await _thumbnailExtractor.extractThumbnailBytes(
          sourcePath,
        );
        if (artworkBytes != null && artworkBytes.isNotEmpty) {
          final cachedThumbnailPath = await ThumbnailCache.instance
              .cacheFromBytes(artworkBytes);

          if (mounted) {
            setState(() {
              _availableThumbnails[displayName] = cachedThumbnailPath;
              _thumbnailToSourceId[cachedThumbnailPath] = sourceId;
            });
          }
        }
      } catch (e) {
        // Silently ignore errors
      }
    }
  }

  List<String> _parseArtists(String artistString) {
    if (artistString.isEmpty) return [];
    final normalized = artistString
        .replaceAll(RegExp(r'\s*[,;/&]\s*'), '|')
        .replaceAll(RegExp(r'\s+feat\.?\s+', caseSensitive: false), '|')
        .replaceAll(RegExp(r'\s+ft\.?\s+', caseSensitive: false), '|')
        .replaceAll(RegExp(r'\s+featuring\s+', caseSensitive: false), '|')
        .replaceAll(RegExp(r'\s+×\s+'), '|')
        .replaceAll(RegExp(r'\s+x\s+', caseSensitive: false), '|');
    return normalized
        .split('|')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  String _joinArtists(List<String> artists) => artists.join(', ');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? context.t.songEditor.titleEdit
              : context.t.songEditor.titleNew,
        ),
        actions: [
          if (_isEditing) ...[
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _reloadMetadataFromSource,
              tooltip: context.t.songEditor.reloadMetadata,
            ),
            IconButton(
              icon: const Icon(Icons.save_alt),
              onPressed: _showWriteMetadataDialog,
              tooltip: context.t.songEditor.writeMetadata,
            ),
          ],
          TextButton(
            onPressed: _saveSongUnit,
            child: Text(context.t.common.save),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSourcesSection(context),
                  const SizedBox(height: 24),
                  _buildBuiltInTagsSection(context),
                  const SizedBox(height: 24),
                  _buildUserTagsSection(context),
                ],
              ),
            ),
    );
  }

  Widget _buildSourcesSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.t.songEditor.sources,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            _buildSourceList(
              context.t.songEditor.display,
              _displaySources,
              SourceType.display,
              Icons.tv,
            ),
            const Divider(),
            _buildSourceList(
              context.t.songEditor.audio,
              _audioSources,
              SourceType.audio,
              Icons.audiotrack,
            ),
            const Divider(),
            _buildSourceList(
              context.t.songEditor.accompaniment,
              _accompanimentSources,
              SourceType.accompaniment,
              Icons.music_note,
            ),
            const Divider(),
            _buildSourceList(
              context.t.songEditor.lyricsLabel,
              _hoverSources,
              SourceType.hover,
              Icons.subtitles,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceList(
    String label,
    List<_SourceWithValidation> sources,
    SourceType type,
    IconData icon,
  ) {
    final showOffset =
        type == SourceType.display ||
        type == SourceType.audio ||
        type == SourceType.accompaniment ||
        type == SourceType.hover;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(label, style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showAddSourceDialog(type),
              tooltip: context.t.songEditor.addSource,
            ),
          ],
        ),
        if (sources.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '${context.t.common.no} $label',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sources.length,
            onReorder: (oldIndex, newIndex) =>
                _reorderSources(sources, type, oldIndex, newIndex),
            itemBuilder: (context, index) {
              final item = sources[index];
              final offset = _getSourceOffset(item.source);

              final linkedVideoName = _getLinkedVideoName(item.source);

              return Card(
                key: ValueKey(item.source.id),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // drag handle index number
                    Padding(
                      padding: const EdgeInsets.only(top: 2, right: 8),
                      child: Text(
                        '${index + 1}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // name — full width
                          Text(
                            item.source.displayName ?? _getSourceName(item.source),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          if (item.source.displayName != null)
                            Text(
                              _getSourceName(item.source),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          if (linkedVideoName != null)
                            Row(
                              children: [
                                Icon(
                                  Icons.videocam,
                                  size: 14,
                                  color: Theme.of(context).colorScheme.tertiary,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'From: $linkedVideoName',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.tertiary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          if (item.error != null)
                            Text(
                              item.error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          if (showOffset && offset != Duration.zero)
                            Text(
                              'Offset: ${_formatOffsetMs(offset)}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                            ),
                          // buttons on second line, right-aligned
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                iconSize: 20,
                                visualDensity: VisualDensity.compact,
                                onPressed: () =>
                                    _showEditSourceNameDialog(sources, type, index),
                                tooltip: 'Edit display name',
                              ),
                              if (showOffset)
                                IconButton(
                                  icon: const Icon(Icons.timer),
                                  iconSize: 20,
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () =>
                                      _showOffsetDialog(sources, type, index),
                                  tooltip: 'Set offset',
                                ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                iconSize: 20,
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _removeSource(sources, type, index),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                ),
              );
            },
          ),
      ],
    );
  }

  Duration _getSourceOffset(Source source) {
    if (source is DisplaySource) return source.offset;
    if (source is AudioSource) return source.offset;
    if (source is AccompanimentSource) return source.offset;
    if (source is HoverSource) return source.offset;
    return Duration.zero;
  }

  String _formatOffsetMs(Duration offset) {
    final ms = offset.inMilliseconds;
    if (ms >= 0) return '+${ms}ms';
    return '${ms}ms';
  }

  void _showOffsetDialog(
    List<_SourceWithValidation> sources,
    SourceType type,
    int index,
  ) {
    final item = sources[index];
    final currentOffset = _getSourceOffset(item.source);
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
              keyboardType: const TextInputType.numberWithOptions(signed: true),
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
              _updateSourceOffset(
                sources,
                type,
                index,
                Duration(milliseconds: ms),
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
    List<_SourceWithValidation> sources,
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
              '${context.t.songEditor.originalName}: ${_getSourceName(item.source)}',
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
              _updateSourceDisplayName(
                sources,
                type,
                index,
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

  void _updateSourceOffset(
    List<_SourceWithValidation> sources,
    SourceType type,
    int index,
    Duration offset,
  ) {
    setState(() {
      final item = sources[index];
      Source updated;

      switch (type) {
        case SourceType.display:
          updated = (item.source as DisplaySource).copyWith(offset: offset);
        case SourceType.audio:
          updated = (item.source as AudioSource).copyWith(offset: offset);
        case SourceType.accompaniment:
          updated = (item.source as AccompanimentSource).copyWith(
            offset: offset,
          );
        case SourceType.hover:
          updated = (item.source as HoverSource).copyWith(offset: offset);
      }

      sources[index] = _SourceWithValidation(updated, item.error);
    });
  }

  void _updateSourceDisplayName(
    List<_SourceWithValidation> sources,
    SourceType type,
    int index,
    String? displayName,
  ) {
    setState(() {
      final item = sources[index];
      Source updated;

      switch (type) {
        case SourceType.display:
          updated = (item.source as DisplaySource).copyWith(
            displayName: displayName,
          );
        case SourceType.audio:
          updated = (item.source as AudioSource).copyWith(
            displayName: displayName,
          );
        case SourceType.accompaniment:
          updated = (item.source as AccompanimentSource).copyWith(
            displayName: displayName,
          );
        case SourceType.hover:
          updated = (item.source as HoverSource).copyWith(
            displayName: displayName,
          );
      }

      sources[index] = _SourceWithValidation(updated, item.error);
    });
  }

  void _reorderSources(
    List<_SourceWithValidation> sources,
    SourceType type,
    int oldIndex,
    int newIndex,
  ) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = sources.removeAt(oldIndex);
      sources.insert(newIndex, item);
      _updateSourcePriorities(sources, type);
    });
  }

  Future<void> _removeSource(
    List<_SourceWithValidation> sources,
    SourceType type,
    int index,
  ) async {
    // Check if removing a video DisplaySource with a linked AudioSource
    if (type == SourceType.display) {
      final source = sources[index].source;
      if (source is DisplaySource && source.displayType == DisplayType.video) {
        // Search for a linked AudioSource in _audioSources
        AudioSource? linkedAudio;
        int? linkedAudioIndex;
        for (var i = 0; i < _audioSources.length; i++) {
          final audio = _audioSources[i].source;
          if (audio is AudioSource &&
              audio.linkedVideoSourceId == source.id) {
            linkedAudio = audio;
            linkedAudioIndex = i;
            break;
          }
        }

        if (linkedAudio != null && linkedAudioIndex != null) {
          final action = await showVideoRemovalPrompt(
            context,
            videoSource: source,
            linkedAudio: linkedAudio,
          );

          if (!mounted) return;

          switch (action) {
            case VideoRemovalAction.cancel:
              return; // Don't remove anything
            case VideoRemovalAction.removeBoth:
              setState(() {
                sources.removeAt(index);
                _updateSourcePriorities(sources, type);
                _audioSources.removeAt(linkedAudioIndex!);
                _updateSourcePriorities(_audioSources, SourceType.audio);
              });
              return;
            case VideoRemovalAction.keepAudio:
              setState(() {
                sources.removeAt(index);
                _updateSourcePriorities(sources, type);
                // Clear the link �?copyWith uses ?? so passing null keeps old
                // value; construct a new AudioSource directly instead.
                final la = linkedAudio!;
                final updated = AudioSource(
                  id: la.id,
                  origin: la.origin,
                  priority: la.priority,
                  displayName: la.displayName,
                  format: la.format,
                  duration: la.duration,
                  offset: la.offset,
                );
                _audioSources[linkedAudioIndex!] =
                    _SourceWithValidation(updated, _audioSources[linkedAudioIndex].error);
                _updateSourcePriorities(_audioSources, SourceType.audio);
              });
              return;
          }
        }
      }
    }

    // Default removal (non-video or video without linked audio)
    setState(() {
      sources.removeAt(index);
      _updateSourcePriorities(sources, type);
    });
  }

  void _updateSourcePriorities(
    List<_SourceWithValidation> sources,
    SourceType type,
  ) {
    for (var i = 0; i < sources.length; i++) {
      final s = sources[i].source;
      Source updated;
      switch (type) {
        case SourceType.display:
          updated = (s as DisplaySource).copyWith(priority: i);
        case SourceType.audio:
          updated = (s as AudioSource).copyWith(priority: i);
        case SourceType.accompaniment:
          updated = (s as AccompanimentSource).copyWith(priority: i);
        case SourceType.hover:
          updated = (s as HoverSource).copyWith(priority: i);
      }
      sources[i] = _SourceWithValidation(updated, sources[i].error);
    }
  }

  String _getSourceName(Source source) {
    switch (source.origin) {
      case LocalFileOrigin(:final path):
        return path.split('/').last.split('\\').last;
      case UrlOrigin(:final url):
        return Uri.tryParse(url)?.pathSegments.lastOrNull ?? url;
      case ApiOrigin(:final provider, :final resourceId):
        return '$provider: $resourceId';
    }
  }

  /// Returns the linked video source's display name if this source is an
  /// extracted audio source, or null otherwise.
  String? _getLinkedVideoName(Source source) {
    if (source is! AudioSource || source.linkedVideoSourceId == null) {
      return null;
    }
    final videoId = source.linkedVideoSourceId!;
    for (final item in _displaySources) {
      if (item.source.id == videoId) {
        return item.source.displayName ?? _getSourceName(item.source);
      }
    }
    // Video source not found (may have been removed) �?show truncated ID
    return videoId.substring(0, 8);
  }

  void _showAddSourceDialog(SourceType type) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t.songEditor.addSource),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.folder),
              title: Text(context.t.songEditor.localFile),
              onTap: () {
                Navigator.pop(context);
                _pickFile(type);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showUrlInputDialog(SourceType type) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t.songEditor.enterUrl),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: context.t.songEditor.urlLabel,
            hintText: context.t.songEditor.urlHint,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.t.common.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                Navigator.pop(context);
                _addSource(type, UrlOrigin(controller.text));
              }
            },
            child: Text(context.t.common.add),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFile(SourceType type) async {
    final extensions = _getFileExtensions(type);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      allowMultiple: true,
    );
    if (result != null && result.files.isNotEmpty) {
      for (final file in result.files) {
        if (file.path != null) {
          await _addSource(type, LocalFileOrigin(file.path!));
        }
      }
    }
  }

  List<String> _getFileExtensions(SourceType type) {
    switch (type) {
      case SourceType.display:
        return [
          'mp4',
          'mkv',
          'avi',
          'mov',
          'webm',
          'jpg',
          'jpeg',
          'png',
          'gif',
          'webp',
        ];
      case SourceType.audio:
      case SourceType.accompaniment:
        return ['mp3', 'flac', 'wav', 'aac', 'ogg', 'm4a'];
      case SourceType.hover:
        return ['lrc'];
    }
  }

  Future<void> _addSource(SourceType type, SourceOrigin origin) async {
    final id = _uuid.v4();
    Source source;
    Duration? duration;

    // Validate URL for audio/video sources
    if (origin is UrlOrigin &&
        (type == SourceType.audio ||
            type == SourceType.accompaniment ||
            type == SourceType.display)) {
      final url = origin.url;
      final uri = Uri.tryParse(url);
      if (uri != null) {
        final path = uri.path.toLowerCase();
        final hasMediaExtension =
            path.endsWith('.mp3') ||
            path.endsWith('.m4a') ||
            path.endsWith('.aac') ||
            path.endsWith('.wav') ||
            path.endsWith('.flac') ||
            path.endsWith('.ogg') ||
            path.endsWith('.mp4') ||
            path.endsWith('.mkv') ||
            path.endsWith('.webm') ||
            path.endsWith('.avi') ||
            path.endsWith('.mov');

        if (!hasMediaExtension && mounted) {
          // Show warning to user
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Warning: URL does not appear to be a direct media file. '
                'Use direct links to audio/video files (e.g., .mp3, .mp4), not web pages.',
              ),
              duration: const Duration(seconds: 5),
              action: SnackBarAction(label: 'OK', onPressed: () {}),
            ),
          );
        }
      }
    }

    // Create source immediately and add to UI (before async operations)
    // This ensures the UI updates immediately
    switch (type) {
      case SourceType.display:
        final isVideo = _isVideoOrigin(origin);
        source = DisplaySource(
          id: id,
          origin: origin,
          priority: _displaySources.length,
          displayType: isVideo ? DisplayType.video : DisplayType.image,
        );
        setState(
          () => _displaySources.add(_SourceWithValidation(source, null)),
        );
      case SourceType.audio:
        source = AudioSource(
          id: id,
          origin: origin,
          priority: _audioSources.length,
          format: _getAudioFormat(origin),
        );
        setState(() => _audioSources.add(_SourceWithValidation(source, null)));
      case SourceType.accompaniment:
        source = AccompanimentSource(
          id: id,
          origin: origin,
          priority: _accompanimentSources.length,
          format: _getAudioFormat(origin),
        );
        setState(
          () => _accompanimentSources.add(_SourceWithValidation(source, null)),
        );
      case SourceType.hover:
        source = HoverSource(
          id: id,
          origin: origin,
          priority: _hoverSources.length,
          format: LyricsFormat.lrc,
        );
        setState(() => _hoverSources.add(_SourceWithValidation(source, null)));
    }

    // Now extract duration, metadata, and thumbnails in background
    // Extract duration for audio/video sources
    if (type == SourceType.audio ||
        type == SourceType.accompaniment ||
        type == SourceType.display) {
      duration = await _extractDuration(origin);

      // Update the source with duration if extracted
      if (duration != null && mounted) {
        setState(() {
          final sourceList = _getSourceList(type);
          final index = sourceList.indexWhere((s) => s.source.id == id);
          if (index != -1) {
            Source updatedSource;
            switch (type) {
              case SourceType.display:
                updatedSource = (sourceList[index].source as DisplaySource)
                    .copyWith(duration: duration);
              case SourceType.audio:
                updatedSource = (sourceList[index].source as AudioSource)
                    .copyWith(duration: duration);
              case SourceType.accompaniment:
                updatedSource =
                    (sourceList[index].source as AccompanimentSource).copyWith(
                      duration: duration,
                    );
              default:
                return;
            }
            sourceList[index] = _SourceWithValidation(updatedSource, null);
          }
        });
      }

      // If duration extraction failed for URL, show error
      if (duration == null && origin is UrlOrigin && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to load media from URL. The URL may be invalid or unreachable.',
            ),
          ),
        );
      }
    }

    // Extract metadata from the first real (non-linked) audio source.
    // When a video is added first, its extracted audio track becomes the first
    // audio source. When the user then adds a real audio source, we should
    // extract metadata from it. We check for real audio sources EXCLUDING the
    // one we just added (id) since it's already in the list.
    if (type == SourceType.audio) {
      final hasOtherRealAudioSource = _audioSources.any((s) {
        final src = s.source;
        return src.id != id &&
            src is AudioSource &&
            src.linkedVideoSourceId == null;
      });
      if (!hasOtherRealAudioSource) {
        await _extractMetadataFromOrigin(origin);
      }
    }

    // Extract thumbnail from audio sources
    if (type == SourceType.audio || type == SourceType.accompaniment) {
      await _extractThumbnailFromOrigin(origin, id);
    }

    // Auto-discover related sources for local files
    if (origin is LocalFileOrigin) {
      await _autoDiscoverRelatedSources(origin.path);
    }

    // Extract audio track from video DisplaySource
    if (type == SourceType.display && source is DisplaySource &&
        source.displayType == DisplayType.video) {
      await _tryExtractAudioFromVideo(source);
    }
  }

  /// Get the source list for a given type
  List<_SourceWithValidation> _getSourceList(SourceType type) {
    switch (type) {
      case SourceType.display:
        return _displaySources;
      case SourceType.audio:
        return _audioSources;
      case SourceType.accompaniment:
        return _accompanimentSources;
      case SourceType.hover:
        return _hoverSources;
    }
  }

  bool _isVideoOrigin(SourceOrigin origin) {
    switch (origin) {
      case LocalFileOrigin(:final path):
        return _isVideoPath(path);
      case UrlOrigin(:final url):
        return _isVideoPath(url);
      case ApiOrigin():
        return true;
    }
  }

  bool _isVideoPath(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ['mp4', 'mkv', 'avi', 'mov', 'webm'].contains(ext);
  }

  AudioFormat _getAudioFormat(SourceOrigin origin) {
    switch (origin) {
      case LocalFileOrigin(:final path):
        return _getAudioFormatFromPath(path);
      case UrlOrigin(:final url):
        return _getAudioFormatFromPath(url);
      case ApiOrigin():
        return AudioFormat.other;
    }
  }

  AudioFormat _getAudioFormatFromPath(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'mp3':
        return AudioFormat.mp3;
      case 'flac':
        return AudioFormat.flac;
      case 'wav':
        return AudioFormat.wav;
      case 'aac':
        return AudioFormat.aac;
      case 'ogg':
        return AudioFormat.ogg;
      case 'm4a':
        return AudioFormat.m4a;
      default:
        return AudioFormat.other;
    }
  }

  /// Try to extract an audio track from a video DisplaySource.
  /// Shows a success snackbar if audio was extracted, or an info snackbar if not.
  Future<void> _tryExtractAudioFromVideo(DisplaySource videoSource) async {
    try {
      final audioSource = await _videoAudioExtractionService
          .createLinkedAudioSource(videoSource);

      if (!mounted) return;

      final videoName = videoSource.displayName ?? _getSourceName(videoSource);

      if (audioSource != null) {
        setState(() {
          _audioSources.add(_SourceWithValidation(audioSource, null));
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t.songEditor.audioExtracted.replaceAll('{name}', videoName)),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t.songEditor.noAudioFound.replaceAll('{name}', videoName)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Video audio extraction error: $e');
    }
  }

  /// Auto-discover and add related sources for a given file path
  Future<void> _autoDiscoverRelatedSources(String filePath) async {
    try {
      debugPrint('Auto-discovering related sources for: $filePath');

      // Discover related sources
      final discovered = await _sourceAutoMatcher.discoverAndCreateSources(
        filePath,
      );

      if (!discovered.hasAnySources) {
        debugPrint('No related sources found');
        return;
      }

      // Track what was added for the notification
      final addedTypes = <String>[];

      // Add discovered sources to the appropriate lists
      if (discovered.audioSources.isNotEmpty) {
        setState(() {
          for (final source in discovered.audioSources) {
            // Check if not already added (avoid duplicates)
            final alreadyExists = _audioSources.any((s) {
              final origin = s.source.origin;
              return origin is LocalFileOrigin &&
                  origin.path == (source.origin as LocalFileOrigin).path;
            });

            if (!alreadyExists) {
              _audioSources.add(_SourceWithValidation(source, null));
            }
          }
        });
        if (discovered.audioSources.isNotEmpty) {
          addedTypes.add('${discovered.audioSources.length} audio');
        }
      }

      if (discovered.videoSources.isNotEmpty) {
        setState(() {
          for (final source in discovered.videoSources) {
            final alreadyExists = _displaySources.any((s) {
              final origin = s.source.origin;
              return origin is LocalFileOrigin &&
                  origin.path == (source.origin as LocalFileOrigin).path;
            });

            if (!alreadyExists) {
              _displaySources.add(_SourceWithValidation(source, null));
            }
          }
        });
        if (discovered.videoSources.isNotEmpty) {
          addedTypes.add('${discovered.videoSources.length} video');
        }
      }

      if (discovered.imageSources.isNotEmpty) {
        setState(() {
          for (final source in discovered.imageSources) {
            final alreadyExists = _displaySources.any((s) {
              final origin = s.source.origin;
              return origin is LocalFileOrigin &&
                  origin.path == (source.origin as LocalFileOrigin).path;
            });

            if (!alreadyExists) {
              _displaySources.add(_SourceWithValidation(source, null));
            }
          }
        });
        if (discovered.imageSources.isNotEmpty) {
          addedTypes.add('${discovered.imageSources.length} image');
        }
      }

      if (discovered.lyricsSources.isNotEmpty) {
        setState(() {
          for (final source in discovered.lyricsSources) {
            final alreadyExists = _hoverSources.any((s) {
              final origin = s.source.origin;
              return origin is LocalFileOrigin &&
                  origin.path == (source.origin as LocalFileOrigin).path;
            });

            if (!alreadyExists) {
              _hoverSources.add(_SourceWithValidation(source, null));
            }
          }
        });
        if (discovered.lyricsSources.isNotEmpty) {
          addedTypes.add('${discovered.lyricsSources.length} lyrics');
        }
      }

      if (discovered.accompanimentSources.isNotEmpty) {
        setState(() {
          for (final source in discovered.accompanimentSources) {
            final alreadyExists = _accompanimentSources.any((s) {
              final origin = s.source.origin;
              return origin is LocalFileOrigin &&
                  origin.path == (source.origin as LocalFileOrigin).path;
            });

            if (!alreadyExists) {
              _accompanimentSources.add(_SourceWithValidation(source, null));
            }
          }
        });
        if (discovered.accompanimentSources.isNotEmpty) {
          addedTypes.add(
            '${discovered.accompanimentSources.length} accompaniment',
          );
        }
      }

      // Show notification if any sources were added
      if (addedTypes.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t.songEditor.autoDiscovered.replaceAll('{types}', addedTypes.join(', '))),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Extract thumbnails from newly added audio/accompaniment sources
      for (final source in [
        ...discovered.audioSources,
        ...discovered.accompanimentSources,
      ]) {
        final origin = source.origin;
        if (origin is LocalFileOrigin) {
          await _extractThumbnailFromOrigin(origin, source.id);
        }
      }

      // Extract duration for video sources
      for (final source in discovered.videoSources) {
        final origin = source.origin;
        if (origin is LocalFileOrigin) {
          final duration = await _extractDuration(origin);
          if (duration != null) {
            setState(() {
              final index = _displaySources.indexWhere(
                (s) => s.source.id == source.id,
              );
              if (index != -1) {
                final updated = source.copyWith(duration: duration);
                _displaySources[index] = _SourceWithValidation(updated, null);
              }
            });
          }
        }
      }

      debugPrint(
        'Auto-discovery complete: ${discovered.totalCount} sources found',
      );
    } catch (e) {
      debugPrint('Error during auto-discovery: $e');
    }
  }

  Future<Duration?> _extractDuration(SourceOrigin origin) async {
    try {
      String mediaPath;
      switch (origin) {
        case LocalFileOrigin(:final path):
          mediaPath = path;
        case UrlOrigin(:final url):
          mediaPath = url;
        case ApiOrigin():
          return null;
      }

      return await _extractDurationWithMediaKit(mediaPath);
    } catch (e) {
      return null;
    }
  }

  Future<Duration?> _extractDurationWithMediaKit(String mediaPath) async {
    try {
      final player = mk.Player();
      final completer = Completer<Duration?>();
      StreamSubscription? sub;

      sub = player.stream.duration.listen((d) {
        if (d > Duration.zero && !completer.isCompleted) {
          completer.complete(d);
          sub?.cancel();
        }
      });

      // Open media with timeout to prevent blocking
      await player
          .open(mk.Media(mediaPath), play: false)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint('Media opening timed out: $mediaPath');
              throw TimeoutException('Media opening timed out');
            },
          );

      final duration = await completer.future.timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint('Duration extraction timed out: $mediaPath');
          return null;
        },
      );
      await player.dispose();
      return duration;
    } catch (e) {
      debugPrint('Duration extraction error: $e');
      return null;
    }
  }

  Future<void> _extractMetadataFromOrigin(SourceOrigin origin) async {
    try {
      String? filePath;
      switch (origin) {
        case LocalFileOrigin(:final path):
          filePath = path;
        case UrlOrigin(:final url):
          // URL metadata extraction works on all platforms
          // It only parses the URL path, doesn't download the file
          filePath = url;
        case ApiOrigin():
          return;
      }

      final result = await _metadataExtractor.extractFromFile(filePath);
      if (result.success && result.metadata != null && mounted) {
        setState(() {
          if (_nameController.text.isEmpty) {
            _nameController.text = result.metadata!.title;
          }
          if (_artistValues.isEmpty && result.metadata!.artist.isNotEmpty) {
            _artistValues = _parseArtists(result.metadata!.artist);
          }
          if (_albumController.text.isEmpty) {
            _albumController.text = result.metadata!.album;
          }
          if (_timeController.text.isEmpty && result.metadata!.year != null) {
            _timeController.text = result.metadata!.year.toString();
          }
        });
      }
    } catch (e) {
      // Ignore extraction errors
      debugPrint('Metadata extraction error: $e');
    }
  }

  Future<void> _extractThumbnailFromOrigin(
    SourceOrigin origin,
    String sourceId,
  ) async {
    try {
      // Only extract from local files
      if (origin is! LocalFileOrigin) return;

      final filePath = origin.path;
      final fileName = filePath.split('/').last.split('\\').last;
      final displayName = 'From: $fileName';

      // Skip if already extracted for this source file
      if (_availableThumbnails.containsKey(displayName)) return;

      final artworkBytes = await _thumbnailExtractor.extractThumbnailBytes(
        filePath,
      );

      if (artworkBytes != null && artworkBytes.isNotEmpty) {
        final cachedThumbnailPath = await ThumbnailCache.instance
            .cacheFromBytes(artworkBytes);

        setState(() {
          _availableThumbnails[displayName] = cachedThumbnailPath;
          _thumbnailToSourceId[cachedThumbnailPath] = sourceId;
          _thumbnailPath ??= cachedThumbnailPath;
        });
      }
    } catch (e) {
      // Silently ignore extraction errors
    }
  }

  Future<void> _reloadMetadataFromSource() async {
    if (_audioSources.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t.songEditor.noAudioSources)),
      );
      return;
    }

    final source = _audioSources.first.source;
    String? filePath;
    switch (source.origin) {
      case LocalFileOrigin(:final path):
        filePath = path;
      case UrlOrigin(:final url):
        filePath = url;
      case ApiOrigin():
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t.common.error)),
        );
        return;
    }

    final result = await _metadataExtractor.extractFromFile(filePath);
    if (result.success && result.metadata != null) {
      setState(() {
        _nameController.text = result.metadata!.title;
        _artistValues = _parseArtists(result.metadata!.artist);
        _albumController.text = result.metadata!.album;
        _timeController.text = result.metadata!.year?.toString() ?? '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t.songEditor.reloadMetadata)),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${context.t.common.error}: ${result.errorMessage}',
            ),
          ),
        );
      }
    }
  }

  Future<void> _reloadThumbnailsFromSources() async {
    final audioFilePaths = <String, String>{}; // path -> sourceId

    // Collect all local audio file paths with their source IDs
    for (final sourceWithValidation in [
      ..._audioSources,
      ..._accompanimentSources,
    ]) {
      final origin = sourceWithValidation.source.origin;
      if (origin is LocalFileOrigin) {
        audioFilePaths[origin.path] = sourceWithValidation.source.id;
      }
    }

    if (audioFilePaths.isEmpty) {
      return;
    }

    setState(() => _isExtractingThumbnails = true);

    try {
      for (final entry in audioFilePaths.entries) {
        final sourcePath = entry.key;
        final sourceId = entry.value;
        final fileName = sourcePath.split('/').last.split('\\').last;
        final displayName = 'From: $fileName';

        // Skip if already extracted for this source file
        if (_availableThumbnails.containsKey(displayName)) continue;

        final artworkBytes = await _thumbnailExtractor.extractThumbnailBytes(
          sourcePath,
        );
        if (artworkBytes != null && artworkBytes.isNotEmpty) {
          final cachedThumbnailPath = await ThumbnailCache.instance
              .cacheFromBytes(artworkBytes);

          _availableThumbnails[displayName] = cachedThumbnailPath;
          _thumbnailToSourceId[cachedThumbnailPath] = sourceId;
        }
      }

      setState(() {
        _isExtractingThumbnails = false;
      });
    } catch (e) {
      setState(() => _isExtractingThumbnails = false);
      // Silently ignore errors
    }
  }

  void _showWriteMetadataDialog() {
    if (_audioSources.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t.songEditor.noAudioSources)),
      );
      return;
    }

    final source = _audioSources.first.source;
    if (source.origin is! LocalFileOrigin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t.common.error)),
      );
      return;
    }

    final path = (source.origin as LocalFileOrigin).path;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t.songEditor.writeMetadata),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.t.songEditor.writeMetadata),
            const SizedBox(height: 16),
            Text('${context.t.songEditor.titleEdit}: ${_nameController.text}'),
            Text('${context.t.songEditor.audio}: ${_joinArtists(_artistValues)}'),
            Text('${context.t.songEditor.accompaniment}: ${_albumController.text}'),
            Text('${context.t.songEditor.lyricsLabel}: ${_timeController.text}'),
            const SizedBox(height: 16),
            Text(
              '${context.t.songEditor.localFile}: ${path.split('/').last}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.t.common.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _writeMetadataToSource(path);
            },
            child: Text(context.t.common.save),
          ),
        ],
      ),
    );
  }

  Future<void> _writeMetadataToSource(String path) async {
    // TODO: Implement actual metadata writing using a library like taglib or ffmpeg
    // For now, show a message that this feature is not yet implemented
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Metadata writing is not yet implemented. Requires external library integration.',
        ),
      ),
    );
  }

  Widget _buildBuiltInTagsSection(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: AppTheme.builtInTagColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Built-in Tags (Metadata)',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildBuiltInTagFieldWithController(
              context,
              tagName: 'name',
              aliasHint: 'title',
              label: context.t.songEditor.titleNew,
              controller: _nameController,
              isRequired: true,
            ),
            const SizedBox(height: 12),
            _buildArtistTagsField(context),
            const SizedBox(height: 12),
            _buildBuiltInTagFieldWithController(
              context,
              tagName: 'album',
              label: context.t.songEditor.accompaniment,
              controller: _albumController,
            ),
            const SizedBox(height: 12),
            _buildBuiltInTagFieldWithController(
              context,
              tagName: 'time',
              label: context.t.songEditor.lyricsLabel,
              controller: _timeController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            _buildThumbnailField(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBuiltInTagFieldWithController(
    BuildContext context, {
    required String tagName,
    required String label,
    required TextEditingController controller,
    String? aliasHint,
    bool isRequired = false,
    TextInputType? keyboardType,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Column(
            children: [
              Chip(
                label: Text(tagName),
                backgroundColor: AppTheme.builtInTagColor.withValues(
                  alpha: 0.2,
                ),
                labelStyle: const TextStyle(
                  color: AppTheme.builtInTagColor,
                  fontWeight: FontWeight.bold,
                ),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              if (aliasHint != null)
                Text(
                  '($aliasHint)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              labelText: label,
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            keyboardType: keyboardType,
            validator: isRequired
                ? (v) => (v == null || v.isEmpty) ? '$label is required' : null
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildArtistTagsField(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 80,
              child: Chip(
                label: Text(context.t.songEditor.artist),
                backgroundColor: AppTheme.builtInTagColor.withValues(
                  alpha: 0.2,
                ),
                labelStyle: const TextStyle(
                  color: AppTheme.builtInTagColor,
                  fontWeight: FontWeight.bold,
                ),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  ..._artistValues.asMap().entries.map(
                    (entry) => InputChip(
                      label: Text(entry.value),
                      onDeleted: () =>
                          setState(() => _artistValues.removeAt(entry.key)),
                      backgroundColor: AppTheme.builtInTagColor.withValues(
                        alpha: 0.1,
                      ),
                    ),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: Text(context.t.songEditor.addSongs),
                    onPressed: () => _showAddArtistDialog(context),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_artistValues.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 92, top: 4),
            child: Text(
              context.t.player.noSongPlaying,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  void _showAddArtistDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t.songEditor.addSongs),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: context.t.tags.tagName,
            hintText: context.t.tags.tagName,
          ),
          autofocus: true,
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              setState(() => _artistValues.addAll(_parseArtists(value)));
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.t.common.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(
                  () => _artistValues.addAll(_parseArtists(controller.text)),
                );
                Navigator.pop(context);
              }
            },
            child: Text(context.t.common.add),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnailField(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Column(
            children: [
              Chip(
                label: Text(context.t.songEditor.thumbnail),
                backgroundColor: AppTheme.builtInTagColor.withValues(
                  alpha: 0.2,
                ),
                labelStyle: const TextStyle(
                  color: AppTheme.builtInTagColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_thumbnailPath != null) ...[
                Container(
                  height: 120,
                  width: 120,
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outline),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_thumbnailPath!),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.broken_image,
                        size: 48,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add_photo_alternate, size: 18),
                      label: Text(context.t.songEditor.addImage),
                      onPressed: _pickThumbnail,
                    ),
                    if (_availableThumbnails.isNotEmpty)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.photo_library, size: 18),
                        label: Text(context.t.songEditor.selectThumbnails.replaceAll('{count}', _availableThumbnails.length.toString())),
                        onPressed: _showThumbnailSelectionDialog,
                      ),
                    if (_audioSources.isNotEmpty ||
                        _accompanimentSources.isNotEmpty)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.refresh, size: 18),
                        label: Text(context.t.common.extract),
                        onPressed: _reloadThumbnailsFromSources,
                      ),
                    TextButton.icon(
                      icon: const Icon(Icons.delete, size: 18),
                      label: Text(context.t.common.remove),
                      onPressed: () => setState(() => _thumbnailPath = null),
                    ),
                  ],
                ),
              ] else ...[
                if (_isExtractingThumbnails)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text(context.t.common.extractingThumbnails),
                      ],
                    ),
                  )
                else ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.add_photo_alternate),
                        label: Text(context.t.songEditor.addImage),
                        onPressed: _pickThumbnail,
                      ),
                      if (_availableThumbnails.isNotEmpty)
                        FilledButton.icon(
                          icon: const Icon(Icons.photo_library),
                          label: Text(
                            context.t.songEditor.selectThumbnails.replaceAll('{count}', _availableThumbnails.length.toString()),
                          ),
                          onPressed: _showThumbnailSelectionDialog,
                        ),
                      if (_audioSources.isNotEmpty ||
                          _accompanimentSources.isNotEmpty)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: Text(context.t.common.extract),
                          onPressed: _reloadThumbnailsFromSources,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _availableThumbnails.isEmpty
                        ? 'Add an image or extract from audio files'
                        : '${_availableThumbnails.length} thumbnail(s) available',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickThumbnail() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);

    if (result != null &&
        result.files.isNotEmpty &&
        result.files.first.path != null) {
      final filePath = result.files.first.path!;
      final fileName = filePath.split('/').last.split('\\').last;

      // Generate a unique ID for this custom thumbnail
      final customId = 'custom_${_uuid.v4()}';

      try {
        // Cache the custom thumbnail
        final bytes = await File(filePath).readAsBytes();
        final cachedPath = await ThumbnailCache.instance.cacheFromBytes(bytes);

        setState(() {
          final displayName = 'Custom: $fileName';
          _availableThumbnails[displayName] = cachedPath;
          _thumbnailToSourceId[cachedPath] = customId;
          _thumbnailPath = cachedPath;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.t.dialogs.errorAddingCustomThumbnail.replaceAll('{error}', e.toString()))),
          );
        }
      }
    }
  }

  void _showThumbnailSelectionDialog() {
    if (_availableThumbnails.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t.common.noThumbnailsAvailable)));
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.t.dialogs.selectThumbnail),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _availableThumbnails.entries.map((entry) {
                  final displayName = entry.key;
                  final thumbnailPath = entry.value;
                  final isSelected = _thumbnailPath == thumbnailPath;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () {
                        setState(() => _thumbnailPath = thumbnailPath);
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
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      width: 60,
                                      height: 60,
                                      color: Colors.grey,
                                      child: const Icon(Icons.error),
                                    ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                displayName,
                                style: Theme.of(context).textTheme.bodyMedium,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () {
                                setState(() {
                                  _availableThumbnails.remove(displayName);
                                  // If the deleted thumbnail was selected, clear selection
                                  if (_thumbnailPath == thumbnailPath) {
                                    _thumbnailPath = null;
                                  }
                                });
                                setDialogState(() {});

                                // Close dialog if no thumbnails left
                                if (_availableThumbnails.isEmpty) {
                                  Navigator.of(dialogContext).pop();
                                }
                              },
                              tooltip: 'Remove from collection',
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
                child: Text(context.t.common.cancel),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserTagsSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: AppTheme.userTagColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'User Tags',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Consumer<TagViewModel>(
              builder: (context, tagViewModel, child) {
                if (tagViewModel.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                final userTags = tagViewModel.allTags
                    .where((t) => t.type == TagType.user && !t.isCollection)
                    .toList();

                if (userTags.isEmpty) {
                  return Text(
                    'No user tags available. Create tags in the Tags section.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  );
                }

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: userTags.map((tag) {
                    final isSelected = _selectedUserTagIds.contains(tag.id);
                    final displayName = _getTagDisplayName(tag, tagViewModel);
                    return FilterChip(
                      label: Text(displayName),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedUserTagIds.add(tag.id);
                          } else {
                            _selectedUserTagIds.remove(tag.id);
                          }
                        });
                      },
                      avatar: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppTheme.userTagColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Get display name for tag (full path for child tags)
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

  Duration _calculateDurationFromSources() {
    // Audio source duration is authoritative
    for (final s in _audioSources) {
      final d = s.source.getDuration();
      if (d != null && d > Duration.zero) return d;
    }
    for (final s in _accompanimentSources) {
      final d = s.source.getDuration();
      if (d != null && d > Duration.zero) return d;
    }
    return Duration.zero;
  }

  /// Show online source search dialog
  Future<void> _showOnlineSourceSearch() async {
    final searchViewModel = context.read<SearchViewModel>();
    final settingsViewModel = context.read<SettingsViewModel>();

    // Get available providers
    final providers = await settingsViewModel.getOnlineProviders();
    final enabledProviders = providers.where((p) => p.enabled).toList();

    if (enabledProviders.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No online providers configured. Please configure providers in Settings.',
          ),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => _OnlineSourceSearchDialog(
        searchViewModel: searchViewModel,
        providers: enabledProviders,
        onSourceSelected: _addOnlineSource,
      ),
    );
  }

  /// Add online source to the appropriate list
  void _addOnlineSource(OnlineSourceResult result, SourceType sourceType) {
    Source source;
    final origin = UrlOrigin(result.url);
    final duration = result.duration != null
        ? Duration(seconds: result.duration!)
        : null;

    switch (sourceType) {
      case SourceType.display:
        source = DisplaySource(
          id: _uuid.v4(),
          origin: origin,
          priority: 0,
          displayName: result.title,
          displayType: DisplayType.video,
          duration: duration,
        );
      case SourceType.audio:
        source = AudioSource(
          id: _uuid.v4(),
          origin: origin,
          priority: 0,
          displayName: result.title,
          format: AudioFormat.other,
          duration: duration,
        );
      case SourceType.accompaniment:
        source = AccompanimentSource(
          id: _uuid.v4(),
          origin: origin,
          priority: 0,
          displayName: result.title,
          format: AudioFormat.other,
          duration: duration,
        );
      case SourceType.hover:
        source = HoverSource(
          id: _uuid.v4(),
          origin: origin,
          priority: 0,
          displayName: result.title,
          format: LyricsFormat.lrc,
        );
    }

    final sourceWithValidation = _SourceWithValidation(source, null);

    setState(() {
      switch (sourceType) {
        case SourceType.display:
          _displaySources.add(sourceWithValidation);
        case SourceType.audio:
          _audioSources.add(sourceWithValidation);
        case SourceType.accompaniment:
          _accompanimentSources.add(sourceWithValidation);
        case SourceType.hover:
          _hoverSources.add(sourceWithValidation);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added ${result.title} to ${context.t.songEditor.sources.toLowerCase()} sources'),
      ),
    );

    // Extract audio track from video DisplaySource
    if (sourceType == SourceType.display && source is DisplaySource &&
        source.displayType == DisplayType.video) {
      _tryExtractAudioFromVideo(source);
    }
  }

  Future<void> _saveSongUnit() async {
    if (!_formKey.currentState!.validate()) return;

    final viewModel = context.read<LibraryViewModel>();
    final settingsViewModel = context.read<SettingsViewModel>();

    // Validate library locations in in-place mode
    if (settingsViewModel.configMode == ConfigurationMode.inPlace &&
        settingsViewModel.settings.libraryLocations.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cannot save Song Unit in in-place mode without library locations. '
              'Please configure at least one library location in Settings.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    final duration = _calculateDurationFromSources();

    // Determine thumbnail source ID (content hash of the cached thumbnail file)
    String? thumbnailSourceId;

    if (_thumbnailPath != null) {
      // Extract the content hash from the cached file path: <dir>/<hash>.jpg
      final fileName = _thumbnailPath!.split('/').last.split('\\').last;
      final hash = fileName.endsWith('.jpg')
          ? fileName.substring(0, fileName.length - 4)
          : fileName;
      if (hash.length == 64) {
        thumbnailSourceId = hash;
      }
    }

    final metadata = Metadata(
      title: _nameController.text,
      artists: _artistValues,
      album: _albumController.text,
      year: _timeController.text.isNotEmpty
          ? int.tryParse(_timeController.text)
          : null,
      duration: duration,
      thumbnailSourceId:
          thumbnailSourceId, // Source ID for extracted thumbnails
    );

    final sources = SourceCollection(
      displaySources: _displaySources
          .map((s) => s.source as DisplaySource)
          .toList(),
      audioSources: _audioSources.map((s) => s.source as AudioSource).toList(),
      accompanimentSources: _accompanimentSources
          .map((s) => s.source as AccompanimentSource)
          .toList(),
      hoverSources: _hoverSources.map((s) => s.source as HoverSource).toList(),
    );

    if (_isEditing && _originalSongUnit != null) {
      final updated = _originalSongUnit!.copyWith(
        metadata: metadata,
        sources: sources,
        tagIds: _selectedUserTagIds.toList(),
      );
      await viewModel.updateSongUnitWithConfig(
        songUnit: updated,
        configMode: settingsViewModel.configMode,
        libraryLocations: settingsViewModel.settings.libraryLocations,
      );
    } else {
      final songUnit = SongUnit(
        id: _uuid.v4(),
        metadata: metadata,
        sources: sources,
        tagIds: _selectedUserTagIds.toList(),
        preferences: const PlaybackPreferences(),
      );
      await viewModel.addSongUnitWithConfig(
        songUnit: songUnit,
        configMode: settingsViewModel.configMode,
        libraryLocations: settingsViewModel.settings.libraryLocations,
      );
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }
}

/// Online source search dialog
class _OnlineSourceSearchDialog extends StatefulWidget {
  const _OnlineSourceSearchDialog({
    required this.searchViewModel,
    required this.providers,
    required this.onSourceSelected,
  });

  final SearchViewModel searchViewModel;
  final List<OnlineProviderConfig> providers;
  final void Function(OnlineSourceResult result, SourceType sourceType)
  onSourceSelected;

  @override
  State<_OnlineSourceSearchDialog> createState() =>
      _OnlineSourceSearchDialogState();
}

class _OnlineSourceSearchDialogState extends State<_OnlineSourceSearchDialog> {
  final _searchController = TextEditingController();
  String? _selectedProviderId;
  SourceType _selectedSourceType = SourceType.audio;
  bool _isSearching = false;
  List<OnlineSourceResult> _results = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedProviderId = widget.providers.first.providerId;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    if (_searchController.text.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
      _error = null;
      _results = [];
    });

    try {
      await widget.searchViewModel.searchOnlineSources(
        _searchController.text.trim(),
        type: _selectedSourceType,
        providerName: _selectedProviderId,
      );

      if (mounted) {
        setState(() {
          _results = widget.searchViewModel.sourceResults;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isSearching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        height: 700,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Search Online Sources',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),

            // Provider selection
            DropdownButtonFormField<String>(
              initialValue: _selectedProviderId,
              decoration: const InputDecoration(
                labelText: 'Provider',
                border: OutlineInputBorder(),
              ),
              items: widget.providers.map((provider) {
                return DropdownMenuItem(
                  value: provider.providerId,
                  child: Text(provider.displayName),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedProviderId = value);
              },
            ),
            const SizedBox(height: 12),

            // Source type selection
            DropdownButtonFormField<SourceType>(
              initialValue: _selectedSourceType,
              decoration: const InputDecoration(
                labelText: 'Source Type',
                border: OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: SourceType.display,
                  child: Text(context.t.common.displayVideoImage),
                ),
                DropdownMenuItem(value: SourceType.audio, child: Text(context.t.songEditor.audio)),
                DropdownMenuItem(
                  value: SourceType.accompaniment,
                  child: Text(context.t.songEditor.accompaniment),
                ),
                DropdownMenuItem(
                  value: SourceType.hover,
                  child: Text(context.t.songEditor.lyricsLabel),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedSourceType = value);
                }
              },
            ),
            const SizedBox(height: 12),

            // Search field
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search Query',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _performSearch,
                ),
              ),
              onSubmitted: (_) => _performSearch(),
            ),
            const SizedBox(height: 16),

            // Results
            Expanded(child: _buildResults()),

            // Close button
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.t.common.close),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('${context.t.common.error}: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _performSearch,
              child: Text(context.t.common.retry),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Text(context.t.common.noResultsEnterSearch),
      );
    }

    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final result = _results[index];
        return Card(
          child: ListTile(
            leading: result.thumbnailUrl != null
                ? Image.network(
                    result.thumbnailUrl!,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(Icons.music_note),
                  )
                : const Icon(Icons.music_note, size: 40),
            title: Text(result.title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (result.artist != null) Text('${context.t.common.artistLabel} ${result.artist}'),
                if (result.album != null) Text('${context.t.common.albumLabel} ${result.album}'),
                Text('${context.t.common.platformLabel} ${result.platform}'),
                if (result.duration != null)
                  Text(
                    'Duration: ${Duration(seconds: result.duration!).toString().split('.').first}',
                  ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                widget.onSourceSelected(result, _selectedSourceType);
                Navigator.of(context).pop();
              },
              tooltip: 'Add to Song Unit',
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}
