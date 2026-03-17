import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/di/service_locator.dart';
import '../i18n/translations.g.dart';
import '../models/configuration_mode.dart';
import '../models/library_item.dart';
import '../models/library_location.dart';
import '../models/song_unit.dart';
import '../models/source.dart';
import '../models/source_collection.dart';
import '../models/tag.dart';
import '../services/library_location_manager.dart';
import '../services/source_auto_matcher.dart';
import '../src/rust/api/evaluator_api.dart' as rust_evaluator;
import '../viewmodels/library_view_model.dart';
import '../viewmodels/player_view_model.dart';
import '../viewmodels/search_view_model.dart';
import '../viewmodels/settings_view_model.dart';
import '../viewmodels/tag_view_model.dart';
import 'widgets/error_display.dart';
import 'widgets/library_action_dialogs.dart';
import 'widgets/library_item_widgets.dart';
import 'widgets/loading_indicator.dart';
import 'widgets/merge_song_units_dialog.dart';
import 'widgets/suggestion_dropdown.dart';

/// Library view widget for managing Song Units
/// Requirements: 1.1, 1.2, 1.3, 1.4, 1.5
class LibraryView extends StatefulWidget {
  const LibraryView({super.key});

  @override
  State<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<LibraryView> {
  bool _isGridView = false;
  final Set<String> _selectedIds = {};
  bool _isSelectionMode = false;

  /// Cached library locations for display
  Map<String, LibraryLocation> _libraryLocations = {};

  /// Current library location filter (null = show all)
  String? _libraryLocationFilter;

  /// Search controller
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  bool _showSuggestions = false;
  bool _suppressFocusShow = false;

  /// IDs of song units matching the current Rust-evaluated search query.
  /// Null means no active search (show all). Empty set means search returned nothing.
  Set<String>? _matchingSearchIds;

  /// Handle ESC key to dismiss suggestions or unfocus.
  /// Called from a parent Focus widget so it doesn't interfere with TextField input.
  KeyEventResult _handleSearchKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      if (_showSuggestions) {
        setState(() => _showSuggestions = false);
        context.read<SearchViewModel>().clearSuggestions();
        return KeyEventResult.handled;
      }
      // If suggestions already hidden, unfocus the field
      _searchFocusNode.unfocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void initState() {
    super.initState();

    // Load library on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LibraryViewModel>().loadAndSync();
      _loadLibraryLocations();
    });

