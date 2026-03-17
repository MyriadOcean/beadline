import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../i18n/translations.g.dart';
import '../../models/metadata.dart';
import '../../models/playback_preferences.dart';
import '../../models/song_unit.dart';
import '../../models/source.dart';
import '../../models/source_collection.dart';
import '../../models/source_origin.dart';
import '../../viewmodels/tag_view_model.dart';
class MergeSongUnitsDialog extends StatefulWidget {
  const MergeSongUnitsDialog({super.key, required this.songUnits, required this.onMerge});
  final List<SongUnit> songUnits;
  final Future<void> Function(SongUnit mergedSongUnit, bool deleteOriginals)
  onMerge;

  @override
  State<MergeSongUnitsDialog> createState() => MergeSongUnitsDialogState();
}

class MergeSongUnitsDialogState extends State<MergeSongUnitsDialog> {
  // Selected metadata field values (index into unique values list)
  int _selectedTitleIndex = 0;
  int _selectedArtistsIndex = 0;
  int _selectedAlbumIndex = 0;
  int _selectedYearIndex = 0;

  // Unique metadata values collected from all song units
  late List<MetadataOption<String>> _titleOptions;
  late List<MetadataOption<List<String>>> _artistsOptions;
  late List<MetadataOption<String>> _albumOptions;
  late List<MetadataOption<int?>> _yearOptions;

  // Deduplicated sources (by origin key)
  late List<DeduplicatedSource<DisplaySource>> _deduplicatedDisplaySources;
  late List<DeduplicatedSource<AudioSource>> _deduplicatedAudioSources;
  late List<DeduplicatedSource<AccompanimentSource>>
  _deduplicatedAccompanimentSources;
  late List<DeduplicatedSource<HoverSource>> _deduplicatedHoverSources;

  // Selected sources (by origin key)
  final Set<String> _selectedDisplayOrigins = {};
  final Set<String> _selectedAudioOrigins = {};
  final Set<String> _selectedAccompanimentOrigins = {};
  final Set<String> _selectedHoverOrigins = {};

  // Selected tags (by tag id)
  final Set<String> _selectedTags = {};

  // Delete originals after merge
  bool _deleteOriginals = true;

  @override
  void initState() {
    super.initState();
    _collectMetadataOptions();
    _deduplicateSources();
    _initializeSelections();
  }

  void _collectMetadataOptions() {
    // Collect unique titles
    final titleMap = <String, List<String>>{};
    for (final song in widget.songUnits) {
      final title = song.metadata.title;
      titleMap
          .putIfAbsent(title, () => [])
          .add(
            song.metadata.title.isNotEmpty ? song.metadata.title : '(Untitled)',
          );
    }
    _titleOptions = titleMap.entries
        .map(
          (e) => MetadataOption(
            e.key,
            widget.songUnits
                .where((s) => s.metadata.title == e.key)
                .map(
                  (s) => s.metadata.title.isNotEmpty
                      ? s.metadata.title
                      : '(Untitled)',
                )
                .toList(),
          ),
        )
        .toList();

    // Collect unique artists (compare as joined string for uniqueness)
    final artistsMap = <String, List<String>>{};
    for (final song in widget.songUnits) {
      final key = song.metadata.artists.join('|');
      artistsMap
          .putIfAbsent(key, () => [])
          .add(
            song.metadata.title.isNotEmpty ? song.metadata.title : '(Untitled)',
          );
    }
    _artistsOptions = artistsMap.entries.map((e) {
      final artists = e.key.isEmpty ? <String>[] : e.key.split('|');
      return MetadataOption(artists, e.value);
    }).toList();

    // Collect unique albums
    final albumMap = <String, List<String>>{};
    for (final song in widget.songUnits) {
      final album = song.metadata.album;
      albumMap
          .putIfAbsent(album, () => [])
          .add(
            song.metadata.title.isNotEmpty ? song.metadata.title : '(Untitled)',
          );
    }
    _albumOptions = albumMap.entries
        .map((e) => MetadataOption(e.key, e.value))
        .toList();

    // Collect unique years
    final yearMap = <int?, List<String>>{};
    for (final song in widget.songUnits) {
      final year = song.metadata.year;
      yearMap
          .putIfAbsent(year, () => [])
          .add(
            song.metadata.title.isNotEmpty ? song.metadata.title : '(Untitled)',
          );
    }
    _yearOptions = yearMap.entries
        .map((e) => MetadataOption(e.key, e.value))
        .toList();
  }

