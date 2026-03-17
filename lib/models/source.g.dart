// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'source.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DisplaySource _$DisplaySourceFromJson(Map<String, dynamic> json) =>
    DisplaySource(
      id: json['id'] as String,
      origin: SourceOrigin.fromJson(json['origin'] as Map<String, dynamic>),
      priority: (json['priority'] as num).toInt(),
      displayName: json['displayName'] as String?,
      displayType: $enumDecode(_$DisplayTypeEnumMap, json['displayType']),
      duration: json['duration'] == null
          ? null
          : Duration(microseconds: (json['duration'] as num).toInt()),
      offset: json['offset'] == null
          ? Duration.zero
          : Duration(microseconds: (json['offset'] as num).toInt()),
    );

Map<String, dynamic> _$DisplaySourceToJson(DisplaySource instance) =>
    <String, dynamic>{
      'id': instance.id,
      'origin': instance.origin.toJson(),
      'priority': instance.priority,
      'displayName': instance.displayName,
      'displayType': _$DisplayTypeEnumMap[instance.displayType]!,
      'duration': instance.duration?.inMicroseconds,
      'offset': instance.offset.inMicroseconds,
    };

const _$DisplayTypeEnumMap = {
  DisplayType.video: 'video',
  DisplayType.image: 'image',
};

AudioSource _$AudioSourceFromJson(Map<String, dynamic> json) => AudioSource(
  id: json['id'] as String,
  origin: SourceOrigin.fromJson(json['origin'] as Map<String, dynamic>),
  priority: (json['priority'] as num).toInt(),
  displayName: json['displayName'] as String?,
  format: $enumDecode(_$AudioFormatEnumMap, json['format']),
  duration: json['duration'] == null
      ? null
      : Duration(microseconds: (json['duration'] as num).toInt()),
  offset: json['offset'] == null
      ? Duration.zero
      : Duration(microseconds: (json['offset'] as num).toInt()),
  linkedVideoSourceId: json['linkedVideoSourceId'] as String?,
);

Map<String, dynamic> _$AudioSourceToJson(AudioSource instance) =>
    <String, dynamic>{
      'id': instance.id,
      'origin': instance.origin.toJson(),
      'priority': instance.priority,
      'displayName': instance.displayName,
      'format': _$AudioFormatEnumMap[instance.format]!,
      'duration': instance.duration?.inMicroseconds,
      'offset': instance.offset.inMicroseconds,
      'linkedVideoSourceId': instance.linkedVideoSourceId,
    };

const _$AudioFormatEnumMap = {
  AudioFormat.mp3: 'mp3',
  AudioFormat.flac: 'flac',
  AudioFormat.wav: 'wav',
  AudioFormat.aac: 'aac',
  AudioFormat.ogg: 'ogg',
  AudioFormat.m4a: 'm4a',
  AudioFormat.other: 'other',
};

AccompanimentSource _$AccompanimentSourceFromJson(Map<String, dynamic> json) =>
    AccompanimentSource(
      id: json['id'] as String,
      origin: SourceOrigin.fromJson(json['origin'] as Map<String, dynamic>),
      priority: (json['priority'] as num).toInt(),
      displayName: json['displayName'] as String?,
      format: $enumDecode(_$AudioFormatEnumMap, json['format']),
      duration: json['duration'] == null
          ? null
          : Duration(microseconds: (json['duration'] as num).toInt()),
      offset: json['offset'] == null
          ? Duration.zero
          : Duration(microseconds: (json['offset'] as num).toInt()),
    );

Map<String, dynamic> _$AccompanimentSourceToJson(
  AccompanimentSource instance,
) => <String, dynamic>{
  'id': instance.id,
  'origin': instance.origin.toJson(),
  'priority': instance.priority,
  'displayName': instance.displayName,
  'format': _$AudioFormatEnumMap[instance.format]!,
  'duration': instance.duration?.inMicroseconds,
  'offset': instance.offset.inMicroseconds,
};

HoverSource _$HoverSourceFromJson(Map<String, dynamic> json) => HoverSource(
  id: json['id'] as String,
  origin: SourceOrigin.fromJson(json['origin'] as Map<String, dynamic>),
  priority: (json['priority'] as num).toInt(),
  displayName: json['displayName'] as String?,
  format: $enumDecode(_$LyricsFormatEnumMap, json['format']),
  offset: json['offset'] == null
      ? Duration.zero
      : Duration(microseconds: (json['offset'] as num).toInt()),
);

Map<String, dynamic> _$HoverSourceToJson(HoverSource instance) =>
    <String, dynamic>{
      'id': instance.id,
      'origin': instance.origin.toJson(),
      'priority': instance.priority,
      'displayName': instance.displayName,
      'format': _$LyricsFormatEnumMap[instance.format]!,
      'offset': instance.offset.inMicroseconds,
    };

const _$LyricsFormatEnumMap = {LyricsFormat.lrc: 'lrc'};
