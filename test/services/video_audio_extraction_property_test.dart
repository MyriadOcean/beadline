/// Property tests for VideoAudioExtractionService
///
/// **Feature: video-audio-extraction**
/// - Property 1: API origin detection defaults to audio present (Task 3.2)
/// - Property 2: Extracted audio source correctness (Task 3.4)
/// - Property 3: Extracted audio display name pattern (Task 3.4)
/// - Property 4: No extraction when no audio track (Task 3.4)
/// - Property 5: Extraction idempotence (Task 3.6)
library;

import 'package:beadline/models/source.dart';
import 'package:beadline/models/source_collection.dart';
import 'package:beadline/models/source_origin.dart';
import 'package:beadline/services/video_audio_extraction_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import '../models/test_generators.dart';

/// A testable subclass that allows injecting probe results.
/// Used for Property 4 where we need probeForAudioTrack to return false.
class _TestableExtractionService extends VideoAudioExtractionService {
  _TestableExtractionService({required this.probeResult});

  final AudioTrackInfo probeResult;

  @override
  Future<AudioTrackInfo> probeForAudioTrack(SourceOrigin origin) async {
    return probeResult;
  }
}

/// Generate a random video DisplaySource with ApiOrigin.
/// ApiOrigin always returns hasAudioTrack=true without needing real files.
DisplaySource _randomVideoDisplaySourceWithApiOrigin({String? displayName}) {
  const uuid = Uuid();
  return DisplaySource(
    id: uuid.v4(),
    origin: ApiOrigin(
      TestGenerators.randomString(),
      TestGenerators.randomString(),
    ),
    priority: TestGenerators.randomInt(0, 10),
    displayName: displayName,
    displayType: DisplayType.video,
    duration: TestGenerators.randomDuration(),
  );
}