  String _getOriginKey(SourceOrigin origin) {
    switch (origin) {
      case LocalFileOrigin(:final path):
        return 'local:$path';
      case UrlOrigin(:final url):
        return 'url:$url';
      case ApiOrigin(:final provider, :final resourceId):
        return 'api:$provider:$resourceId';
    }
  }

  void _deduplicateSources() {
    // Deduplicate display sources by origin
    final displayMap = <String, DeduplicatedSource<DisplaySource>>{};
    for (final song in widget.songUnits) {
      for (final s in song.sources.displaySources) {
        final key = _getOriginKey(s.origin);
        if (!displayMap.containsKey(key)) {
          displayMap[key] = DeduplicatedSource(s, []);
        }
        displayMap[key]!.fromSongs.add(
          song.metadata.title.isNotEmpty ? song.metadata.title : '(Untitled)',
        );
      }
    }
    _deduplicatedDisplaySources = displayMap.values.toList();

    // Deduplicate audio sources
    final audioMap = <String, DeduplicatedSource<AudioSource>>{};
    for (final song in widget.songUnits) {
      for (final s in song.sources.audioSources) {
        final key = _getOriginKey(s.origin);
        if (!audioMap.containsKey(key)) {
          audioMap[key] = DeduplicatedSource(s, []);
        }
        audioMap[key]!.fromSongs.add(
          song.metadata.title.isNotEmpty ? song.metadata.title : '(Untitled)',
        );
      }
    }
    _deduplicatedAudioSources = audioMap.values.toList();

    // Deduplicate accompaniment sources
    final accompMap = <String, DeduplicatedSource<AccompanimentSource>>{};
    for (final song in widget.songUnits) {
      for (final s in song.sources.accompanimentSources) {
        final key = _getOriginKey(s.origin);
        if (!accompMap.containsKey(key)) {
          accompMap[key] = DeduplicatedSource(s, []);
        }
        accompMap[key]!.fromSongs.add(
          song.metadata.title.isNotEmpty ? song.metadata.title : '(Untitled)',
        );
      }
    }
    _deduplicatedAccompanimentSources = accompMap.values.toList();

    // Deduplicate hover sources
    final hoverMap = <String, DeduplicatedSource<HoverSource>>{};
    for (final song in widget.songUnits) {
      for (final s in song.sources.hoverSources) {
        final key = _getOriginKey(s.origin);
        if (!hoverMap.containsKey(key)) {
          hoverMap[key] = DeduplicatedSource(s, []);
        }
        hoverMap[key]!.fromSongs.add(
          song.metadata.title.isNotEmpty ? song.metadata.title : '(Untitled)',
        );
      }
    }
    _deduplicatedHoverSources = hoverMap.values.toList();
  }

