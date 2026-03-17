import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/online_provider_config.dart';
import '../models/source.dart';

/// Abstract interface for online source providers (third-party APIs)
/// Requirements: 7.2
abstract class OnlineSourceProvider {
  OnlineSourceProvider(this.config);

  /// Provider configuration
  final OnlineProviderConfig config;

  /// Provider unique identifier
  String get providerId => config.providerId;

  /// Display name for UI
  String get displayName => config.displayName;

  /// Whether this provider is currently available/configured
  bool get isAvailable => config.enabled && config.baseUrl.isNotEmpty;

  /// Search for sources from this provider
  Future<List<OnlineSourceResult>> search(
    String query, {
    SourceType? type,
    int page = 0,
    int pageSize = 20,
  });

  /// Extract direct media URL from platform URL
  /// Returns null if extraction not supported or fails
  Future<String?> extractMediaUrl(String platformUrl);

  /// Test if provider is reachable
  Future<bool> testConnection() async {
    if (!isAvailable) return false;

    try {
      final response = await http
          .get(Uri.parse(config.baseUrl))
          .timeout(Duration(seconds: config.timeout));
      return response.statusCode < 500;
    } catch (e) {
      return false;
    }
  }

  /// Helper to make HTTP requests with provider config
  Future<http.Response> makeRequest(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    final uri = Uri.parse(
      '${config.baseUrl}$endpoint',
    ).replace(queryParameters: queryParams);

    final headers = <String, String>{
      'Content-Type': 'application/json',
      ...config.customHeaders,
    };

    if (config.apiKey != null) {
      headers['Authorization'] = 'Bearer ${config.apiKey}';
    }

    return http
        .get(uri, headers: headers)
        .timeout(Duration(seconds: config.timeout));
  }
}

/// Bilibili source provider
/// Requires user-hosted API bridge (e.g., yt-dlp wrapper)
///
/// Expected API endpoints:
/// - GET /search?q={query}&type={video|audio}&page={page}
/// - GET /extract?url={bilibili_url}
class BilibiliSourceProvider extends OnlineSourceProvider {
  BilibiliSourceProvider(super.config);

  @override
  Future<List<OnlineSourceResult>> search(
    String query, {
    SourceType? type,
    int page = 0,
    int pageSize = 20,
  }) async {
    if (!isAvailable || query.isEmpty) return [];

    try {
      final typeParam = type == SourceType.audio ? 'audio' : 'video';
      final response = await makeRequest(
        '/search',
        queryParams: {
          'q': query,
          'type': typeParam,
          'page': page.toString(),
          'limit': pageSize.toString(),
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List?;

        if (results != null) {
          return results
              .map(
                (item) => OnlineSourceResult(
                  id: item['id'] ?? '',
                  title: item['title'] ?? '',
                  platform: displayName,
                  url: item['url'] ?? '',
                  artist: item['author'],
                  duration: item['duration'],
                  thumbnailUrl: item['thumbnail'],
                  description: item['description'],
                ),
              )
              .toList();
        }
      }
    } catch (e) {
      // Log error but don't throw
      debugPrint('Bilibili search error: $e');
    }

    return [];
  }

  @override
  Future<String?> extractMediaUrl(String platformUrl) async {
    if (!isAvailable) return null;

    try {
      final response = await makeRequest(
        '/extract',
        queryParams: {'url': platformUrl},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['url'] as String?;
      }
    } catch (e) {
      debugPrint('Bilibili extract error: $e');
    }

    return null;
  }
}

/// NetEase Cloud Music source provider
/// Requires user-hosted API bridge (e.g., NeteaseCloudMusicApi)
///
/// Expected API endpoints:
/// - GET /search?keywords={query}&type={1|1004}&limit={limit}
/// - GET /song/url?id={song_id}
/// - GET /lyric?id={song_id}
class NetEaseSourceProvider extends OnlineSourceProvider {
  NetEaseSourceProvider(super.config);

