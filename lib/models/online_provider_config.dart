import 'package:json_annotation/json_annotation.dart';

part 'online_provider_config.g.dart';

/// Configuration for an online source provider
@JsonSerializable()
class OnlineProviderConfig {
  const OnlineProviderConfig({
    required this.providerId,
    required this.displayName,
    required this.baseUrl,
    this.enabled = true,
    this.apiKey,
    this.customHeaders = const {},
    this.timeout = 10,
  });

  factory OnlineProviderConfig.fromJson(Map<String, dynamic> json) =>
      _$OnlineProviderConfigFromJson(json);

  /// Unique provider identifier (e.g., 'bilibili', 'netease')
  final String providerId;

  /// Display name shown in UI
  final String displayName;

  /// Base URL for API bridge (e.g., 'http://localhost:3000')
  final String baseUrl;

  /// Whether this provider is enabled
  final bool enabled;

  /// Optional API key for authentication
  final String? apiKey;

  /// Custom HTTP headers
  final Map<String, String> customHeaders;

  /// Request timeout in seconds
  final int timeout;

  Map<String, dynamic> toJson() => _$OnlineProviderConfigToJson(this);

  OnlineProviderConfig copyWith({
    String? providerId,
    String? displayName,
    String? baseUrl,
    bool? enabled,
    String? apiKey,
    Map<String, String>? customHeaders,
    int? timeout,
  }) {
    return OnlineProviderConfig(
      providerId: providerId ?? this.providerId,
      displayName: displayName ?? this.displayName,
      baseUrl: baseUrl ?? this.baseUrl,
      enabled: enabled ?? this.enabled,
      apiKey: apiKey ?? this.apiKey,
      customHeaders: customHeaders ?? this.customHeaders,
      timeout: timeout ?? this.timeout,
    );
  }
}

/// Result from online source search
@JsonSerializable()
class OnlineSourceResult {
  const OnlineSourceResult({
    required this.id,
    required this.title,
    required this.platform,
    required this.url,
    this.artist,
    this.album,
    this.duration,
    this.thumbnailUrl,
    this.description,
  });

  factory OnlineSourceResult.fromJson(Map<String, dynamic> json) =>
      _$OnlineSourceResultFromJson(json);

  /// Unique identifier from platform
  final String id;

  /// Title/name of the content
  final String title;

  /// Platform name (e.g., 'Bilibili', 'NetEase')
  final String platform;

  /// Direct URL to media or platform page
  final String url;

  /// Artist/creator name
  final String? artist;

  /// Album name
  final String? album;

  /// Duration in seconds
  final int? duration;

  /// Thumbnail/cover image URL
  final String? thumbnailUrl;

  /// Description or additional info
  final String? description;

  Map<String, dynamic> toJson() => _$OnlineSourceResultToJson(this);
}
