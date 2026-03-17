import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Value object for cache statistics.
class CacheStats {
  const CacheStats({
    required this.totalEntries,
    required this.totalBytes,
    required this.orphanCount,
  });

  final int totalEntries;
  final int totalBytes;
  final int orphanCount;
}

/// Content-addressed thumbnail cache.
///
/// Thumbnails are stored as `<sha256hex>.jpg` under the cache directory.
/// Identical artwork is stored exactly once regardless of how many Song Units
/// share it. The returned content hash is stored as `thumbnailSourceId` on
/// `Metadata`.
class ThumbnailCache {
  ThumbnailCache._();

  static final ThumbnailCache instance = ThumbnailCache._();

  String? _cacheDir;
  Timer? _purgeDebounceTimer;
  Future<Set<String>> Function()? _referencedHashesProvider;

  /// Initialize the cache directory (idempotent).
  Future<void> initialize() async {
    if (_cacheDir != null) return;
    final appDir = await getApplicationDocumentsDirectory();
    _cacheDir = path.join(appDir.path, 'beadline', 'thumbnail_cache');
    final dir = Directory(_cacheDir!);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
  }

  String get _cacheDirPath {
    assert(
      _cacheDir != null,
      'ThumbnailCache.initialize() must be called first',
    );
    return _cacheDir!;
  }

  /// Cache [bytes] and return the 64-char hex SHA-256 content hash.
  ///
  /// If a file with the same hash already exists, it is not overwritten.
  Future<String> cacheFromBytes(List<int> bytes) async {
    await initialize();
    final hash = sha256.convert(bytes).toString();
    final file = File(path.join(_cacheDirPath, '$hash.jpg'));
    if (!file.existsSync()) {
      await file.writeAsBytes(bytes);
    }
    return hash;
  }

  /// Return the absolute path of the cached thumbnail for [contentHash],
  /// or `null` if no such entry exists or the hash is not 64 characters.
  Future<String?> getThumbnail(String contentHash) async {
    await initialize();
    if (contentHash.length != 64) return null;
    final file = File(path.join(_cacheDirPath, '$contentHash.jpg'));
    return file.existsSync() ? file.path : null;
  }

  /// Get thumbnail path from metadata (convenience method for display components).
  Future<String?> getThumbnailFromMetadata(dynamic metadata) async {
    if (metadata.thumbnailSourceId != null) {
      return getThumbnail(metadata.thumbnailSourceId as String);
    }
    return null;
  }

  /// Delete `.jpg` files in the cache directory whose stem is not in
  /// [referencedHashes]. Returns the count of files deleted.
  Future<int> purgeOrphans(Set<String> referencedHashes) async {
    await initialize();
    final dir = Directory(_cacheDirPath);
    if (!dir.existsSync()) return 0;

    var deleted = 0;
    for (final entity in dir.listSync()) {
      if (entity is! File) continue;
      if (path.extension(entity.path).toLowerCase() != '.jpg') continue;
      final stem = path.basenameWithoutExtension(entity.path);
      if (!referencedHashes.contains(stem)) {
        try {
          await entity.delete();
          deleted++;
        } catch (e) {
          debugPrint('ThumbnailCache: failed to delete ${entity.path}: $e');
        }
      }
    }
    return deleted;
  }

  /// Return the subset of [referencedHashes] whose `.jpg` files do not exist.
  Future<Set<String>> findMissingEntries(Set<String> referencedHashes) async {
    await initialize();
    final missing = <String>{};
    for (final hash in referencedHashes) {
      final file = File(path.join(_cacheDirPath, '$hash.jpg'));
      if (!file.existsSync()) {
        missing.add(hash);
      }
    }
    return missing;
  }

  /// Return aggregate statistics for the cache relative to [referencedHashes].
  Future<CacheStats> getCacheStats(Set<String> referencedHashes) async {
    await initialize();
    final dir = Directory(_cacheDirPath);
    if (!dir.existsSync()) {
      return const CacheStats(
        totalEntries: 0,
        totalBytes: 0,
        orphanCount: 0,
      );
    }

    var totalEntries = 0;
    var totalBytes = 0;
    var orphanCount = 0;

    for (final entity in dir.listSync()) {
      if (entity is! File) continue;
      if (path.extension(entity.path).toLowerCase() != '.jpg') continue;
      totalEntries++;
      totalBytes += entity.lengthSync();
      final stem = path.basenameWithoutExtension(entity.path);
      if (!referencedHashes.contains(stem)) {
        orphanCount++;
      }
    }

    return CacheStats(
      totalEntries: totalEntries,
      totalBytes: totalBytes,
      orphanCount: orphanCount,
    );
  }

  /// Register a provider that returns the current set of referenced hashes.
  /// Called by [schedulePurge] when the debounce timer fires.
  // ignore: use_setters_to_change_properties
  void registerHashesProvider(Future<Set<String>> Function() provider) {
    _referencedHashesProvider = provider;
  }

  /// Schedule a purge to run after a 30-second debounce.
  /// Multiple calls within the window collapse into a single purge.
  void schedulePurge() {
    _purgeDebounceTimer?.cancel();
    _purgeDebounceTimer = Timer(const Duration(seconds: 30), () async {
      try {
        final provider = _referencedHashesProvider;
        if (provider == null) return;
        final hashes = await provider();
        await purgeOrphans(hashes);
        debugPrint('ThumbnailCache: scheduled purge complete');
      } catch (e) {
        debugPrint('ThumbnailCache: scheduled purge failed: $e');
      }
    });
  }

  /// Get cache directory path (for diagnostics).
  Future<String> getCachePath() async {
    await initialize();
    return _cacheDirPath;
  }
}
