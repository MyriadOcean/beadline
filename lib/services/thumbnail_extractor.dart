import 'package:flutter/foundation.dart';

import '../src/rust/api/media_api.dart' as rust_media;

/// Service for extracting thumbnails from audio files via lofty (Rust FFI).
///
/// Replaces the old manual binary-parsing approach with a single call
/// to the Rust `lofty` crate (MP3, FLAC, M4A, OGG, WAV, etc.).
class ThumbnailExtractor {
  /// Extract embedded artwork bytes from an audio file.
  /// Returns raw image bytes (JPEG/PNG), or null if none.
  Future<Uint8List?> extractThumbnailBytes(String audioFilePath) async {
    try {
      final meta = await rust_media.extractMediaMetadata(
        filePath: audioFilePath,
      );
      if (meta == null || meta.artwork.isEmpty) return null;
      return meta.artwork;
    } catch (e) {
      debugPrint('ThumbnailExtractor: lofty error: $e');
      return null;
    }
  }

  /// Legacy API - returns null. Callers should use extractThumbnailBytes
  /// + ThumbnailCache.cacheFromBytes instead.
  Future<String?> extractThumbnail(String audioFilePath) async {
    return null;
  }
}
