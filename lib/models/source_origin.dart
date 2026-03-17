import 'package:json_annotation/json_annotation.dart';

part 'source_origin.g.dart';

/// Represents the origin of a source (local file, URL, or API)
sealed class SourceOrigin {
  const SourceOrigin();

  factory SourceOrigin.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    switch (type) {
      case 'localFile':
        return LocalFileOrigin.fromJson(json);
      case 'url':
        return UrlOrigin.fromJson(json);
      case 'api':
        return ApiOrigin.fromJson(json);
      default:
        throw ArgumentError('Unknown SourceOrigin type: $type');
    }
  }

  Map<String, dynamic> toJson();
}

/// Source from a local file
@JsonSerializable()
class LocalFileOrigin extends SourceOrigin {
  const LocalFileOrigin(this.path);

  factory LocalFileOrigin.fromJson(Map<String, dynamic> json) =>
      _$LocalFileOriginFromJson(json);
  final String path;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'localFile',
    ..._$LocalFileOriginToJson(this),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalFileOrigin &&
          runtimeType == other.runtimeType &&
          path == other.path;

  @override
  int get hashCode => path.hashCode;
}

/// Source from a URL
@JsonSerializable()
class UrlOrigin extends SourceOrigin {
  const UrlOrigin(this.url);

  factory UrlOrigin.fromJson(Map<String, dynamic> json) =>
      _$UrlOriginFromJson(json);
  final String url;

  @override
  Map<String, dynamic> toJson() => {'type': 'url', ..._$UrlOriginToJson(this)};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UrlOrigin &&
          runtimeType == other.runtimeType &&
          url == other.url;

  @override
  int get hashCode => url.hashCode;
}

/// Source from a third-party API
@JsonSerializable()
class ApiOrigin extends SourceOrigin {
  const ApiOrigin(this.provider, this.resourceId);

  factory ApiOrigin.fromJson(Map<String, dynamic> json) =>
      _$ApiOriginFromJson(json);
  final String provider;
  final String resourceId;

  @override
  Map<String, dynamic> toJson() => {'type': 'api', ..._$ApiOriginToJson(this)};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApiOrigin &&
          runtimeType == other.runtimeType &&
          provider == other.provider &&
          resourceId == other.resourceId;

  @override
  int get hashCode => provider.hashCode ^ resourceId.hashCode;
}
