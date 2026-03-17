// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'source_origin.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LocalFileOrigin _$LocalFileOriginFromJson(Map<String, dynamic> json) =>
    LocalFileOrigin(json['path'] as String);

Map<String, dynamic> _$LocalFileOriginToJson(LocalFileOrigin instance) =>
    <String, dynamic>{'path': instance.path};

UrlOrigin _$UrlOriginFromJson(Map<String, dynamic> json) =>
    UrlOrigin(json['url'] as String);

Map<String, dynamic> _$UrlOriginToJson(UrlOrigin instance) => <String, dynamic>{
  'url': instance.url,
};

ApiOrigin _$ApiOriginFromJson(Map<String, dynamic> json) =>
    ApiOrigin(json['provider'] as String, json['resourceId'] as String);

Map<String, dynamic> _$ApiOriginToJson(ApiOrigin instance) => <String, dynamic>{
  'provider': instance.provider,
  'resourceId': instance.resourceId,
};
