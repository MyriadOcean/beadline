import '../models/source.dart';
import '../models/source_origin.dart';

/// Result of a source validation
class ValidationResult {
  const ValidationResult({
    required this.isValid,
    this.errorMessage,
    this.detectedType,
    this.detectedDisplayType,
    this.detectedAudioFormat,
    this.detectedLyricsFormat,
  });

  factory ValidationResult.valid({
    required SourceType type,
    DisplayType? displayType,
    AudioFormat? audioFormat,
    LyricsFormat? lyricsFormat,
  }) {
    return ValidationResult(
      isValid: true,
      detectedType: type,
      detectedDisplayType: displayType,
      detectedAudioFormat: audioFormat,
      detectedLyricsFormat: lyricsFormat,
    );
  }

  factory ValidationResult.invalid(String message) {
    return ValidationResult(isValid: false, errorMessage: message);
  }
  final bool isValid;
  final String? errorMessage;
  final SourceType? detectedType;
  final DisplayType? detectedDisplayType;
  final AudioFormat? detectedAudioFormat;
  final LyricsFormat? detectedLyricsFormat;
}

/// Service for validating source files and URLs
class SourceValidator {
  // Supported video file extensions
  static const Set<String> videoExtensions = {
    'mp4',
    'mkv',
    'avi',
    'mov',
    'wmv',
    'flv',
    'webm',
    'm4v',
    '3gp',
  };

  // Supported audio file extensions
  static const Set<String> audioExtensions = {
    'mp3',
    'flac',
    'wav',
    'aac',
    'ogg',
    'm4a',
    'wma',
    'opus',
  };

