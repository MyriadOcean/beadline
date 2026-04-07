// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playlist_metadata.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PlaylistItem _$PlaylistItemFromJson(Map<String, dynamic> json) => PlaylistItem(
  id: json['id'] as String,
  type: $enumDecode(_$PlaylistItemTypeEnumMap, json['type']),
  targetId: json['targetId'] as String,
  order: (json['order'] as num).toInt(),
  inheritLock: json['inheritLock'] as bool? ?? true,
);

Map<String, dynamic> _$PlaylistItemToJson(PlaylistItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$PlaylistItemTypeEnumMap[instance.type]!,
      'targetId': instance.targetId,
      'order': instance.order,
      'inheritLock': instance.inheritLock,
    };

const _$PlaylistItemTypeEnumMap = {
  PlaylistItemType.songUnit: 'songUnit',
  PlaylistItemType.collectionReference: 'collectionReference',
};

PlaylistMetadata _$PlaylistMetadataFromJson(Map<String, dynamic> json) =>
    PlaylistMetadata(
      isLocked: json['isLocked'] as bool,
      displayOrder: (json['displayOrder'] as num).toInt(),
      items: (json['items'] as List<dynamic>)
          .map((e) => PlaylistItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      currentIndex: (json['currentIndex'] as num?)?.toInt() ?? -1,
      playbackPositionMs: (json['playbackPositionMs'] as num?)?.toInt() ?? 0,
      wasPlaying: json['wasPlaying'] as bool? ?? false,
      removeAfterPlay: json['removeAfterPlay'] as bool? ?? false,
      isQueue: json['isQueue'] as bool? ?? false,
    );

Map<String, dynamic> _$PlaylistMetadataToJson(PlaylistMetadata instance) =>
    <String, dynamic>{
      'isLocked': instance.isLocked,
      'displayOrder': instance.displayOrder,
      'items': instance.items,
      'currentIndex': instance.currentIndex,
      'playbackPositionMs': instance.playbackPositionMs,
      'wasPlaying': instance.wasPlaying,
      'removeAfterPlay': instance.removeAfterPlay,
      'isQueue': instance.isQueue,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
