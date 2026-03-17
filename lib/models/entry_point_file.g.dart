// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'entry_point_file.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SourceReference _$SourceReferenceFromJson(Map<String, dynamic> json) =>
    SourceReference(
      id: json['id'] as String,
      sourceType: json['sourceType'] as String,
      originType: json['originType'] as String,
      path: json['path'] as String,
      priority: (json['priority'] as num).toInt(),
      metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
    );

Map<String, dynamic> _$SourceReferenceToJson(SourceReference instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sourceType': instance.sourceType,
      'originType': instance.originType,
      'path': instance.path,
      'priority': instance.priority,
      'metadata': instance.metadata,
    };

EntryPointFile _$EntryPointFileFromJson(
  Map<String, dynamic> json,
) => EntryPointFile(
  version: (json['version'] as num?)?.toInt() ?? 1,
  songUnitId: json['songUnitId'] as String,
  name: json['name'] as String,
  metadata: Metadata.fromJson(json['metadata'] as Map<String, dynamic>),
  sources: (json['sources'] as List<dynamic>)
      .map((e) => SourceReference.fromJson(e as Map<String, dynamic>))
      .toList(),
  tagIds:
      (json['tagIds'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  tagNames:
      (json['tagNames'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      [],
  playbackPreferences: json['playbackPreferences'] == null
      ? null
      : PlaybackPreferences.fromJson(
          json['playbackPreferences'] as Map<String, dynamic>,
        ),
  createdAt: DateTime.parse(json['createdAt'] as String),
  modifiedAt: DateTime.parse(json['modifiedAt'] as String),
);

Map<String, dynamic> _$EntryPointFileToJson(EntryPointFile instance) =>
    <String, dynamic>{
      'version': instance.version,
      'songUnitId': instance.songUnitId,
      'name': instance.name,
      'metadata': instance.metadata.toJson(),
      'sources': instance.sources.map((e) => e.toJson()).toList(),
      'tagIds': instance.tagIds,
      'tagNames': instance.tagNames,
      'playbackPreferences': instance.playbackPreferences?.toJson(),
      'createdAt': instance.createdAt.toIso8601String(),
      'modifiedAt': instance.modifiedAt.toIso8601String(),
    };
