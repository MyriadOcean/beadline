import 'package:flutter/material.dart';

import '../../i18n/translations.g.dart';
import '../../models/online_provider_config.dart';
import '../../models/source.dart';
import '../../viewmodels/search_view_model.dart';

/// Online source search dialog.
class OnlineSourceSearchDialog extends StatefulWidget {
  const OnlineSourceSearchDialog({
    super.key,
    required this.searchViewModel,
    required this.providers,
    required this.onSourceSelected,
  });

  final SearchViewModel searchViewModel;
  final List<OnlineProviderConfig> providers;
  final void Function(OnlineSourceResult result, SourceType sourceType)
      onSourceSelected;

  @override
  State<OnlineSourceSearchDialog> createState() =>
      _OnlineSourceSearchDialogState();
}

class _OnlineSourceSearchDialogState extends State<OnlineSourceSearchDialog> {
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
              context.t.songEditor.searchOnlineSources,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedProviderId,
              decoration: InputDecoration(
                labelText: context.t.songEditor.providerLabel,
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
            DropdownButtonFormField<SourceType>(
              initialValue: _selectedSourceType,
              decoration: InputDecoration(
                labelText: context.t.songEditor.sourceTypeLabel,
                border: OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: SourceType.display,
                  child: Text(context.t.common.displayVideoImage),
                ),
                DropdownMenuItem(
                  value: SourceType.audio,
                  child: Text(context.t.songEditor.audio),
                ),
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
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: context.t.songEditor.searchQueryLabel,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _performSearch,
                ),
              ),
              onSubmitted: (_) => _performSearch(),
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildResults()),
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
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.music_note),
                  )
                : const Icon(Icons.music_note, size: 40),
            title: Text(result.title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (result.artist != null)
                  Text('${context.t.common.artistLabel} ${result.artist}'),
                if (result.album != null)
                  Text('${context.t.common.albumLabel} ${result.album}'),
                Text('${context.t.common.platformLabel} ${result.platform}'),
                if (result.duration != null)
                  Text(
                    context.t.songEditor.durationDisplay.replaceAll('{value}', Duration(seconds: result.duration!).toString().split('.').first),
                  ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                widget.onSourceSelected(result, _selectedSourceType);
                Navigator.of(context).pop();
              },
              tooltip: context.t.songEditor.addToSongUnit,
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}
