import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/search_history_storage.dart';
import '../models/dart_suggestion.dart';
import '../models/online_provider_config.dart';
import '../models/song_unit.dart';
import '../models/source.dart';
import '../repositories/search_repository.dart';
import '../repositories/settings_repository.dart';
import '../src/rust/api/evaluator_api.dart' as rust_evaluator;
import '../src/rust/api/parser_api.dart' as rust_parser;
import '../src/rust/api/suggestion_api.dart' as rust_suggestion;

/// ViewModel for search functionality.
///
/// Thin FRB wrapper: delegates query parsing, evaluation, and suggestions
/// to the Rust `beadline-tags` crate via Flutter Rust Bridge.
/// Source search (local/online) remains Dart-side via [SearchRepository].
class SearchViewModel extends ChangeNotifier {
  SearchViewModel({
    required SearchRepository searchRepository,
    required SettingsRepository settingsRepository,
    SearchHistoryStorage? searchHistoryStorage,
  }) : _searchRepository = searchRepository,
       _settingsRepository = settingsRepository,
       _searchHistory = searchHistoryStorage ?? SearchHistoryStorage() {
    _loadHistory();
  }

  final SearchRepository _searchRepository;
  final SettingsRepository _settingsRepository;
  final SearchHistoryStorage _searchHistory;

  // Query state
  String _queryText = '';
  rust_evaluator.QueryExpression? _currentQuery;
  List<rust_parser.DartQueryChip> _chips = [];
  String? _parseError;

  // Suggestion state
  List<DartSuggestion> _suggestions = [];
  Timer? _suggestionDebounce;
  static const _suggestionDebounceMs = 100;
  static const _maxSuggestions = 10;

  // Search history state
  List<String> _recentSearches = [];
  static const _maxHistoryItems = 20;

  // Song Unit search results (via Rust evaluator)
  List<String> _matchingIds = [];
  List<SongUnit> _songUnitResults = [];
  bool _isSearching = false;
  String? _error;
  int _totalSongUnitCount = 0;

  // Source search results (Dart-side, unchanged)
  List<OnlineSourceResult> _sourceResults = [];
  int _totalSourceCount = 0;
  int _currentPage = 0;
  static const int _pageSize = 50;

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  String get queryText => _queryText;
  rust_evaluator.QueryExpression? get currentQuery => _currentQuery;
  List<rust_parser.DartQueryChip> get chips => List.unmodifiable(_chips);
  List<DartSuggestion> get suggestions => List.unmodifiable(_suggestions);
  List<String> get recentSearches => List.unmodifiable(_recentSearches);
  List<SongUnit> get songUnitResults => List.unmodifiable(_songUnitResults);
  List<String> get matchingIds => List.unmodifiable(_matchingIds);
  List<OnlineSourceResult> get sourceResults =>
      List.unmodifiable(_sourceResults);
  bool get isSearching => _isSearching;
  String? get error => _error;
  String? get parseError => _parseError;
  int get totalSongUnitCount => _totalSongUnitCount;
  int get totalSourceCount => _totalSourceCount;
  int get currentPage => _currentPage;
  bool get hasMoreSongUnits =>
      (_currentPage + 1) * _pageSize < _totalSongUnitCount;
  bool get hasMoreSources => (_currentPage + 1) * _pageSize < _totalSourceCount;

  // ---------------------------------------------------------------------------
  // Query text & parsing (Rust FRB)
  // ---------------------------------------------------------------------------

  /// Update the query text, parse it via Rust, and trigger suggestions.
  ///
  /// This is intentionally synchronous for use as an `onChanged` callback.
  /// The async Rust calls are fired internally and notify listeners on completion.
  void updateQueryText(String text) {
    _queryText = text;
    _parseError = null;

    if (text.isEmpty) {
      _currentQuery = null;
      _chips = [];
      _suggestionDebounce?.cancel();
      // Show recent searches + all tags when input is empty
      _fetchSuggestions(text);
      notifyListeners();
      return;
    }

    notifyListeners();

    // Fire async parsing and chip extraction
    _parseQueryAsync(text);

    // Debounced suggestions
    _scheduleSuggestions(text);
  }

