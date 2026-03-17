import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:uuid/uuid.dart';

import '../models/source.dart';
import '../models/source_collection.dart';
import '../models/source_origin.dart';

/// Information about an audio track detected in a video source.
class AudioTrackInfo {
  const AudioTrackInfo({
    required this.hasAudioTrack,
    this.duration,
    required this.format,
  });

  /// Whether the video contains an audio track.
  final bool hasAudioTrack;

  /// Duration of the audio track, if available.
  final Duration? duration;

  /// Detected audio format.
  final AudioFormat format;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioTrackInfo &&
          runtimeType == other.runtimeType &&
          hasAudioTrack == other.hasAudioTrack &&
          duration == other.duration &&
          format == other.format;

  @override
  int get hashCode =>
      hasAudioTrack.hashCode ^ duration.hashCode ^ format.hashCode;

  @override
  String toString() =>
      'AudioTrackInfo(hasAudioTrack: $hasAudioTrack, duration: $duration, format: $format)';
}

/// Service responsible for probing video files for audio tracks
/// and creating linked AudioSources.
class VideoAudioExtractionService {
  static const _uuid = Uuid();
  /// Probe a video source's origin to detect audio tracks.
  ///
  /// - For [LocalFileOrigin]: uses media_kit Player to open and inspect track list.
  /// - For [UrlOrigin]: same approach via media_kit (supports http/https).
  /// - For [ApiOrigin]: assumes audio present (cannot probe remotely).
  /// - On any failure: assumes audio present and logs a warning (fail-safe).
  Future<AudioTrackInfo> probeForAudioTrack(SourceOrigin origin) async {
    if (origin is ApiOrigin) {
      return const AudioTrackInfo(
        hasAudioTrack: true,
        format: AudioFormat.other,
      );
    }

    final String mediaPath;
    if (origin is LocalFileOrigin) {
      mediaPath = origin.path;
    } else if (origin is UrlOrigin) {
      mediaPath = origin.url;
    } else {
      // Unknown origin type — fail-safe: assume audio present
      if (kDebugMode) {
        debugPrint(
          'VideoAudioExtractionService: Unknown origin type, assuming audio present',
        );
      }
      return const AudioTrackInfo(
        hasAudioTrack: true,
        format: AudioFormat.other,
      );
    }

    final player = mk.Player();
    try {
      await player.open(mk.Media(mediaPath), play: false);

      // Wait briefly for track info to populate
      final audioTracks = await player.stream.tracks.first.timeout(
        const Duration(seconds: 5),
        onTimeout: () => player.state.tracks,
      );

      final hasAudio = audioTracks.audio.length > 1 ||
          (audioTracks.audio.isNotEmpty &&
              audioTracks.audio.any((t) => t.id != 'auto'));

      final duration = player.state.duration != Duration.zero
          ? player.state.duration
          : null;

      return AudioTrackInfo(
        hasAudioTrack: hasAudio,
        duration: duration,
        format: AudioFormat.other,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'VideoAudioExtractionService: Failed to probe $mediaPath for audio tracks: $e',
        );
      }
      // Fail-safe: assume audio is present
      return const AudioTrackInfo(
        hasAudioTrack: true,
        format: AudioFormat.other,
      );
    } finally {
      await player.dispose();
    }
  }

  /// Create a linked AudioSource from a video DisplaySource.
  ///
  /// Probes the video for an audio track. If found, creates an [AudioSource]
  /// sharing the same origin with [linkedVideoSourceId] pointing back to the
  /// video. Returns `null` if no audio track is detected.
  Future<AudioSource?> createLinkedAudioSource(
      DisplaySource videoSource) async {
    final probeResult = await probeForAudioTrack(videoSource.origin);

    if (!probeResult.hasAudioTrack) {
      return null;
    }

    final label = videoSource.displayName ?? videoSource.id;

    return AudioSource(
      id: _uuid.v4(),
      origin: videoSource.origin,
      priority: 0,
      displayName: 'Audio from $label',
      format: AudioFormat.other,
      duration: probeResult.duration,
      linkedVideoSourceId: videoSource.id,
    );
  }

  /// Create a linked AudioSource only if one does not already exist for the
  /// given video source in the provided [collection].
  ///
  /// This is the idempotent entry point: calling it multiple times for the
  /// same video source and collection will never produce duplicates.
  /// Returns the existing linked AudioSource if one is found, the newly
  /// created one if extraction succeeds, or `null` if no audio track is
  /// detected.
  Future<AudioSource?> createLinkedAudioSourceIfNeeded(
    DisplaySource videoSource,
    SourceCollection collection,
  ) async {
    final existing = collection.getLinkedAudioSource(videoSource.id);
    if (existing != null) {
      return existing;
    }
    return createLinkedAudioSource(videoSource);
  }

  /// Re-probe a video source after its origin has changed.
  ///
  /// Returns an updated [SourceCollection] with the linked AudioSource
  /// updated, created, or removed as appropriate:
  /// - Audio found + linked audio exists → update linked audio's origin
  /// - Audio found + no linked audio → create new linked AudioSource
  /// - No audio + linked audio exists → remove linked AudioSource
  /// - No audio + no linked audio → no change
  Future<SourceCollection> handleVideoOriginChange(
    DisplaySource updatedVideoSource,
    SourceCollection collection,
  ) async {
    final existingLinkedAudio =
        collection.getLinkedAudioSource(updatedVideoSource.id);
    final probeResult = await probeForAudioTrack(updatedVideoSource.origin);

    if (probeResult.hasAudioTrack && existingLinkedAudio != null) {
      // Audio found AND linked audio exists: update origin and display name
      final label = updatedVideoSource.displayName ?? updatedVideoSource.id;
      final updatedAudio = AudioSource(
        id: existingLinkedAudio.id,
        origin: updatedVideoSource.origin,
        priority: existingLinkedAudio.priority,
        displayName: 'Audio from $label',
        format: existingLinkedAudio.format,
        duration: probeResult.duration,
        offset: existingLinkedAudio.offset,
        linkedVideoSourceId: existingLinkedAudio.linkedVideoSourceId,
      );
      final updatedAudioSources = collection.audioSources
          .map((a) => a.id == existingLinkedAudio.id ? updatedAudio : a)
          .toList();
      return collection.copyWith(audioSources: updatedAudioSources);
    }

    if (probeResult.hasAudioTrack && existingLinkedAudio == null) {
      // Audio found AND no linked audio: create new linked AudioSource
      final label = updatedVideoSource.displayName ?? updatedVideoSource.id;
      final newAudio = AudioSource(
        id: _uuid.v4(),
        origin: updatedVideoSource.origin,
        priority: collection.audioSources.length,
        displayName: 'Audio from $label',
        format: AudioFormat.other,
        duration: probeResult.duration,
        linkedVideoSourceId: updatedVideoSource.id,
      );
      return collection.copyWith(
        audioSources: [...collection.audioSources, newAudio],
      );
    }

    if (!probeResult.hasAudioTrack && existingLinkedAudio != null) {
      // No audio AND linked audio exists: remove it
      final updatedAudioSources = collection.audioSources
          .where((a) => a.id != existingLinkedAudio.id)
          .toList();
      return collection.copyWith(audioSources: updatedAudioSources);
    }

    // No audio AND no linked audio: no change
    return collection;
  }
}
