/// Task 1.4: Unit tests for SourceCollection video-audio extension methods
///
/// Tests for `getLinkedAudioSource`, `getLinkedVideoSource`, and
/// `hasLinkedAudioSource` on `SourceCollectionVideoAudio`.
///
/// **Validates: Requirements 2.5, 4.3**
library;

import 'package:beadline/models/source.dart';
import 'package:beadline/models/source_collection.dart';
import 'package:beadline/models/source_origin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Shared fixtures
  const videoOrigin = LocalFileOrigin('/videos/concert.mp4');
  const audioOrigin = LocalFileOrigin('/audio/track.mp3');

  const videoSource = DisplaySource(
    id: 'video-1',
    origin: videoOrigin,
    priority: 0,
    displayType: DisplayType.video,
    displayName: 'Concert Video',
  );

  const linkedAudio = AudioSource(
    id: 'audio-linked-1',
    origin: videoOrigin,
    priority: 1,
    format: AudioFormat.other,
    displayName: 'Audio from Concert Video',
    linkedVideoSourceId: 'video-1',
  );

  const unlinkedAudio = AudioSource(
    id: 'audio-standalone',
    origin: audioOrigin,
    priority: 0,
    format: AudioFormat.mp3,
    displayName: 'Standalone Track',
  );

  group('getLinkedAudioSource', () {
    test('returns the linked AudioSource when one exists', () {
      const collection = SourceCollection(
        displaySources: [videoSource],
        audioSources: [unlinkedAudio, linkedAudio],
      );

      final result = collection.getLinkedAudioSource('video-1');

      expect(result, isNotNull);
      expect(result!.id, equals('audio-linked-1'));
      expect(result.linkedVideoSourceId, equals('video-1'));
    });

    test('returns null when no linked AudioSource exists', () {
      const collection = SourceCollection(
        displaySources: [videoSource],
        audioSources: [unlinkedAudio],
      );

      final result = collection.getLinkedAudioSource('video-1');

      expect(result, isNull);
    });

    test('returns null when audioSources is empty', () {
      const collection = SourceCollection(
        displaySources: [videoSource],
      );

      final result = collection.getLinkedAudioSource('video-1');

      expect(result, isNull);
    });

    test('returns null for a non-existent video ID', () {
      const collection = SourceCollection(
        audioSources: [linkedAudio],
      );

      final result = collection.getLinkedAudioSource('video-nonexistent');

      expect(result, isNull);
    });
  });

  group('getLinkedVideoSource', () {
    test('returns the video DisplaySource when audio has a link', () {
      const collection = SourceCollection(
        displaySources: [videoSource],
        audioSources: [linkedAudio],
      );

      final result = collection.getLinkedVideoSource('audio-linked-1');

      expect(result, isNotNull);
      expect(result!.id, equals('video-1'));
      expect(result.displayType, equals(DisplayType.video));
    });

    test('returns null when audio source has no linkedVideoSourceId', () {
      const collection = SourceCollection(
        displaySources: [videoSource],
        audioSources: [unlinkedAudio],
      );

      final result = collection.getLinkedVideoSource('audio-standalone');

      expect(result, isNull);
    });

    test('returns null when audio source is not found', () {
      const collection = SourceCollection(
        displaySources: [videoSource],
        audioSources: [linkedAudio],
      );

      final result = collection.getLinkedVideoSource('audio-nonexistent');

      expect(result, isNull);
    });

    test('returns null when linked video is not in displaySources', () {
      // Audio references a video ID that doesn't exist in the collection
      const orphanedAudio = AudioSource(
        id: 'audio-orphan',
        origin: videoOrigin,
        priority: 0,
        format: AudioFormat.other,
        linkedVideoSourceId: 'video-deleted',
      );

      const collection = SourceCollection(
        displaySources: [videoSource], // only has 'video-1'
        audioSources: [orphanedAudio],
      );

      final result = collection.getLinkedVideoSource('audio-orphan');

      expect(result, isNull);
    });
  });

  group('hasLinkedAudioSource', () {
    test('returns true when a linked AudioSource exists', () {
      const collection = SourceCollection(
        displaySources: [videoSource],
        audioSources: [linkedAudio, unlinkedAudio],
      );

      expect(collection.hasLinkedAudioSource('video-1'), isTrue);
    });

    test('returns false when no linked AudioSource exists', () {
      const collection = SourceCollection(
        displaySources: [videoSource],
        audioSources: [unlinkedAudio],
      );

      expect(collection.hasLinkedAudioSource('video-1'), isFalse);
    });

    test('returns false for empty audio sources', () {
      const collection = SourceCollection(
        displaySources: [videoSource],
      );

      expect(collection.hasLinkedAudioSource('video-1'), isFalse);
    });

    test('returns false for non-existent video ID', () {
      const collection = SourceCollection(
        audioSources: [linkedAudio],
      );

      expect(collection.hasLinkedAudioSource('video-999'), isFalse);
    });
  });
}
