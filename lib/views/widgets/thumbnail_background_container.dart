import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/metadata.dart';
import '../../services/thumbnail_cache.dart';

/// Container that optionally shows thumbnail as background with gradient overlay
class ThumbnailBackgroundContainer extends StatefulWidget {
  const ThumbnailBackgroundContainer({
    required this.metadata,
    required this.useThumbnailBackground,
    required this.fallbackSourceIds,
    required this.child,
    super.key,
  });

  final Metadata metadata;
  final bool useThumbnailBackground;
  final List<String> fallbackSourceIds;
  final Widget child;

  @override
  State<ThumbnailBackgroundContainer> createState() =>
      _ThumbnailBackgroundContainerState();
}

class _ThumbnailBackgroundContainerState
    extends State<ThumbnailBackgroundContainer> {
  String? _cachedThumbnailPath;
  bool _isLoading = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(ThumbnailBackgroundContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only reload if thumbnail source ID changed
    if (oldWidget.metadata.thumbnailSourceId !=
        widget.metadata.thumbnailSourceId) {
      _loadThumbnail();
    }
  }

  Future<void> _loadThumbnail() async {
    // Early exit if no thumbnail needed
    if (!widget.useThumbnailBackground) return;

    // No primary ID and no fallbacks - nothing to look up
    if (widget.metadata.thumbnailSourceId == null &&
        widget.fallbackSourceIds.isEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Try primary thumbnailSourceId first
      String? thumbnailPath;
      if (widget.metadata.thumbnailSourceId != null) {
        thumbnailPath = await ThumbnailCache.instance
            .getThumbnailFromMetadata(widget.metadata);
      }

      // Try fallback source IDs
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
    // No thumbnail needed
    if (!widget.useThumbnailBackground) {
      return widget.child;
    }

    // No primary ID and no fallbacks
    if (widget.metadata.thumbnailSourceId == null &&
        widget.fallbackSourceIds.isEmpty) {
      return widget.child;
    }

    // Still loading or error - show child without background
    if (_isLoading || _hasError || _cachedThumbnailPath == null) {
      return widget.child;
    }

    // Check if file exists
    final file = File(_cachedThumbnailPath!);
    if (!file.existsSync()) {
      return widget.child;
    }

    // Show thumbnail background
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: FileImage(file),
          fit: BoxFit.cover,
          opacity: 0.2,
          onError: (error, stackTrace) {},
        ),
      ),
      child: widget.child,
    );
  }
}
