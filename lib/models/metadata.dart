import 'package:json_annotation/json_annotation.dart';

part 'metadata.g.dart';

/// Metadata for a Song Unit
@JsonSerializable()
class Metadata {
  const Metadata({
    required this.title,
    required this.artists,
    required this.album,
    this.year,
    required this.duration,
    this.thumbnailPath,
    this.thumbnailSourceId,
    this.customThumbnailPaths,
  });

  /// Custom fromJson to handle backward compatibility with old data format
  /// Old format had 'artist' as String, new format has 'artists' as `List<String>`
  factory Metadata.fromJson(Map<String, dynamic> json) {
    // Handle backward compatibility: old data has 'artist' string, new has 'artists' list
    List<String> artists;
    if (json['artists'] != null) {
      artists = (json['artists'] as List<dynamic>)
          .map((e) => e as String)
          .toList();
    } else if (json['artist'] != null) {
      // Old format: single artist string - parse it
      final artistStr = json['artist'] as String;
      artists = artistStr.isEmpty ? [] : _parseArtistString(artistStr);
    } else {
      artists = [];
    }

    return Metadata(
      title: json['title'] as String? ?? '',
      artists: artists,
      album: json['album'] as String? ?? '',
      year: (json['year'] as num?)?.toInt(),
      duration: json['duration'] != null
          ? Duration(microseconds: (json['duration'] as num).toInt())
          : Duration.zero,
      thumbnailPath: json['thumbnailPath'] as String?,
      thumbnailSourceId: json['thumbnailSourceId'] as String?,
      customThumbnailPaths: json['customThumbnailPaths'] != null
          ? (json['customThumbnailPaths'] as List<dynamic>)
                .map((e) => e as String)
                .toList()
          : null,
    );
  }

  /// Create default metadata
  factory Metadata.empty() {
    return const Metadata(
      title: '',
      artists: [],
      album: '',
      duration: Duration.zero,
    );
  }
  final String title;
  final List<String> artists;
  final String album;
  final int? year;
  final Duration duration;

  /// Path to thumbnail image (can be local file path or URL)
  /// If null, will attempt to extract from audio file metadata
  /// For custom thumbnails: use relative path like "./thumbnail.jpg" for portability
  /// For extracted thumbnails: use thumbnailSourceId instead
  @JsonKey(includeToJson: true, includeFromJson: true)
  final String? thumbnailPath;

  /// ID of the source from which the thumbnail was extracted
  /// If set, the thumbnail should be extracted from this source at runtime
  /// This makes the Song Unit portable without absolute paths
  /// Only used for thumbnails extracted from audio sources
  final String? thumbnailSourceId;

  /// List of custom thumbnail paths added by the user
  /// DEPRECATED: Not saved to JSON anymore - use internal cache
  @Deprecated('Custom thumbnails are not saved to avoid absolute paths')
  @JsonKey(includeToJson: false, includeFromJson: false)
  final List<String>? customThumbnailPaths;

  /// Parse artist string with multiple separators
  static List<String> _parseArtistString(String artistString) {
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

  Map<String, dynamic> toJson() => _$MetadataToJson(this);

  /// Get artists as a single string (for display)
  String get artistDisplay => artists.join(', ');

  /// Legacy getter for backward compatibility
  @Deprecated('Use artists list instead')
  String get artist => artistDisplay;

  Metadata copyWith({
    String? title,
    List<String>? artists,
    String? album,
    int? year,
    Duration? duration,
    String? thumbnailPath,
    String? thumbnailSourceId,
    List<String>? customThumbnailPaths,
  }) {
    return Metadata(
      title: title ?? this.title,
      artists: artists ?? this.artists,
      album: album ?? this.album,
      year: year ?? this.year,
      duration: duration ?? this.duration,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      thumbnailSourceId: thumbnailSourceId ?? this.thumbnailSourceId,
      customThumbnailPaths: customThumbnailPaths ?? this.customThumbnailPaths,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Metadata &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          _listEquals(artists, other.artists) &&
          album == other.album &&
          year == other.year &&
          duration == other.duration &&
          thumbnailPath == other.thumbnailPath &&
          thumbnailSourceId == other.thumbnailSourceId &&
          _listEquals(
            customThumbnailPaths ?? [],
            other.customThumbnailPaths ?? [],
          );

  @override
  int get hashCode =>
      title.hashCode ^
      artists.hashCode ^
      album.hashCode ^
      year.hashCode ^
      duration.hashCode ^
      thumbnailPath.hashCode ^
      thumbnailSourceId.hashCode ^
      (customThumbnailPaths?.hashCode ?? 0);

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