    // Show/hide suggestions based on focus
    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus) {
        if (_suppressFocusShow) {
          _suppressFocusShow = false;
          return;
        }
        setState(() => _showSuggestions = true);
        // Trigger suggestions (shows history + all tags when empty)
        context.read<SearchViewModel>().requestSuggestions();
      } else {
        // Delay hiding so that suggestion tap handlers can fire first
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted && !_searchFocusNode.hasFocus) {
            setState(() => _showSuggestions = false);
            context.read<SearchViewModel>().clearSuggestions();
          }
        });
      }
    });

    // Listen to search changes - update suggestions and trigger rebuild for clear button
    _searchController.addListener(() {
      // Update suggestions via SearchViewModel
      context.read<SearchViewModel>().updateQueryText(_searchController.text);
      // Force rebuild so clear button visibility updates
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// Execute search: save to history and apply filter via Rust FFI
  Future<void> _executeSearch() async {
    final searchVM = context.read<SearchViewModel>();
    final text = _searchController.text;
    if (text.isNotEmpty) {
      searchVM.addToHistory(text);
    }
    searchVM.clearSuggestions();
    _searchFocusNode.unfocus();

    if (text.trim().isEmpty) {
      setState(() {
        _searchQuery = '';
        _matchingSearchIds = null;
        _showSuggestions = false;
      });
      return;
    }

    // Delegate to Rust - it fetches everything from DB itself
    try {
      final matchingIds = await rust_evaluator.searchSongUnits(
        queryText: text.trim(),
        nameAutoSearch: true,
      );
      if (mounted) {
        setState(() {
          _searchQuery = text.toLowerCase();
          _matchingSearchIds = matchingIds.toSet();
          _showSuggestions = false;
        });
      }
    } catch (_) {
      // If Rust parsing fails, fall back to simple text search
      if (mounted) {
        setState(() {
          _searchQuery = text.toLowerCase();
          _matchingSearchIds = null; // null = use fallback text search
          _showSuggestions = false;
        });
      }
    }
  }

  /// Build clear button using ValueListenableBuilder so it reacts to text changes
  Widget? _buildClearButton(SearchViewModel searchVM) {
    if (_searchController.text.isNotEmpty || _searchQuery.isNotEmpty) {
      return IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          _searchController.clear();
          searchVM.clearSearch();
          setState(() {
            _searchQuery = '';
            _matchingSearchIds = null;
            _showSuggestions = false;
          });
        },
      );
    }
    return null;
  }

  Future<void> _loadLibraryLocations() async {
    try {
      final manager = getIt<LibraryLocationManager>();
      final locations = await manager.getLocations();
      setState(() {
        _libraryLocations = {for (final loc in locations) loc.id: loc};
      });
    } catch (e) {
      // Ignore errors - library locations are optional
    }
  }

  /// Get the library location name for a song unit
  String? _getLibraryLocationName(SongUnit songUnit) {
    if (songUnit.libraryLocationId == null) return null;
    return _libraryLocations[songUnit.libraryLocationId]?.name;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: Consumer<LibraryViewModel>(
        builder: (context, viewModel, child) {
          return Stack(
            children: [
              LoadingOverlay(
                isLoading: viewModel.isLoading,
                message: context.t.library.loading,
                child: _buildContent(context, viewModel),
              ),
              // Progress overlay for import/export
              if (viewModel.isOperationInProgress)
                _buildProgressOverlay(context, viewModel),
            ],
          );
        },
      ),
      floatingActionButton: _buildFab(context),
    );
  }

  Widget _buildProgressOverlay(
    BuildContext context,
    LibraryViewModel viewModel,
  ) {
    final progress = viewModel.operationProgress;
    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(32),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                if (progress != null) ...[
                  Text(
                    progress.message,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: progress.progress),
                  const SizedBox(height: 8),
                  Text(
                    '${progress.current} / ${progress.total}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ] else
                    Text(context.t.library.processing),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, LibraryViewModel viewModel) {
    if (viewModel.error != null && viewModel.libraryItems.isEmpty) {
      return _buildErrorState(context, viewModel);
    }

    if (viewModel.libraryItems.isEmpty && !viewModel.isLoading) {
      return _buildEmptyState(context);
    }

    return GestureDetector(
      onTap: () {
        // Dismiss suggestions when tapping outside the search bar
        if (_showSuggestions) {
          setState(() => _showSuggestions = false);
          context.read<SearchViewModel>().clearSuggestions();
        }
        _searchFocusNode.unfocus();
      },
      behavior: HitTestBehavior.translucent,
      child: Column(
        children: [
          // Search bar at the top
          if (!_isSelectionMode) _buildSearchBar(context),
          // Show error banner if there's an error but we have data
          if (viewModel.error != null)
            ErrorBanner(
              message: viewModel.error!,
              onDismiss: viewModel.clearError,
              onRetry: viewModel.refresh,
            ),
          // Content
          Expanded(
            child: _isGridView
                ? _buildGridView(context, viewModel)
                : _buildListView(context, viewModel),
          ),
        ],
      ),
    );
  }

  /// Build search bar with suggestion dropdown
  Widget _buildSearchBar(BuildContext context) {
    final theme = Theme.of(context);
    final searchVM = context.watch<SearchViewModel>();
    final suggestions = searchVM.suggestions;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Focus(
                  onKeyEvent: _handleSearchKeyEvent,
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    decoration: InputDecoration(
                      hintText: context.t.library.searchHint,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _buildClearButton(searchVM),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _executeSearch(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                icon: const Icon(Icons.search),
                onPressed: _executeSearch,
                tooltip: 'Search',
              ),
            ],
          ),
          if (_showSuggestions && suggestions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: SuggestionDropdown(
                suggestions: suggestions,
                onSuggestionSelected: (suggestion) {
                  final isKeySelection = suggestion.insertText.endsWith(':');
                  final newText = searchVM.acceptSuggestion(suggestion);
                  // Update the text field to match the new query text
                  _searchController.text = newText;
                  _searchController.selection = TextSelection.fromPosition(
                    TextPosition(offset: newText.length),
                  );
                  if (isKeySelection) {
                    // Key selected (e.g. "album:") - keep suggestions open,
                    // cursor stays after colon for user to type value
                    setState(() {
                      _showSuggestions = true;
                    });
                  } else {
                    // Value selected - close suggestions, keep focus for Enter
                    _suppressFocusShow = true;
                    setState(() {
                      _showSuggestions = false;
                    });
                    _searchFocusNode.requestFocus();
                  }
                },
                onDismiss: () {
                  setState(() => _showSuggestions = false);
                  searchVM.clearSuggestions();
                },
              ),
            ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    final viewModel = context.watch<LibraryViewModel>();

    if (_isSelectionMode) {
      // Check what types are selected
      final selectedFull = viewModel.songUnits
          .where((s) => _selectedIds.contains(s.id) && !s.isTemporary)
          .toList();
      final selectedTemporary = viewModel.songUnits
          .where((s) => _selectedIds.contains(s.id) && s.isTemporary)
          .toList();

      final hasFull = selectedFull.isNotEmpty;
      final hasTemporary = selectedTemporary.isNotEmpty;
      final onlyFull = hasFull && !hasTemporary;
      final onlyTemporary = hasTemporary && !hasFull;

      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _clearSelection,
        ),
        title: Text('${_selectedIds.length} ${context.t.common.selected}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.select_all),
            onPressed: () => _selectAll(viewModel.libraryItems),
            tooltip: context.t.library.actions.selectAll,
          ),
          IconButton(
            icon: const Icon(Icons.queue),
            onPressed: _selectedIds.isNotEmpty ? _addSelectedToQueue : null,
            tooltip: context.t.library.actions.addToQueue,
          ),
          // Playlist - only for full Song Units
          if (onlyFull)
            IconButton(
              icon: const Icon(Icons.playlist_add),
              onPressed: _addSelectedToPlaylist,
              tooltip: context.t.library.actions.addToPlaylist,
            ),
          // Tags - only for full Song Units
          if (onlyFull)
            IconButton(
              icon: const Icon(Icons.label),
              onPressed: _addTagsToSelected,
              tooltip: context.t.library.actions.addTagsToSelected,
            ),
          // Promote - only for temporary Song Units alone
          if (onlyTemporary)
            IconButton(
              icon: const Icon(Icons.upgrade),
              onPressed: _convertSelectedToSongUnits,
              tooltip: context.t.library.actions.promoteToSongUnits,
            ),
          // Merge - only for full Song Units (2+)
          if (onlyFull && selectedFull.length >= 2)
            IconButton(
              icon: const Icon(Icons.merge),
              onPressed: _mergeSelected,
              tooltip: context.t.library.actions.mergeSelected,
            ),
          // Export - only for full Song Units
          if (onlyFull)
            IconButton(
              icon: const Icon(Icons.file_download),
              onPressed: _exportSelected,
              tooltip: context.t.library.actions.exportSelected,
            ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _selectedIds.isNotEmpty ? _deleteSelected : null,
            tooltip: context.t.library.actions.deleteSelected,
          ),
        ],
      );
    }

    return AppBar(
      title: _libraryLocationFilter == null
          ? Text(context.t.library.title)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.t.library.title),
                const SizedBox(width: 8),
                _buildFilterChip(context),
              ],
            ),
      actions: [
        // Library location filter button
        if (_libraryLocations.isNotEmpty)
          IconButton(
            icon: Icon(
              _libraryLocationFilter != null
                  ? Icons.filter_alt
                  : Icons.filter_alt_outlined,
            ),
            onPressed: () => _showLibraryLocationFilterDialog(context),
            tooltip: context.t.library.filterByLocation,
          ),
        IconButton(
          icon: Icon(_isGridView ? Icons.list : Icons.grid_view),
          onPressed: () => setState(() => _isGridView = !_isGridView),
          tooltip: _isGridView ? context.t.library.listView : context.t.library.gridView,
        ),
        IconButton(
          icon: const Icon(Icons.file_upload),
          onPressed: () => _importSongUnits(context),
          tooltip: context.t.common.import,
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'refresh':
                viewModel.refresh();
                _loadLibraryLocations();
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'refresh',
              child: ListTile(
                leading: const Icon(Icons.refresh),
                title: Text(context.t.common.refresh),
                dense: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Build a chip showing the current filter
  Widget _buildFilterChip(BuildContext context) {
    final theme = Theme.of(context);
    final locationName =
        _libraryLocations[_libraryLocationFilter]?.name ?? 'Unknown';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder,
            size: 14,
            color: theme.colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 4),
          Text(
            locationName,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: () => setState(() => _libraryLocationFilter = null),
            child: Icon(
              Icons.close,
              size: 14,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  /// Show dialog to select library location filter
  /// Requirements: 7.3
  void _showLibraryLocationFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t.library.filterByLocation),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.folder_open),
                title: Text(context.t.library.allLocations),
                selected: _libraryLocationFilter == null,
                trailing: _libraryLocationFilter == null
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  setState(() => _libraryLocationFilter = null);
                  Navigator.of(dialogContext).pop();
                },
              ),
              const Divider(),
              ..._libraryLocations.values.map((location) {
                final isSelected = _libraryLocationFilter == location.id;
                return ListTile(
                  leading: Icon(
                    location.isAccessible ? Icons.folder : Icons.folder_off,
                    color: location.isAccessible ? null : Colors.red,
                  ),
                  title: Text(location.name),
                  subtitle: Text(
                    location.rootPath,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  selected: isSelected,
                  trailing: isSelected ? const Icon(Icons.check) : null,
                  onTap: () {
                    setState(() => _libraryLocationFilter = location.id);
                    Navigator.of(dialogContext).pop();
                  },
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.t.common.cancel),
          ),
        ],
      ),
    );
  }

  List<LibraryItem> _getFilteredLibraryItems(List<LibraryItem> items) {
    var filtered = items;

    // Filter by library location
    if (_libraryLocationFilter != null) {
      filtered = filtered.where((item) {
        return item.songUnit.libraryLocationId == _libraryLocationFilter;
      }).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((item) {
        final songUnit = item.songUnit;

        // If Rust search returned matching IDs, use them for non-temporary items
        if (!item.isTemporary && _matchingSearchIds != null) {
          return _matchingSearchIds!.contains(songUnit.id);
        }

        // Fallback: simple text search on title/artist/album
        final query = _searchQuery;
        final title = songUnit.displayName.toLowerCase();
        final artist = songUnit.metadata.artistDisplay.toLowerCase();
        final album = songUnit.metadata.album.toLowerCase();
        return title.contains(query) ||
            artist.contains(query) ||
            album.contains(query);
      }).toList();
    }

    return filtered;
  }

  Widget _buildListView(BuildContext context, LibraryViewModel viewModel) {
    final filteredItems = _getFilteredLibraryItems(viewModel.libraryItems);
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: filteredItems.length,
      // Performance optimizations for large lists
      itemExtent: 80, // Increased height for 3 lines (title, artist, tags)
      cacheExtent: 500, // Cache more items for smoother scrolling
      addAutomaticKeepAlives: false, // Don't keep offscreen items alive
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        final songUnit = item.songUnit;
        final isSelected = _selectedIds.contains(songUnit.id);
        
        return LibraryListItem(
          songUnit: songUnit,
          index: index,
          isSelected: isSelected,
          isSelectionMode: _isSelectionMode,
          onTap: _isSelectionMode
              ? () => _toggleSelection(songUnit.id)
              : () => _handleItemAction(context, songUnit, 'add_to_queue'),
          onLongPress: () {
            if (!_isSelectionMode) {
              setState(() {
                _isSelectionMode = true;
                _selectedIds.add(songUnit.id);
              });
            }
          },
          onMenuAction: (value) => _handleItemAction(context, songUnit, value),
        );
      },
    );
  }

  Widget _buildGridView(BuildContext context, LibraryViewModel viewModel) {
    final filteredItems = _getFilteredLibraryItems(viewModel.libraryItems);
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.8,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: filteredItems.length,
      // Performance optimizations for large grids
      cacheExtent: 500, // Cache more items for smoother scrolling
      addAutomaticKeepAlives: false, // Don't keep offscreen items alive
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        final songUnit = item.songUnit;
        final isSelected = _selectedIds.contains(songUnit.id);
        final libraryLocationName = _getLibraryLocationName(songUnit);
        
        return LibraryGridItem(
          songUnit: songUnit,
          isSelected: isSelected,
          isSelectionMode: _isSelectionMode,
          libraryLocationName: libraryLocationName,
          onTap: _isSelectionMode
              ? () => _toggleSelection(songUnit.id)
              : () => _handleItemAction(context, songUnit, 'add_to_queue'),
          onLongPress: () {
            if (!_isSelectionMode) {
              setState(() {
                _isSelectionMode = true;
                _selectedIds.add(songUnit.id);
              });
            }
          },
        );
      },
    );
  }


  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.library_music,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            context.t.library.noItems,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.t.common.import,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _importSongUnits(context),
            icon: const Icon(Icons.file_upload),
            label: Text(context.t.common.import),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, LibraryViewModel viewModel) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text(context.t.library.errorLoadingLibrary, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            viewModel.error ?? 'Unknown error',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              viewModel
                ..clearError()
                ..loadAndSync();
            },
            icon: const Icon(Icons.refresh),
            label: Text(context.t.common.retry),
          ),
        ],
      ),
    );
  }

  Widget _buildFab(BuildContext context) {
    if (_isSelectionMode) {
      return const SizedBox.shrink();
    }

    final settingsViewModel = context.watch<SettingsViewModel>();
    final isInPlaceMode =
        settingsViewModel.configMode == ConfigurationMode.inPlace;
    final hasLibraryLocations =
        settingsViewModel.settings.libraryLocations.isNotEmpty;

    // Disable FAB in in-place mode without library locations
    final isDisabled = isInPlaceMode && !hasLibraryLocations;

    return FloatingActionButton(
      onPressed: isDisabled ? null : () => _createSongUnit(context),
      tooltip: isDisabled
          ? 'Configure library locations in Settings to add Song Units'
          : 'Add Song Unit',
      backgroundColor: isDisabled ? Colors.grey : null,
      child: const Icon(Icons.add),
    );
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll(List<LibraryItem> items) {
    setState(() {
      _selectedIds.addAll(
        items.map((item) => item.id).where((id) => id.isNotEmpty),
      );
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
      _isSelectionMode = false;
    });
  }

  void _handleItemAction(
    BuildContext context,
    SongUnit songUnit,
    String action,
  ) {
    final tagViewModel = context.read<TagViewModel>();
    final playerViewModel = context.read<PlayerViewModel>();
    final libraryViewModel = context.read<LibraryViewModel>();

    switch (action) {
      case 'play':
        // Add to queue and start playing
        tagViewModel.requestSong(songUnit.id);
        playerViewModel.play(songUnit);
        break;
      case 'add_to_queue':
        tagViewModel.requestSong(songUnit.id).then((wasFirstSong) {
          if (wasFirstSong) {
            // Auto-play when first song is added to empty queue
            playerViewModel.play(songUnit);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t.search.addedToQueue.replaceAll('{title}', songUnit.metadata.title),
            ),
          ),
        );
        break;
      case 'edit':
        Navigator.pushNamed(
          context,
          '/song-unit-editor',
          arguments: songUnit.id,
        );
        break;
      case 'add_to_playlist':
        _showAddToPlaylistDialog(context, songUnit);
        break;
      case 'export':
        _exportSongUnit(context, songUnit.id);
        break;
      case 'promote':
        _promoteSongUnit(context, songUnit);
        break;
      case 'delete':
        _showDeleteDialog(context, songUnit, libraryViewModel);
        break;
    }
  }

  void _showAddToPlaylistDialog(BuildContext context, SongUnit songUnit) {
    showDialog(
      context: context,
      builder: (context) => AddToPlaylistDialog(
        songUnit: songUnit,
        onCreatePlaylist: () => _showCreatePlaylistDialog(context, songUnit),
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context, SongUnit songUnit) {
    showDialog(
      context: context,
      builder: (context) => CreatePlaylistDialog(songUnit: songUnit),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    SongUnit songUnit,
    LibraryViewModel viewModel,
  ) {
    showDialog(
      context: context,
      builder: (context) => DeleteSongUnitDialog(songUnit: songUnit),
    );
  }

  void _deleteSelected() {
    final libraryViewModel = context.read<LibraryViewModel>();

    final selectedItems = libraryViewModel.songUnits
        .where((s) => _selectedIds.contains(s.id))
        .toList();

    showDialog(
      context: context,
      builder: (context) => BulkDeleteDialog(
        selectedItems: selectedItems,
        onConfirm: () async {
          for (final songUnit in selectedItems) {
            await libraryViewModel.deleteSongUnit(songUnit.id);
          }

          _clearSelection();

          if (mounted) {
            libraryViewModel.refresh();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.t.library.deletedItems
                    .replaceAll('{count}', selectedItems.length.toString())),
              ),
            );
          }
        },
      ),
    );
  }

  void _addSelectedToQueue() async {
    final tagViewModel = context.read<TagViewModel>();
    final libraryViewModel = context.read<LibraryViewModel>();
    final playerViewModel = context.read<PlayerViewModel>();

    // Get all selected song units (both full and temporary)
    final allSongUnits = libraryViewModel.songUnits
        .where((s) => _selectedIds.contains(s.id))
        .toList();

    final totalCount = allSongUnits.length;
    _clearSelection();

    if (allSongUnits.isEmpty) return;

    final wasFirst = await tagViewModel.requestSongsBatch(allSongUnits);
    if (wasFirst) {
      playerViewModel.play(allSongUnits.first);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t.library.addedItemsToQueue.replaceAll('{count}', totalCount.toString()))),
      );
    }
  }

  void _convertSelectedToSongUnits() async {
    final libraryViewModel = context.read<LibraryViewModel>();
    final settingsViewModel = context.read<SettingsViewModel>();

    // Get selected temporary song units
    final selectedTemporary = libraryViewModel.songUnits
        .where((s) => _selectedIds.contains(s.id) && s.isTemporary)
        .toList();

    if (selectedTemporary.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t.library.noTemporaryEntriesSelected)),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t.library.actions.promoteToSongUnits),
        content: Text(
          'Promote ${selectedTemporary.length} ${selectedTemporary.length == 1 ? "entry" : "entries"} to full Song Units?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.t.common.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.t.library.actions.promoteToSongUnits),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    var successCount = 0;
    for (final tempUnit in selectedTemporary) {
      try {
        // Promote: clear temporary flag
        final promoted = tempUnit.promote();
        await libraryViewModel.updateSongUnitWithConfig(
          songUnit: promoted,
          configMode: settingsViewModel.configMode,
          libraryLocations: settingsViewModel.settings.libraryLocations,
        );
        successCount++;
      } catch (e) {
        debugPrint('Error promoting song unit ${tempUnit.id}: $e');
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Promoted $successCount of ${selectedTemporary.length} ${selectedTemporary.length == 1 ? "entry" : "entries"}',
          ),
        ),
      );
      _clearSelection();
      libraryViewModel.refresh();
    }
  }

  void _addSelectedToPlaylist() {
    final tagViewModel = context.read<TagViewModel>();

    // Find actual playlists: collections that are not groups and not queues
    final playlistTags = tagViewModel.allTags
        .where((t) => t.isPlaylist)
        .toList();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t.library.addSongsToPlaylistTitle.replaceAll('{count}', _selectedIds.length.toString())),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (playlistTags.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(context.t.library.noPlaylistsCreateFirst),
                )
              else
                ...playlistTags.map((tag) {
                  return ListTile(
                    leading: const Icon(Icons.playlist_add),
                    title: Text(tag.name),
                    onTap: () async {
                      for (final id in _selectedIds) {
                        await tagViewModel.addToPlaylist(tag.id, id);
                      }
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Added ${_selectedIds.length} song(s) to "${tag.name}"',
                            ),
                          ),
                        );
                        _clearSelection();
                      }
                    },
                  );
                }),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.add),
                title: Text(context.t.playlists.createPlaylist),
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  _showCreatePlaylistForSelectedDialog();
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.t.common.cancel),
          ),
        ],
      ),
    );
  }

  void _addTagsToSelected() {
    final tagViewModel = context.read<TagViewModel>();
    final libraryViewModel = context.read<LibraryViewModel>();

    // Only show pure user tags (not playlists, queues, or groups)
    final userTags = tagViewModel.getTagPanelTags();

    // Track selected tags in the dialog
    final selectedTagIds = <String>{};

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(context.t.library.addSongsToPlaylistTitle.replaceAll('{count}', _selectedIds.length.toString())),
          content: SizedBox(
            width: 300,
            height: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (userTags.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No user tags yet. Create tags in the Tags section.',
                    ),
                  )
                else
                  Expanded(
                    child: ListView(
                      children: userTags.map((tag) {
                        // Build display name with full path for child tags
                        var displayName = tag.name;
                        if (tag.parentId != null) {
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
                          displayName = pathParts.join('/');
                        }
                        
                        final isSelected = selectedTagIds.contains(tag.id);
                        return CheckboxListTile(
                          title: Text(displayName),
                          value: isSelected,
                          onChanged: (selected) {
                            setState(() {
                              if (selected == true) {
                                selectedTagIds.add(tag.id);
                              } else {
                                selectedTagIds.remove(tag.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text(context.t.common.cancel),
            ),
            FilledButton(
              onPressed: selectedTagIds.isEmpty
                  ? null
                  : () async {
                      // Add selected tags to all selected song units
                      for (final songUnitId in _selectedIds) {
                        final songUnit = await libraryViewModel.getSongUnit(
                          songUnitId,
                        );
                        if (songUnit != null) {
                          final updatedTagIds = {
                            ...songUnit.tagIds,
                            ...selectedTagIds,
                          }.toList();
                          final updatedSongUnit = songUnit.copyWith(
                            tagIds: updatedTagIds,
                          );
                          await libraryViewModel.updateSongUnit(
                            updatedSongUnit,
                          );
                        }
                      }

                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Added ${selectedTagIds.length} tag(s) to ${_selectedIds.length} song(s)',
                            ),
                          ),
                        );
                        _clearSelection();
                      }
                    },
              child: Text(context.t.library.actions.addTagsToSelected),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreatePlaylistForSelectedDialog() {
    final nameController = TextEditingController();
    final tagViewModel = context.read<TagViewModel>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t.playlists.createPlaylist),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Playlist Name',
            hintText: 'Enter playlist name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.t.common.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                await tagViewModel.createPlaylist(name);
                for (final id in _selectedIds) {
                  await tagViewModel.addToPlaylist(name, id);
                }
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Created "$name" and added ${_selectedIds.length} song(s)',
                      ),
                    ),
                  );
                  _clearSelection();
                }
              }
            },
            child: Text(context.t.playlists.createAndAdd),
          ),
        ],
      ),
    );
  }

  void _mergeSelected() {
    final libraryViewModel = context.read<LibraryViewModel>();
    final selectedSongs = libraryViewModel.songUnits
        .where((s) => _selectedIds.contains(s.id))
        .toList();

    if (selectedSongs.length < 2) return;

    showDialog(
      context: context,
      builder: (dialogContext) => MergeSongUnitsDialog(
        songUnits: selectedSongs,
        onMerge: (mergedSongUnit, deleteOriginals) async {
          // Add the merged song unit
          await libraryViewModel.addSongUnit(mergedSongUnit);

          // Delete originals if requested
          if (deleteOriginals) {
            for (final song in selectedSongs) {
              await libraryViewModel.deleteSongUnit(song.id);
            }
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Merged ${selectedSongs.length} song units into "${mergedSongUnit.metadata.title}"',
                ),
              ),
            );
            _clearSelection();
          }
        },
      ),
    );
  }

  Future<void> _exportSongUnit(BuildContext context, String id) async {
    final libraryViewModel = context.read<LibraryViewModel>();
    final songUnit = await libraryViewModel.getSongUnit(id);
    if (songUnit == null) return;

    // Generate filename: title_hash.zip
    final sanitizedTitle = _sanitizeFileName(songUnit.metadata.title);
    final hash = songUnit.id.length >= 8
        ? songUnit.id.substring(0, 8)
        : songUnit.id;
    final defaultFileName = '${sanitizedTitle}_$hash.zip';

    // Ask user for output location
    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Song Unit',
      fileName: defaultFileName,
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (outputPath == null) return;

    final file = await libraryViewModel.exportSongUnit(
      id,
      outputPath: outputPath,
    );
    if (file != null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t.library.exportedTo.replaceAll('{path}', file.path))));
    }
  }

  Future<void> _exportSelected() async {
    final libraryViewModel = context.read<LibraryViewModel>();

    // Generate filename based on selection
    String defaultFileName;
    if (_selectedIds.length == 1) {
      final songUnit = await libraryViewModel.getSongUnit(_selectedIds.first);
      if (songUnit != null) {
        final sanitizedTitle = _sanitizeFileName(songUnit.metadata.title);
        final hash = songUnit.id.length >= 8
            ? songUnit.id.substring(0, 8)
            : songUnit.id;
        defaultFileName = '${sanitizedTitle}_$hash.zip';
      } else {
        defaultFileName = 'export.zip';
      }
    } else {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      defaultFileName =
          'batch_export_${_selectedIds.length}_songs_$timestamp.zip';
    }

    // Ask user for output location
    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Selected Song Units',
      fileName: defaultFileName,
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (outputPath == null) return;

    final file = await libraryViewModel.exportSongUnits(
      _selectedIds.toList(),
      outputPath: outputPath,
    );
    if (file != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Exported ${_selectedIds.length} song(s) to ${file.path}',
          ),
        ),
      );
      _clearSelection();
    }
  }

  String _sanitizeFileName(String name) {
    if (name.isEmpty) return 'untitled';
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
  }

  Future<void> _importSongUnits(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      dialogTitle: 'Select ZIP file to import',
    );

    if (result == null || result.files.isEmpty) return;

    final filePath = result.files.single.path;
    if (filePath == null) return;

    final viewModel = context.read<LibraryViewModel>();
    final importResult = await viewModel.importFromZip(File(filePath));

    if (importResult != null && mounted) {
      _showImportResultDialog(context, importResult);
    }
  }

  void _showImportResultDialog(BuildContext context, dynamic importResult) {
    showDialog(
      context: context,
      builder: (context) => ImportResultDialog(importResult: importResult),
    );
  }

  void _createSongUnit(BuildContext context) {
    Navigator.pushNamed(context, '/song-unit-editor');
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get the duration from the song unit's audio sources
  /// Audio source duration is authoritative per the design
  Duration _getAudioDuration(SongUnit songUnit) {
    // Try audio sources first (authoritative)
    for (final source in songUnit.sources.audioSources) {
      final duration = source.getDuration();
      if (duration != null && duration != Duration.zero) {
        return duration;
      }
    }
    // Fallback to accompaniment sources
    for (final source in songUnit.sources.accompanimentSources) {
      final duration = source.getDuration();
      if (duration != null && duration != Duration.zero) {
        return duration;
      }
    }
    // Fallback to display sources (video)
    for (final source in songUnit.sources.displaySources) {
      final duration = source.getDuration();
      if (duration != null && duration != Duration.zero) {
        return duration;
      }
    }
    // Fallback to metadata duration
    if (songUnit.metadata.duration != Duration.zero) {
      return songUnit.metadata.duration;
    }
    return Duration.zero;
  }

  /// Promote a temporary Song Unit to a full one with auto-discovery
  Future<void> _promoteSongUnit(
    BuildContext context,
    SongUnit tempSongUnit,
  ) async {
    final filePath = tempSongUnit.originalFilePath;

    // Auto-discover related sources (lyrics, videos, images, accompaniment)
    DiscoveredSources? discovered;
    if (filePath != null) {
      final autoMatcher = SourceAutoMatcher();
      discovered = await autoMatcher.discoverAndCreateSources(filePath);

      // Show discovery results if any sources were found
      if (discovered.hasAnySources && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Auto-discovered ${discovered.totalCount} related source(s): '
              '${discovered.videoSources.length} video, '
              '${discovered.imageSources.length} image, '
              '${discovered.lyricsSources.length} lyrics, '
              '${discovered.accompanimentSources.length} accompaniment',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }

    // Build promoted song unit with discovered sources merged in
    final promoted = tempSongUnit.copyWith(
      isTemporary: false,
      sources: discovered != null && discovered.hasAnySources
          ? SourceCollection(
              displaySources: [
                ...tempSongUnit.sources.displaySources,
                ...discovered.videoSources,
                ...discovered.imageSources,
              ],
              audioSources: [
                ...tempSongUnit.sources.audioSources,
                ...discovered.audioSources,
              ],
              accompanimentSources: [
                ...tempSongUnit.sources.accompanimentSources,
                ...discovered.accompanimentSources,
              ],
              hoverSources: [
                ...tempSongUnit.sources.hoverSources,
                ...discovered.lyricsSources,
              ],
            )
          : null,
    );

    // Update in library
    final libraryViewModel = context.read<LibraryViewModel>();
    final settingsViewModel = context.read<SettingsViewModel>();

    final success = await libraryViewModel.updateSongUnitWithConfig(
      songUnit: promoted,
      configMode: settingsViewModel.configMode,
      libraryLocations: settingsViewModel.settings.libraryLocations,
    );

    if (!success) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to promote: ${libraryViewModel.error}',
            ),
          ),
        );
      }
      return;
    }

    // Navigate to song unit editor
    if (context.mounted) {
      await Navigator.pushNamed(
        context,
        '/song-unit-editor',
        arguments: promoted.id,
      );

      // Refresh library after editing
      await libraryViewModel.refresh();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t.library.promoted.replaceAll('{displayName}', promoted.displayName)),
          ),
        );
      }
    }
  }

  /// Get audio format from file extension
  AudioFormat _getAudioFormat(String extension) {
    switch (extension) {
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

}
