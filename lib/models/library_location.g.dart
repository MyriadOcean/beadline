// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_location.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LibraryLocation _$LibraryLocationFromJson(Map<String, dynamic> json) =>
    LibraryLocation(
      id: json['id'] as String,
      name: json['name'] as String,
      rootPath: json['rootPath'] as String,
      isDefault: json['isDefault'] as bool? ?? false,
      addedAt: DateTime.parse(json['addedAt'] as String),
      configMode: $enumDecodeNullable(
        _$ConfigurationModeEnumMap,
        json['configMode'],
      ),
    );

Map<String, dynamic> _$LibraryLocationToJson(LibraryLocation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'rootPath': instance.rootPath,
      'isDefault': instance.isDefault,
      'addedAt': instance.addedAt.toIso8601String(),
      'configMode': instance.configMode,
    };

const _$ConfigurationModeEnumMap = {
  ConfigurationMode.centralized: 'centralized',
  ConfigurationMode.inPlace: 'inPlace',
};
