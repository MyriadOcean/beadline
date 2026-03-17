import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../i18n/translations.g.dart';

import '../models/online_provider_config.dart';
import '../models/song_unit.dart';
import '../models/source.dart';
import '../viewmodels/search_view_model.dart';
import '../viewmodels/tag_view_model.dart';
import 'widgets/cached_thumbnail.dart';
import 'widgets/error_display.dart';
import 'widgets/loading_indicator.dart';
import 'widgets/search_chip.dart';
import 'widgets/suggestion_dropdown.dart';

/// Search view widget for searching Song Units and Sources
/// Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 7.1, 7.2, 7.3, 7.4
class SearchView extends StatefulWidget {
  const SearchView({super.key});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  bool _showQueryBuilder = false;
  String _sourceSearchMode = 'all'; // 'all', 'local', 'online'

  /// Index of the chip currently being edited, or -1 if none.
  int _editingChipIndex = -1;
  final TextEditingController _chipEditController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _chipEditController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t.search.title),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: context.t.search.songUnits),
            Tab(text: context.t.search.sources),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(context),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSongUnitResults(context),
                _buildSourceResults(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final viewModel = context.watch<SearchViewModel>();
    final chips = viewModel.chips;
    final suggestions = viewModel.suggestions;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chip row: rendered when we have parsed chips
          if (chips.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: _buildChipWidgets(context, viewModel, chips),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: context.t.search.hint,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_searchController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              viewModel.clearSearch();
                              setState(() {
                                _editingChipIndex = -1;
                              });
                            },
                          ),
                        IconButton(
                          icon: Icon(
                            _showQueryBuilder ? Icons.text_fields : Icons.tune,
                          ),
                          onPressed: () {
                            setState(() {
                              _showQueryBuilder = !_showQueryBuilder;
                            });
                          },
                          tooltip: _showQueryBuilder
                              ? context.t.search.textMode
                              : context.t.search.queryBuilder,
                        ),
                      ],
                    ),
                    errorText: viewModel.parseError,
                  ),
                  onChanged: (text) {
                    viewModel.updateQueryText(text);
                    setState(() {
                      _editingChipIndex = -1;
                    });
                  },
                  onTap: viewModel.requestSuggestions,
                  onSubmitted: (_) {
                    viewModel.clearSuggestions();
                    if (_tabController.index == 0) {
                      viewModel.executeSearch();
                    } else {
                      _executeSourceSearch(context);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  viewModel.clearSuggestions();
                  if (_tabController.index == 0) {
                    viewModel.executeSearch();
                  } else {
                    _executeSourceSearch(context);
                  }
                },
                child: Text(context.t.common.search),
              ),
            ],
          ),
          // Suggestion dropdown: appears below the search field
          if (suggestions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: SuggestionDropdown(
                suggestions: suggestions,
                onSuggestionSelected: (suggestion) {
                  final newText = viewModel.acceptSuggestion(suggestion);
                  _searchController.text = newText;
                  _searchController.selection = TextSelection.fromPosition(
                    TextPosition(offset: newText.length),
                  );
                },
                onDismiss: viewModel.clearSuggestions,
              ),
            ),
          if (_showQueryBuilder) ...[
            const SizedBox(height: 16),
            _buildQueryBuilder(context),
          ],
        ],
      ),
    );
  }

  /// Build the list of chip widgets from parsed DartQueryChip data.
  /// Uses a color index counter that skips OR operators so condition chips
  /// cycle through the palette and adjacent conditions always differ.
  /// Requirements: 10.1, 10.2, 10.4, 10.5
  List<Widget> _buildChipWidgets(
    BuildContext context,
    SearchViewModel viewModel,
    List<dynamic> chips,
  ) {
    final widgets = <Widget>[];
    var conditionColorIndex = 0;

    for (var i = 0; i < chips.length; i++) {
      final chip = chips[i];
      final chipType = chip.chipType as String;
      final chipText = chip.text as String;

      if (chipType == 'or_operator') {
        widgets.add(
          SearchChip(
            chipType: chipType,
            text: chipText,
            colorIndex: 0, // not used for OR
          ),
        );
        continue;
      }

      // Check if this chip is being edited
      if (_editingChipIndex == i) {
        widgets.add(
          SizedBox(
            width: 160,
            child: TextField(
              controller: _chipEditController,
              autofocus: true,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onSubmitted: (newText) {
                viewModel.editChip(i, newText);
                _searchController.text = viewModel.queryText;
                _searchController.selection = TextSelection.fromPosition(
                  TextPosition(offset: viewModel.queryText.length),
                );
                setState(() {
                  _editingChipIndex = -1;
                });
              },
              onTapOutside: (_) {
                setState(() {
                  _editingChipIndex = -1;
                });
              },
            ),
          ),
        );
      } else {
        widgets.add(
          SearchChip(
            chipType: chipType,
            text: chipText,
            colorIndex: conditionColorIndex,
            onDeleted: () {
              viewModel.deleteChip(i);
              // Sync the text controller with the updated query
              _searchController.text = viewModel.queryText;
              _searchController.selection = TextSelection.fromPosition(
                TextPosition(offset: viewModel.queryText.length),
              );
            },
            onTap: () {
              setState(() {
                _editingChipIndex = i;
                _chipEditController.text = chipText;
              });
            },
          ),
        );
      }

      conditionColorIndex++;
    }

    return widgets;
  }

  Widget _buildQueryBuilder(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t.search.queryBuilder,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 16),
            _buildQueryBuilderRow(
              context,
              label: context.t.search.tag,
              hint: context.t.search.tagExample,
              onAdd: _appendToQuery,
            ),
            const SizedBox(height: 8),
            _buildQueryBuilderRow(
              context,
              label: context.t.search.range,
              hint: context.t.search.rangeExample,
              onAdd: _appendToQuery,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _appendToQuery('OR'),
                  icon: const Icon(Icons.add),
                  label: Text(context.t.search.or),
                ),
                TextButton.icon(
                  onPressed: () => _appendToQuery('-'),
                  icon: const Icon(Icons.remove),
                  label: Text(context.t.search.not),
                ),
                TextButton.icon(
                  onPressed: () => _appendToQuery('('),
                  icon: const Icon(Icons.code),
                  label: Text(context.t.common.openParen),
                ),
                TextButton.icon(
                  onPressed: () => _appendToQuery(')'),
                  icon: const Icon(Icons.code),
                  label: Text(context.t.common.closeParen),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueryBuilderRow(
    BuildContext context, {
    required String label,
    required String hint,
    required void Function(String) onAdd,
  }) {
    final controller = TextEditingController();

    return Row(
      children: [
        SizedBox(width: 60, child: Text(label)),
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: hint, isDense: true),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () {
            if (controller.text.isNotEmpty) {
              onAdd(controller.text);
              controller.clear();
            }
          },
        ),
      ],
    );
  }

  void _appendToQuery(String text) {
    final currentText = _searchController.text;
    final newText = currentText.isEmpty ? text : '$currentText $text';
    _searchController.text = newText;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: newText.length),
    );
    context.read<SearchViewModel>().updateQueryText(newText);
  }

  Widget _buildSongUnitResults(BuildContext context) {
    final viewModel = context.watch<SearchViewModel>();

    if (viewModel.isSearching && viewModel.songUnitResults.isEmpty) {
      return CenteredLoading(message: context.t.search.searching);
    }

    if (viewModel.error != null && viewModel.songUnitResults.isEmpty) {
      return ErrorDisplay(
        title: context.t.search.searchError,
        message: viewModel.error,
        onRetry: viewModel.executeSearch,
      );
    }

    if (viewModel.songUnitResults.isEmpty) {
      return _buildEmptyResults(context, context.t.search.noSongUnitsFound);
    }

    return Column(
      children: [
        // Show error banner if there's an error but we have results
        if (viewModel.error != null)
          ErrorBanner(
            message: viewModel.error!,
            onDismiss: viewModel.clearError,
          ),
        Expanded(
          child: ListView.builder(
            itemCount:
                viewModel.songUnitResults.length +
                (viewModel.hasMoreSongUnits ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == viewModel.songUnitResults.length) {
                return viewModel.isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: CenteredLoading(),
                      )
                    : _buildLoadMoreButton(
                        context,
                        onPressed: viewModel.loadMoreSongUnits,
                      );
              }
              return _buildSongUnitItem(
                context,
                viewModel.songUnitResults[index],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSongUnitItem(BuildContext context, SongUnit songUnit) {
    final tagViewModel = context.read<TagViewModel>();

    return ListTile(
      leading: songUnit.metadata.thumbnailSourceId != null
          ? ClipOval(
              child: CachedThumbnail(
                metadata: songUnit.metadata,
                width: 40,
                height: 40,
              ),
            )
          : CircleAvatar(
              child: Text(
                songUnit.metadata.title.isNotEmpty
                    ? songUnit.metadata.title[0].toUpperCase()
                    : '?',
              ),
            ),
      title: Text(songUnit.metadata.title),
      subtitle: Text(songUnit.metadata.artistDisplay),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: () {
              tagViewModel.requestSong(songUnit.id);
            },
            tooltip: 'Play',
          ),
          IconButton(
            icon: const Icon(Icons.queue),
            onPressed: () {
              tagViewModel.requestSong(songUnit.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.t.search.addedToQueue.replaceAll('{title}', songUnit.metadata.title)),
                ),
              );
            },
            tooltip: 'Add to queue',
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/song-unit-editor',
                arguments: songUnit.id,
              );
            },
            tooltip: 'Edit',
          ),
        ],
      ),
      onTap: () {
        tagViewModel.requestSong(songUnit.id);
      },
    );
  }

  Widget _buildSourceResults(BuildContext context) {
    final viewModel = context.watch<SearchViewModel>();

    return Column(
      children: [
        // Source search mode selector (local/online/all)
        _buildSourceModeSelector(context),
        if (viewModel.error != null)
          ErrorBanner(
            message: viewModel.error!,
            onDismiss: viewModel.clearError,
          ),
        Expanded(child: _buildSourceResultsList(context, viewModel)),
      ],
    );
  }

  Widget _buildSourceModeSelector(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SegmentedButton<String>(
        segments: [
          ButtonSegment(
            value: 'all',
            label: Text(context.t.search.all),
            icon: const Icon(Icons.public),
          ),
          ButtonSegment(
            value: 'local',
            label: Text(context.t.search.local),
            icon: const Icon(Icons.folder),
          ),
          ButtonSegment(
            value: 'online',
            label: Text(context.t.search.online),
            icon: const Icon(Icons.cloud),
          ),
        ],
        selected: {_sourceSearchMode},
        onSelectionChanged: (selection) {
          setState(() {
            _sourceSearchMode = selection.first;
          });
          // Re-run search with new mode
          if (_searchController.text.isNotEmpty) {
            _executeSourceSearch(context);
          }
        },
      ),
    );
  }

  void _executeSourceSearch(BuildContext context) {
    final viewModel = context.read<SearchViewModel>();
    final query = _searchController.text;

    switch (_sourceSearchMode) {
      case 'local':
        viewModel.searchSources(query);
        break;
      case 'online':
        viewModel.searchOnlineSources(query);
        break;
      case 'all':
      default:
        viewModel.searchAllSources(query);
        break;
    }
  }

  Widget _buildSourceResultsList(
    BuildContext context,
    SearchViewModel viewModel,
  ) {
    if (viewModel.isSearching && viewModel.sourceResults.isEmpty) {
      return CenteredLoading(message: context.t.search.searchingSources);
    }

    if (viewModel.error != null && viewModel.sourceResults.isEmpty) {
      return ErrorDisplay(
        title: context.t.search.searchError,
        message: viewModel.error,
        onRetry: () => _executeSourceSearch(context),
      );
    }

    if (viewModel.sourceResults.isEmpty) {
      return _buildEmptyResults(
        context,
        _sourceSearchMode == 'online'
            ? context.t.search.noOnlineSources
            : _sourceSearchMode == 'local'
            ? context.t.search.noLocalSources
            : context.t.search.noSources,
      );
    }

    return ListView.builder(
      itemCount:
          viewModel.sourceResults.length + (viewModel.hasMoreSources ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == viewModel.sourceResults.length) {
          return viewModel.isSearching
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: CenteredLoading(),
                )
              : _buildLoadMoreButton(
                  context,
                  onPressed: () =>
                      viewModel.loadMoreSources(_searchController.text),
                );
        }
        return _buildSourceItem(context, viewModel.sourceResults[index]);
      },
    );
  }

  Widget _buildSourceItem(BuildContext context, OnlineSourceResult source) {
    final isOnline = source.platform != 'Local';

    // Determine source type from URL/path
    final sourceType = _getSourceTypeFromPath(source.url);

    return ListTile(
      leading: Stack(
        children: [
          Icon(_getSourceTypeIcon(sourceType)),
          if (isOnline)
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud,
                  size: 10,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
        ],
      ),
      title: Text(source.title),
      subtitle: Text(
        '${source.platform} - ${sourceType.name}',
        style: TextStyle(
          color: isOnline
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.add),
        onPressed: () {
          // TODO: Add source to current Song Unit
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.t.search.addSource.replaceAll('{title}', source.title))),
          );
        },
        tooltip: 'Add to Song Unit',
      ),
    );
  }

  IconData _getSourceTypeIcon(SourceType type) {
    switch (type) {
      case SourceType.display:
        return Icons.videocam;
      case SourceType.audio:
        return Icons.audiotrack;
      case SourceType.accompaniment:
        return Icons.mic;
      case SourceType.hover:
        return Icons.lyrics;
    }
  }

  /// Determine source type from file path or URL
  SourceType _getSourceTypeFromPath(String path) {
    final extension = path.split('.').last.toLowerCase();

    // Video extensions
    if ([
      'mp4',
      'mkv',
      'avi',
      'mov',
      'wmv',
      'flv',
      'webm',
    ].contains(extension)) {
      return SourceType.display;
    }

    // Audio extensions
    if ([
      'mp3',
      'flac',
      'wav',
      'aac',
      'ogg',
      'm4a',
      'wma',
    ].contains(extension)) {
      return SourceType.audio;
    }

    // Image extensions
    if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension)) {
      return SourceType.display;
    }

    // Lyrics extensions
    if (['lrc'].contains(extension)) {
      return SourceType.hover;
    }

    // Default to audio for unknown types
    return SourceType.audio;
  }

  Widget _buildEmptyResults(BuildContext context, String message) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.t.library.tryDifferentSearch,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMoreButton(
    BuildContext context, {
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: OutlinedButton(
          onPressed: onPressed,
          child: Text(context.t.search.loadMore),
        ),
      ),
    );
  }
}
