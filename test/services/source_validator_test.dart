import 'dart:math';
import 'package:beadline/models/source.dart';
import 'package:beadline/models/source_origin.dart';
import 'package:beadline/services/source_validator.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test generators for source validation property tests
class SourceValidatorTestGenerators {
  static final Random _random = Random();

  static String randomString({int minLength = 1, int maxLength = 20}) {
    final length = minLength + _random.nextInt(maxLength - minLength + 1);
    const chars = 'abcdefghijklmnopqrstuvwxyz';
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => chars.codeUnitAt(_random.nextInt(chars.length)),
      ),
    );
  }

  /// Generate a random valid video extension
  static String randomVideoExtension() {
    const extensions = ['mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm'];
    return extensions[_random.nextInt(extensions.length)];
  }

  /// Generate a random valid audio extension
  static String randomAudioExtension() {
    const extensions = ['mp3', 'flac', 'wav', 'aac', 'ogg', 'm4a'];
    return extensions[_random.nextInt(extensions.length)];
  }

  /// Generate a random valid image extension
  static String randomImageExtension() {
    const extensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'];
    return extensions[_random.nextInt(extensions.length)];
  }

  /// Generate a random valid lyrics extension
  static String randomLyricsExtension() {
    return 'lrc';
  }

  /// Generate a random invalid extension
  static String randomInvalidExtension() {
    const extensions = ['txt', 'pdf', 'doc', 'exe', 'zip', 'xyz', 'abc'];
    return extensions[_random.nextInt(extensions.length)];
  }

  /// Generate a random local file path with given extension
  static String randomLocalPath(String extension) {
    return '/path/to/${randomString()}.$extension';
  }

  /// Generate a random URL with given extension
  static String randomUrl(String extension) {
    return 'https://${randomString()}.com/${randomString()}.$extension';
  }

  /// Generate a random valid LRC content
  static String randomValidLrcContent() {
    final lines = <String>[];
    for (var i = 0; i < _random.nextInt(10) + 1; i++) {
      final minutes = _random.nextInt(5);
      final seconds = _random.nextInt(60);
      final centiseconds = _random.nextInt(100);
      lines.add(
        '[${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${centiseconds.toString().padLeft(2, '0')}]${randomString()}',
      );
    }
    return lines.join('\n');
  }

  /// Generate invalid LRC content (no timestamps)
  static String randomInvalidLrcContent() {
    final lines = <String>[];
    for (var i = 0; i < _random.nextInt(5) + 1; i++) {
      lines.add(randomString());
    }
    return lines.join('\n');
  }
}