  @override
  Future<List<OnlineSourceResult>> search(
    String query, {
    SourceType? type,
    int page = 0,
    int pageSize = 20,
  }) async {
    if (!isAvailable || query.isEmpty) return [];

    try {
      // NetEase API: type 1 = song, type 1004 = MV
      final searchType = type == SourceType.display ? '1004' : '1';
      final response = await makeRequest(
        '/search',
        queryParams: {
          'keywords': query,
          'type': searchType,
          'limit': pageSize.toString(),
          'offset': (page * pageSize).toString(),
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = data['result'];

        if (result != null) {
          final items = (result['songs'] ?? result['mvs']) as List?;

          if (items != null) {
            return items
                .map(
                  (item) => OnlineSourceResult(
                    id: item['id'].toString(),
                    title: item['name'] ?? '',
                    platform: displayName,
                    url: 'https://music.163.com/#/song?id=${item['id']}',
                    artist: _extractArtists(item['artists'] ?? item['ar']),
                    album: item['album']?['name'] ?? item['al']?['name'],
                    duration: (item['duration'] ?? item['dt'])?.toInt() ?? 0,
                    thumbnailUrl:
                        item['album']?['picUrl'] ??
                        item['al']?['picUrl'] ??
                        item['cover'],
                  ),
                )
                .toList();
          }
        }
      }
    } catch (e) {
      debugPrint('NetEase search error: $e');
    }

    return [];
  }

  String? _extractArtists(dynamic artists) {
    if (artists == null) return null;
    if (artists is List) {
      return artists.map((a) => a['name']).join(', ');
    }
    return null;
  }

  @override
  Future<String?> extractMediaUrl(String platformUrl) async {
    if (!isAvailable) return null;

    try {
      // Extract song ID from URL
      final uri = Uri.tryParse(platformUrl);
      final songId = uri?.queryParameters['id'];

      if (songId == null) return null;

      final response = await makeRequest(
        '/song/url',
        queryParams: {'id': songId},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final urls = data['data'] as List?;

        if (urls != null && urls.isNotEmpty) {
          return urls.first['url'] as String?;
        }
      }
    } catch (e) {
      debugPrint('NetEase extract error: $e');
    }

    return null;
  }

  /// Get lyrics for a song
  Future<String?> getLyrics(String songId) async {
    if (!isAvailable) return null;

    try {
      final response = await makeRequest('/lyric', queryParams: {'id': songId});

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['lrc']?['lyric'] as String?;
      }
    } catch (e) {
      debugPrint('NetEase lyrics error: $e');
    }

    return null;
  }
}

/// Registry of all available online source providers
class OnlineSourceProviderRegistry {
  OnlineSourceProviderRegistry({List<OnlineProviderConfig>? configs}) {
    // Initialize with provided configs or defaults
    if (configs != null && configs.isNotEmpty) {
      for (final config in configs) {
        _initializeProvider(config);
      }
    } else {
      // Register default placeholder providers (disabled by default)
      _providers
        ..add(
          BilibiliSourceProvider(
            const OnlineProviderConfig(
              providerId: 'bilibili',
              displayName: 'Bilibili',
              baseUrl: '',
              enabled: false,
            ),
          ),
        )
        ..add(
          NetEaseSourceProvider(
            const OnlineProviderConfig(
              providerId: 'netease',
              displayName: 'NetEase Cloud Music',
              baseUrl: '',
              enabled: false,
            ),
          ),
        );
    }
  }

  final List<OnlineSourceProvider> _providers = [];

  void _initializeProvider(OnlineProviderConfig config) {
    switch (config.providerId) {
      case 'bilibili':
        _providers.add(BilibiliSourceProvider(config));
      case 'netease':
        _providers.add(NetEaseSourceProvider(config));
      default:
        // Unknown provider, skip
        debugPrint('Unknown provider: ${config.providerId}');
    }
  }

  /// Get all registered providers
  List<OnlineSourceProvider> get providers => List.unmodifiable(_providers);

  /// Get all available (enabled and configured) providers
  List<OnlineSourceProvider> get availableProviders =>
      _providers.where((p) => p.isAvailable).toList();

  /// Get provider by ID
  OnlineSourceProvider? getProvider(String providerId) {
    try {
      return _providers.firstWhere((p) => p.providerId == providerId);
    } catch (_) {
      return null;
    }
  }

  /// Update provider configuration
  void updateProvider(OnlineProviderConfig config) {
    // Remove old provider with same ID
    _providers.removeWhere((p) => p.providerId == config.providerId);
    // Add new provider with updated config
    _initializeProvider(config);
  }

  /// Register a custom provider
  void registerProvider(OnlineSourceProvider provider) {
    _providers.add(provider);
  }

  /// Search across all available providers
  Future<List<OnlineSourceResult>> searchAll(
    String query, {
    SourceType? type,
    int page = 0,
    int pageSize = 20,
  }) async {
    final results = <OnlineSourceResult>[];

    for (final provider in availableProviders) {
      try {
        final providerResults = await provider.search(
          query,
          type: type,
          page: page,
          pageSize: pageSize,
        );
        results.addAll(providerResults);
      } catch (e) {
        debugPrint('Provider ${provider.providerId} search error: $e');
      }
    }

    return results;
  }

  /// Test all provider connections
  Future<Map<String, bool>> testAllConnections() async {
    final results = <String, bool>{};

    for (final provider in _providers) {
      results[provider.providerId] = await provider.testConnection();
    }

    return results;
  }
}
