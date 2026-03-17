import 'package:json_annotation/json_annotation.dart';
import 'source_origin.dart';

part 'source.g.dart';

/// Source type enumeration
enum SourceType { display, audio, accompaniment, hover }

/// Display type for display sources
enum DisplayType { video, image }

/// Audio format enumeration
enum AudioFormat { mp3, flac, wav, aac, ogg, m4a, other }

/// Lyrics format enumeration
enum LyricsFormat { lrc }

/// Abstract base class for all sources
abstract class Source {
  const Source({
    required this.id,
    required this.origin,
    required this.priority,
    this.displayName,
  });

  factory Source.fromJson(Map<String, dynamic> json) {
    final type = json['sourceType'] as String;
    switch (type) {
      case 'display':
        return DisplaySource.fromJson(json);
      case 'audio':
        return AudioSource.fromJson(json);
      case 'accompaniment':
        return AccompanimentSource.fromJson(json);
      case 'hover':
        return HoverSource.fromJson(json);
      default:
        throw ArgumentError('Unknown Source type: $type');
    }
  }
  final String id;
  final SourceOrigin origin;
  final int priority;

  /// Optional display name for this source (shown in UI instead of file path)
  final String? displayName;

  /// Get the duration of this source (if available)
  Duration? getDuration();

  /// Get the source type
  SourceType get sourceType;

  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Source &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          origin == other.origin &&
          priority == other.priority &&
          displayName == other.displayName;

  @override
  int get hashCode =>
      id.hashCode ^ origin.hashCode ^ priority.hashCode ^ displayName.hashCode;
}

/// Display source (video or image)
@JsonSerializable(explicitToJson: true)
class DisplaySource extends Source {
  const DisplaySource({
    required super.id,
    required super.origin,
    required super.priority,
    super.displayName,
    required this.displayType,
    this.duration,
    this.offset = Duration.zero,
  });

  factory DisplaySource.fromJson(Map<String, dynamic> json) =>
      _$DisplaySourceFromJson(json);
  final DisplayType displayType;
  final Duration? duration;

  /// Offset to align with audio source (positive = delay, negative = advance)
  final Duration offset;

  @override
  Map<String, dynamic> toJson() => {
    'sourceType': 'display',
    ..._$DisplaySourceToJson(this),
  };

  @override
  Duration? getDuration() => duration;

  @override
  SourceType get sourceType => SourceType.display;

