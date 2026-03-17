// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tag.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Tag _$TagFromJson(Map<String, dynamic> json) => Tag(
  id: json['id'] as String,
  name: json['name'] as String,
  type: $enumDecode(_$TagTypeEnumMap, json['type']),
  parentId: json['parentId'] as String?,
  aliasNames:
      (json['aliasNames'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  includeChildren: json['includeChildren'] as bool? ?? true,
  playlistMetadata: json['playlistMetadata'] == null
      ? null
      : PlaylistMetadata.fromJson(
          json['playlistMetadata'] as Map<String, dynamic>,
        ),
  isGroup: json['isGroup'] as bool? ?? false,
);

Map<String, dynamic> _$TagToJson(Tag instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'type': _$TagTypeEnumMap[instance.type]!,
  'parentId': instance.parentId,
  'aliasNames': instance.aliasNames,
  'includeChildren': instance.includeChildren,
  'playlistMetadata': instance.playlistMetadata,
  'isGroup': instance.isGroup,
};

const _$TagTypeEnumMap = {
  TagType.builtIn: 'builtIn',
  TagType.user: 'user',
  TagType.automatic: 'automatic',
};
