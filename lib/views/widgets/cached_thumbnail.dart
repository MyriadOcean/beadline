import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/metadata.dart';
import '../../services/thumbnail_cache.dart';

/// Widget that displays a thumbnail from cache using metadata.thumbnailSourceId
/// Falls back to checking [fallbackSourceIds] in the cache, then to a placeholder icon
class CachedThumbnail extends StatefulWidget {
  const CachedThumbnail({
    super.key,
    required this.metadata,
    this.fallbackSourceIds = const [],
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholderIcon = Icons.music_note,
    this.placeholderColor,
    this.placeholderBackgroundColor,
  });

  final Metadata metadata;

  /// Audio/accompaniment source IDs to check in the cache as fallback
  /// when [metadata.thumbnailSourceId] is null or not cached.
  /// The editor caches thumbnails by source ID, so these can pick up
  /// thumbnails that were extracted in the editor but not yet saved
  /// back to the song unit's metadata.
  final List<String> fallbackSourceIds;

  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final IconData placeholderIcon;
  final Color? placeholderColor;
  final Color? placeholderBackgroundColor;

  @override
  State<CachedThumbnail> createState() => _CachedThumbnailState();
}

class _CachedThumbnailState extends State<CachedThumbnail> {
  String? _cachedThumbnailPath;
  bool _isLoading = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(CachedThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.metadata.thumbnailSourceId !=
            widget.metadata.thumbnailSourceId ||
        oldWidget.metadata != widget.metadata ||
        !_listEquals(oldWidget.fallbackSourceIds, widget.fallbackSourceIds)) {
      _loadThumbnail();
    }
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _loadThumbnail() async {
    if (_isLoading) return;

    // If no thumbnail source ID and no fallbacks, show placeholder
    if (widget.metadata.thumbnailSourceId == null &&
        widget.fallbackSourceIds.isEmpty) {
      if (mounted && _cachedThumbnailPath != null) {
        setState(() {
          _cachedThumbnailPath = null;
          _hasError = false;
          _isLoading = false;
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
      _cachedThumbnailPath = null;
    });

    try {
      // Try primary thumbnailSourceId first
      String? thumbnailPath;
      if (widget.metadata.thumbnailSourceId != null) {
        thumbnailPath = await ThumbnailCache.instance
            .getThumbnailFromMetadata(widget.metadata);
      }

      // If not found, try fallback source IDs
      if (thumbnailPath == null) {
        for (final sourceId in widget.fallbackSourceIds) {
          thumbnailPath = await ThumbnailCache.instance.getThumbnail(sourceId);
          if (thumbnailPath != null) break;
        }
      }

      if (mounted) {
        setState(() {
          _cachedThumbnailPath = thumbnailPath;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // If no thumbnail source ID and no fallbacks, always show placeholder
    if (widget.metadata.thumbnailSourceId == null &&
        widget.fallbackSourceIds.isEmpty) {
      return _buildPlaceholder(theme);
    }

    // Show placeholder if error, still loading, or no cached path
    if (_hasError || _isLoading || _cachedThumbnailPath == null) {
      return _buildPlaceholder(theme);
    }

    final file = File(_cachedThumbnailPath!);
    if (!file.existsSync()) {
      return _buildPlaceholder(theme);
    }

    final image = Image.file(
      file,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      errorBuilder: (context, error, stackTrace) {
        if (mounted) {
          setState(() {
            _hasError = true;
          });
        }
        return _buildPlaceholder(theme);
      },
    );

    if (widget.borderRadius != null) {
      return ClipRRect(borderRadius: widget.borderRadius!, child: image);
    }
    return image;
  }

  Widget _buildPlaceholder(ThemeData theme) {
    final bgColor =
        widget.placeholderBackgroundColor ?? theme.colorScheme.primaryContainer;
    final iconColor =
        widget.placeholderColor ?? theme.colorScheme.onPrimaryContainer;

    final placeholder = Container(
      width: widget.width,
      height: widget.height,
      color: bgColor,
      child: Center(
        child: Icon(
          widget.placeholderIcon,
          size: (widget.width != null && widget.height != null)
              ? (widget.width! + widget.height!) / 4
              : 48,
          color: iconColor,
        ),
      ),
    );

    if (widget.borderRadius != null) {
      return ClipRRect(borderRadius: widget.borderRadius!, child: placeholder);
    }
    return placeholder;
  }
}
