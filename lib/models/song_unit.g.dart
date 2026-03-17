// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'song_unit.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SongUnit _$SongUnitFromJson(Map<String, dynamic> json) => SongUnit(
  id: json['id'] as String,
  metadata: Metadata.fromJson(json['metadata'] as Map<String, dynamic>),
  sources: SourceCollection.fromJson(json['sources'] as Map<String, dynamic>),
  tagIds:
      (json['tagIds'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  preferences: PlaybackPreferences.fromJson(
    json['preferences'] as Map<String, dynamic>,
  ),
  libraryLocationId: json['libraryLocationId'] as String?,
  isTemporary: json['isTemporary'] as bool? ?? false,
  discoveredAt: SongUnit._dateTimeFromMillisOrNull(
    (json['discoveredAt'] as num?)?.toInt(),
  ),
  originalFilePath: json['originalFilePath'] as String?,
);

Map<String, dynamic> _$SongUnitToJson(SongUnit instance) => <String, dynamic>{
  'id': instance.id,
  'metadata': instance.metadata.toJson(),
  'sources': instance.sources.toJson(),
  'tagIds': instance.tagIds,
  'preferences': instance.preferences.toJson(),
  'libraryLocationId': instance.libraryLocationId,
  'isTemporary': instance.isTemporary,
  'discoveredAt': SongUnit._dateTimeToMillisOrNull(instance.discoveredAt),
  'originalFilePath': instance.originalFilePath,
};
