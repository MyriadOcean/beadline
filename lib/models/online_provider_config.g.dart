// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'online_provider_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OnlineProviderConfig _$OnlineProviderConfigFromJson(
  Map<String, dynamic> json,
) => OnlineProviderConfig(
  providerId: json['providerId'] as String,
  displayName: json['displayName'] as String,
  baseUrl: json['baseUrl'] as String,
  enabled: json['enabled'] as bool? ?? true,
  apiKey: json['apiKey'] as String?,
  customHeaders:
      (json['customHeaders'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ) ??
      const {},
  timeout: (json['timeout'] as num?)?.toInt() ?? 10,
);

Map<String, dynamic> _$OnlineProviderConfigToJson(
  OnlineProviderConfig instance,
) => <String, dynamic>{
  'providerId': instance.providerId,
  'displayName': instance.displayName,
  'baseUrl': instance.baseUrl,
  'enabled': instance.enabled,
  'apiKey': instance.apiKey,
  'customHeaders': instance.customHeaders,
  'timeout': instance.timeout,
};

OnlineSourceResult _$OnlineSourceResultFromJson(Map<String, dynamic> json) =>
    OnlineSourceResult(
      id: json['id'] as String,
      title: json['title'] as String,
      platform: json['platform'] as String,
      url: json['url'] as String,
      artist: json['artist'] as String?,
      album: json['album'] as String?,
      duration: (json['duration'] as num?)?.toInt(),
      thumbnailUrl: json['thumbnailUrl'] as String?,
      description: json['description'] as String?,
    );

Map<String, dynamic> _$OnlineSourceResultToJson(OnlineSourceResult instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'platform': instance.platform,
      'url': instance.url,
      'artist': instance.artist,
      'album': instance.album,
      'duration': instance.duration,
      'thumbnailUrl': instance.thumbnailUrl,
      'description': instance.description,
    };