void main() {
  group('VideoAudioExtractionService Property Tests', () {
    late VideoAudioExtractionService service;

    setUp(() {
      service = VideoAudioExtractionService();
    });

    // ========================================================================
    // Feature: video-audio-extraction, Property 1: API origin detection
    // defaults to audio present
    // **Validates: Requirements 1.4**
    // ========================================================================
    test(
      'Property 1: API origin detection defaults to audio present',
      () async {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          final provider = TestGenerators.randomString(
            maxLength: 30,
          );
          final resourceId = TestGenerators.randomString(
            maxLength: 30,
          );
          final apiOrigin = ApiOrigin(provider, resourceId);

          final result = await service.probeForAudioTrack(apiOrigin);

          expect(
            result.hasAudioTrack,
            isTrue,
            reason:
                'Iteration $i: ApiOrigin(provider: "$provider", '
                'resourceId: "$resourceId") should always report '
                'hasAudioTrack = true',
          );

          expect(
            result.format,
            equals(AudioFormat.other),
            reason:
                'Iteration $i: ApiOrigin probe should return '
                'AudioFormat.other as the format',
          );
        }
      },
    );

    // ========================================================================
    // Feature: video-audio-extraction, Property 2: Extracted audio source
    // correctness
    // **Validates: Requirements 2.1, 2.3**
    //
    // For any video DisplaySource with a detected audio track, the created
    // AudioSource SHALL have the same origin as the video AND its
    // linkedVideoSourceId SHALL equal the video's id.
    // ========================================================================
    test(
      'Property 2: Extracted audio source correctness',
      () async {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          final videoSource = _randomVideoDisplaySourceWithApiOrigin(
            displayName: TestGenerators.randomString(maxLength: 30),
          );

          final audioSource = await service.createLinkedAudioSource(videoSource);

          expect(
            audioSource,
            isNotNull,
            reason:
                'Iteration $i: ApiOrigin video should always produce an '
                'extracted AudioSource',
          );

          expect(
            audioSource!.origin,
            equals(videoSource.origin),
            reason:
                'Iteration $i: Extracted AudioSource origin must match '
                'the video DisplaySource origin',
          );

          expect(
            audioSource.linkedVideoSourceId,
            equals(videoSource.id),
            reason:
                'Iteration $i: Extracted AudioSource linkedVideoSourceId '
                'must equal the video DisplaySource id',
          );
        }
      },
    );

    // ========================================================================
    // Feature: video-audio-extraction, Property 3: Extracted audio display
    // name pattern
    // **Validates: Requirements 2.2**
    //
    // For any extracted AudioSource created from a video DisplaySource, the
    // displayName SHALL be non-null and contain a reference to the originating
    // video source's display name or ID.
    // ========================================================================
    test(
      'Property 3: Extracted audio display name pattern',
      () async {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          // Test with displayName set
          final withName = _randomVideoDisplaySourceWithApiOrigin(
            displayName: TestGenerators.randomString(maxLength: 30),
          );

          final audioWithName =
              await service.createLinkedAudioSource(withName);

          expect(
            audioWithName,
            isNotNull,
            reason: 'Iteration $i: Should create AudioSource for video with name',
          );
          expect(
            audioWithName!.displayName,
            isNotNull,
            reason:
                'Iteration $i: Extracted AudioSource displayName must not be null',
          );
          expect(
            audioWithName.displayName!.contains(withName.displayName!),
            isTrue,
            reason:
                'Iteration $i: Extracted AudioSource displayName must '
                'reference the video displayName "${withName.displayName}"',
          );

          // Test with displayName null (should fall back to ID)
          final withoutName = _randomVideoDisplaySourceWithApiOrigin();

          final audioWithoutName =
              await service.createLinkedAudioSource(withoutName);

          expect(
            audioWithoutName,
            isNotNull,
            reason:
                'Iteration $i: Should create AudioSource for video without name',
          );
          expect(
            audioWithoutName!.displayName,
            isNotNull,
            reason:
                'Iteration $i: Extracted AudioSource displayName must not '
                'be null even when video has no displayName',
          );
          expect(
            audioWithoutName.displayName!.contains(withoutName.id),
            isTrue,
            reason:
                'Iteration $i: When video has no displayName, extracted '
                'AudioSource displayName must reference the video ID',
          );
        }
      },
    );

    // ========================================================================
    // Feature: video-audio-extraction, Property 4: No extraction when no
    // audio track
    // **Validates: Requirements 2.4**
    //
    // For any video DisplaySource where the probe returns hasAudioTrack=false,
    // createLinkedAudioSource SHALL return null.
    // ========================================================================
    test(
      'Property 4: No extraction when no audio track',
      () async {
        const iterations = 100;

        final noAudioService = _TestableExtractionService(
          probeResult: const AudioTrackInfo(
            hasAudioTrack: false,
            format: AudioFormat.other,
          ),
        );

        for (var i = 0; i < iterations; i++) {
          // Generate video sources with various origin types
          final origins = <SourceOrigin>[
            ApiOrigin(
              TestGenerators.randomString(),
              TestGenerators.randomString(),
            ),
            LocalFileOrigin('/path/to/${TestGenerators.randomString()}.mp4'),
            UrlOrigin(
              'https://example.com/${TestGenerators.randomString()}.mp4',
            ),
          ];

          final origin = origins[i % origins.length];

          final videoSource = DisplaySource(
            id: const Uuid().v4(),
            origin: origin,
            priority: TestGenerators.randomInt(0, 10),
            displayName: TestGenerators.randomString(maxLength: 30),
            displayType: DisplayType.video,
            duration: TestGenerators.randomDuration(),
          );

          final result =
              await noAudioService.createLinkedAudioSource(videoSource);

          expect(
            result,
            isNull,
            reason:
                'Iteration $i: When probe returns hasAudioTrack=false, '
                'createLinkedAudioSource must return null '
                '(origin type: ${origin.runtimeType})',
          );
        }
      },
    );

    // ========================================================================
    // Feature: video-audio-extraction, Property 5: Extraction idempotence
    // **Validates: Requirements 2.5**
    //
    // For any video DisplaySource, calling createLinkedAudioSourceIfNeeded
    // twice on the same SourceCollection SHALL result in exactly one linked
    // AudioSource for that video — the second call SHALL not create a
    // duplicate.
    // ========================================================================
    test(
      'Property 5: Extraction idempotence',
      () async {
        const iterations = 100;

        // Use a testable service that always reports audio present,
        // so we can test idempotence without needing real media files.
        final idempotentService = _TestableExtractionService(
          probeResult: const AudioTrackInfo(
            hasAudioTrack: true,
            format: AudioFormat.other,
          ),
        );

        for (var i = 0; i < iterations; i++) {
          // 1. Generate a random video DisplaySource with ApiOrigin
          final videoSource = _randomVideoDisplaySourceWithApiOrigin(
            displayName: TestGenerators.randomString(maxLength: 30),
          );

          // 2. Create an initial SourceCollection (optionally with some
          //    pre-existing unrelated audio sources)
          final preExistingAudio = List.generate(
            TestGenerators.randomInt(0, 3),
            (j) => TestGenerators.randomAudioSource(priority: j),
          );
          var collection = SourceCollection(
            displaySources: [videoSource],
            audioSources: preExistingAudio,
          );

          // 3. First call — should create a new linked AudioSource
          final firstResult =
              await idempotentService.createLinkedAudioSourceIfNeeded(
            videoSource,
            collection,
          );

          expect(
            firstResult,
            isNotNull,
            reason:
                'Iteration $i: First call should create a linked AudioSource',
          );
          expect(
            firstResult!.linkedVideoSourceId,
            equals(videoSource.id),
            reason:
                'Iteration $i: Created AudioSource must link to the video',
          );

          // 4. Add the newly created AudioSource to the collection
          collection = collection.copyWith(
            audioSources: [...collection.audioSources, firstResult],
          );

          // 5. Second call — should return the existing one, not create new
          final secondResult =
              await idempotentService.createLinkedAudioSourceIfNeeded(
            videoSource,
            collection,
          );

          expect(
            secondResult,
            isNotNull,
            reason:
                'Iteration $i: Second call should return existing AudioSource',
          );
          expect(
            secondResult!.id,
            equals(firstResult.id),
            reason:
                'Iteration $i: Second call must return the same AudioSource '
                '(same id) as the first call, not a new one',
          );

          // 6. Verify the collection still has exactly one linked AudioSource
          //    for this video
          final linkedCount = collection.audioSources
              .where((a) => a.linkedVideoSourceId == videoSource.id)
              .length;
          expect(
            linkedCount,
            equals(1),
            reason:
                'Iteration $i: Collection must contain exactly one linked '
                'AudioSource for video ${videoSource.id}, found $linkedCount',
          );
        }
      },
    );
  });
}
