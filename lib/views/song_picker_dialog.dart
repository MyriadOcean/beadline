import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../i18n/translations.g.dart';
import '../viewmodels/library_view_model.dart';
import '../viewmodels/search_view_model.dart';
import 'widgets/cached_thumbnail.dart';

/// Dialog for picking songs from the library
class SongPickerDialog extends StatefulWidget {
  const SongPickerDialog({
    super.key,
    this.multiSelect = true,
    this.excludeSongIds = const [],
  });

  final bool multiSelect;
  final List<String> excludeSongIds;

  @override
  State<SongPickerDialog> createState() => _SongPickerDialogState();
}

class _SongPickerDialogState extends State<SongPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedSongIds = {};
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final libraryVM = context.watch<LibraryViewModel>();
    final searchVM = context.watch<SearchViewModel>();

    final songs = _isSearching && _searchController.text.isNotEmpty
        ? searchVM.songUnitResults
        : libraryVM.songUnits;

    final filteredSongs = songs
        .where((song) => !widget.excludeSongIds.contains(song.id))
        .toList();

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.library_music, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    widget.multiSelect ? context.t.songPicker.selectSongs : context.t.songPicker.selectSong,
                    style: theme.textTheme.titleLarge,
                  ),
                  const Spacer(),
                  if (widget.multiSelect && _selectedSongIds.isNotEmpty) ...[
                    Text(
                      '${_selectedSongIds.length} ${context.t.common.selected}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Cancel',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: context.t.songPicker.searchHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _isSearching = false;
                            });
                            searchVM.clearSearch();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _isSearching = value.isNotEmpty;
                  });
                  if (value.isNotEmpty) {
                    searchVM
                      ..updateQueryText(value)
                      ..executeSearch();
                  } else {
                    searchVM.clearSearch();
                  }
                },
              ),
            ),
            // Song list
            Expanded(
              child: filteredSongs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isSearching
                                ? Icons.search_off
                                : Icons.library_music,
                            size: 64,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _isSearching
                                ? context.t.songPicker.noSongsFound
                                : context.t.songPicker.noSongsInLibrary,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredSongs.length,
                      itemBuilder: (context, index) {
                        final song = filteredSongs[index];
                        final isSelected = _selectedSongIds.contains(song.id);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: widget.multiSelect
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Checkbox(
                                        value: isSelected,
                                        onChanged: (value) {
                                          setState(() {
                                            if (value == true) {
                                              _selectedSongIds.add(song.id);
                                            } else {
                                              _selectedSongIds.remove(song.id);
                                            }
                                          });
                                        },
                                      ),
                                      _buildSongThumbnail(song),
                                    ],
                                  )
                                : _buildSongThumbnail(song),
                            title: Text(
                              song.metadata.title,
                              style: isSelected
                                  ? TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    )
                                  : null,
                            ),
                            subtitle: Text(
                              song.metadata.artistDisplay,
                              style: isSelected
                                  ? TextStyle(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.7),
                                    )
                                  : null,
                            ),
                            onTap: () {
                              if (widget.multiSelect) {
                                setState(() {
                                  if (isSelected) {
                                    _selectedSongIds.remove(song.id);
                                  } else {
                                    _selectedSongIds.add(song.id);
                                  }
                                });
                              } else {
                                Navigator.of(context).pop([song.id]);
                              }
                            },
                          ),
                        );
                      },
                    ),
            ),
            // Footer
            if (widget.multiSelect) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(context.t.common.cancel),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton(
                        onPressed: _selectedSongIds.isEmpty
                            ? null
                            : () {
                                Navigator.of(
                                  context,
                                ).pop(_selectedSongIds.toList());
                              },
                        child: Text(
                          _selectedSongIds.isEmpty
                              ? context.t.songPicker.selectSongs
                              : context.t.songPicker.addSongs,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSongThumbnail(dynamic song) {
    if (song.metadata.thumbnailSourceId != null) {
      return ClipOval(
        child: CachedThumbnail(
          metadata: song.metadata,
          width: 40,
          height: 40,
        ),
      );
    }
    return CircleAvatar(
      child: Text(
        song.metadata.title.isNotEmpty
            ? song.metadata.title[0].toUpperCase()
            : '?',
      ),
    );
  }
}
