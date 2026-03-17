import 'dart:io';

import '../data/file_system_service.dart';
import '../models/online_provider_config.dart';
import '../models/song_unit.dart';
import '../models/source.dart';
import '../services/online_source_provider.dart';
import '../src/rust/api/evaluator_api.dart' as rust_evaluator;
import 'library_repository.dart';
import 'tag_repository.dart';

/// Search result with pagination info
class SearchResult<T> {
  const SearchResult({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });
  final List<T> items;
  final int totalCount;
  final int page;
  final int pageSize;

  bool get hasMore => (page + 1) * pageSize < totalCount;
}

/// Repository for searching Song Units and Sources
/// Requirements: 6.1-6.7, 7.1-7.4
class SearchRepository {
  SearchRepository(
    this._libraryRepository,
    this._tagRepository,
    this._fileSystem, {
    OnlineSourceProviderRegistry? onlineProviders,
  }) : _onlineProviders = onlineProviders ?? OnlineSourceProviderRegistry();
  final LibraryRepository _libraryRepository;
  final TagRepository _tagRepository;
  final FileSystemService _fileSystem;
  final OnlineSourceProviderRegistry _onlineProviders;

  /// Search Song Units using a text query
  /// Bare keywords are transformed to name:*keyword* by the Rust parser
  Future<SearchResult<SongUnit>> searchSongUnitsByText(
    String queryText, {
    int page = 0,
    int pageSize = 50,
  }) async {
    // If query is empty, return empty results (not all)
    if (queryText.trim().isEmpty) {
      return SearchResult(
        items: [],
        totalCount: 0,
        page: page,
        pageSize: pageSize,
      );
    }

    // Delegate to Rust — it fetches song units + tags from DB itself
    // and injects metadata as synthetic built-in tags for evaluation.
    Set<String> idSet;
    try {
      final matchingIds = await rust_evaluator.searchSongUnits(
        queryText: queryText,
        nameAutoSearch: true,
      );
      idSet = matchingIds.toSet();
    } catch (_) {
      idSet = {};
    }

    // Get all song units for filtering results
    final allSongUnits = await _libraryRepository.getAllSongUnits();

    final matchingSongUnits = allSongUnits.where((u) => idSet.contains(u.id)).toList();

    // Apply pagination
    final startIndex = page * pageSize;
    final endIndex = (startIndex + pageSize).clamp(0, matchingSongUnits.length);
    final pageItems = startIndex < matchingSongUnits.length
        ? matchingSongUnits.sublist(startIndex, endIndex)
        : <SongUnit>[];

    return SearchResult(
      items: pageItems,
      totalCount: matchingSongUnits.length,
      page: page,
      pageSize: pageSize,
    );
  }

  /// Search for local sources (audio, video, lyrics files)
  Future<SearchResult<OnlineSourceResult>> searchSources(
    String query, {
    SourceType? type,
    String? directoryPath,
    int page = 0,
    int pageSize = 50,
  }) async {
    final results = <OnlineSourceResult>[];

    // Use provided directory or default to library directory
    String searchPath;
    if (directoryPath != null) {
      searchPath = directoryPath;
    } else {
      final libraryDir = await _fileSystem.getLibraryDirectory();
      searchPath = libraryDir.path;
    }

    final files = await _scanDirectory(searchPath, query, type);
    results.addAll(files);

    // Apply pagination
    final startIndex = page * pageSize;
    final endIndex = (startIndex + pageSize).clamp(0, results.length);
    final pageItems = startIndex < results.length
        ? results.sublist(startIndex, endIndex)
        : <OnlineSourceResult>[];

    return SearchResult(
      items: pageItems,
      totalCount: results.length,
      page: page,
      pageSize: pageSize,
    );
  }