  Future<void> _parseQueryAsync(String text) async {
    final nameAutoSearch = await _getNameAutoSearch();

    try {
      _currentQuery = await rust_parser.parseQuery(
        input: text,
        nameAutoSearch: nameAutoSearch,
      );
      _parseError = null;
    } catch (e) {
      _parseError = e.toString();
      _currentQuery = null;
    }

    // Parse chips for UI rendering
    try {
      _chips = await rust_parser.parseToDartChips(
        input: text,
        nameAutoSearch: nameAutoSearch,
      );
    } catch (_) {
      _chips = [];
    }

    notifyListeners();
  }

  /// Serialize the current query AST back to text via Rust.
  Future<String?> getSerializedQuery() async {
    if (_currentQuery == null) return null;
    try {
      return await rust_parser.serializeQuery(expr: _currentQuery!);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Build a query from a Rust QueryExpression and update query text.
  Future<void> buildQueryFromExpression(
    rust_evaluator.QueryExpression expr,
  ) async {
    _currentQuery = expr;
    try {
      _queryText = await rust_parser.serializeQuery(expr: expr);
      _parseError = null;
    } catch (e) {
      _parseError = e.toString();
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Suggestions (Rust FRB, debounced)
  // ---------------------------------------------------------------------------

  void _scheduleSuggestions(String text) {
    _suggestionDebounce?.cancel();
    _suggestionDebounce = Timer(
      const Duration(milliseconds: _suggestionDebounceMs),
      () => _fetchSuggestions(text),
    );
  }

  Future<void> _fetchSuggestions(String text) async {
    try {
      // Extract the current fragment (last space-separated token) for suggestions
      final fragment = _extractCurrentFragment(text);

      final rustSuggestions = await rust_suggestion.getDartSuggestions(
        fragment: fragment,
        maxResults: _maxSuggestions,
      );

      _suggestions = [];

      // If input is empty or fragment is empty, prepend recent searches
      if (text.isEmpty || fragment.isEmpty) {
        for (final recent in _recentSearches) {
          if (_suggestions.length >= _maxSuggestions) break;
          _suggestions.add(DartSuggestion(
            displayText: recent,
            insertText: recent,
            suggestionType: 'history',
          ));
        }
      }

      // Add Rust suggestions up to the limit
      for (final s in rustSuggestions) {
        if (_suggestions.length >= _maxSuggestions) break;
        _suggestions.add(DartSuggestion(
          displayText: s.displayText,
          insertText: s.insertText,
          suggestionType: s.suggestionType,
        ));
      }

      // For built-in key queries (name:, artist:, album:), supplement with
      // metadata from song units since these values aren't stored as tags.
      if (fragment.contains(':')) {
        final colonPos = fragment.indexOf(':');
        final key = fragment.substring(0, colonPos).toLowerCase();
        final partial = fragment.substring(colonPos + 1);
        if (_builtInMetadataKeys.contains(key) && partial.isNotEmpty) {
          await _addMetadataSuggestions(key, partial);
        }
      }
    } catch (e) {
      debugPrint('Suggestion error: $e');
      // Fallback: show history even if Rust call fails
      _suggestions = _recentSearches
          .take(_maxSuggestions)
          .map((r) => DartSuggestion(
                displayText: r,
                insertText: r,
                suggestionType: 'history',
              ))
          .toList();
    }
    notifyListeners();
  }

  /// Built-in keys whose values come from song unit metadata, not the tags table.
  static const _builtInMetadataKeys = {'name', 'artist', 'album'};

  /// Add suggestions from song unit metadata for built-in key queries.
  Future<void> _addMetadataSuggestions(String key, String partial) async {
    try {
      final allSongUnits = await _searchRepository.getAllSongUnitsForSuggestions();
      final partialLower = partial.toLowerCase();
      final seen = <String>{};

      // Collect existing suggestion display texts to avoid duplicates
      for (final s in _suggestions) {
        seen.add(s.displayText.toLowerCase());
      }

      for (final su in allSongUnits) {
        if (_suggestions.length >= _maxSuggestions) break;

        final String value;
        switch (key) {
          case 'name':
            value = su.metadata.title;
            break;
          case 'artist':
            value = su.metadata.artistDisplay;
            break;
          case 'album':
            value = su.metadata.album;
            break;
          default:
            continue;
        }

        if (value.isEmpty) continue;
        final valueLower = value.toLowerCase();
        if (seen.contains(valueLower)) continue;

        // Match: contains check (covers CJK partial matching)
        if (valueLower.contains(partialLower)) {
          seen.add(valueLower);
          // Quote values containing spaces for proper query syntax
          final insertValue = value.contains(' ') ? '$key:"$value"' : '$key:$value';
          _suggestions.add(DartSuggestion(
            displayText: value,
            insertText: insertValue,
            suggestionType: 'named_tag_value',
          ));
        }
      }
    } catch (e) {
      debugPrint('Metadata suggestion error: $e');
    }
  }

  /// Extract the current fragment being typed (the last token in the query).
  /// This is used for suggestion context — we suggest based on what the user
  /// is currently typing, not the entire query.
  /// Quote-aware: treats `key:"value with spaces"` as a single token.
  String _extractCurrentFragment(String text) {
    if (text.isEmpty) return '';
    final trimmed = text.trimRight();
    if (trimmed.isEmpty) return '';

    // Walk backwards to find the start of the current token,
    // respecting quoted strings.
    var i = trimmed.length - 1;
    var inQuotes = false;
    while (i >= 0) {
      final ch = trimmed[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (ch == ' ' && !inQuotes) {
        break;
      }
      i--;
    }
    return trimmed.substring(i + 1);
  }

  /// Dismiss the suggestion dropdown.
  void clearSuggestions() {
    _suggestions = [];
    _suggestionDebounce?.cancel();
    notifyListeners();
  }

  /// Accept a suggestion: replace the current fragment in the query with the
  /// suggestion's insert text.
  ///
  /// If the suggestion is a named tag key (insert_text ends with ':'),
  /// keep suggestions open and fetch values for that key.
  /// Otherwise, append a space and clear suggestions.
  ///
  /// Returns the new query text so the caller can update the TextField controller.
  String acceptSuggestion(DartSuggestion suggestion) {
    final isKeySelection = suggestion.insertText.endsWith(':');
    final fragment = _extractCurrentFragment(_queryText);

    if (fragment.isEmpty) {
      _queryText = suggestion.insertText;
      if (!isKeySelection) _queryText += ' ';
    } else {
      final lastIndex = _queryText.lastIndexOf(fragment);
      if (lastIndex >= 0) {
        _queryText =
            '${_queryText.substring(0, lastIndex)}${suggestion.insertText}';
        if (!isKeySelection) _queryText += ' ';
      } else {
        _queryText = suggestion.insertText;
        if (!isKeySelection) _queryText += ' ';
      }
    }

    _suggestionDebounce?.cancel();

    if (isKeySelection) {
      // Key selected (e.g. "album:") — fetch values for this key
      _fetchSuggestions(_queryText);
    } else {
      // Value selected — close suggestions and re-parse
      _suggestions = [];
      _parseQueryAsync(_queryText.trimRight());
    }

    // Don't call notifyListeners() here - let the caller update the TextField
    // controller directly to avoid race conditions with text input
    return _queryText;
  }

  // ---------------------------------------------------------------------------
  // Search history
  // ---------------------------------------------------------------------------

  Future<void> _loadHistory() async {
    _recentSearches = await _searchHistory.loadHistory();
  }

  /// Add a search term to history. Called when the user executes a search.
  Future<void> addToHistory(String term) async {
    final trimmed = term.trim();
    if (trimmed.isEmpty) return;

    // Remove duplicate if exists, then prepend
    _recentSearches.remove(trimmed);
    _recentSearches.insert(0, trimmed);
    if (_recentSearches.length > _maxHistoryItems) {
      _recentSearches = _recentSearches.sublist(0, _maxHistoryItems);
    }
    await _searchHistory.saveHistory(_recentSearches);
    notifyListeners();
  }

  /// Clear all search history.
  Future<void> clearHistory() async {
    _recentSearches = [];
    await _searchHistory.saveHistory(_recentSearches);
    notifyListeners();
  }

  /// Request suggestions to show (e.g. when the search field gains focus).
  void requestSuggestions() {
    _fetchSuggestions(_queryText);
  }

  // ---------------------------------------------------------------------------
  // Song Unit search (Rust evaluator via FRB)
  // ---------------------------------------------------------------------------

  /// Execute search for Song Units using the current parsed query.
  ///
  /// Currently delegates to the Dart-side [SearchRepository] for evaluation.
  /// When the FRB bridge exposes a `SongUnitView` constructor, this will
  /// switch to the Rust evaluator for full named/nameless tag support.
  Future<void> executeSearch() async {
    final trimmedQuery = _queryText.trim();
    if (trimmedQuery.isEmpty) {
      _songUnitResults = [];
      _matchingIds = [];
      _totalSongUnitCount = 0;
      _currentPage = 0;
      notifyListeners();
      return;
    }

    // Save to search history
    await addToHistory(_queryText);

    try {
      _isSearching = true;
      _error = null;
      _currentPage = 0;
      notifyListeners();

      final result = await _searchRepository.searchSongUnitsByText(trimmedQuery);

      _songUnitResults = result.items;
      _totalSongUnitCount = result.totalCount;

      _isSearching = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isSearching = false;
      notifyListeners();
    }
  }

  /// Load more Song Unit results (pagination).
  Future<void> loadMoreSongUnits() async {
    if (!hasMoreSongUnits || _isSearching) return;

    try {
      _isSearching = true;
      notifyListeners();

      final nextPage = _currentPage + 1;
      final result = await _searchRepository.searchSongUnitsByText(
        _queryText,
        page: nextPage,
      );

      _songUnitResults = [..._songUnitResults, ...result.items];
      _currentPage = nextPage;

      _isSearching = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isSearching = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Source search (Dart-side, unchanged)
  // ---------------------------------------------------------------------------

  /// Search for sources (local files).
  Future<void> searchSources(
    String query, {
    SourceType? type,
    String? directoryPath,
  }) async {
    if (query.isEmpty) {
      _sourceResults = [];
      _totalSourceCount = 0;
      notifyListeners();
      return;
    }

    try {
      _isSearching = true;
      _error = null;
      notifyListeners();

      final result = await _searchRepository.searchSources(
        query,
        type: type,
        directoryPath: directoryPath,
      );

      _sourceResults = result.items;
      _totalSourceCount = result.totalCount;

      _isSearching = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isSearching = false;
      notifyListeners();
    }
  }

  /// Load more Source results (pagination).
  Future<void> loadMoreSources(
    String query, {
    SourceType? type,
    String? directoryPath,
  }) async {
    if (!hasMoreSources || _isSearching) return;

    try {
      _isSearching = true;
      notifyListeners();

      final nextPage = _currentPage + 1;
      final result = await _searchRepository.searchSources(
        query,
        type: type,
        directoryPath: directoryPath,
        page: nextPage,
      );

      _sourceResults = [..._sourceResults, ...result.items];
      _currentPage = nextPage;

      _isSearching = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isSearching = false;
      notifyListeners();
    }
  }

  /// Search for online sources from third-party APIs.
  Future<void> searchOnlineSources(
    String query, {
    SourceType? type,
    String? providerName,
  }) async {
    if (query.isEmpty) {
      _sourceResults = [];
      _totalSourceCount = 0;
      notifyListeners();
      return;
    }

    try {
      _isSearching = true;
      _error = null;
      notifyListeners();

      final result = await _searchRepository.searchOnlineSources(
        query,
        type: type,
        providerName: providerName,
        pageSize: _pageSize,
      );

      _sourceResults = result.items;
      _totalSourceCount = result.totalCount;

      _isSearching = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isSearching = false;
      notifyListeners();
    }
  }

  /// Search for sources from both local and online sources.
  Future<void> searchAllSources(
    String query, {
    SourceType? type,
    String? directoryPath,
    bool includeLocal = true,
    bool includeOnline = true,
  }) async {
    if (query.isEmpty) {
      _sourceResults = [];
      _totalSourceCount = 0;
      notifyListeners();
      return;
    }

    try {
      _isSearching = true;
      _error = null;
      notifyListeners();

      final result = await _searchRepository.searchAllSources(
        query,
        type: type,
        directoryPath: directoryPath,
        includeLocal: includeLocal,
        includeOnline: includeOnline,
      );

      _sourceResults = result.items;
      _totalSourceCount = result.totalCount;

      _isSearching = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isSearching = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Chip operations (delete, edit)
  // ---------------------------------------------------------------------------

  /// Delete a chip at the given index by removing its text span from the query
  /// and re-serializing.
  Future<void> deleteChip(int chipIndex) async {
    if (chipIndex < 0 || chipIndex >= _chips.length) return;

    final chip = _chips[chipIndex];
    final start = chip.start.toInt();
    final end = chip.end.toInt();

    // Build new query text by removing the chip's span
    var newText = _queryText.substring(0, start) + _queryText.substring(end);

    // If we deleted an OR chip or a condition next to an OR, clean up
    // Remove double spaces and leading/trailing whitespace
    newText = newText.replaceAll(RegExp(r'\s+'), ' ').trim();
    // Remove orphaned OR at start/end
    newText = newText.replaceAll(RegExp(r'^\s*OR\s+'), '');
    newText = newText.replaceAll(RegExp(r'\s+OR\s*$'), '');
    // Remove double OR
    newText = newText.replaceAll(RegExp(r'\s+OR\s+OR\s+'), ' OR ');

    _queryText = newText;
    notifyListeners();

    // Re-parse
    if (newText.isEmpty) {
      _currentQuery = null;
      _chips = [];
      _parseError = null;
      notifyListeners();
    } else {
      await _parseQueryAsync(newText);
    }
  }

  /// Replace a chip's text with new text and re-parse the full query.
  Future<void> editChip(int chipIndex, String newChipText) async {
    if (chipIndex < 0 || chipIndex >= _chips.length) return;

    final chip = _chips[chipIndex];
    final start = chip.start.toInt();
    final end = chip.end.toInt();

    final newText =
        _queryText.substring(0, start) +
        newChipText +
        _queryText.substring(end);

    _queryText = newText;
    notifyListeners();

    await _parseQueryAsync(newText);
  }

  // ---------------------------------------------------------------------------
  // Clear / reset
  // ---------------------------------------------------------------------------

  void clearSearch() {
    _queryText = '';
    _currentQuery = null;
    _chips = [];
    _suggestions = [];
    _songUnitResults = [];
    _matchingIds = [];
    _sourceResults = [];
    _totalSongUnitCount = 0;
    _totalSourceCount = 0;
    _currentPage = 0;
    _error = null;
    _parseError = null;
    _suggestionDebounce?.cancel();
    notifyListeners();
  }

  void clearError() {
    _error = null;
    _parseError = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<bool> _getNameAutoSearch() async {
    try {
      final settings = await _settingsRepository.loadSettings();
      return settings.nameAutoSearch;
    } catch (_) {
      return true; // default: enabled
    }
  }

  @override
  void dispose() {
    _suggestionDebounce?.cancel();
    super.dispose();
  }
}
