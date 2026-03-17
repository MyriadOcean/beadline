// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'source_collection.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SourceCollection _$SourceCollectionFromJson(Map<String, dynamic> json) =>
    SourceCollection(
      displaySources:
          (json['displaySources'] as List<dynamic>?)
              ?.map((e) => DisplaySource.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      audioSources:
          (json['audioSources'] as List<dynamic>?)
              ?.map((e) => AudioSource.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      accompanimentSources:
          (json['accompanimentSources'] as List<dynamic>?)
              ?.map(
                (e) => AccompanimentSource.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      hoverSources:
          (json['hoverSources'] as List<dynamic>?)
              ?.map((e) => HoverSource.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$SourceCollectionToJson(SourceCollection instance) =>
    <String, dynamic>{
      'displaySources': instance.displaySources.map((e) => e.toJson()).toList(),
      'audioSources': instance.audioSources.map((e) => e.toJson()).toList(),
      'accompanimentSources': instance.accompanimentSources
          .map((e) => e.toJson())
          .toList(),
      'hoverSources': instance.hoverSources.map((e) => e.toJson()).toList(),
    };