  DisplaySource copyWith({
    String? id,
    SourceOrigin? origin,
    int? priority,
    String? displayName,
    DisplayType? displayType,
    Duration? duration,
    Duration? offset,
  }) {
    return DisplaySource(
      id: id ?? this.id,
      origin: origin ?? this.origin,
      priority: priority ?? this.priority,
      displayName: displayName ?? this.displayName,
      displayType: displayType ?? this.displayType,
      duration: duration ?? this.duration,
      offset: offset ?? this.offset,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is DisplaySource &&
          displayType == other.displayType &&
          duration == other.duration &&
          offset == other.offset;

  @override
  int get hashCode =>
      super.hashCode ^
      displayType.hashCode ^
      duration.hashCode ^
      offset.hashCode;
}

/// Audio source
@JsonSerializable(explicitToJson: true)
class AudioSource extends Source {
  const AudioSource({
    required super.id,
    required super.origin,
    required super.priority,
    super.displayName,
    required this.format,
    this.duration,
    this.offset = Duration.zero,
    this.linkedVideoSourceId,
  });

  factory AudioSource.fromJson(Map<String, dynamic> json) =>
      _$AudioSourceFromJson(json);
  final AudioFormat format;
  final Duration? duration;

  /// Offset to align with the logical timeline (positive = delay, negative = advance)
  /// For example, if an alternative audio source starts 5 seconds earlier than the main audio,
  /// set offset to -5000ms so it syncs correctly with the timeline
  final Duration offset;

  /// ID of the video DisplaySource this audio was extracted from.
  /// Null for manually added audio sources.
  final String? linkedVideoSourceId;

  @override
  Map<String, dynamic> toJson() => {
    'sourceType': 'audio',
    ..._$AudioSourceToJson(this),
  };

  @override
  Duration? getDuration() => duration;

  @override
  SourceType get sourceType => SourceType.audio;

  AudioSource copyWith({
    String? id,
    SourceOrigin? origin,
    int? priority,
    String? displayName,
    AudioFormat? format,
    Duration? duration,
    Duration? offset,
    String? linkedVideoSourceId,
  }) {
    return AudioSource(
      id: id ?? this.id,
      origin: origin ?? this.origin,
      priority: priority ?? this.priority,
      displayName: displayName ?? this.displayName,
      format: format ?? this.format,
      duration: duration ?? this.duration,
      offset: offset ?? this.offset,
      linkedVideoSourceId: linkedVideoSourceId ?? this.linkedVideoSourceId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is AudioSource &&
          format == other.format &&
          duration == other.duration &&
          offset == other.offset &&
          linkedVideoSourceId == other.linkedVideoSourceId;

  @override
  int get hashCode =>
      super.hashCode ^
      format.hashCode ^
      duration.hashCode ^
      offset.hashCode ^
      linkedVideoSourceId.hashCode;
}

/// Accompaniment source (mutually exclusive with audio)
@JsonSerializable(explicitToJson: true)
class AccompanimentSource extends Source {
  const AccompanimentSource({
    required super.id,
    required super.origin,
    required super.priority,
    super.displayName,
    required this.format,
    this.duration,
    this.offset = Duration.zero,
  });

  factory AccompanimentSource.fromJson(Map<String, dynamic> json) =>
      _$AccompanimentSourceFromJson(json);
  final AudioFormat format;
  final Duration? duration;

  /// Offset to align with audio source (positive = delay, negative = advance)
  final Duration offset;

  @override
  Map<String, dynamic> toJson() => {
    'sourceType': 'accompaniment',
    ..._$AccompanimentSourceToJson(this),
  };

  @override
  Duration? getDuration() => duration;

  @override
  SourceType get sourceType => SourceType.accompaniment;

  AccompanimentSource copyWith({
    String? id,
    SourceOrigin? origin,
    int? priority,
    String? displayName,
    AudioFormat? format,
    Duration? duration,
    Duration? offset,
  }) {
    return AccompanimentSource(
      id: id ?? this.id,
      origin: origin ?? this.origin,
      priority: priority ?? this.priority,
      displayName: displayName ?? this.displayName,
      format: format ?? this.format,
      duration: duration ?? this.duration,
      offset: offset ?? this.offset,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is AccompanimentSource &&
          format == other.format &&
          duration == other.duration &&
          offset == other.offset;

  @override
  int get hashCode =>
      super.hashCode ^ format.hashCode ^ duration.hashCode ^ offset.hashCode;
}

/// Hover source (lyrics)
@JsonSerializable(explicitToJson: true)
class HoverSource extends Source {
  const HoverSource({
    required super.id,
    required super.origin,
    required super.priority,
    super.displayName,
    required this.format,
    this.offset = Duration.zero,
  });

  factory HoverSource.fromJson(Map<String, dynamic> json) =>
      _$HoverSourceFromJson(json);
  final LyricsFormat format;

  /// Offset to align lyrics with audio source (positive = delay, negative = advance)
  final Duration offset;

  @override
  Map<String, dynamic> toJson() => {
    'sourceType': 'hover',
    ..._$HoverSourceToJson(this),
  };

  @override
  Duration? getDuration() => null;

  @override
  SourceType get sourceType => SourceType.hover;

  HoverSource copyWith({
    String? id,
    SourceOrigin? origin,
    int? priority,
    String? displayName,
    LyricsFormat? format,
    Duration? offset,
  }) {
    return HoverSource(
      id: id ?? this.id,
      origin: origin ?? this.origin,
      priority: priority ?? this.priority,
      displayName: displayName ?? this.displayName,
      format: format ?? this.format,
      offset: offset ?? this.offset,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is HoverSource &&
          format == other.format &&
          offset == other.offset;

  @override
  int get hashCode => super.hashCode ^ format.hashCode ^ offset.hashCode;
}