  // Supported image file extensions
  static const Set<String> imageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'bmp',
    'webp',
    'svg',
  };

  // Supported lyrics file extensions
  static const Set<String> lyricsExtensions = {'lrc'};

  /// Validate a source origin for a specific source type
  ValidationResult validateForType(SourceOrigin origin, SourceType targetType) {
    switch (origin) {
      case LocalFileOrigin(:final path):
        return _validateLocalFile(path, targetType);
      case UrlOrigin(:final url):
        return _validateUrl(url, targetType);
      case ApiOrigin():
        // API origins are always considered valid as they're validated by the API
        return _validResultForType(targetType);
    }
  }

  /// Validate a local file path
  ValidationResult _validateLocalFile(String path, SourceType targetType) {
    final extension = _getExtension(path);
    if (extension == null) {
      return ValidationResult.invalid('File has no extension: $path');
    }

    return _validateExtension(extension, targetType);
  }

  /// Validate a URL
  ValidationResult _validateUrl(String url, SourceType targetType) {
    // Check if URL is well-formed
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      return ValidationResult.invalid('Invalid URL format: $url');
    }

    // Check for supported schemes
    if (!['http', 'https', 'file'].contains(uri.scheme.toLowerCase())) {
      return ValidationResult.invalid('Unsupported URL scheme: ${uri.scheme}');
    }

    // Try to extract extension from URL path
    final extension = _getExtension(uri.path);
    if (extension != null) {
      return _validateExtension(extension, targetType);
    }

    // For URLs without clear extensions, accept based on target type
    // (streaming URLs often don't have file extensions)
    return _validResultForType(targetType);
  }

  /// Extract file extension from a path
  String? _getExtension(String path) {
    final lastDot = path.lastIndexOf('.');
    if (lastDot == -1 || lastDot == path.length - 1) {
      return null;
    }
    // Handle query strings in URLs
    final extensionPart = path.substring(lastDot + 1);
    final queryIndex = extensionPart.indexOf('?');
    if (queryIndex != -1) {
      return extensionPart.substring(0, queryIndex).toLowerCase();
    }
    return extensionPart.toLowerCase();
  }

  /// Validate an extension against a target source type
  ValidationResult _validateExtension(String extension, SourceType targetType) {
    switch (targetType) {
      case SourceType.display:
        if (videoExtensions.contains(extension)) {
          return ValidationResult.valid(
            type: SourceType.display,
            displayType: DisplayType.video,
          );
        }
        if (imageExtensions.contains(extension)) {
          return ValidationResult.valid(
            type: SourceType.display,
            displayType: DisplayType.image,
          );
        }
        return ValidationResult.invalid(
          'Invalid display source extension: $extension. '
          'Expected video (${videoExtensions.join(", ")}) or '
          'image (${imageExtensions.join(", ")})',
        );

      case SourceType.audio:
      case SourceType.accompaniment:
        if (audioExtensions.contains(extension)) {
          return ValidationResult.valid(
            type: targetType,
            audioFormat: _extensionToAudioFormat(extension),
          );
        }
        // Video files can also be used as audio sources (extract audio track)
        if (videoExtensions.contains(extension)) {
          return ValidationResult.valid(
            type: targetType,
            audioFormat: AudioFormat.other,
          );
        }
        return ValidationResult.invalid(
          'Invalid audio source extension: $extension. '
          'Expected audio (${audioExtensions.join(", ")}) or '
          'video (${videoExtensions.join(", ")})',
        );

      case SourceType.hover:
        if (lyricsExtensions.contains(extension)) {
          return ValidationResult.valid(
            type: SourceType.hover,
            lyricsFormat: LyricsFormat.lrc,
          );
        }
        return ValidationResult.invalid(
          'Invalid lyrics source extension: $extension. '
          'Expected: ${lyricsExtensions.join(", ")}',
        );
    }
  }

  /// Create a valid result for a given source type (for API origins or extensionless URLs)
  ValidationResult _validResultForType(SourceType targetType) {
    switch (targetType) {
      case SourceType.display:
        return ValidationResult.valid(
          type: SourceType.display,
          displayType: DisplayType.video, // Default to video for unknown
        );
      case SourceType.audio:
        return ValidationResult.valid(
          type: SourceType.audio,
          audioFormat: AudioFormat.other,
        );
      case SourceType.accompaniment:
        return ValidationResult.valid(
          type: SourceType.accompaniment,
          audioFormat: AudioFormat.other,
        );
      case SourceType.hover:
        return ValidationResult.valid(
          type: SourceType.hover,
          lyricsFormat: LyricsFormat.lrc,
        );
    }
  }

  /// Convert file extension to AudioFormat
  AudioFormat _extensionToAudioFormat(String extension) {
    switch (extension) {
      case 'mp3':
        return AudioFormat.mp3;
      case 'flac':
        return AudioFormat.flac;
      case 'wav':
        return AudioFormat.wav;
      case 'aac':
        return AudioFormat.aac;
      case 'ogg':
      case 'opus':
        return AudioFormat.ogg;
      case 'm4a':
        return AudioFormat.m4a;
      default:
        return AudioFormat.other;
    }
  }

  /// Auto-detect source type from a local file path
  ValidationResult detectSourceType(String path) {
    final extension = _getExtension(path);
    if (extension == null) {
      return ValidationResult.invalid(
        'Cannot detect type: file has no extension',
      );
    }

    if (videoExtensions.contains(extension)) {
      return ValidationResult.valid(
        type: SourceType.display,
        displayType: DisplayType.video,
      );
    }
    if (imageExtensions.contains(extension)) {
      return ValidationResult.valid(
        type: SourceType.display,
        displayType: DisplayType.image,
      );
    }
    if (audioExtensions.contains(extension)) {
      return ValidationResult.valid(
        type: SourceType.audio,
        audioFormat: _extensionToAudioFormat(extension),
      );
    }
    if (lyricsExtensions.contains(extension)) {
      return ValidationResult.valid(
        type: SourceType.hover,
        lyricsFormat: LyricsFormat.lrc,
      );
    }

    return ValidationResult.invalid('Unknown file extension: $extension');
  }

  /// Validate LRC content format
  ValidationResult validateLrcContent(String content) {
    if (content.trim().isEmpty) {
      return ValidationResult.invalid('LRC content is empty');
    }

    // LRC files should contain at least one timestamp line
    // Format: [mm:ss.xx] or [mm:ss:xx] or [mm:ss]
    final timestampPattern = RegExp(r'\[\d{1,2}:\d{2}(?:[.:]\d{2,3})?\]');
    if (!timestampPattern.hasMatch(content)) {
      return ValidationResult.invalid(
        'Invalid LRC format: no valid timestamps found',
      );
    }

    return ValidationResult.valid(
      type: SourceType.hover,
      lyricsFormat: LyricsFormat.lrc,
    );
  }

  /// Check if a file extension is a valid video format
  bool isVideoExtension(String extension) {
    return videoExtensions.contains(extension.toLowerCase());
  }

  /// Check if a file extension is a valid audio format
  bool isAudioExtension(String extension) {
    return audioExtensions.contains(extension.toLowerCase());
  }

  /// Check if a file extension is a valid image format
  bool isImageExtension(String extension) {
    return imageExtensions.contains(extension.toLowerCase());
  }

  /// Check if a file extension is a valid lyrics format
  bool isLyricsExtension(String extension) {
    return lyricsExtensions.contains(extension.toLowerCase());
  }

  /// Get all supported extensions for a source type
  Set<String> getSupportedExtensions(SourceType type) {
    switch (type) {
      case SourceType.display:
        return {...videoExtensions, ...imageExtensions};
      case SourceType.audio:
      case SourceType.accompaniment:
        return {...audioExtensions, ...videoExtensions};
      case SourceType.hover:
        return lyricsExtensions;
    }
  }
}
