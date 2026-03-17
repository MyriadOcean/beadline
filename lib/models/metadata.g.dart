// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'metadata.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Metadata _$MetadataFromJson(Map<String, dynamic> json) => Metadata(
  title: json['title'] as String,
  artists: (json['artists'] as List<dynamic>).map((e) => e as String).toList(),
  album: json['album'] as String,
  year: (json['year'] as num?)?.toInt(),
  duration: Duration(microseconds: (json['duration'] as num).toInt()),
  thumbnailPath: json['thumbnailPath'] as String?,
  thumbnailSourceId: json['thumbnailSourceId'] as String?,
);

Map<String, dynamic> _$MetadataToJson(Metadata instance) => <String, dynamic>{
  'title': instance.title,
  'artists': instance.artists,
  'album': instance.album,
  'year': instance.year,
  'duration': instance.duration.inMicroseconds,
  'thumbnailPath': instance.thumbnailPath,
  'thumbnailSourceId': instance.thumbnailSourceId,
};
