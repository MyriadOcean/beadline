// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppSettings _$AppSettingsFromJson(Map<String, dynamic> json) => AppSettings(
  libraryPath: json['libraryPath'] as String,
  metadataWriteBack: json['metadataWriteBack'] as bool? ?? false,
  lyricsMode:
      $enumDecodeNullable(_$LyricsModeEnumMap, json['lyricsMode']) ??
      LyricsMode.off,
  displayMode:
      $enumDecodeNullable(_$DisplayModeEnumMap, json['displayMode']) ??
      DisplayMode.enabled,
  ktvMode: json['ktvMode'] as bool? ?? false,
  hideDisplayPanel: json['hideDisplayPanel'] as bool? ?? false,
  themeMode: json['themeMode'] as String? ?? 'system',
  languageCode: json['languageCode'] as String?,
  username: json['username'] as String? ?? 'User',
  primaryColorSeed: (json['primaryColorSeed'] as num?)?.toInt(),
  configMode:
      $enumDecodeNullable(_$ConfigurationModeEnumMap, json['configMode']) ??
      ConfigurationMode.centralized,
  libraryLocations:
      (json['libraryLocations'] as List<dynamic>?)
          ?.map((e) => LibraryLocation.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  isConfigured: json['isConfigured'] as bool? ?? false,
  useThumbnailBackgroundInQueue:
      json['useThumbnailBackgroundInQueue'] as bool? ?? false,
  useThumbnailBackgroundInLibrary:
      json['useThumbnailBackgroundInLibrary'] as bool? ?? false,
  onlineProviders:
      (json['onlineProviders'] as List<dynamic>?)
          ?.map((e) => OnlineProviderConfig.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  autoDiscoverAudioFiles: json['autoDiscoverAudioFiles'] as bool? ?? false,
  activeQueueId: json['activeQueueId'] as String?,
  nameAutoSearch: json['nameAutoSearch'] as bool? ?? true,
);

Map<String, dynamic> _$AppSettingsToJson(
  AppSettings instance,
) => <String, dynamic>{
  'libraryPath': instance.libraryPath,
  'metadataWriteBack': instance.metadataWriteBack,
  'lyricsMode': instance.lyricsMode.toJson(),
  'displayMode': instance.displayMode.toJson(),
  'ktvMode': instance.ktvMode,
  'hideDisplayPanel': instance.hideDisplayPanel,
  'themeMode': instance.themeMode,
  'languageCode': instance.languageCode,
  'username': instance.username,
  'primaryColorSeed': instance.primaryColorSeed,
  'configMode': instance.configMode.toJson(),
  'libraryLocations': instance.libraryLocations.map((e) => e.toJson()).toList(),
  'isConfigured': instance.isConfigured,
  'useThumbnailBackgroundInQueue': instance.useThumbnailBackgroundInQueue,
  'useThumbnailBackgroundInLibrary': instance.useThumbnailBackgroundInLibrary,
  'onlineProviders': instance.onlineProviders.map((e) => e.toJson()).toList(),
  'autoDiscoverAudioFiles': instance.autoDiscoverAudioFiles,
  'activeQueueId': instance.activeQueueId,
  'nameAutoSearch': instance.nameAutoSearch,
};

const _$LyricsModeEnumMap = {
  LyricsMode.off: 'off',
  LyricsMode.screen: 'screen',
  LyricsMode.floating: 'floating',
  LyricsMode.rolling: 'rolling',
};

const _$DisplayModeEnumMap = {
  DisplayMode.enabled: 'enabled',
  DisplayMode.imageOnly: 'imageOnly',
  DisplayMode.disabled: 'disabled',
  DisplayMode.hidden: 'hidden',
};

const _$ConfigurationModeEnumMap = {
  ConfigurationMode.centralized: 'centralized',
  ConfigurationMode.inPlace: 'inPlace',
};