void main() {
  late SourceValidator validator;

  setUp(() {
    validator = SourceValidator();
  });

  group('Property 5: Source type validation', () {
    // Feature: song-unit-core, Property 5: Source type validation
    // For any Source addition operation, the System SHALL accept the Source
    // if and only if it matches one of the valid types for its category.
    // **Validates: Requirements 2.1, 2.2, 2.4**

    group('Display sources (video/image)', () {
      test('valid video files are accepted for display sources', () {
        // Property: For any valid video extension, validation for display type succeeds
        for (var i = 0; i < 100; i++) {
          final extension =
              SourceValidatorTestGenerators.randomVideoExtension();
          final path = SourceValidatorTestGenerators.randomLocalPath(extension);
          final origin = LocalFileOrigin(path);

          final result = validator.validateForType(origin, SourceType.display);

          expect(
            result.isValid,
            isTrue,
            reason:
                'Video file with extension .$extension should be valid for display',
          );
          expect(result.detectedType, equals(SourceType.display));
          expect(result.detectedDisplayType, equals(DisplayType.video));
        }
      });

      test('valid image files are accepted for display sources', () {
        // Property: For any valid image extension, validation for display type succeeds
        for (var i = 0; i < 100; i++) {
          final extension =
              SourceValidatorTestGenerators.randomImageExtension();
          final path = SourceValidatorTestGenerators.randomLocalPath(extension);
          final origin = LocalFileOrigin(path);

          final result = validator.validateForType(origin, SourceType.display);

          expect(
            result.isValid,
            isTrue,
            reason:
                'Image file with extension .$extension should be valid for display',
          );
          expect(result.detectedType, equals(SourceType.display));
          expect(result.detectedDisplayType, equals(DisplayType.image));
        }
      });

      test('video URLs are accepted for display sources', () {
        // Property: For any valid video URL, validation for display type succeeds
        for (var i = 0; i < 100; i++) {
          final extension =
              SourceValidatorTestGenerators.randomVideoExtension();
          final url = SourceValidatorTestGenerators.randomUrl(extension);
          final origin = UrlOrigin(url);

          final result = validator.validateForType(origin, SourceType.display);

          expect(
            result.isValid,
            isTrue,
            reason:
                'Video URL with extension .$extension should be valid for display',
          );
          expect(result.detectedType, equals(SourceType.display));
        }
      });

      test('image URLs are accepted for display sources', () {
        // Property: For any valid image URL, validation for display type succeeds
        for (var i = 0; i < 100; i++) {
          final extension =
              SourceValidatorTestGenerators.randomImageExtension();
          final url = SourceValidatorTestGenerators.randomUrl(extension);
          final origin = UrlOrigin(url);

          final result = validator.validateForType(origin, SourceType.display);

          expect(
            result.isValid,
            isTrue,
            reason:
                'Image URL with extension .$extension should be valid for display',
          );
          expect(result.detectedType, equals(SourceType.display));
        }
      });

      test('invalid extensions are rejected for display sources', () {
        // Property: For any invalid extension, validation for display type fails
        for (var i = 0; i < 100; i++) {
          final extension =
              SourceValidatorTestGenerators.randomInvalidExtension();
          final path = SourceValidatorTestGenerators.randomLocalPath(extension);
          final origin = LocalFileOrigin(path);

          final result = validator.validateForType(origin, SourceType.display);

          expect(
            result.isValid,
            isFalse,
            reason:
                'File with extension .$extension should be invalid for display',
          );
          expect(result.errorMessage, isNotNull);
        }
      });
    });

    group('Audio sources', () {
      test('valid audio files are accepted for audio sources', () {
        // Property: For any valid audio extension, validation for audio type succeeds
        for (var i = 0; i < 100; i++) {
          final extension =
              SourceValidatorTestGenerators.randomAudioExtension();
          final path = SourceValidatorTestGenerators.randomLocalPath(extension);
          final origin = LocalFileOrigin(path);

          final result = validator.validateForType(origin, SourceType.audio);

          expect(
            result.isValid,
            isTrue,
            reason:
                'Audio file with extension .$extension should be valid for audio',
          );
          expect(result.detectedType, equals(SourceType.audio));
          expect(result.detectedAudioFormat, isNotNull);
        }
      });

      test('video files are accepted for audio sources (extractable audio)', () {
        // Property: For any valid video extension, validation for audio type succeeds
        // (video sources can have extractable audio tracks per Requirement 2.2)
        for (var i = 0; i < 100; i++) {
          final extension =
              SourceValidatorTestGenerators.randomVideoExtension();
          final path = SourceValidatorTestGenerators.randomLocalPath(extension);
          final origin = LocalFileOrigin(path);

          final result = validator.validateForType(origin, SourceType.audio);

          expect(
            result.isValid,
            isTrue,
            reason:
                'Video file with extension .$extension should be valid for audio (extractable track)',
          );
          expect(result.detectedType, equals(SourceType.audio));
        }
      });

      test('audio URLs are accepted for audio sources', () {
        // Property: For any valid audio URL, validation for audio type succeeds
        for (var i = 0; i < 100; i++) {
          final extension =
              SourceValidatorTestGenerators.randomAudioExtension();
          final url = SourceValidatorTestGenerators.randomUrl(extension);
          final origin = UrlOrigin(url);

          final result = validator.validateForType(origin, SourceType.audio);

          expect(
            result.isValid,
            isTrue,
            reason:
                'Audio URL with extension .$extension should be valid for audio',
          );
          expect(result.detectedType, equals(SourceType.audio));
        }
      });

      test('invalid extensions are rejected for audio sources', () {
        // Property: For any invalid extension (not audio or video), validation for audio type fails
        for (var i = 0; i < 100; i++) {
          final extension =
              SourceValidatorTestGenerators.randomInvalidExtension();
          final path = SourceValidatorTestGenerators.randomLocalPath(extension);
          final origin = LocalFileOrigin(path);

          final result = validator.validateForType(origin, SourceType.audio);

          expect(
            result.isValid,
            isFalse,
            reason:
                'File with extension .$extension should be invalid for audio',
          );
          expect(result.errorMessage, isNotNull);
        }
      });
    });

    group('Accompaniment sources', () {
      test('valid audio files are accepted for accompaniment sources', () {
        // Property: For any valid audio extension, validation for accompaniment type succeeds
        for (var i = 0; i < 100; i++) {
          final extension =
              SourceValidatorTestGenerators.randomAudioExtension();
          final path = SourceValidatorTestGenerators.randomLocalPath(extension);
          final origin = LocalFileOrigin(path);

          final result = validator.validateForType(
            origin,
            SourceType.accompaniment,
          );

          expect(
            result.isValid,
            isTrue,
            reason:
                'Audio file with extension .$extension should be valid for accompaniment',
          );
          expect(result.detectedType, equals(SourceType.accompaniment));
        }
      });

      test('video files are accepted for accompaniment sources', () {
        // Property: For any valid video extension, validation for accompaniment type succeeds
        for (var i = 0; i < 100; i++) {
          final extension =
              SourceValidatorTestGenerators.randomVideoExtension();
          final path = SourceValidatorTestGenerators.randomLocalPath(extension);
          final origin = LocalFileOrigin(path);

          final result = validator.validateForType(
            origin,
            SourceType.accompaniment,
          );

          expect(
            result.isValid,
            isTrue,
            reason:
                'Video file with extension .$extension should be valid for accompaniment',
          );
          expect(result.detectedType, equals(SourceType.accompaniment));
        }
      });
    });

    group('Hover sources (lyrics)', () {
      test('valid LRC files are accepted for hover sources', () {
        // Property: For any valid LRC extension, validation for hover type succeeds
        for (var i = 0; i < 100; i++) {
          final extension =
              SourceValidatorTestGenerators.randomLyricsExtension();
          final path = SourceValidatorTestGenerators.randomLocalPath(extension);
          final origin = LocalFileOrigin(path);

          final result = validator.validateForType(origin, SourceType.hover);

          expect(
            result.isValid,
            isTrue,
            reason: 'LRC file should be valid for hover source',
          );
          expect(result.detectedType, equals(SourceType.hover));
          expect(result.detectedLyricsFormat, equals(LyricsFormat.lrc));
        }
      });

      test('LRC URLs are accepted for hover sources', () {
        // Property: For any valid LRC URL, validation for hover type succeeds
        for (var i = 0; i < 100; i++) {
          final extension =
              SourceValidatorTestGenerators.randomLyricsExtension();
          final url = SourceValidatorTestGenerators.randomUrl(extension);
          final origin = UrlOrigin(url);

          final result = validator.validateForType(origin, SourceType.hover);

          expect(
            result.isValid,
            isTrue,
            reason: 'LRC URL should be valid for hover source',
          );
          expect(result.detectedType, equals(SourceType.hover));
        }
      });

      test('non-LRC extensions are rejected for hover sources', () {
        // Property: For any non-LRC extension, validation for hover type fails
        for (var i = 0; i < 100; i++) {
          final extension =
              SourceValidatorTestGenerators.randomInvalidExtension();
          final path = SourceValidatorTestGenerators.randomLocalPath(extension);
          final origin = LocalFileOrigin(path);

          final result = validator.validateForType(origin, SourceType.hover);

          expect(
            result.isValid,
            isFalse,
            reason:
                'File with extension .$extension should be invalid for hover',
          );
          expect(result.errorMessage, isNotNull);
        }
      });

      test('audio files are rejected for hover sources', () {
        // Property: Audio files should not be valid for hover sources
        for (var i = 0; i < 100; i++) {
          final extension =
              SourceValidatorTestGenerators.randomAudioExtension();
          final path = SourceValidatorTestGenerators.randomLocalPath(extension);
          final origin = LocalFileOrigin(path);

          final result = validator.validateForType(origin, SourceType.hover);

          expect(
            result.isValid,
            isFalse,
            reason: 'Audio file should be invalid for hover source',
          );
        }
      });
    });

    group('API origins', () {
      test('API origins are always valid for any source type', () {
        // Property: API origins are validated by the API itself, so always accepted
        for (var i = 0; i < 100; i++) {
          final origin = ApiOrigin(
            SourceValidatorTestGenerators.randomString(),
            SourceValidatorTestGenerators.randomString(),
          );

          for (final sourceType in SourceType.values) {
            final result = validator.validateForType(origin, sourceType);
            expect(
              result.isValid,
              isTrue,
              reason: 'API origin should be valid for $sourceType',
            );
          }
        }
      });
    });

    group('LRC content validation', () {
      test('valid LRC content with timestamps is accepted', () {
        // Property: For any LRC content with valid timestamps, validation succeeds
        for (var i = 0; i < 100; i++) {
          final content = SourceValidatorTestGenerators.randomValidLrcContent();

          final result = validator.validateLrcContent(content);

          expect(
            result.isValid,
            isTrue,
            reason: 'Valid LRC content should be accepted',
          );
          expect(result.detectedLyricsFormat, equals(LyricsFormat.lrc));
        }
      });

      test('LRC content without timestamps is rejected', () {
        // Property: For any content without valid timestamps, validation fails
        for (var i = 0; i < 100; i++) {
          final content =
              SourceValidatorTestGenerators.randomInvalidLrcContent();

          final result = validator.validateLrcContent(content);

          expect(
            result.isValid,
            isFalse,
            reason: 'LRC content without timestamps should be rejected',
          );
          expect(result.errorMessage, isNotNull);
        }
      });

      test('empty LRC content is rejected', () {
        final result = validator.validateLrcContent('');
        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('empty'));
      });
    });
  });
}
