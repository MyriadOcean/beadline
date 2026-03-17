import 'package:json_annotation/json_annotation.dart';

part 'playback_preferences.g.dart';

/// Playback preferences for a Song Unit
@JsonSerializable()
class PlaybackPreferences {
  const PlaybackPreferences({
    this.preferAccompaniment = false,
    this.preferredDisplaySourceId,
    this.preferredAudioSourceId,
    this.preferredAccompanimentSourceId,
    this.preferredHoverSourceId,
  });

  factory PlaybackPreferences.fromJson(Map<String, dynamic> json) =>
      _$PlaybackPreferencesFromJson(json);

  factory PlaybackPreferences.defaults() {
    return const PlaybackPreferences();
  }

  /// Whether to prefer accompaniment over audio source
  final bool preferAccompaniment;

  /// ID of the preferred display source (video/image)
  final String? preferredDisplaySourceId;

  /// ID of the preferred audio source
  final String? preferredAudioSourceId;

  /// ID of the preferred accompaniment source
  final String? preferredAccompanimentSourceId;

  /// ID of the preferred hover source (lyrics)
  final String? preferredHoverSourceId;

  Map<String, dynamic> toJson() => _$PlaybackPreferencesToJson(this);

  PlaybackPreferences copyWith({
    bool? preferAccompaniment,
    String? preferredDisplaySourceId,
    String? preferredAudioSourceId,
    String? preferredAccompanimentSourceId,
    String? preferredHoverSourceId,
    bool clearDisplaySourceId = false,
    bool clearAudioSourceId = false,
    bool clearAccompanimentSourceId = false,
    bool clearHoverSourceId = false,
  }) {
    return PlaybackPreferences(
      preferAccompaniment: preferAccompaniment ?? this.preferAccompaniment,
      preferredDisplaySourceId: clearDisplaySourceId
          ? null
          : (preferredDisplaySourceId ?? this.preferredDisplaySourceId),
      preferredAudioSourceId: clearAudioSourceId
          ? null
          : (preferredAudioSourceId ?? this.preferredAudioSourceId),
      preferredAccompanimentSourceId: clearAccompanimentSourceId
          ? null
          : (preferredAccompanimentSourceId ??
                this.preferredAccompanimentSourceId),
      preferredHoverSourceId: clearHoverSourceId
          ? null
          : (preferredHoverSourceId ?? this.preferredHoverSourceId),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaybackPreferences &&
          runtimeType == other.runtimeType &&
          preferAccompaniment == other.preferAccompaniment &&
          preferredDisplaySourceId == other.preferredDisplaySourceId &&
          preferredAudioSourceId == other.preferredAudioSourceId &&
          preferredAccompanimentSourceId ==
              other.preferredAccompanimentSourceId &&
          preferredHoverSourceId == other.preferredHoverSourceId;

  @override
  int get hashCode =>
      preferAccompaniment.hashCode ^
      preferredDisplaySourceId.hashCode ^
      preferredAudioSourceId.hashCode ^
      preferredAccompanimentSourceId.hashCode ^
      preferredHoverSourceId.hashCode;
}
