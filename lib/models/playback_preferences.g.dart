// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playback_preferences.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PlaybackPreferences _$PlaybackPreferencesFromJson(Map<String, dynamic> json) =>
    PlaybackPreferences(
      preferAccompaniment: json['preferAccompaniment'] as bool? ?? false,
      preferredDisplaySourceId: json['preferredDisplaySourceId'] as String?,
      preferredAudioSourceId: json['preferredAudioSourceId'] as String?,
      preferredAccompanimentSourceId:
          json['preferredAccompanimentSourceId'] as String?,
      preferredHoverSourceId: json['preferredHoverSourceId'] as String?,
    );

Map<String, dynamic> _$PlaybackPreferencesToJson(
  PlaybackPreferences instance,
) => <String, dynamic>{
  'preferAccompaniment': instance.preferAccompaniment,
  'preferredDisplaySourceId': instance.preferredDisplaySourceId,
  'preferredAudioSourceId': instance.preferredAudioSourceId,
  'preferredAccompanimentSourceId': instance.preferredAccompanimentSourceId,
  'preferredHoverSourceId': instance.preferredHoverSourceId,
};
