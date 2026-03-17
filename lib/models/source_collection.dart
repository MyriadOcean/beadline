import 'package:json_annotation/json_annotation.dart';
import 'source.dart';

part 'source_collection.g.dart';

/// Collection of sources for a Song Unit
@JsonSerializable(explicitToJson: true)
class SourceCollection {
  const SourceCollection({
    this.displaySources = const [],
    this.audioSources = const [],
    this.accompanimentSources = const [],
    this.hoverSources = const [],
  });

  factory SourceCollection.fromJson(Map<String, dynamic> json) =>
      _$SourceCollectionFromJson(json);
  final List<DisplaySource> displaySources;
  final List<AudioSource> audioSources;
  final List<AccompanimentSource> accompanimentSources;
  final List<HoverSource> hoverSources;

  Map<String, dynamic> toJson() => _$SourceCollectionToJson(this);

  /// Get the active source of a given type based on priority
  /// Returns the source with the lowest priority number (highest priority)
  Source? getActiveSource(SourceType type) {
    List<Source> sources;
    switch (type) {
      case SourceType.display:
        sources = displaySources;
        break;
      case SourceType.audio:
        sources = audioSources;
        break;
      case SourceType.accompaniment:
        sources = accompanimentSources;
        break;
      case SourceType.hover:
        sources = hoverSources;
        break;
    }

    if (sources.isEmpty) return null;

    // Sort by priority (lower number = higher priority)
    final sortedSources = List<Source>.from(sources)
      ..sort((a, b) => a.priority.compareTo(b.priority));

    return sortedSources.first;
  }

  /// Get all sources as a flat list
  List<Source> getAllSources() {
    return [
      ...displaySources,
      ...audioSources,
      ...accompanimentSources,
      ...hoverSources,
    ];
  }

  SourceCollection copyWith({
    List<DisplaySource>? displaySources,
    List<AudioSource>? audioSources,
    List<AccompanimentSource>? accompanimentSources,
    List<HoverSource>? hoverSources,
  }) {
    return SourceCollection(
      displaySources: displaySources ?? this.displaySources,
      audioSources: audioSources ?? this.audioSources,
      accompanimentSources: accompanimentSources ?? this.accompanimentSources,
      hoverSources: hoverSources ?? this.hoverSources,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SourceCollection &&
          runtimeType == other.runtimeType &&
          _listEquals(displaySources, other.displaySources) &&
          _listEquals(audioSources, other.audioSources) &&
          _listEquals(accompanimentSources, other.accompanimentSources) &&
          _listEquals(hoverSources, other.hoverSources);

  @override
  int get hashCode =>
      displaySources.hashCode ^
      audioSources.hashCode ^
      accompanimentSources.hashCode ^
      hoverSources.hashCode;

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Extension methods for querying video-audio links in a SourceCollection.
extension SourceCollectionVideoAudio on SourceCollection {
  /// Find the extracted AudioSource linked to a given video DisplaySource ID.
  /// Returns null if no linked AudioSource exists.
  AudioSource? getLinkedAudioSource(String videoSourceId) {
    for (final audio in audioSources) {
      if (audio.linkedVideoSourceId == videoSourceId) {
        return audio;
      }
    }
    return null;
  }

  /// Find the video DisplaySource that a given AudioSource was extracted from.
  /// Looks up the AudioSource by [audioSourceId], reads its linkedVideoSourceId,
  /// then finds the DisplaySource with that ID.
  /// Returns null if the audio source is not found, has no link, or the video
  /// source is not found.
  DisplaySource? getLinkedVideoSource(String audioSourceId) {
    // Find the audio source
    AudioSource? audioSource;
    for (final audio in audioSources) {
      if (audio.id == audioSourceId) {
        audioSource = audio;
        break;
      }
    }
    if (audioSource == null || audioSource.linkedVideoSourceId == null) {
      return null;
    }

    // Find the video display source
    for (final display in displaySources) {
      if (display.id == audioSource.linkedVideoSourceId) {
        return display;
      }
    }
    return null;
  }

  /// Check if an extracted AudioSource already exists for a given video
  /// DisplaySource ID.
  bool hasLinkedAudioSource(String videoSourceId) {
    return getLinkedAudioSource(videoSourceId) != null;
  }
}