  /// Scan a directory for matching files
  Future<List<OnlineSourceResult>> _scanDirectory(
    String directoryPath,
    String query,
    SourceType? type,
  ) async {
    final results = <OnlineSourceResult>[];
    final directory = Directory(directoryPath);

    if (!directory.existsSync()) {
      return results;
    }

    try {
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          final fileName = entity.path.split('/').last;
          final lowerFileName = fileName.toLowerCase();
          final lowerQuery = query.toLowerCase();

          // Check if file name matches query
          if (lowerFileName.contains(lowerQuery)) {
            final sourceType = _getSourceTypeFromExtension(fileName);

            // Filter by type if specified
            if (type != null && sourceType != type) {
              continue;
            }

            // Convert local file to OnlineSourceResult format
            results.add(
              OnlineSourceResult(
                id: entity.path,
                title: fileName,
                platform: 'Local',
                url: entity.path,
              ),
            );
          }
        }
      }
    } catch (e) {
      // Ignore permission errors and other issues
    }

    return results;
  }

  /// Determine source type from file extension
  SourceType _getSourceTypeFromExtension(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();

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

    // Default to audio
    return SourceType.audio;
  }

  /// Search for online sources from third-party APIs
  /// Requirements: 7.2, 7.3
  Future<SearchResult<OnlineSourceResult>> searchOnlineSources(
    String query, {
    SourceType? type,
    String? providerName,
    int page = 0,
    int pageSize = 20,
  }) async {
    List<OnlineSourceResult> results;

    if (providerName != null) {
      // Search specific provider
      final provider = _onlineProviders.getProvider(providerName);
      if (provider == null || !provider.isAvailable) {
        return SearchResult(
          items: [],
          totalCount: 0,
          page: page,
          pageSize: pageSize,
        );
      }
      results = await provider.search(
        query,
        type: type,
        page: page,
        pageSize: pageSize,
      );
    } else {
      // Search all available providers
      results = await _onlineProviders.searchAll(
        query,
        type: type,
        page: page,
        pageSize: pageSize,
      );
    }

    // Apply pagination (providers may return more than pageSize)
    const startIndex = 0; // Providers handle their own pagination
    final endIndex = pageSize.clamp(0, results.length);
    final pageItems = results.sublist(startIndex, endIndex);

    return SearchResult(
      items: pageItems,
      totalCount: results.length,
      page: page,
      pageSize: pageSize,
    );
  }

  /// Search for sources from both local and online sources
  /// Requirements: 7.1, 7.2, 7.3, 7.4
  Future<SearchResult<OnlineSourceResult>> searchAllSources(
    String query, {
    SourceType? type,
    String? directoryPath,
    bool includeLocal = true,
    bool includeOnline = true,
    int page = 0,
    int pageSize = 50,
  }) async {
    final allResults = <OnlineSourceResult>[];

    // Search local sources
    if (includeLocal) {
      final localResults = await searchSources(
        query,
        type: type,
        directoryPath: directoryPath,
        pageSize: 1000, // Get all local results
      );
      allResults.addAll(localResults.items);
    }

    // Search online sources
    if (includeOnline) {
      final onlineResults = await searchOnlineSources(
        query,
        type: type,
        pageSize: 100, // Get reasonable amount from online
      );
      allResults.addAll(onlineResults.items);
    }

    // Apply pagination to combined results
    final startIndex = page * pageSize;
    final endIndex = (startIndex + pageSize).clamp(0, allResults.length);
    final pageItems = startIndex < allResults.length
        ? allResults.sublist(startIndex, endIndex)
        : <OnlineSourceResult>[];

    return SearchResult(
      items: pageItems,
      totalCount: allResults.length,
      page: page,
      pageSize: pageSize,
    );
  }

  /// Get all Song Units for suggestion matching (e.g. built-in key values).
  Future<List<SongUnit>> getAllSongUnitsForSuggestions() async {
    return _libraryRepository.getAllSongUnits();
  }

  /// Get list of available online source providers
  List<OnlineSourceProvider> get availableOnlineProviders =>
      _onlineProviders.availableProviders;
}