  void _initializeSelections() {
    // Select all deduplicated sources by default
    for (final s in _deduplicatedDisplaySources) {
      _selectedDisplayOrigins.add(_getOriginKey(s.source.origin));
    }
    for (final s in _deduplicatedAudioSources) {
      _selectedAudioOrigins.add(_getOriginKey(s.source.origin));
    }
    for (final s in _deduplicatedAccompanimentSources) {
      _selectedAccompanimentOrigins.add(_getOriginKey(s.source.origin));
    }
    for (final s in _deduplicatedHoverSources) {
      _selectedHoverOrigins.add(_getOriginKey(s.source.origin));
    }
    // Select all tags
    for (final song in widget.songUnits) {
      _selectedTags.addAll(song.tagIds);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 800),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Merge ${widget.songUnits.length} Song Units',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Select metadata values and sources to keep. Duplicate sources are automatically merged.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMetadataSection(context),
                      const Divider(height: 32),
                      _buildSourcesSection(context),
                      const Divider(height: 32),
                      _buildTagsSection(context),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: _deleteOriginals,
                onChanged: (v) => setState(() => _deleteOriginals = v ?? true),
                title: Text(context.t.library.deleteOriginalAfterMerge),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.t.common.cancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _performMerge,
                    child: Text(context.t.library.actions.mergeSelected),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataSection(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.t.library.sectionMetadata, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          context.t.songEditor.chooseMetadataValues,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        // Title field
        _buildMetadataFieldSection<String>(
          context,
          fieldName: 'Title',
          icon: Icons.title,
          options: _titleOptions,
          selectedIndex: _selectedTitleIndex,
          onChanged: (i) => setState(() => _selectedTitleIndex = i),
          displayValue: (v) => v.isEmpty ? '(Empty)' : v,
        ),
        const SizedBox(height: 12),
        // Artists field
        _buildMetadataFieldSection<List<String>>(
          context,
          fieldName: 'Artists',
          icon: Icons.person,
          options: _artistsOptions,
          selectedIndex: _selectedArtistsIndex,
          onChanged: (i) => setState(() => _selectedArtistsIndex = i),
          displayValue: (v) => v.isEmpty ? '(No artists)' : v.join(', '),
        ),
        const SizedBox(height: 12),
        // Album field
        _buildMetadataFieldSection<String>(
          context,
          fieldName: 'Album',
          icon: Icons.album,
          options: _albumOptions,
          selectedIndex: _selectedAlbumIndex,
          onChanged: (i) => setState(() => _selectedAlbumIndex = i),
          displayValue: (v) => v.isEmpty ? '(No album)' : v,
        ),
        const SizedBox(height: 12),
        // Year field
        _buildMetadataFieldSection<int?>(
          context,
          fieldName: 'Year',
          icon: Icons.calendar_today,
          options: _yearOptions,
          selectedIndex: _selectedYearIndex,
          onChanged: (i) => setState(() => _selectedYearIndex = i),
          displayValue: (v) => v?.toString() ?? '(No year)',
        ),
      ],
    );
  }

  Widget _buildMetadataFieldSection<T>(
    BuildContext context, {
    required String fieldName,
    required IconData icon,
    required List<MetadataOption<T>> options,
    required int selectedIndex,
    required void Function(int) onChanged,
    required String Function(T) displayValue,
  }) {
    final theme = Theme.of(context);

    // If only one unique value, just show it without selection
    if (options.length == 1) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: Text(fieldName, style: theme.textTheme.titleSmall),
          ),
          Expanded(
            child: Text(
              displayValue(options[0].value),
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      );
    }

    // Multiple unique values - show radio options
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(fieldName, style: theme.textTheme.titleSmall),
          ],
        ),
        const SizedBox(height: 4),
        ...options.asMap().entries.map((entry) {
          final index = entry.key;
          final option = entry.value;
          return RadioListTile<int>(
            value: index,
            groupValue: selectedIndex,
            onChanged: (v) => onChanged(v ?? 0),
            title: Text(displayValue(option.value)),
            subtitle: Text(
              'From: ${option.fromSongs.join(", ")}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            dense: true,
            contentPadding: const EdgeInsets.only(left: 28),
          );
        }),
      ],
    );
  }

  Widget _buildSourcesSection(BuildContext context) {
    final theme = Theme.of(context);

    final hasAnySources =
        _deduplicatedDisplaySources.isNotEmpty ||
        _deduplicatedAudioSources.isNotEmpty ||
        _deduplicatedAccompanimentSources.isNotEmpty ||
        _deduplicatedHoverSources.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sources', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Duplicate sources (same file/URL) are automatically merged.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        if (_deduplicatedDisplaySources.isNotEmpty) ...[
          _buildDeduplicatedSourceSection(
            context,
            'Display',
            Icons.tv,
            _deduplicatedDisplaySources,
            _selectedDisplayOrigins,
          ),
          const SizedBox(height: 8),
        ],
        if (_deduplicatedAudioSources.isNotEmpty) ...[
          _buildDeduplicatedSourceSection(
            context,
            'Audio',
            Icons.audiotrack,
            _deduplicatedAudioSources,
            _selectedAudioOrigins,
          ),
          const SizedBox(height: 8),
        ],
        if (_deduplicatedAccompanimentSources.isNotEmpty) ...[
          _buildDeduplicatedSourceSection(
            context,
            'Accompaniment',
            Icons.music_note,
            _deduplicatedAccompanimentSources,
            _selectedAccompanimentOrigins,
          ),
          const SizedBox(height: 8),
        ],
        if (_deduplicatedHoverSources.isNotEmpty)
          _buildDeduplicatedSourceSection(
            context,
            'Lyrics',
            Icons.subtitles,
            _deduplicatedHoverSources,
            _selectedHoverOrigins,
          ),
        if (!hasAnySources)
          Text(
            'No sources to merge',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }

  Widget _buildDeduplicatedSourceSection<T extends Source>(
    BuildContext context,
    String label,
    IconData icon,
    List<DeduplicatedSource<T>> sources,
    Set<String> selectedOrigins,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Text(label, style: theme.textTheme.titleSmall),
            const SizedBox(width: 8),
            Text(
              '(${sources.length} unique)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                setState(() {
                  final allKeys = sources
                      .map((s) => _getOriginKey(s.source.origin))
                      .toSet();
                  if (selectedOrigins.containsAll(allKeys)) {
                    selectedOrigins.removeAll(allKeys);
                  } else {
                    selectedOrigins.addAll(allKeys);
                  }
                });
              },
              child: Text(
                selectedOrigins.containsAll(
                      sources.map((s) => _getOriginKey(s.source.origin)),
                    )
                    ? 'Deselect All'
                    : 'Select All',
              ),
            ),
          ],
        ),
        ...sources.map((dedup) {
          final originKey = _getOriginKey(dedup.source.origin);
          final isSelected = selectedOrigins.contains(originKey);
          final isDuplicate = dedup.fromSongs.length > 1;

          return CheckboxListTile(
            value: isSelected,
            onChanged: (v) {
              setState(() {
                if (v == true) {
                  selectedOrigins.add(originKey);
                } else {
                  selectedOrigins.remove(originKey);
                }
              });
            },
            title: Row(
              children: [
                Expanded(child: Text(_getSourceName(dedup.source))),
                if (isDuplicate)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '×${dedup.fromSongs.length}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Text(
              'In: ${dedup.fromSongs.join(", ")}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
          );
        }),
      ],
    );
  }

  Widget _buildTagsSection(BuildContext context) {
    final theme = Theme.of(context);
    final tagViewModel = context.read<TagViewModel>();

    // Build a map of tag ID to tag for quick lookup
    final tagMap = {for (final t in tagViewModel.allTags) t.id: t};

    // Collect tags with their source song units, only include resolvable tags
    final tagInfoList = <TagInfo>[];
    final seenTagIds = <String>{};

    for (final song in widget.songUnits) {
      final songTitle = song.metadata.title.isNotEmpty
          ? song.metadata.title
          : '(Untitled)';
      for (final tagId in song.tagIds) {
        final tag = tagMap[tagId];
        if (tag == null) continue; // Skip unresolvable tags

        if (!seenTagIds.contains(tagId)) {
          seenTagIds.add(tagId);
          tagInfoList.add(TagInfo(tagId, tag.name, []));
        }
        tagInfoList.firstWhere((t) => t.id == tagId).fromSongs.add(songTitle);
      }
    }

    if (tagInfoList.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tags', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'No tags to merge',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    // Sort by tag name for better UX
    tagInfoList.sort((a, b) => a.name.compareTo(b.name));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Tags', style: theme.textTheme.titleMedium),
            const Spacer(),
            TextButton(
              onPressed: () {
                setState(() {
                  final allIds = tagInfoList.map((t) => t.id).toSet();
                  if (_selectedTags.containsAll(allIds)) {
                    _selectedTags.removeAll(allIds);
                  } else {
                    _selectedTags.addAll(allIds);
                  }
                });
              },
              child: Text(
                _selectedTags.containsAll(tagInfoList.map((t) => t.id))
                    ? 'Deselect All'
                    : 'Select All',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...tagInfoList.map((tagInfo) {
          final isSelected = _selectedTags.contains(tagInfo.id);
          final isShared = tagInfo.fromSongs.length == widget.songUnits.length;

          return CheckboxListTile(
            value: isSelected,
            onChanged: (v) {
              setState(() {
                if (v == true) {
                  _selectedTags.add(tagInfo.id);
                } else {
                  _selectedTags.remove(tagInfo.id);
                }
              });
            },
            title: Row(
              children: [
                Expanded(child: Text(tagInfo.name)),
                if (isShared)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'All',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Text(
              'In: ${tagInfo.fromSongs.join(", ")}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
          );
        }),
      ],
    );
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

  void _performMerge() {
    // Build metadata from selected field values
    final title = _titleOptions[_selectedTitleIndex].value;
    final artists = _artistsOptions[_selectedArtistsIndex].value;
    final album = _albumOptions[_selectedAlbumIndex].value;
    final year = _yearOptions[_selectedYearIndex].value;

    // Collect selected sources with updated priorities
    final displaySources = <DisplaySource>[];
    final audioSources = <AudioSource>[];
    final accompanimentSources = <AccompanimentSource>[];
    final hoverSources = <HoverSource>[];

    for (final dedup in _deduplicatedDisplaySources) {
      final key = _getOriginKey(dedup.source.origin);
      if (_selectedDisplayOrigins.contains(key)) {
        displaySources.add(
          dedup.source.copyWith(priority: displaySources.length),
        );
      }
    }
    for (final dedup in _deduplicatedAudioSources) {
      final key = _getOriginKey(dedup.source.origin);
      if (_selectedAudioOrigins.contains(key)) {
        audioSources.add(dedup.source.copyWith(priority: audioSources.length));
      }
    }
    for (final dedup in _deduplicatedAccompanimentSources) {
      final key = _getOriginKey(dedup.source.origin);
      if (_selectedAccompanimentOrigins.contains(key)) {
        accompanimentSources.add(
          dedup.source.copyWith(priority: accompanimentSources.length),
        );
      }
    }
    for (final dedup in _deduplicatedHoverSources) {
      final key = _getOriginKey(dedup.source.origin);
      if (_selectedHoverOrigins.contains(key)) {
        hoverSources.add(dedup.source.copyWith(priority: hoverSources.length));
      }
    }

    // Calculate duration from selected audio sources
    var duration = Duration.zero;
    for (final s in audioSources) {
      final d = s.getDuration();
      if (d != null && d > Duration.zero) {
        duration = d;
        break;
      }
    }
    if (duration == Duration.zero) {
      for (final s in accompanimentSources) {
        final d = s.getDuration();
        if (d != null && d > Duration.zero) {
          duration = d;
          break;
        }
      }
    }

    final mergedSongUnit = SongUnit(
      id: const Uuid().v4(),
      metadata: Metadata(
        title: title,
        artists: artists,
        album: album,
        year: year,
        duration: duration,
      ),
      sources: SourceCollection(
        displaySources: displaySources,
        audioSources: audioSources,
        accompanimentSources: accompanimentSources,
        hoverSources: hoverSources,
      ),
      tagIds: _selectedTags.toList(),
      preferences: const PlaybackPreferences(),
    );

    Navigator.of(context).pop();
    widget.onMerge(mergedSongUnit, _deleteOriginals);
  }
}

/// Helper class for metadata options with source tracking
class MetadataOption<T> {
  MetadataOption(this.value, this.fromSongs);
  final T value;
  final List<String> fromSongs;
}

/// Helper class for deduplicated sources
class DeduplicatedSource<T extends Source> {
  DeduplicatedSource(this.source, this.fromSongs);
  final T source;
  final List<String> fromSongs;
}

/// Helper class for tag info with source tracking
class TagInfo {
  TagInfo(this.id, this.name, this.fromSongs);
  final String id;
  final String name;
  final List<String> fromSongs;
}
